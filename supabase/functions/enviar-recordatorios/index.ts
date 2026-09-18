// ==============================================================================
// Supabase Edge Function: enviar-recordatorios
// Despacho de notificaciones push de recordatorios diarios vía FCM API v1
// ==============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2.48.1';
import * as jose from 'npm:jose@5.9.6';

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface RecordatorioCumpleanos {
  entorno_id: string;
  evento_id: string;
  persona_cumpleanos: string;
  ideas_regalo: string | null;
  dias_restantes: number;
}

interface RecordatorioTarea {
  entorno_id: string;
  tarea_id: string;
  titulo: string;
  tiempo_estimado_minutos: number;
  asignado_a: string;
}

// Cabeceras CORS
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Cache en memoria para access_token de Google OAuth2
let cachedGoogleToken: string | null = null;
let googleTokenExpiresAt = 0; // ms

/**
 * Genera un JWT firmado con RS256 y obtiene un access_token para FCM API v1
 */
async function getGoogleAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Date.now();
  if (cachedGoogleToken && now < googleTokenExpiresAt - 60000) {
    return cachedGoogleToken;
  }

  // Normalizar clave privada reemplazando saltos de línea escapados si vinieron como literal \n
  const formattedKey = serviceAccount.private_key.includes('\\n')
    ? serviceAccount.private_key.replace(/\\n/g, '\n')
    : serviceAccount.private_key;

  // Importar clave privada en formato PKCS#8
  const privateKey = await jose.importPKCS8(formattedKey, 'RS256');

  // Firmar JWT
  const jwt = await new jose.SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(privateKey);

  // Intercambiar JWT por access_token OAuth2
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`Error en Google OAuth2 (${tokenResponse.status}): ${errorText}`);
  }

  const tokenData = await tokenResponse.json();
  cachedGoogleToken = tokenData.access_token;
  googleTokenExpiresAt = now + (tokenData.expires_in * 1000);

  return cachedGoogleToken!;
}

/**
 * Envía un mensaje individual a través de FCM HTTP v1
 */
