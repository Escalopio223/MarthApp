// ==============================================================================
// Supabase Edge Function: push-dispatcher
// Despachador unificado de notificaciones push vía Firebase Cloud Messaging (FCM v1)
// Soporta:
//   1. Modo Inmediato (Event-driven: solicitudes amistad, invitaciones entorno, reparto tareas)
//   2. Modo Programado (Time-driven: escaneo de planificador_tarea_recordatorios con ciclo 8h)
// ==============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2.48.1';
import * as jose from 'npm:jose@5.9.6';

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface ImmediatePayload {
  user_ids?: string[];
  title?: string;
  body?: string;
  data?: Record<string, string>;
  // Payload específico para eventos
  type?: string;
  sesion_id?: string;
  entorno_id?: string;
  usuarios_participantes?: string[];
  minutos_totales?: number;
}

interface RequestBody {
  mode?: 'immediate' | 'scheduled';
  payload?: ImmediatePayload;
  // Compatibilidad si los campos vienen directamente en la raíz
  user_ids?: string[];
  title?: string;
  body?: string;
  data?: Record<string, string>;
  type?: string;
  sesion_id?: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Caché en memoria para el access_token de Google OAuth2
let cachedGoogleToken: string | null = null;
let googleTokenExpiresAt = 0;

/**
 * Obtiene un access_token válido para la API de FCM HTTP v1 usando la Service Account
 */
async function getGoogleAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Date.now();
  if (cachedGoogleToken && now < googleTokenExpiresAt - 60000) {
    return cachedGoogleToken;
  }

  // Normalizar clave privada reemplazando saltos literales si existen
  const formattedKey = serviceAccount.private_key.includes('\\n')
    ? serviceAccount.private_key.replace(/\\n/g, '\n')
    : serviceAccount.private_key;

  const privateKey = await jose.importPKCS8(formattedKey, 'RS256');

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

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const errText = await tokenResponse.text();
    throw new Error(`Google OAuth2 Error (${tokenResponse.status}): ${errText}`);
  }

  const tokenData = await tokenResponse.json();
  cachedGoogleToken = tokenData.access_token;
  googleTokenExpiresAt = now + tokenData.expires_in * 1000;

  return cachedGoogleToken!;
}

/**
 * Envía un mensaje individual a un token FCM específico
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

/**
 * Elimina tokens caducados o desinstalados de la tabla usuario_fcm_tokens
 */
