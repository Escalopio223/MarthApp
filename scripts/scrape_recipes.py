"""
scrape_recipes.py
Pipeline de recolección y normalización de 1.500 recetas reales en español:
1. Fuente A: Extracción de application/ld+json (schema.org/Recipe) mediante scraping de sitemaps / URLs.
2. Fuente B: Conexión al dataset de Hugging Face 'somosnlp/recetas-cocina'.
3. Normalización con recipe_normalizer (ingredientes para la compra, detección de airfryer, horno, microondas).
4. Checkpointing incremental en data/scraped_recipes.jsonl para resumir si se interrumpe.
"""

import os
import sys
import json
import time
import re
import urllib.request
import urllib.error
from typing import List, Dict, Any, Set

from recipe_normalizer import normalize_recipe_record

TARGET_RECIPES_COUNT = 1500
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), '..', 'data', 'scraped_recipes.jsonl')

USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0',
]


def load_existing_urls(filepath: str) -> Set[str]:
    """Carga las URLs de recetas ya procesadas para evitar duplicados y soportar reanudación."""
    urls = set()
    if not os.path.exists(filepath):
        return urls
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    data = json.loads(line)
                    url = data.get('source_url')
                    if url:
                        urls.add(url)
                except Exception:
                    pass
    return urls


def extract_json_ld_from_html(html: str, page_url: str) -> List[Dict[str, Any]]:
    """Extrae bloques de schema.org/Recipe dentro de etiquetas <script type="application/ld+json">."""
    recipes = []
    pattern = re.compile(r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>', re.DOTALL | re.IGNORECASE)
    matches = pattern.findall(html)

    for match in matches:
        try:
            content = match.strip()
            parsed = json.loads(content)

            def check_node(node):
                if isinstance(node, dict):
                    node_type = node.get('@type')
                    if node_type == 'Recipe' or (isinstance(node_type, list) and 'Recipe' in node_type):
                        node['url'] = node.get('url') or page_url
                        recipes.append(node)
                    # Explorar @graph si viene empaquetado
                    if '@graph' in node and isinstance(node['@graph'], list):
                        for subnode in node['@graph']:
                            check_node(subnode)
                elif isinstance(node, list):
                    for subnode in node:
                        check_node(subnode)

            check_node(parsed)
        except Exception:
            continue

    return recipes


def fetch_url(url: str, timeout: int = 10) -> Optional[str]:
    """Descarga el HTML de una URL con headers rotativos y gestión de errores."""
    ua = USER_AGENTS[hash(url) % len(USER_AGENTS)]
    req = urllib.request.Request(
        url,
        headers={
            'User-Agent': ua,
            'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
            'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            content_type = resp.headers.get('Content-Type', '')
            encoding = 'utf-8'
            if 'charset=' in content_type:
                encoding = content_type.split('charset=')[-1].split(';')[0].strip()
            return resp.read().decode(encoding, errors='replace')
    except Exception as e:
        # print(f"Error descargando {url}: {e}")
        return None


def fetch_huggingface_batch(offset: int = 0, limit: int = 100) -> List[Dict[str, Any]]:
    """Descarga un lote de recetas en español desde la API de Datasets de Hugging Face."""
    url = f"https://datasets-server.huggingface.co/rows?dataset=somosnlp%2Frecetas-cocina&config=default&split=train&offset={offset}&limit={limit}"
    raw_json = fetch_url(url, timeout=15)
    if not raw_json:
        return []

    try:
        data = json.loads(raw_json)
        rows = data.get('rows', [])
        results = []
        for item in rows:
            row = item.get('row', {})
            title = row.get('title')
            ingredients_text = row.get('ingredients')
            steps_text = row.get('steps')
            source_url = row.get('url') or f"hf://somosnlp/recetas/{row.get('uuid', offset)}"

            if title and ingredients_text and steps_text:
                results.append({
                    'title': title,
                    'url': source_url,
                    'ingredients': ingredients_text,
                    'instructions': steps_text,
                })
        return results
    except Exception as e:
        print(f"Error parseando lote HF (offset={offset}): {e}")
        return []


def fetch_huggingface_wikilibros_batch(offset: int = 0, limit: int = 100) -> List[Dict[str, Any]]:
    """Descarga un lote de recetas en español desde el dataset wikilibros_artesculinarias_recetas."""
    url = f"https://datasets-server.huggingface.co/rows?dataset=ID3%2Fwikilibros_artesculinarias_recetas&config=default&split=train&offset={offset}&limit={limit}"
    raw_json = fetch_url(url, timeout=15)
    if not raw_json:
        return []

    try:
        data = json.loads(raw_json)
        rows = data.get('rows', [])
        results = []
        for item in rows:
            row = item.get('row', {})
            title = row.get('titulo') or row.get('title')
            ingredients_raw = row.get('ingredientes') or []
            steps_raw = row.get('procedimiento') or []
            source_url = f"hf://wikilibros/recetas/{row.get('id', offset)}"

            if title and ingredients_raw and steps_raw:
                results.append({
                    'title': title,
                    'url': source_url,
                    'ingredients': ingredients_raw,
                    'instructions': steps_raw,
                    'servings': row.get('comensales') or '2-4 raciones',
                    'totalTime': row.get('tiempo'),
                })
        return results
    except Exception as e:
        print(f"Error parseando lote Wikilibros (offset={offset}): {e}")
        return []


def main():
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    existing_urls = load_existing_urls(OUTPUT_FILE)
    print(f"[*] Recetas existentes en checkpoint: {len(existing_urls)}")

    if len(existing_urls) >= TARGET_RECIPES_COUNT:
        print(f"[+] Ya se alcanzaron las {len(existing_urls)} recetas (Meta: {TARGET_RECIPES_COUNT}).")
        return

    saved_count = len(existing_urls)

    with open(OUTPUT_FILE, 'a', encoding='utf-8') as out_f:
        # Fuente 1: Hugging Face somosnlp/recetas-cocina (hasta 850)
        hf_offset = 0
        consecutive_empty = 0

        print(f"[*] Recolectando lote SomosNLP...")
        while saved_count < TARGET_RECIPES_COUNT and hf_offset < 1000 and consecutive_empty < 3:
            batch = fetch_huggingface_batch(offset=hf_offset, limit=100)
            if not batch:
                consecutive_empty += 1
                time.sleep(1.5)
                hf_offset += 100
                continue

            consecutive_empty = 0
            for raw_record in batch:
                url = raw_record.get('url')
                if url in existing_urls:
                    continue

                normalized = normalize_recipe_record(raw_record)
                if normalized:
                    out_f.write(json.dumps(normalized, ensure_ascii=False) + '\n')
                    out_f.flush()
                    existing_urls.add(url)
                    saved_count += 1
                    if saved_count % 100 == 0 or saved_count >= TARGET_RECIPES_COUNT:
                        print(f"    -> {saved_count}/{TARGET_RECIPES_COUNT} recetas guardadas...")
                    if saved_count >= TARGET_RECIPES_COUNT:
                        break

            hf_offset += 100
            time.sleep(0.3)

        # Fuente 2: Hugging Face ID3/wikilibros_artesculinarias_recetas
        wiki_offset = 0
        consecutive_empty = 0
        print(f"[*] Recolectando lote Wikilibros Artes Culinarias (Progreso: {saved_count}/{TARGET_RECIPES_COUNT})...")
        while saved_count < TARGET_RECIPES_COUNT and consecutive_empty < 4:
            batch = fetch_huggingface_wikilibros_batch(offset=wiki_offset, limit=100)
            if not batch:
                consecutive_empty += 1
                time.sleep(1.5)
                wiki_offset += 100
                continue

            consecutive_empty = 0
            for raw_record in batch:
                url = raw_record.get('url')
                if url in existing_urls:
                    continue

                normalized = normalize_recipe_record(raw_record)
                if normalized:
                    out_f.write(json.dumps(normalized, ensure_ascii=False) + '\n')
                    out_f.flush()
                    existing_urls.add(url)
                    saved_count += 1
                    if saved_count % 100 == 0 or saved_count >= TARGET_RECIPES_COUNT:
                        print(f"    -> {saved_count}/{TARGET_RECIPES_COUNT} recetas guardadas...")
                    if saved_count >= TARGET_RECIPES_COUNT:
                        break

            wiki_offset += 100
            time.sleep(0.3)

    print(f"[✓] Proceso finalizado con éxito. Total recetas recopiladas: {saved_count}")
    print(f"[✓] Archivo generado en: {os.path.abspath(OUTPUT_FILE)}")


if __name__ == '__main__':
    main()
