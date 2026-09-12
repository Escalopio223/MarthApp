// ==============================================================================
// Supabase Edge Function: igdb-proxy
// Proxy seguro para IGDB API v4 con autenticación OAuth2 Twitch
// ==============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2.48.1';

// Cabeceras CORS estándar
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Cache en memoria para el token de Twitch
let cachedToken: string | null = null;
let tokenExpiresAt = 0; // Timestamp en ms

/**
 * Obtiene o reutiliza un token de acceso OAuth2 para Twitch/IGDB
 */
async function getTwitchAccessToken(clientId: string, clientSecret: string): Promise<string> {
  const now = Date.now();
  // Reutilizar token si aún le quedan más de 60 segundos de validez
  if (cachedToken && now < tokenExpiresAt - 60000) {
    return cachedToken;
  }

  const tokenUrl = `https://id.twitch.tv/oauth2/token?client_id=${encodeURIComponent(clientId)}&client_secret=${encodeURIComponent(clientSecret)}&grant_type=client_credentials`;

  const response = await fetch(tokenUrl, { method: 'POST' });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Error al solicitar token a Twitch (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  cachedToken = data.access_token;
  // data.expires_in viene en segundos (ej. 5000000s)
  tokenExpiresAt = now + (data.expires_in * 1000);

  return cachedToken!;
}

Deno.serve(async (req: Request) => {
  // Manejo de preflight CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Método no permitido. Solo se acepta POST.' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  try {
    // 1. Validar autenticación con JWT de Supabase
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'No autorizado. Se requiere token Bearer en el header Authorization.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

    if (supabaseUrl && supabaseAnonKey) {
      const supabase = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      });

      const token = authHeader.replace('Bearer ', '').trim();
      const { data: { user }, error: authError } = await supabase.auth.getUser(token);

      if (authError || !user) {
        return new Response(
          JSON.stringify({ error: 'Sesión de Supabase no válida o expirada.' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 2. Obtener secretos de Twitch
    const twitchClientId = Deno.env.get('TWITCH_CLIENT_ID');
    const twitchClientSecret = Deno.env.get('TWITCH_CLIENT_SECRET');

    if (!twitchClientId || !twitchClientSecret) {
      return new Response(
        JSON.stringify({
          error: 'Credenciales de Twitch no configuradas en el servidor (TWITCH_CLIENT_ID / TWITCH_CLIENT_SECRET).'
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 3. Procesar payload del cliente
    let bodyJson: Record<string, unknown> = {};
    const contentType = req.headers.get('content-type') || '';

    if (contentType.includes('application/json')) {
      bodyJson = await req.json();
    } else {
      const rawText = await req.text();
      bodyJson = { query: rawText };
    }

    const endpointRaw = typeof bodyJson.endpoint === 'string' ? bodyJson.endpoint.trim() : '/games';
    const query = typeof bodyJson.query === 'string' ? bodyJson.query : '';

    // Sanitización estricta del endpoint para prevenir SSRF
    const endpoint = endpointRaw.startsWith('/') ? endpointRaw : `/${endpointRaw}`;
    if (!/^\/[a-zA-Z0-9_\-\/]+$/.test(endpoint)) {
      return new Response(
        JSON.stringify({ error: 'Endpoint de IGDB no válido o potencialmente inseguro.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 4. Obtener token de Twitch
    const accessToken = await getTwitchAccessToken(twitchClientId, twitchClientSecret);

    // 5. Enviar consulta Apicalypse a IGDB v4
    const igdbUrl = `https://api.igdb.com/v4${endpoint}`;
    const igdbResponse = await fetch(igdbUrl, {
      method: 'POST',
      headers: {
        'Client-ID': twitchClientId,
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json',
        'Content-Type': 'text/plain',
      },
      body: query,
    });

    const igdbData = await igdbResponse.json();

    return new Response(JSON.stringify(igdbData), {
      status: igdbResponse.status,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });

  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
