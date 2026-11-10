"""
seed_supabase.py
Script de inserción por lotes (upsert) en Supabase para 'global_recipes':
- Lee las recetas procesadas desde data/scraped_recipes.jsonl
- Realiza upsert en bloques de 100 filas
- Usa 'source_url' como clave de resolución de conflictos
- Requiere las variables de entorno SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY (o SUPABASE_ANON_KEY)
"""

import os
import sys
import json
import urllib.request
import urllib.error
from typing import List, Dict, Any

RECIPES_FILE = os.path.join(os.path.dirname(__file__), '..', 'data', 'scraped_recipes.jsonl')
BATCH_SIZE = 100


def get_supabase_credentials():
    url = os.environ.get('SUPABASE_URL')
    key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY') or os.environ.get('SUPABASE_ANON_KEY')

    if not url or not key:
        print("[!] ADVERTENCIA: Variables de entorno no encontradas.")
        print("    Por favor define:")
        print("    export SUPABASE_URL='https://tu-proyecto.supabase.co'")
        print("    export SUPABASE_SERVICE_ROLE_KEY='tu-service-role-key'")
        return None, None
    return url.rstrip('/'), key


def upsert_batch(supabase_url: str, supabase_key: str, batch: List[Dict[str, Any]]) -> bool:
    """Envía un lote de recetas a Supabase PostgREST endpoint con resolución de conflictos en source_url."""
    endpoint = f"{supabase_url}/rest/v1/global_recipes?on_conflict=source_url"
    data_bytes = json.dumps(batch, ensure_ascii=False).encode('utf-8')

    req = urllib.request.Request(
        endpoint,
        data=data_bytes,
        headers={
            'apikey': supabase_key,
            'Authorization': f'Bearer {supabase_key}',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates,return=minimal',
        },
        method='POST'
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status in (200, 201, 204)
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8', errors='replace')
        print(f"[!] Error HTTP {e.code} en upsert: {error_body}")
        return False
    except Exception as e:
        print(f"[!] Error de conexión: {e}")
        return False


def main():
    if not os.path.exists(RECIPES_FILE):
        print(f"[!] Archivo de datos no encontrado: {RECIPES_FILE}")
        print("    Ejecuta primero: python scripts/scrape_recipes.py")
        sys.exit(1)

    supabase_url, supabase_key = get_supabase_credentials()
    if not supabase_url or not supabase_key:
        print("\n[i] Para probar la lectura sin credenciales, se verificará la integridad del JSONL:")
        count = 0
        with open(RECIPES_FILE, 'r', encoding='utf-8') as f:
            for _ in f:
                count += 1
        print(f"    Total de recetas listas para sembrar: {count}")
        return

    print(f"[*] Conectando a Supabase: {supabase_url}")
    print(f"[*] Leyendo recetas desde {RECIPES_FILE}...")

    current_batch = []
    total_processed = 0
    total_upserted = 0

    with open(RECIPES_FILE, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                recipe = json.loads(line)
                current_batch.append(recipe)
                total_processed += 1

                if len(current_batch) >= BATCH_SIZE:
                    ok = upsert_batch(supabase_url, supabase_key, current_batch)
                    if ok:
                        total_upserted += len(current_batch)
                        print(f"    -> {total_upserted} recetas sincronizadas en Supabase...")
                    else:
                        print(f"[!] Falló el lote en el registro {total_processed}")
                    current_batch = []
            except Exception as e:
                print(f"[!] Error en línea: {e}")

        # Subir remanente
        if current_batch:
            ok = upsert_batch(supabase_url, supabase_key, current_batch)
            if ok:
                total_upserted += len(current_batch)

    print(f"\n[✓] Inserción finalizada con éxito.")
    print(f"[✓] Total recetas leídas: {total_processed}")
    print(f"[✓] Total recetas upserted en Supabase: {total_upserted}")


if __name__ == '__main__':
    main()