async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
  dataPayload: Record<string, string> = {}
): Promise<{ success: boolean; error?: string; unregistered?: boolean }> {
  try {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: {
              title,
              body,
            },
            data: {
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              ...dataPayload,
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channel_id: 'marthapp_planificador',
              },
            },
          },
        }),
      }
    );

    if (response.ok) {
      return { success: true };
    }

    const errorJson = await response.json().catch(() => null);
    const errorCode = errorJson?.error?.details?.[0]?.errorCode;
    const isUnregistered =
      response.status === 404 ||
      errorCode === 'UNREGISTERED' ||
      errorJson?.error?.status === 'NOT_FOUND';

    return {
      success: false,
      error: `Status ${response.status}: ${JSON.stringify(errorJson)}`,
      unregistered: isUnregistered,
    };
  } catch (err: unknown) {
    return {
      success: false,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Inicializar cliente Supabase Admin (Service Role)
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Faltan variables de entorno SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY');
    }
    if (!serviceAccountRaw) {
      throw new Error('Falta el secret FIREBASE_SERVICE_ACCOUNT con la Service Account de Firebase');
    }

    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountRaw);
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 2. Obtener Token de Google OAuth2 para FCM API v1
    const accessToken = await getGoogleAccessToken(serviceAccount);

    // 3. Consultar Cumpleaños a notificar (14 días, 7 días, 3 días o Hoy)
    let cumpleanosList: RecordatorioCumpleanos[] = [];
    const { data: rawCumpleanos, error: errorCumple } = await supabase.rpc(
      'planificador_obtener_cumpleanos_recordatorios'
    );
    if (!errorCumple && rawCumpleanos) {
      cumpleanosList = rawCumpleanos;
    } else {
      console.warn('Fallback a consulta directa de cumpleaños:', errorCumple?.message);
      const { data: directEventos } = await supabase
        .from('planificador_eventos')
        .select('id, entorno_id, titulo, persona_cumpleanos, ideas_regalo, fecha_inicio')
        .eq('tipo', 'cumpleanos');

      if (directEventos) {
        const today = new Date();
        const targetOffsets = [0, 3, 7, 14];
        for (const ev of directEventos) {
          const evDate = new Date(ev.fecha_inicio);
          const evMonth = evDate.getUTCMonth();
          const evDay = evDate.getUTCDate();

          for (const offset of targetOffsets) {
            const targetDate = new Date(today);
            targetDate.setUTCDate(today.getUTCDate() + offset);
            if (targetDate.getUTCMonth() === evMonth && targetDate.getUTCDate() === evDay) {
              cumpleanosList.push({
                entorno_id: ev.entorno_id,
                evento_id: ev.id,
                persona_cumpleanos: ev.persona_cumpleanos || ev.titulo,
                ideas_regalo: ev.ideas_regalo,
                dias_restantes: offset,
              });
              break;
            }
          }
        }
      }
    }

    // 4. Consultar Tareas cuya fecha_limite::DATE = CURRENT_DATE y no completadas
    let tareasList: RecordatorioTarea[] = [];
    const { data: rawTareas, error: errorTareas } = await supabase.rpc(
      'planificador_obtener_tareas_hoy'
    );
    if (!errorTareas && rawTareas) {
      tareasList = rawTareas;
    } else {
      console.warn('Fallback a consulta directa de tareas:', errorTareas?.message);
      const todayIso = new Date().toISOString().split('T')[0];
      const { data: directTareas } = await supabase
        .from('planificador_tareas')
        .select('id, entorno_id, titulo, tiempo_estimado_minutos, asignado_a, fecha_limite')
        .neq('estado', 'completada')
        .not('asignado_a', 'is', null)
        .gte('fecha_limite', `${todayIso}T00:00:00.000Z`)
        .lte('fecha_limite', `${todayIso}T23:59:59.999Z`);

      if (directTareas) {
        tareasList = directTareas.map((t) => ({
          entorno_id: t.entorno_id,
          tarea_id: t.id,
          titulo: t.titulo,
          tiempo_estimado_minutos: t.tiempo_estimado_minutos,
          asignado_a: t.asignado_a,
        }));
      }
    }

    let totalEnviados = 0;
    let totalFallidos = 0;
    const tokensInvalidosAEliminar: string[] = [];

    // 5. Procesar Recordatorios de Cumpleaños
    for (const cumple of cumpleanosList) {
      // Obtener todos los tokens FCM de los miembros del entorno
      const { data: tokensData } = await supabase
        .from('usuario_fcm_tokens')
        .select('fcm_token, user_id')
        .eq('entorno_id', cumple.entorno_id);

      if (!tokensData || tokensData.length === 0) continue;

      let titulo = '🎂 Recordatorio de Cumpleaños';
      let mensaje = '';

      if (cumple.dias_restantes === 0) {
        titulo = '🎉 ¡Hoy es un día especial!';
        mensaje = `¡Hoy es el cumpleaños de ${cumple.persona_cumpleanos}! Deséale un feliz día.`;
      } else if (cumple.dias_restantes === 3) {
        mensaje = `¡Solo quedan 3 días para el cumpleaños de ${cumple.persona_cumpleanos}!`;
        if (cumple.ideas_regalo) {
          mensaje += ` Ideas de regalo: ${cumple.ideas_regalo}`;
        }
      } else if (cumple.dias_restantes === 7) {
        mensaje = `Falta exactamente 1 semana para el cumpleaños de ${cumple.persona_cumpleanos}.`;
      } else if (cumple.dias_restantes === 14) {
        mensaje = `Faltan 2 semanas para el cumpleaños de ${cumple.persona_cumpleanos}. ¡Buen momento para planear regalos!`;
      }

      for (const t of tokensData) {
        const result = await sendFcmMessage(
          serviceAccount.project_id,
          accessToken,
          t.fcm_token,
          titulo,
          mensaje,
          {
            tipo: 'cumpleanos',
            evento_id: cumple.evento_id,
            entorno_id: cumple.entorno_id,
          }
        );

        if (result.success) {
          totalEnviados++;
        } else {
          totalFallidos++;
          if (result.unregistered) {
            tokensInvalidosAEliminar.push(t.fcm_token);
          }
        }
      }
    }

    // 6. Procesar Recordatorios de Tareas para Hoy
    for (const tarea of tareasList) {
      if (!tarea.asignado_a) continue;

      // Obtener tokens FCM del responsable asignado en este entorno
      const { data: tokensData } = await supabase
        .from('usuario_fcm_tokens')
        .select('fcm_token')
        .eq('entorno_id', tarea.entorno_id)
        .eq('user_id', tarea.asignado_a);

      if (!tokensData || tokensData.length === 0) continue;

      const titulo = '📋 Tarea para hoy';
      const mensaje = `Tienes programada para hoy: "${tarea.titulo}" (~${tarea.tiempo_estimado_minutos} min).`;

      for (const t of tokensData) {
        const result = await sendFcmMessage(
          serviceAccount.project_id,
          accessToken,
          t.fcm_token,
          titulo,
          mensaje,
          {
            tipo: 'tarea_hoy',
            tarea_id: tarea.tarea_id,
            entorno_id: tarea.entorno_id,
          }
        );

        if (result.success) {
          totalEnviados++;
        } else {
          totalFallidos++;
          if (result.unregistered) {
            tokensInvalidosAEliminar.push(t.fcm_token);
          }
        }
      }
    }

    // 7. Poda preventiva de tokens caducados/desregistrados
    if (tokensInvalidosAEliminar.length > 0) {
      await supabase
        .from('usuario_fcm_tokens')
        .delete()
        .in('fcm_token', tokensInvalidosAEliminar);
    }

    return new Response(
      JSON.stringify({
        success: true,
        cumpleanos_evaluados: cumpleanosList.length,
        tareas_evaluadas: tareasList.length,
        notificaciones_enviadas: totalEnviados,
        notificaciones_fallidas: totalFallidos,
        tokens_purgados: tokensInvalidosAEliminar.length,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: unknown) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.error('Error en enviar-recordatorios:', errorMsg);
    return new Response(
      JSON.stringify({ success: false, error: errorMsg }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
