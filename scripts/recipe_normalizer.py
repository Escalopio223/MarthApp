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

# Palabras adicionales y conectores a eliminar
CONNECTORS_REGEX = re.compile(
    r'\b(de|del|en|para|al|a|la|el|los|las|un|una|unos|unas|con|sin|y|o)\b',
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
    Limpia un string de ingrediente (ej. '400 gramos de pechuga de pollo en dados')
    dejando solo el nombre del producto ('Pechuga de pollo').
    """
    if not raw_text or not isinstance(raw_text, str):
        return None

    cleaned = raw_text.strip()
    # Eliminar contenido entre paréntesis (ej. "(opcional)", "(unos 200g)")
    cleaned = re.sub(r'\(.*?\)', '', cleaned)

    # Eliminar números, fracciones y caracteres especiales
    cleaned = re.sub(r'[\d½¼¾⅓⅔⅛/\-.,:+*%]', ' ', cleaned)

    # Eliminar unidades de medida
    cleaned = UNITS_REGEX.sub(' ', cleaned)

    # Eliminar descriptores de preparación
    cleaned = DESCRIPTORS_REGEX.sub(' ', cleaned)

    # Eliminar conectores sobrantes
    words = cleaned.split()
    clean_words = []
    for w in words:
        w_lower = w.lower()
        if not CONNECTORS_REGEX.fullmatch(w_lower) and len(w) > 1:
            clean_words.append(w_lower)

    result = " ".join(clean_words).strip().capitalize()

    if not result or len(result) < 3:
        return None

    # Excluir agua / sal / pimienta básicas
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
        # Separar por saltos de línea o puntos
        lines = [s.strip() for s in re.split(r'\n+|\.\s+', instructions) if len(s.strip()) > 5]
        raw_steps = lines if lines else [instructions.strip()]

    full_text = f"{title} " + " ".join(raw_steps)

    supported: List[str] = []
    method_data: Dict[str, Any] = {}

    has_airfryer = bool(AIRFRYER_TERMS.search(full_text))
    has_oven = bool(OVEN_TERMS.search(full_text))
    has_micro = bool(MICROWAVE_TERMS.search(full_text))
    has_stovetop = bool(STOVETOP_TERMS.search(full_text))

    # Extracción de temperaturas y tiempos
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

    # Si no tiene ninguno de los 3 electrodomésticos, o se detectó fuego tradicional
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
    """
    Normaliza un registro de receta de schema.org o dataset:
    Valida campos obligatorios y genera shopping_ingredients y supported_appliances.
    """
    title = (raw_recipe.get('name') or raw_recipe.get('title') or '').strip()
    if not title or len(title) < 3:
        return None

    source_url = raw_recipe.get('url') or raw_recipe.get('source_url') or f"generated://{hash(title)}"

    # Ingredientes detallados originales
    raw_ingredients = raw_recipe.get('recipeIngredient') or raw_recipe.get('ingredients') or []
    if isinstance(raw_ingredients, str):
        raw_ingredients = [i.strip() for i in raw_ingredients.split('\n') if i.strip()]

    detailed_ingredients = [str(i).strip() for i in raw_ingredients if str(i).strip()]
    if not detailed_ingredients:
        return None

    # Limpieza de ingredientes para lista de compra
    shopping_set = set()
    shopping_list = []
    for raw_ing in detailed_ingredients:
        cleaned = clean_single_ingredient(raw_ing)
        if cleaned and cleaned.lower() not in shopping_set:
            shopping_set.add(cleaned.lower())
            shopping_list.append(cleaned)

    # Si la lista de la compra quedó vacía, rescatar los 3 primeros nombres simples
    if not shopping_list:
        for raw_ing in detailed_ingredients[:4]:
            fallback = re.sub(r'[\d½¼¾⅓⅔⅛/\-.,:+*]', '', raw_ing).strip()
            if len(fallback) > 3:
                shopping_list.append(fallback[:30].capitalize())

    # Instrucciones y electrodomésticos
    raw_instructions = raw_recipe.get('recipeInstructions') or raw_recipe.get('instructions') or []
    appliances, instructions_payload = extract_cooking_methods_and_steps(title, raw_instructions)

    # Duración
    total_time = raw_recipe.get('total_time_minutes')
    if total_time is None and raw_recipe.get('totalTime'):
        total_time = parse_iso_duration(raw_recipe.get('totalTime'))
    if total_time is None:
        # Fallback de tiempo según appliance
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