async function pruneInvalidTokens(supabase: any, tokens: string[]) {
  if (tokens.length === 0) return;
  try {
    await supabase.from('usuario_fcm_tokens').delete().in('fcm_token', tokens);
    console.log(`[push-dispatcher] Podados ${tokens.length} tokens FCM obsoletos.`);
  } catch (err) {
    console.error('[push-dispatcher] Error podando tokens obsoletos:', err);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Faltan variables SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY');
    }
    if (!serviceAccountRaw) {
      throw new Error('Falta el secreto FIREBASE_SERVICE_ACCOUNT');
    }

    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountRaw);
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Validación de seguridad inter-servicio (sin exponer claves maestras en tablas)
    const internalSecretEnv = Deno.env.get('INTERNAL_PUSH_SECRET') || 'marthapp_internal_push_secret_key_2026';
    const reqInternalSecret = req.headers.get('x-internal-secret');
    const authHeader = req.headers.get('authorization');

    const isAuthorized =
      (reqInternalSecret && reqInternalSecret === internalSecretEnv) ||
      (authHeader && authHeader.includes(supabaseServiceKey));

    if (!isAuthorized) {
      console.warn('[push-dispatcher] Llamada rechazada: Secreto inter-servicio no válido o ausente.');
      return new Response(
        JSON.stringify({ error: 'No autorizado: Cabecera x-internal-secret requerida' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401,
        }
      );
    }

    const accessToken = await getGoogleAccessToken(serviceAccount);

    // Leer payload del request
    let bodyData: RequestBody = {};
    try {
      bodyData = await req.json();
    } catch (_) {
      bodyData = {};
    }

    const mode = bodyData.mode || 'immediate';
    const payload = bodyData.payload || bodyData;
    const invalidTokens: string[] = [];
    let sentCount = 0;
    let failedCount = 0;

    // ============================================================================
    // MODO 1: INMEDIATO (Event-Driven)
    // ============================================================================
    if (mode === 'immediate') {
      // Caso 1.1: Evento de Reparto de Tareas de una sesión
      if (payload.type === 'reparto_sesion' && payload.sesion_id) {
        const sesionId = payload.sesion_id;
        const participantes: string[] = payload.usuarios_participantes || [];

        // Lectura determinista y libre de condiciones de carrera:
        // El trigger sólo se dispara una vez que la sesión pasa a 'completado' y todos los items están comprometidos
        const { data: items, error: itemsError } = await supabase
          .from('planificador_repartos_items')
          .select('usuario_asignado_final, tiempo_minutos')
          .eq('sesion_id', sesionId);

        if (itemsError) {
          console.error('[push-dispatcher] Error al consultar planificador_repartos_items:', itemsError);
        }

        // Agrupar tareas y minutos por participante
        const statsByUser = new Map<string, { count: number; minutos: number }>();
        for (const p of participantes) {
          statsByUser.set(p, { count: 0, minutos: 0 });
        }

        if (items) {
          for (const item of items) {
            const uid = item.usuario_asignado_final;
            const current = statsByUser.get(uid) || { count: 0, minutos: 0 };
            current.count += 1;
            current.minutos += (item.tiempo_minutos || 0);
            statsByUser.set(uid, current);
          }
        }

        // Obtener tokens de todos los participantes
        const { data: userTokens } = await supabase
          .from('usuario_fcm_tokens')
          .select('user_id, fcm_token')
          .in('user_id', participantes);

        const tokensByUser = new Map<string, string[]>();
        if (userTokens) {
          for (const t of userTokens) {
            const list = tokensByUser.get(t.user_id) || [];
            list.push(t.fcm_token);
            tokensByUser.set(t.user_id, list);
          }
        }

        // Despachar a cada participante su resumen personalizado
        for (const [userId, stats] of statsByUser.entries()) {
          const tokens = tokensByUser.get(userId) || [];
          if (tokens.length === 0) continue;

          const title = 'Reparto de tareas completado';
          const bodyText = stats.count > 0
            ? `Tienes ${stats.count} tarea${stats.count > 1 ? 's' : ''} asignada${stats.count > 1 ? 's' : ''} (~${stats.minutos} min). ¡A por ello!`
            : 'No tienes tareas asignadas en esta sesión. ¡Día despejado!';

          const dataPayload = {
            type: 'reparto_sesion',
            sesion_id: sesionId,
            entorno_id: payload.entorno_id || '',
          };

          for (const token of tokens) {
            const res = await sendFcmMessage(
              serviceAccount.project_id,
              accessToken,
              token,
              title,
              bodyText,
              dataPayload
            );
            if (res.success) {
              sentCount++;
            } else {
              failedCount++;
              if (res.unregistered) invalidTokens.push(token);
            }
          }
        }
      }
      // Caso 1.2: Payload directo a destinatarios específicos (Amistad, Entornos u otros)
      else {
        const userIds = payload.user_ids || (bodyData.user_ids ? bodyData.user_ids : []);
        const title = payload.title || 'MarthApp Notificación';
        const bodyText = payload.body || '';
        const dataPayload = payload.data || {};

        if (userIds.length > 0) {
          const { data: userTokens, error: tokenError } = await supabase
            .from('usuario_fcm_tokens')
            .select('fcm_token, user_id')
            .in('user_id', userIds);

          if (tokenError) {
            console.error('[push-dispatcher] Error al consultar usuario_fcm_tokens:', tokenError);
          }

          if (userTokens && userTokens.length > 0) {
            for (const t of userTokens) {
              const res = await sendFcmMessage(
                serviceAccount.project_id,
                accessToken,
                t.fcm_token,
                title,
                bodyText,
                dataPayload
              );
              if (res.success) {
                sentCount++;
              } else {
                failedCount++;
                if (res.unregistered) invalidTokens.push(t.fcm_token);
              }
            }
          }
        }
      }

      await pruneInvalidTokens(supabase, invalidTokens);

      return new Response(
        JSON.stringify({
          success: true,
          mode: 'immediate',
          sentCount,
          failedCount,
          invalidTokensRemoved: invalidTokens.length,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    // ============================================================================
    // MODO 2: PROGRAMADO (Time-Driven - pg_cron / hourly scan)
    // ============================================================================
    if (mode === 'scheduled') {
      const now = new Date();
      // Soporte para zona horaria de la aplicación (por defecto Europe/Madrid)
      const appTimeZone = Deno.env.get('APP_TIMEZONE') || 'Europe/Madrid';
      let todayStr = now.toISOString().split('T')[0];
      let currentHour = now.getUTCHours();
      let currentMinutes = now.getUTCMinutes();

      try {
        const dtf = new Intl.DateTimeFormat('en-CA', {
          timeZone: appTimeZone,
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
          hour12: false,
        });
        const parts = dtf.formatToParts(now);
        const map: Record<string, string> = {};
        for (const p of parts) map[p.type] = p.value;
        if (map.year && map.month && map.day) {
          todayStr = `${map.year}-${map.month}-${map.day}`;
        }
        if (map.hour) currentHour = parseInt(map.hour, 10);
        if (map.minute) currentMinutes = parseInt(map.minute, 10);
      } catch (tzErr) {
        console.warn(`[push-dispatcher] Error parseando timezone ${appTimeZone}, usando UTC:`, tzErr);
      }

      console.log(`[push-dispatcher] Escaneo scheduled iniciado. Fecha local: ${todayStr}, Hora: ${currentHour}:${currentMinutes.toString().padLeft ? currentMinutes.toString().padStart(2, '0') : currentMinutes}`);

      // Consultar recordatorios activos de tareas cuya fecha sea <= hoy
      const { data: recordatorios, error: recError } = await supabase
        .from('planificador_tarea_recordatorios')
        .select(`
          id,
          tarea_id,
          fecha_notificacion,
          hora_notificacion,
          enviado,
          ultimo_envio_at,
          tarea:planificador_tareas (
            id,
            titulo,
            estado,
            asignado_a,
            entorno_id,
            fecha_limite
          )
        `)
        .lte('fecha_notificacion', todayStr);

      if (recError) {
        throw new Error(`Error consultando recordatorios: ${recError.message}`);
      }

      const remindersToDispatch: Array<{
        recordatorioId: string;
        asignadoA: string;
        tituloTarea: string;
        tareaId: string;
        entornoId: string;
        fechaLimite: string | null;
        esHoraFija: boolean;
      }> = [];

      for (const rec of recordatorios || []) {
        const tarea = rec.tarea as any;
        // Se ignoran tareas completadas, eliminadas o sin responsable asignado
        if (!tarea || tarea.estado === 'completada' || !tarea.asignado_a) {
          continue;
        }

        const isExactToday = rec.fecha_notificacion === todayStr;
        const isPastDay = rec.fecha_notificacion < todayStr;

        // ====================================================================
        // CASO 1: Recordatorio con HORA FIJA (hora_notificacion IS NOT NULL)
        // Se envía al cumplirse la hora y se marca enviado = true
        // ====================================================================
        if (rec.hora_notificacion) {
          if (!rec.enviado) {
            if (isExactToday) {
              const [hStr, mStr] = rec.hora_notificacion.split(':');
              const targetH = parseInt(hStr, 10);
              const targetM = parseInt(mStr || '0', 10);

              // Si la hora actual es mayor o igual a la hora programada
              if (currentHour > targetH || (currentHour === targetH && currentMinutes >= targetM)) {
                remindersToDispatch.push({
                  recordatorioId: rec.id,
                  asignadoA: tarea.asignado_a,
                  tituloTarea: tarea.titulo,
                  tareaId: tarea.id,
                  entornoId: tarea.entorno_id,
                  fechaLimite: tarea.fecha_limite,
                  esHoraFija: true,
                });
              }
            } else if (isPastDay) {
              // Si la fecha programada ya pasó y por algún motivo no se envió aún
              remindersToDispatch.push({
                recordatorioId: rec.id,
                asignadoA: tarea.asignado_a,
                tituloTarea: tarea.titulo,
                tareaId: tarea.id,
                entornoId: tarea.entorno_id,
                fechaLimite: tarea.fecha_limite,
                esHoraFija: true,
              });
            }
          }
        }
        // ====================================================================
        // CASO 2: Recordatorio SIN HORA FIJA (hora_notificacion IS NULL)
        // Ciclo cada 8 horas desde las 00:00 durante fecha_notificacion = CURRENT_DATE
        // ====================================================================
        else {
          if (isExactToday) {
            const ultimoEnvio = rec.ultimo_envio_at ? new Date(rec.ultimo_envio_at).getTime() : 0;
            const diffHours = (now.getTime() - ultimoEnvio) / (1000 * 60 * 60);

            // Se activa desde las 00:00 (ultimo_envio_at es null) o tras >= 7.5h desde el último disparo
            if (!rec.ultimo_envio_at || diffHours >= 7.5) {
              remindersToDispatch.push({
                recordatorioId: rec.id,
                asignadoA: tarea.asignado_a,
                tituloTarea: tarea.titulo,
                tareaId: tarea.id,
                entornoId: tarea.entorno_id,
                fechaLimite: tarea.fecha_limite,
                esHoraFija: false,
              });
            }
          }
        }
      }

      // Si hay recordatorios para despachar, buscar tokens
      if (remindersToDispatch.length > 0) {
        const userIds = Array.from(new Set(remindersToDispatch.map((r) => r.asignadoA)));
        const { data: userTokens } = await supabase
          .from('usuario_fcm_tokens')
          .select('fcm_token, user_id')
          .in('user_id', userIds);

        const tokensByUser = new Map<string, string[]>();
        if (userTokens) {
          for (const t of userTokens) {
            const list = tokensByUser.get(t.user_id) || [];
            list.push(t.fcm_token);
            tokensByUser.set(t.user_id, list);
          }
        }

        for (const item of remindersToDispatch) {
          const tokens = tokensByUser.get(item.asignadoA) || [];
          const title = `⏰ Recordatorio: ${item.tituloTarea}`;
          const bodyText = item.fechaLimite
            ? `Tienes pendiente la tarea "${item.tituloTarea}". Fecha límite: ${new Date(item.fechaLimite).toLocaleDateString()}`
            : `Tienes pendiente la tarea "${item.tituloTarea}".`;

          const dataPayload = {
            type: 'task_reminder',
            tarea_id: item.tareaId,
            entorno_id: item.entornoId,
          };

          for (const token of tokens) {
            const res = await sendFcmMessage(
              serviceAccount.project_id,
              accessToken,
              token,
              title,
              bodyText,
              dataPayload
            );
            if (res.success) {
              sentCount++;
            } else {
              failedCount++;
              if (res.unregistered) invalidTokens.push(token);
            }
          }

          // Actualizar estado del recordatorio
          const updateData: Record<string, any> = {
            ultimo_envio_at: now.toISOString(),
          };
          if (item.esHoraFija) {
            updateData.enviado = true;
          }

          await supabase
            .from('planificador_tarea_recordatorios')
            .update(updateData)
            .eq('id', item.recordatorioId);
        }
      }

      await pruneInvalidTokens(supabase, invalidTokens);

      return new Response(
        JSON.stringify({
          success: true,
          mode: 'scheduled',
          remindersEvaluated: (recordatorios || []).length,
          remindersDispatched: remindersToDispatch.length,
          sentCount,
          failedCount,
          invalidTokensRemoved: invalidTokens.length,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    return new Response(
      JSON.stringify({ error: `Modo no soportado: ${mode}` }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('[push-dispatcher] Error no controlado:', message);
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
