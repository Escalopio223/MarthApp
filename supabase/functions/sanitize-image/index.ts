// ==============================================================================
// Supabase Edge Function: sanitize-image
// Pipeline de Confianza Cero y Sanitización de Medios (Defensa en Profundidad)
// ==============================================================================

import { createClient } from '@supabase/supabase-js';
import sharp from 'sharp';

export const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5 MB
export const MAX_DIMENSION = 4096; // 4096 x 4096 px máx

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ==============================================================================
// 1. Excepciones de Dominio y Mapeo HTTP
// ==============================================================================

export class SanitizationError extends Error {
  readonly statusCode: number;
  readonly errorCode: string;

  constructor(message: string, statusCode: number, errorCode: string) {
    super(message);
    this.name = 'SanitizationError';
    this.statusCode = statusCode;
    this.errorCode = errorCode;
  }

  toJSON() {
    return {
      error: this.name,
      code: this.errorCode,
      message: this.message,
      statusCode: this.statusCode,
    };
  }
}

// ==============================================================================
// 2. Validación Estricta de Firmas Binarias (Magic Numbers)
// ==============================================================================

const MALICIOUS_SIGNATURES: Array<{ name: string; bytes: number[] }> = [
  { name: 'Ejecutable Windows PE (MZ)', bytes: [0x4d, 0x5a] },
  { name: 'Ejecutable Linux ELF', bytes: [0x7f, 0x45, 0x4c, 0x46] },
  { name: 'Script Shebang (#!/)', bytes: [0x23, 0x21, 0x2f] },
  { name: 'Script PHP (<?php)', bytes: [0x3c, 0x3f, 0x70, 0x68, 0x70] },
  { name: 'Etiqueta HTML/JS (<script)', bytes: [0x3c, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74] },
];

function matchBytes(buffer: Uint8Array, pattern: number[], offset = 0): boolean {
  if (buffer.length < offset + pattern.length) return false;
  for (let i = 0; i < pattern.length; i++) {
    if (buffer[offset + i] !== pattern[i]) return false;
  }
  return true;
}

export function validateMagicBytes(buffer: Uint8Array): { mimeType: string; extension: string } {
  if (!buffer || buffer.length < 16) {
    throw new SanitizationError(
      'Archivo demasiado pequeño o inválido para ser una imagen.',
      415,
      'UNSUPPORTED_MEDIA_TYPE'
    );
  }

  if (buffer.length > MAX_FILE_SIZE) {
    throw new SanitizationError(
      `El archivo excede el tamaño máximo permitido de 5 MB (${buffer.length} bytes).`,
      413,
      'PAYLOAD_TOO_LARGE'
    );
  }

  // Detección proactiva de ejecutables o scripts camuflados
  for (const sig of MALICIOUS_SIGNATURES) {
    if (matchBytes(buffer, sig.bytes, 0)) {
      throw new SanitizationError(
        `Firma prohibida detectada: ${sig.name}. Archivo rechazado por seguridad.`,
        400,
        'SECURITY_VIOLATION_DETECTED'
      );
    }
  }

  // JPEG (SOI 0xFF 0xD8 0xFF)
  if (matchBytes(buffer, [0xff, 0xd8, 0xff], 0)) {
    return { mimeType: 'image/jpeg', extension: 'jpg' };
  }

  // PNG (8 bytes firma + chunk IHDR)
  if (
    matchBytes(buffer, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], 0) &&
    matchBytes(buffer, [0x49, 0x48, 0x44, 0x52], 12)
  ) {
    return { mimeType: 'image/png', extension: 'png' };
  }

  // WebP (RIFF + WEBP + VP8/VP8L/VP8X)
  if (
    matchBytes(buffer, [0x52, 0x49, 0x46, 0x46], 0) &&
    matchBytes(buffer, [0x57, 0x45, 0x42, 0x50], 8)
  ) {
    return { mimeType: 'image/webp', extension: 'webp' };
  }

  throw new SanitizationError(
    'Firma binaria no permitida. Solo se aceptan formatos JPEG, PNG y WebP seguros.',
    415,
    'UNSUPPORTED_MEDIA_TYPE'
  );
}

// ==============================================================================
// 3. Re-rasterización en Bajo Nivel y Persistencia Criptográfica
// ==============================================================================

export interface SanitizedOutput {
  buffer: Uint8Array;
  filename: string;
  mimeType: string;
  width: number;
  height: number;
  originalSizeBytes: number;
  sanitizedSizeBytes: number;
  sha256Hash: string;
}

