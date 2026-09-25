import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import { validateMagicBytes, sanitizeImageBuffer, SanitizationError } from './index.ts';

describe('Sanitización de Medios - Backend Zero Trust', () => {

  describe('1. Validación de Magic Numbers', () => {
    it('acepta JPEG válido', async () => {
      const buf = await sharp({ create: { width: 16, height: 16, channels: 3, background: { r: 255, g: 0, b: 0 } } }).jpeg().toBuffer();
      const res = validateMagicBytes(new Uint8Array(buf));
      assert.equal(res.mimeType, 'image/jpeg');
      assert.equal(res.extension, 'jpg');
    });

    it('acepta PNG válido con chunk IHDR', async () => {
      const buf = await sharp({ create: { width: 16, height: 16, channels: 4, background: { r: 0, g: 255, b: 0, alpha: 1 } } }).png().toBuffer();
      const res = validateMagicBytes(new Uint8Array(buf));
      assert.equal(res.mimeType, 'image/png');
      assert.equal(res.extension, 'png');
    });

    it('acepta WebP válido', async () => {
      const buf = await sharp({ create: { width: 16, height: 16, channels: 3, background: { r: 0, g: 0, b: 255 } } }).webp().toBuffer();
      const res = validateMagicBytes(new Uint8Array(buf));
      assert.equal(res.mimeType, 'image/webp');
      assert.equal(res.extension, 'webp');
    });

    it('rechaza ejecutable Windows PE camuflado con MZ', () => {
      const exe = new Uint8Array([0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00]);
      assert.throws(() => validateMagicBytes(exe), (err) => err instanceof SanitizationError && err.statusCode === 400);
    });

    it('rechaza script camuflado con Shebang (#!/)', () => {
      const script = new Uint8Array([0x23, 0x21, 0x2F, 0x62, 0x69, 0x6E, 0x2F, 0x73, 0x68, 0x0A, 0x65, 0x63, 0x68, 0x6F, 0x20, 0x31]);
      assert.throws(() => validateMagicBytes(script), (err) => err instanceof SanitizationError && err.statusCode === 400);
    });

    it('rechaza script PHP (<?php)', () => {
      const php = new Uint8Array([0x3C, 0x3F, 0x70, 0x68, 0x70, 0x20, 0x65, 0x63, 0x68, 0x6F, 0x20, 0x31, 0x3B, 0x20, 0x3F, 0x3E]);
      assert.throws(() => validateMagicBytes(php), (err) => err instanceof SanitizationError && err.statusCode === 400);
    });

    it('rechaza bytes aleatorios no reconocidos', () => {
      const garbage = new Uint8Array([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]);
      assert.throws(() => validateMagicBytes(garbage), (err) => err instanceof SanitizationError && err.statusCode === 415);
    });
  });

  describe('2. Re-rasterización y Destrucción de EXIF (Defensa en Profundidad)', () => {
    it('elimina por completo coordenadas GPS y metadatos EXIF', async () => {
      // 1. Crear JPEG base
      const baseJpeg = await sharp({ create: { width: 32, height: 32, channels: 3, background: { r: 100, g: 150, b: 200 } } }).jpeg().toBuffer();

      // 2. Inyectar segmento APP1 con coordenadas GPS y cámara
      const exifPayload = Buffer.from('Exif\0\0GPS:41.40338N,2.17403E;Camera:SecretSpyModel;Tag:SensitiveData');
      const app1 = Buffer.concat([Buffer.from([0xFF, 0xE1, 0x00, exifPayload.length + 2]), exifPayload]);
      const jpegWithExif = Buffer.concat([baseJpeg.subarray(0, 2), app1, baseJpeg.subarray(2)]);

      assert.ok(jpegWithExif.toString('latin1').includes('41.40338N'), 'El buffer previo debe contener GPS');

      // 3. Sanitizar
      const sanitized = await sanitizeImageBuffer(new Uint8Array(jpegWithExif), 'webp');
      const sanitizedStr = Buffer.from(sanitized.buffer).toString('latin1');

      assert.equal(sanitizedStr.includes('41.40338N'), false, 'El buffer limpio NO debe contener GPS');
      assert.equal(sanitizedStr.includes('SecretSpyModel'), false, 'El buffer limpio NO debe contener cámara');
      assert.equal(sanitized.mimeType, 'image/webp');
      assert.match(sanitized.filename, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.webp$/);
    });
  });

  describe('3. Mitigación DoS y Manejo de Errores', () => {
    it('rechaza archivos que excedan el límite de tamaño (413)', async () => {
      const oversized = new Uint8Array(5 * 1024 * 1024 + 100);
      oversized.fill(0xFF);
      await assert.rejects(
        () => sanitizeImageBuffer(oversized),
        (err) => err instanceof SanitizationError && err.statusCode === 413
      );
    });

    it('rechaza flujo de imagen corrupto (422)', async () => {
      const corrupt = new Uint8Array([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0xDE, 0xAD]);
      await assert.rejects(
        () => sanitizeImageBuffer(corrupt),
        (err) => err instanceof SanitizationError && err.statusCode === 422
      );
    });
  });

});
