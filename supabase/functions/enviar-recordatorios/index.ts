// ==============================================================================
// Supabase Edge Function: enviar-recordatorios
// Despacho de notificaciones push de recordatorios diarios vía FCM API v1
// Soporta personalización dinámica de cumpleaños con entidades normalizadas (profiles.birth_date)
// y agrupamiento de múltiples cumpleañeros en la misma fecha.
// ==============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2.48.1';
import * as jose from 'npm:jose@5.9.6';

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface GrupoCumpleanosEntorno {
  entorno_id: string;
  dias_restantes: number;
  names: string[];
  ideas_regalo?: string | null;
  evento_id?: string | null;
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
 * Resuelve la conjunción copulativa adecuada ('y' o 'e') en español
 */
export function resolveConjunction(nextWord: string): string {
  const lower = nextWord.toLowerCase().trim();
  if (
    lower.startsWith('hie') ||
    lower.startsWith('hia') ||
    lower.startsWith('hio') ||
    lower.startsWith('hiu')
  ) {
    return 'y';
  }
  if (lower.startsWith('i') || lower.startsWith('hi')) {
    return 'e';
  }
  return 'y';
}

/**
 * Formatea una lista de nombres con gramática española correcta:
 * - 1 persona: "Laura"
 * - 2 personas: "Juan y María" / "Laura e Ignacio"
 * - 3+ personas: "Juan, María y Pedro"
 */
export function formatNameList(rawNames: string[]): string {
  const cleanNames: string[] = [];
  for (const raw of rawNames) {
    const trimmed = raw.trim();
    if (trimmed.length > 0 && !cleanNames.includes(trimmed)) {
      cleanNames.push(trimmed);
    }
  }

  if (cleanNames.length === 0) return '';
  if (cleanNames.length === 1) return cleanNames[0];
  if (cleanNames.length === 2) {
    const connector = resolveConjunction(cleanNames[1]);
    return `${cleanNames[0]} ${connector} ${cleanNames[1]}`;
  }

  const allExceptLast = cleanNames.slice(0, cleanNames.length - 1);
  const last = cleanNames[cleanNames.length - 1];
  const connector = resolveConjunction(last);
  return `${allExceptLast.join(', ')} ${connector} ${last}`;
}

/**
 * Compone el mensaje dinámico (título y cuerpo) a partir de los cumpleañeros coincidentes
 * sustituyendo plantillas estáticas por variables reales.
 */
export function formatBirthdayNotification(
  names: string[],
  diasRestantes = 0,
  ideasRegalo?: string | null
): { title: string; body: string } {
  const cleanNames = Array.from(new Set(names.map((n) => n.trim()).filter((n) => n.length > 0)));

  if (cleanNames.length === 0) {
    return {
      title: '🎂 Recordatorio de Cumpleaños',
      body: 'Hay un cumpleaños próximo en tu entorno.',
    };
  }

  const formattedNames = formatNameList(cleanNames);
  const isMultiple = cleanNames.length > 1;

  switch (diasRestantes) {
    case 0: // Hoy
      if (!isMultiple) {
        return {
          title: `¡Hoy es el cumpleaños de ${formattedNames}! 🎂`,
          body: `Felicita a ${formattedNames} en su día especial.`,
        };
      } else {
        return {
          title: `${formattedNames} cumplen años hoy 🎂`,
          body: `¡Hoy es el cumpleaños de ${formattedNames}! Deséales un feliz día especial.`,
        };
      }

    case 1: // Mañana
      if (!isMultiple) {
        return {
          title: `🎂 ¡Mañana es el cumpleaños de ${formattedNames}!`,
          body: `Mañana es el cumpleaños de ${formattedNames}. ¡Felicítale en su día!`,
        };
      } else {
        return {
          title: `🎂 ¡Mañana es el cumpleaños de ${formattedNames}!`,
          body: `Mañana cumplen años ${formattedNames}. ¡Deséales un gran día!`,
        };
      }

    case 3:
      if (!isMultiple) {
        let body = `¡Solo quedan 3 días para el cumpleaños de ${formattedNames}!`;
        if (ideasRegalo && ideasRegalo.trim().length > 0) {
          body += ` Ideas de regalo: ${ideasRegalo.trim()}`;
        }
        return {
          title: `🎂 Próximo cumpleaños: ${formattedNames}`,
          body,
        };
      } else {
        return {
          title: `🎂 Próximos cumpleaños: ${formattedNames}`,
          body: `¡Solo quedan 3 días para el cumpleaños de ${formattedNames}!`,
        };
      }

    case 7:
      return {
        title: isMultiple
          ? `🎂 Próximos cumpleaños: ${formattedNames}`
          : `🎂 Próximo cumpleaños: ${formattedNames}`,
        body: `Falta exactamente 1 semana para el cumpleaños de ${formattedNames}.`,
      };

    case 14:
      return {
        title: isMultiple
          ? `🎂 Próximos cumpleaños: ${formattedNames}`
          : `🎂 Próximo cumpleaños: ${formattedNames}`,
        body: `Faltan 2 semanas para el cumpleaños de ${formattedNames}. ¡Buen momento para planear regalos!`,
      };

    default:
      return {
        title: `🎂 Cumpleaños de ${formattedNames}`,
        body: `Quedan ${diasRestantes} días para el cumpleaños de ${formattedNames}.`,
      };
  }
}

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
 * Envía un mensaje individual a través de FCM HTTP v1 respetando los contratos
 * de entrega en foreground, background y killed state (Android / iOS APNS).
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
    const stringData: Record<string, string> = {
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      title: title || '',
      body: body || '',
    };
    for (const [k, v] of Object.entries(dataPayload)) {
      stringData[k] = typeof v === 'string' ? v : String(v);
    }

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
            data: stringData,
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channel_id: 'marthapp_notifications',
                icon: 'ic_notification',
                color: '#7CBCA2',
                priority: 'max',
                default_sound: true,
                default_vibrate_timings: true,
                visibility: 'public',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
              },
            },
            apns: {
              headers: {
                'apns-priority': '10',
                'apns-push-type': 'alert',
              },
              payload: {
                aps: {
                  alert: {
                    title,
                    body,
                  },
                  sound: 'default',
                  badge: 1,
                  'content-available': 1,
                  category: 'FLUTTER_NOTIFICATION_CLICK',
                },
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

    // 3. Consultar Cumpleaños normalizados agrupados por entorno y días restantes
    const gruposMap = new Map<string, GrupoCumpleanosEntorno>();

    // 3.1. Intentar RPC optimizada agrupada desde la entidad canónica profiles.birth_date
    const { data: rawGrupos, error: errorGrupos } = await supabase.rpc(
      'obtener_cumpleanos_entornos_recordatorios'
    );

    if (!errorGrupos && rawGrupos && rawGrupos.length > 0) {
      for (const item of rawGrupos) {
        const key = `${item.entorno_id}_${item.dias_restantes}`;
        gruposMap.set(key, {
          entorno_id: item.entorno_id,
          dias_restantes: item.dias_restantes,
          names: item.nombres_cumpleaneros || [],
        });
      }
    } else {
      // 3.2. Fallback a planificador_obtener_cumpleanos_recordatorios
      const { data: rawCumpleanos, error: errorCumple } = await supabase.rpc(
        'planificador_obtener_cumpleanos_recordatorios'
      );

      if (!errorCumple && rawCumpleanos) {
        for (const item of rawCumpleanos) {
          const key = `${item.entorno_id}_${item.dias_restantes}`;
          const existing = gruposMap.get(key) || {
            entorno_id: item.entorno_id,
            dias_restantes: item.dias_restantes,
            names: [],
            ideas_regalo: item.ideas_regalo,
            evento_id: item.evento_id,
          };
          if (item.persona_cumpleanos && !existing.names.includes(item.persona_cumpleanos)) {
            existing.names.push(item.persona_cumpleanos);
          }
          if (item.ideas_regalo && !existing.ideas_regalo) {
            existing.ideas_regalo = item.ideas_regalo;
          }
          gruposMap.set(key, existing);
        }
      } else {
        console.warn('Fallback a consulta directa de miembros y perfiles:', errorCumple?.message);
        // Fallback directo a base de datos: environment_members + profiles (birth_date canónico)
        const { data: memberProfiles } = await supabase
          .from('environment_members')
          .select('environment_id, user_id, profiles(username, nombre_completo, birth_date)');

        if (memberProfiles) {
          const today = new Date();
          const targetOffsets = [0, 3, 7, 14];

          for (const row of memberProfiles) {
            const p = (row as any).profiles;
            if (!p || !p.birth_date) continue;

            const bDate = new Date(p.birth_date);
            const bMonth = bDate.getUTCMonth();
            const bDay = bDate.getUTCDate();
            const nombre = p.nombre_completo || p.username || 'Miembro';
            const envId = (row as any).environment_id;

            for (const offset of targetOffsets) {
              const targetDate = new Date(today);
              targetDate.setUTCDate(today.getUTCDate() + offset);

              if (targetDate.getUTCMonth() === bMonth && targetDate.getUTCDate() === bDay) {
                const key = `${envId}_${offset}`;
                const existing = gruposMap.get(key) || {
                  entorno_id: envId,
                  dias_restantes: offset,
                  names: [],
                };
                if (!existing.names.includes(nombre)) {
                  existing.names.push(nombre);
                }
                gruposMap.set(key, existing);
                break;
              }
            }
          }
        }
      }
    }

    const gruposCumpleanos = Array.from(gruposMap.values());

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

    // 5. Procesar Recordatorios de Cumpleaños con personalización dinámica
    for (const grupo of gruposCumpleanos) {
      if (grupo.names.length === 0) continue;

      // Obtener todos los tokens FCM de los miembros del entorno
      const { data: tokensData } = await supabase
        .from('usuario_fcm_tokens')
        .select('fcm_token, user_id')
        .eq('entorno_id', grupo.entorno_id);

      if (!tokensData || tokensData.length === 0) continue;

      // Composición dinámica inyectando variables reales y formateo de múltiples cumpleañeros
      const { title, body } = formatBirthdayNotification(
        grupo.names,
        grupo.dias_restantes,
        grupo.ideas_regalo
      );

      const dataPayload: Record<string, string> = {
        type: 'cumpleanos',
        tipo: 'cumpleanos',
        entorno_id: grupo.entorno_id,
        dias_restantes: String(grupo.dias_restantes),
        names: grupo.names.join(', '),
      };
      if (grupo.evento_id) {
        dataPayload.evento_id = grupo.evento_id;
      }

      for (const t of tokensData) {
        const result = await sendFcmMessage(
          serviceAccount.project_id,
          accessToken,
          t.fcm_token,
          title,
          body,
          dataPayload
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
            type: 'tarea_hoy',
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
        grupos_cumpleanos_evaluados: gruposCumpleanos.length,
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
