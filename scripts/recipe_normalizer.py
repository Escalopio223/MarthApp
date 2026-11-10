"""
recipe_normalizer.py
Módulo de procesamiento y limpieza de recetas:
- Detección de electrodomésticos (Airfryer, Horno, Microondas, Tradicional / Fuego)
- Extracción de temperatura y tiempos
- Limpieza y normalización de ingredientes para la lista de la compra (Shopping Ingredients)
"""

import re
from typing import List, Dict, Any, Tuple, Optional

# Unidades de medida y palabras comunes a eliminar en ingredientes
UNITS_REGEX = re.compile(
    r'\b('
    r'gramos?|gr?|kilogramos?|kg|mililitros?|ml|litros?|l|'
    r'cucharadas?|cucharaditas?|cda|cdta|tazas?|vasos?|copas?|'
    r'pizcas?|chorritos?|gotas?|dientes?|hojas?|ramas?|tallos?|'
    r'rebanadas?|lonchas?|rodajas?|trozos?|pedazos?|puñados?|'
    r'unidades?|piezas?|latas?|paquetes?|sobres?|tarros?|botes?'
    r')\b',
    re.IGNORECASE
)

# Frases sobre preparación o condimentos irrelevantes
DESCRIPTORS_REGEX = re.compile(
    r'\b('
    r'picad[oa]s?|trocead[oa]s?|cortad[oa]s?|en dados|en juliana|rallad[oa]s?|'
    r'al gusto|a gusto|opcional|fresc[oa]s?|secos?|cocid[oa]s?|limpi[oa]s?|'
    r'pelad[oa]s?|lavad[oa]s?|deshuesad[oa]s?|filetead[oa]s?|madur[oa]s?|'
    r'a temperatura ambiente|tibio|caliente|fr[ií]o|desmenuzad[oa]s?'
    r')\b',
    re.IGNORECASE
)

# Básicos comunes a excluir de la lista de la compra si vienen solos
BASIC_STAPLES_TO_SKIP = {
    'agua', 'sal', 'sal fina', 'sal gruesa', 'pimienta', 'sal y pimienta',
    'sal pimienta', 'sal y pimienta al gusto', 'pizca de sal', 'chorrito de agua', 'agua tibia', 'agua fría'
}

# Regex para detección de métodos de cocción
AIRFRYER_TERMS = re.compile(r'\b(freidora de aire|airfryer|air fryer|freidora sin aceite)\b', re.IGNORECASE)
OVEN_TERMS = re.compile(r'\b(horno|hornear|hornead[oa]|precalentar el horno|gratinar|bandeja de horno)\b', re.IGNORECASE)
MICROWAVE_TERMS = re.compile(r'\b(microondas|potencia máxima|vatios|\d{3,4}\s*w)\b', re.IGNORECASE)
STOVETOP_TERMS = re.compile(r'\b(sart[eé]n|olla|cazuela|cazo|wok|fuego lento|fuego medio|fuego fuerte|cocer|hervir|fre[ií]r|saltear)\b', re.IGNORECASE)

TEMP_REGEX = re.compile(r'(\d{2,3})\s*(?:°|º)?\s*[cC](?:\b|[\s,.])')
TIME_REGEX = re.compile(r'(\d{1,3})\s*(?:minutos?|mins?|min)\b', re.IGNORECASE)


def parse_iso_duration(duration_str: Optional[str]) -> Optional[int]:
    """Convierte duración ISO 8601 (ej. PT30M, PT1H15M) a minutos enteros."""
    if not duration_str:
        return None
    try:
        hours = 0
        minutes = 0
        match_h = re.search(r'(\d+)H', duration_str)
        match_m = re.search(r'(\d+)M', duration_str)
        if match_h:
            hours = int(match_h.group(1))
        if match_m:
            minutes = int(match_m.group(1))
        total = hours * 60 + minutes
        return total if total > 0 else None
    except Exception:
        return None


def clean_single_ingredient(raw_text: str) -> Optional[str]:
    """
    Limpia un string de ingrediente (ej. '⅓ taza de queso mozzarella o queso blanco rallado')
    dejando solo el nombre natural del producto ('Queso mozzarella').
    """
    if not raw_text or not isinstance(raw_text, str):
        return None

    # 1. Eliminar paréntesis (ej. "(opcional)", "(unos 200g)")
    cleaned = re.sub(r'\(.*?\)', '', raw_text).strip()

    # 2. Quedarse con la opción principal si hay alternativas con ' o ', ' u ', ' / '
    # Ej: 'queso mozzarella o queso blanco' -> 'queso mozzarella'
    cleaned = re.split(r'\s+(?:o|u|/)\s+', cleaned, maxsplit=1, flags=re.IGNORECASE)[0].strip()

    # 3. Eliminar números, fracciones y caracteres especiales
    cleaned = re.sub(r'[\d½¼¾⅓⅔⅛/\-.,:+*%]', ' ', cleaned)

    # 4. Eliminar unidades de medida
    cleaned = UNITS_REGEX.sub(' ', cleaned)

    # 5. Eliminar descriptores de preparación (picado, rallado, etc.)
    cleaned = DESCRIPTORS_REGEX.sub(' ', cleaned)

    # 6. Normalizar espacios
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()

    # 7. Limpiar partículas de inicio superfluas (ej. "de pechuga de pollo" -> "Pechuga de pollo")
    cleaned = re.sub(r'^(?:de|del|el|la|los|las|un|una|unos|unas)\s+', '', cleaned, flags=re.IGNORECASE).strip()

    # 8. Deduplicar palabras repetidas en el mismo ingrediente
    words = cleaned.split()
    seen = set()
    dedup = []
    for w in words:
        wl = w.lower()
        if wl not in seen:
            seen.add(wl)
            dedup.append(w)

    result = " ".join(dedup).strip().capitalize()

    if not result or len(result) < 3:
        return None

    # Excluir agua / sal básicas
    if result.lower() in BASIC_STAPLES_TO_SKIP:
        return None

    return result