export async function sanitizeImageBuffer(
  rawBuffer: Uint8Array,
  outputFormat: 'webp' | 'jpeg' | 'png' = 'webp',
  quality = 85
): Promise<SanitizedOutput> {
  // 1. Validar firmas binarias (Confianza Cero)
  validateMagicBytes(rawBuffer);

  // 2. Decodificar píxeles puros con Sharp (destruye 100% de metadatos EXIF/IPTC/XMP)
  const image = sharp(rawBuffer, {
    failOn: 'error',
    limitInputPixels: MAX_DIMENSION * MAX_DIMENSION,
  });

  let meta;
  try {
    meta = await image.metadata();
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    if (msg.toLowerCase().includes('pixel limit')) {
      throw new SanitizationError('Dimensiones de imagen excesivas (Pixel Flood DoS).', 422, 'DIMENSIONS_EXCEEDED');
    }
    throw new SanitizationError(`Fallo al decodificar píxeles de la imagen: ${msg}`, 422, 'CORRUPT_IMAGE_STREAM');
  }

  const width = meta.width ?? 0;
  const height = meta.height ?? 0;
  if (!width || !height || width > MAX_DIMENSION || height > MAX_DIMENSION) {
    throw new SanitizationError(
      `Dimensiones (${width}x${height}) superan el límite máximo (${MAX_DIMENSION}x${MAX_DIMENSION}).`,
      422,
      'DIMENSIONS_EXCEEDED'
    );
  }

  // 3. Re-codificar píxeles limpios en contenedor nuevo
  let cleanBuffer: Buffer;
  let finalMime = 'image/webp';
  let finalExt = 'webp';

  if (outputFormat === 'jpeg') {
    cleanBuffer = await image.rotate().jpeg({ quality, mozjpeg: true }).toBuffer();
    finalMime = 'image/jpeg';
    finalExt = 'jpg';
  } else if (outputFormat === 'png') {
    cleanBuffer = await image.rotate().png({ compressionLevel: 8 }).toBuffer();
    finalMime = 'image/png';
    finalExt = 'png';
  } else {
    cleanBuffer = await image.rotate().webp({ quality, effort: 4 }).toBuffer();
  }

  // 4. Generar nombre UUID v4 criptográfico (descartando completamente el original del cliente)
  const filename = `${crypto.randomUUID()}.${finalExt}`;

  // 5. Hash SHA-256 de integridad
  const hashBuffer = await crypto.subtle.digest('SHA-256', cleanBuffer);
  const sha256Hash = Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  return {
    buffer: new Uint8Array(cleanBuffer),
    filename,
    mimeType: finalMime,
    width,
    height,
    originalSizeBytes: rawBuffer.length,
    sanitizedSizeBytes: cleanBuffer.length,
    sha256Hash,
  };
}

// ==============================================================================
// 4. Controlador HTTP Supabase Edge Function
// ==============================================================================

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Solo se acepta POST' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const contentType = req.headers.get('content-type') || '';
    let rawBuffer: Uint8Array;
    let bucket: string | null = null;
    let destinationPath: string | null = null;
    let outputFormat: 'webp' | 'jpeg' | 'png' = 'webp';

    if (contentType.includes('application/json')) {
      const json = await req.json();
      const b64 = (json.image_base64 || '').replace(/^data:image\/[a-zA-Z+]+;base64,/, '');
      const binaryString = atob(b64);
      rawBuffer = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        rawBuffer[i] = binaryString.charCodeAt(i);
      }
      bucket = json.bucket || null;
      destinationPath = json.destination_path || null;
      outputFormat = json.output_format || 'webp';
    } else {
      const arrayBuf = await req.arrayBuffer();
      rawBuffer = new Uint8Array(arrayBuf);
      const url = new URL(req.url);
      bucket = url.searchParams.get('bucket');
      destinationPath = url.searchParams.get('destination_path');
    }

    // Ejecutar pipeline de sanitización
    const sanitized = await sanitizeImageBuffer(rawBuffer, outputFormat);

    // Persistencia opcional en Storage
    if (bucket) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY') || '';
      const supabase = createClient(supabaseUrl, supabaseKey);

      const targetPath = destinationPath
        ? `${destinationPath.replace(/^[/\\]+|[/\\]+$/g, '')}/${sanitized.filename}`
        : sanitized.filename;

      const { error: uploadErr } = await supabase.storage
        .from(bucket)
        .upload(targetPath, sanitized.buffer, {
          contentType: sanitized.mimeType,
          upsert: true,
        });

      if (uploadErr) {
        throw new SanitizationError(`Error al guardar en Storage: ${uploadErr.message}`, 500, 'STORAGE_ERROR');
      }

      const { data: pubData } = supabase.storage.from(bucket).getPublicUrl(targetPath);

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            publicUrl: pubData.publicUrl,
            storagePath: targetPath,
            filename: sanitized.filename,
            mimeType: sanitized.mimeType,
            width: sanitized.width,
            height: sanitized.height,
            originalSizeBytes: sanitized.originalSizeBytes,
            sanitizedSizeBytes: sanitized.sanitizedSizeBytes,
            sha256Hash: sanitized.sha256Hash,
          },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json', 'X-Content-Type-Options': 'nosniff' } }
      );
    }

    // Responder directamente con metadatos y buffer base64 si no se especificó bucket
    let binary = '';
    for (let i = 0; i < sanitized.buffer.length; i++) {
      binary += String.fromCharCode(sanitized.buffer[i]);
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          ...sanitized,
          image_base64: btoa(binary),
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json', 'X-Content-Type-Options': 'nosniff' } }
    );

  } catch (err) {
    if (err instanceof SanitizationError) {
      return new Response(JSON.stringify(err.toJSON()), {
        status: err.statusCode,
        headers: { ...corsHeaders, 'Content-Type': 'application/json', 'X-Content-Type-Options': 'nosniff' },
      });
    }

    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: 'InternalServerError', code: 'INTERNAL_SERVER_ERROR', message, statusCode: 500 }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}

// deno-lint-ignore no-explicit-any
if (typeof (globalThis as any).Deno?.serve === 'function') {
  // deno-lint-ignore no-explicit-any
  (globalThis as any).Deno.serve(handleRequest);
}