def extract_cooking_methods_and_steps(
    title: str,
    instructions: Any
) -> Tuple[List[str], Dict[str, Any]]:
    """
    Analiza título e instrucciones para clasificar en airfryer, oven, microwave y stovetop.
    Extrae temperaturas y tiempos sugeridos por método.
    """
    raw_steps: List[str] = []
    if isinstance(instructions, list):
        for item in instructions:
            if isinstance(item, dict):
                text = item.get('text') or item.get('name') or ''
                if text:
                    raw_steps.append(str(text).strip())
            elif isinstance(item, str) and item.strip():
                raw_steps.append(item.strip())
    elif isinstance(instructions, str) and instructions.strip():
        lines = [s.strip() for s in re.split(r'\n+|\.\s+', instructions) if len(s.strip()) > 5]
        raw_steps = lines if lines else [instructions.strip()]

    full_text = f"{title} " + " ".join(raw_steps)

    supported: List[str] = []
    method_data: Dict[str, Any] = {}

    has_airfryer = bool(AIRFRYER_TERMS.search(full_text))
    has_oven = bool(OVEN_TERMS.search(full_text))
    has_micro = bool(MICROWAVE_TERMS.search(full_text))
    has_stovetop = bool(STOVETOP_TERMS.search(full_text))

    temp_matches = [int(m) for m in TEMP_REGEX.findall(full_text) if 60 <= int(m) <= 260]
    time_matches = [int(m) for m in TIME_REGEX.findall(full_text) if 1 <= int(m) <= 180]

    dominant_temp = temp_matches[0] if temp_matches else None
    dominant_time = time_matches[0] if time_matches else None

    if has_airfryer:
        supported.append('airfryer')
        method_data['airfryer'] = {
            'temp_celsius': dominant_temp or 180,
            'time_minutes': dominant_time or 15,
        }

    if has_oven:
        supported.append('oven')
        method_data['oven'] = {
            'temp_celsius': dominant_temp or 190,
            'time_minutes': dominant_time or 25,
        }

    if has_micro:
        supported.append('microwave')
        method_data['microwave'] = {
            'power': 'Máxima',
            'time_minutes': dominant_time or 5,
        }

    if not supported or has_stovetop:
        supported.append('stovetop')
        method_data['stovetop'] = {
            'type': 'Fuego tradicional / Sartén / Olla',
            'time_minutes': dominant_time or 20,
        }

    formatted_instructions = {
        'steps': raw_steps,
        'methods_info': method_data,
    }

    return supported, formatted_instructions


def normalize_recipe_record(raw_recipe: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    title = (raw_recipe.get('name') or raw_recipe.get('title') or '').strip()
    if not title or len(title) < 3:
        return None

    source_url = raw_recipe.get('url') or raw_recipe.get('source_url') or f"generated://{hash(title)}"

    raw_ingredients = raw_recipe.get('recipeIngredient') or raw_recipe.get('ingredients') or []
    if isinstance(raw_ingredients, str):
        raw_ingredients = [i.strip() for i in re.split(r'[\r\n]+|\s{3,}', raw_ingredients) if i.strip()]

    detailed_ingredients = []
    for item in raw_ingredients:
        if isinstance(item, str):
            parts = [p.strip() for p in re.split(r'[\r\n]+|\s{3,}', item) if p.strip()]
            detailed_ingredients.extend(parts)

    if not detailed_ingredients:
        return None

    shopping_set = set()
    shopping_list = []
    for raw_ing in detailed_ingredients:
        cleaned = clean_single_ingredient(raw_ing)
        if cleaned and cleaned.lower() not in shopping_set:
            shopping_set.add(cleaned.lower())
            shopping_list.append(cleaned)

    if not shopping_list:
        for raw_ing in detailed_ingredients[:4]:
            fallback = re.sub(r'[\d½¼¾⅓⅔⅛/\-.,:+*]', '', raw_ing).strip()
            if len(fallback) > 3:
                shopping_list.append(fallback[:30].capitalize())

    raw_instructions = raw_recipe.get('recipeInstructions') or raw_recipe.get('instructions') or []
    appliances, instructions_payload = extract_cooking_methods_and_steps(title, raw_instructions)

    total_time = raw_recipe.get('total_time_minutes')
    if total_time is None and raw_recipe.get('totalTime'):
        total_time = parse_iso_duration(raw_recipe.get('totalTime'))
    if total_time is None:
        total_time = 30

    cuisine = raw_recipe.get('recipeCuisine') or raw_recipe.get('cuisine') or 'Internacional'
    if isinstance(cuisine, list):
        cuisine = cuisine[0] if cuisine else 'Internacional'

    category = raw_recipe.get('recipeCategory') or raw_recipe.get('category') or 'Plato principal'
    if isinstance(category, list):
        category = category[0] if category else 'Plato principal'

    servings = raw_recipe.get('recipeYield') or raw_recipe.get('servings') or '2-4 raciones'
    if isinstance(servings, list):
        servings = str(servings[0])

    return {
        'source_url': source_url,
        'title': title,
        'cuisine': str(cuisine).capitalize(),
        'category': str(category).capitalize(),
        'total_time_minutes': int(total_time) if total_time else 30,
        'servings': str(servings),
        'shopping_ingredients': shopping_list,
        'detailed_ingredients': detailed_ingredients,
        'supported_appliances': appliances,
        'instructions': instructions_payload,
    }
