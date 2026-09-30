/**
 * ==============================================================================
 * SCRIPT DE GENERACIÓN Y SEEDING DEL CATÁLOGO DE ALIMENTACIÓN (MARTHAPP)
 * Genera ~1.000 recetas curadas de consumo cotidiano e internacional
 * con métodos de cocción (horno, airfryer, microondas) e ingredientes normalizados.
 *
 * Salidas:
 * 1. Genera archivo SQL optimizado e idempotente: supabase/seed_food_module.sql
 * 2. Si se suministran credenciales de Supabase en .env, permite ejecución directa por API.
 * ==============================================================================
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// 1. Mapeo de categorías maestras con UUIDs deterministas
const CATEGORIES = {
  dairy: { id: '00000000-0000-0000-0000-000000000001', name: 'Lácteos y Derivados' },
  fruit: { id: '00000000-0000-0000-0000-000000000002', name: 'Frutas' },
  vegetable: { id: '00000000-0000-0000-0000-000000000003', name: 'Verduras y Hortalizas' },
  meat: { id: '00000000-0000-0000-0000-000000000004', name: 'Carnes y Aves' },
  fish: { id: '00000000-0000-0000-0000-000000000005', name: 'Pescados y Mariscos' },
  grain: { id: '00000000-0000-0000-0000-000000000006', name: 'Cereales, Legumbres y Pastas' },
  bakery: { id: '00000000-0000-0000-0000-000000000007', name: 'Panadería y Masas' },
  snack: { id: '00000000-0000-0000-0000-000000000008', name: 'Snacks y Dulces' },
  cleaning: { id: '00000000-0000-0000-0000-000000000009', name: 'Limpieza y Hogar' }
};

// Generador determinista de UUID v4 basado en namespace y texto para que las recetas tengan IDs predecibles
function generateDeterministicUUID(seedText) {
  const hash = crypto.createHash('sha256').update('marthapp-food:' + seedText).digest('hex');
  return [
    hash.substring(0, 8),
    hash.substring(8, 12),
    '4' + hash.substring(13, 16),
    '8' + hash.substring(17, 20),
    hash.substring(20, 32)
  ].join('-');
}

// 2. Diccionario de Ingredientes y su Categoría
const INGREDIENT_CAT_MAP = {
  // Lácteos
  'leche entera': 'dairy',
  'leche desnatada': 'dairy',
  'leche de avena': 'dairy',
  'leche de almendras': 'dairy',
  'leche de soja': 'dairy',
  'yogur natural': 'dairy',
  'yogur griego': 'dairy',
  'queso parmesano': 'dairy',
  'queso mozzarella': 'dairy',
  'queso feta': 'dairy',
  'queso cheddar': 'dairy',
  'queso gouda': 'dairy',
  'queso emmental': 'dairy',
  'queso manchego': 'dairy',
  'queso gorgonzola': 'dairy',
  'queso ricotta': 'dairy',
  'queso crema': 'dairy',
  'queso fresco': 'dairy',
  'queso de cabra': 'dairy',
  'nata para cocinar': 'dairy',
  'mantequilla': 'dairy',
  'mantequilla clarificada (ghee)': 'dairy',

  // Frutas
  'manzana': 'fruit',
  'manzana golden': 'fruit',
  'pera': 'fruit',
  'plátano': 'fruit',
  'fresa': 'fruit',
  'frambuesa': 'fruit',
  'arándano': 'fruit',
  'limón': 'fruit',
  'zumo de limón': 'fruit',
  'lima': 'fruit',
  'zumo de lima': 'fruit',
  'naranja': 'fruit',
  'zumo de naranja': 'fruit',
  'aguacate': 'fruit',
  'piña': 'fruit',
  'mango': 'fruit',
  'melocotón': 'fruit',
  'kiwi': 'fruit',
  'uvas': 'fruit',
  'granada': 'fruit',
  'higos': 'fruit',

  // Verduras y Hortalizas
  'cebolla': 'vegetable',
  'cebolla morada': 'vegetable',
  'cebolleta': 'vegetable',
  'diente de ajo': 'vegetable',
  'tomate': 'vegetable',
  'tomate cherry': 'vegetable',
  'tomate triturado': 'vegetable',
  'tomate concentrado': 'vegetable',
  'pimiento rojo': 'vegetable',
  'pimiento verde': 'vegetable',
  'pimiento amarillo': 'vegetable',
  'calabacín': 'vegetable',
  'berenjena': 'vegetable',
  'zanahoria': 'vegetable',
  'patata': 'vegetable',
  'boniato': 'vegetable',
  'espinacas frescas': 'vegetable',
  'acelgas': 'vegetable',
  'lechuga romana': 'vegetable',
  'canónigos': 'vegetable',
  'rúcula': 'vegetable',
  'col': 'vegetable',
  'col lombarda': 'vegetable',
  'coliflor': 'vegetable',
  'brócoli': 'vegetable',
  'espárragos verdes': 'vegetable',
  'judías verdes': 'vegetable',
  'champiñones': 'vegetable',
  'setas shiitake': 'vegetable',
  'boletus': 'vegetable',
  'puerro': 'vegetable',
  'apio': 'vegetable',
  'calabaza': 'vegetable',
  'pepino': 'vegetable',
  'alcachofa': 'vegetable',
  'jalapeño': 'vegetable',
  'chile rojo': 'vegetable',
  'jengibre fresco': 'vegetable',
  'cilantro fresco': 'vegetable',
  'perejil fresco': 'vegetable',
  'albahaca fresca': 'vegetable',
  'menta fresca': 'vegetable',
  'orégano': 'vegetable',
  'romero fresco': 'vegetable',
  'tomillo': 'vegetable',

  // Carnes y Aves
  'pechuga de pollo': 'meat',
  'muslos de pollo': 'meat',
  'alitas de pollo': 'meat',
  'pollo picado': 'meat',
  'pechuga de pavo': 'meat',
  'solomillo de pavo': 'meat',
  'ternera picada': 'meat',
  'filete de ternera': 'meat',
  'solomillo de ternera': 'meat',
  'entrecot de ternera': 'meat',
  'lomo de cerdo': 'meat',
  'solomillo de cerdo': 'meat',
  'costillas de cerdo': 'meat',
  'carne picada mixta': 'meat',
  'jamón ibérico': 'meat',
  'jamón serrano': 'meat',
  'tocino ahumado': 'meat',
  'bacon': 'meat',
  'chorizo': 'meat',
  'morcilla': 'meat',
  'chuletas de cordero': 'meat',
  'conejo': 'meat',
  'huevo': 'meat', // clasificado tradicionalmente en proteína cárnica/avícola
  'clara de huevo': 'meat',

  // Pescados y Mariscos
  'lomo de salmón': 'fish',
  'filete de merluza': 'fish',
  'lomo de bacalao': 'fish',
  'atún fresco': 'fish',
  'atún en conserva': 'fish',
  'dorada': 'fish',
  'lubina': 'fish',
  'sardinas': 'fish',
  'boquerones': 'fish',
  'bonito del norte': 'fish',
  'sepia': 'fish',
  'calamar': 'fish',
  'pulpo cocido': 'fish',
  'gambas': 'fish',
  'langostinos': 'fish',
  'mejillones': 'fish',
  'almejas': 'fish',
  'bogavante': 'fish',
  'pescadilla': 'fish',
  'trucha': 'fish',

  // Cereales, Legumbres y Pastas
  'arroz bomba': 'grain',
  'arroz basmati': 'grain',
  'arroz jazmín': 'grain',
  'arroz integral': 'grain',
  'arroz arborio': 'grain',
  'espaguetis': 'grain',
  'macarrones': 'grain',
  'placas de lasaña': 'grain',
  'tallarines': 'grain',
  'noodles de arroz': 'grain',
  'fideos udon': 'grain',
  'fideos soba': 'grain',
  'fideos de trigo': 'grain',
  'garbanzos cocidos': 'grain',
  'lentejas pardinas': 'grain',
  'lentejas rojas': 'grain',
  'alubias blancas': 'grain',
  'frijoles negros': 'grain',
  'quinoa': 'grain',
  'cuscús': 'grain',
  'copos de avena': 'grain',
  'harina de trigo': 'grain',
  'harina de avena': 'grain',
  'harina de maíz': 'grain',
  'almidón de maíz': 'grain',
  'soja texturizada': 'grain',
  'edamame': 'grain',
  'tofu': 'grain',

  // Panadería y Masas
  'pan de hogaza': 'bakery',
  'pan integral': 'bakery',
  'pan de centeno': 'bakery',
  'pan rallado': 'bakery',
  'pan de molde': 'bakery',
  'pan de pita': 'bakery',
  'pan de hamburguesa': 'bakery',
  'pan naan': 'bakery',
  'masa de pizza': 'bakery',
  'masa quebrada': 'bakery',
  'masa de hojaldre': 'bakery',
  'tortillas de trigo': 'bakery',
  'tortillas de maíz': 'bakery',
  'obleas de empanadilla': 'bakery',
  'biscotes': 'bakery',

  // Snacks, Dulces, Frutos Secos y Condimentos Dulces
  'nueces': 'snack',
  'almendras': 'snack',
  'avellanas': 'snack',
  'cacahuetes': 'snack',
  'pistachos': 'snack',
  'anacardos': 'snack',
  'semillas de chía': 'snack',
  'semillas de lino': 'snack',
  'semillas de sésamo': 'snack',
  'pipas de calabaza': 'snack',
  'miel': 'snack',
  'sirope de arce': 'snack',
  'cacao en polvo puro': 'snack',
  'chocolate negro 85%': 'snack',
  'canela en polvo': 'snack',
  'extracto de vainilla': 'snack',
  'pasas': 'snack',
  'dátiles': 'snack',
  'totopos': 'snack',
  'patatas fritas': 'snack',
  'mantequilla de cacahuete': 'snack',

  // Despensa y Aceites (se asocian por cercanía a grain o vegetable)
  'aceite de oliva virgen extra': 'vegetable',
  'aceite de sésamo': 'snack',
  'aceite de girasol': 'vegetable',
  'vinagre de jerez': 'vegetable',
  'vinagre de manzana': 'vegetable',
  'vinagre de arroz': 'grain',
  'salsa de soja': 'grain',
  'salsa de pescado': 'fish',
  'caldo de pollo': 'meat',
  'caldo de verduras': 'vegetable',
  'caldo de pescado': 'fish',
  'leche de coco': 'fruit',
  'mostaza dijon': 'vegetable',
  'pasta de curry rojo': 'vegetable',
  'pasta de curry verde': 'vegetable',
  'pimentón dulce': 'vegetable',
  'pimentón picante': 'vegetable',
  'comino molido': 'vegetable',
  'cúrcuma': 'vegetable',
  'pimienta negra': 'vegetable',
  'sal fina': 'snack',
  'sal marina': 'snack'
};

// Función para obtener la categoría de un ingrediente con fallback inteligente
function getCategorySlug(ingredientName) {
  const norm = ingredientName.toLowerCase().trim();
  if (INGREDIENT_CAT_MAP[norm]) return INGREDIENT_CAT_MAP[norm];

  // Reglas heurísticas de coincidencia de subcadena
  if (norm.includes('queso') || norm.includes('leche') || norm.includes('yogur') || norm.includes('nata') || norm.includes('mantequilla')) return 'dairy';
  if (norm.includes('pollo') || norm.includes('ternera') || norm.includes('cerdo') || norm.includes('pavo') || norm.includes('jamón') || norm.includes('huevo') || norm.includes('bacon') || norm.includes('chorizo') || norm.includes('carne')) return 'meat';
  if (norm.includes('salmón') || norm.includes('merluza') || norm.includes('atún') || norm.includes('bacalao') || norm.includes('dorada') || norm.includes('lubina') || norm.includes('gamba') || norm.includes('calamar') || norm.includes('pulpo') || norm.includes('mejillón') || norm.includes('pescado')) return 'fish';
  if (norm.includes('arroz') || norm.includes('pasta') || norm.includes('espagueti') || norm.includes('macarrón') || norm.includes('lenteja') || norm.includes('garbanzo') || norm.includes('alubia') || norm.includes('fideo') || norm.includes('harina') || norm.includes('quinoa') || norm.includes('avena') || norm.includes('tofu')) return 'grain';
  if (norm.includes('pan') || norm.includes('masa') || norm.includes('tortilla de trigo') || norm.includes('tortilla de maíz') || norm.includes('hojaldre') || norm.includes('oblea')) return 'bakery';
  if (norm.includes('manzana') || norm.includes('plátano') || norm.includes('fresa') || norm.includes('naranja') || norm.includes('limón') || norm.includes('lima') || norm.includes('aguacate') || norm.includes('arándano') || norm.includes('mango') || norm.includes('piña') || norm.includes('fruta')) return 'fruit';
  if (norm.includes('nuez') || norm.includes('almendra') || norm.includes('chocolate') || norm.includes('cacao') || norm.includes('miel') || norm.includes('chía') || norm.includes('semilla') || norm.includes('snack') || norm.includes('dulce')) return 'snack';
  if (norm.includes('detergente') || norm.includes('estropajo') || norm.includes('papel') || norm.includes('lejía') || norm.includes('limpieza') || norm.includes('jabón')) return 'cleaning';

  return 'vegetable';
}

console.log('Iniciando construcción y curación de recetas...');

// 3. Catálogo base estructurado y generador curado
const curatedRecipes = [];
const seenTitles = new Set();

function addRecipe(r) {
  const title = r.title || r.t;
  if (!title) return;
  const normTitle = title.trim();
  if (seenTitles.has(normTitle)) return;
  seenTitles.add(normTitle);

  const ingredientsList = r.ingredients || r.ing || [];
  const processedIngredients = ingredientsList.map(ing => {
    const rawName = typeof ing === 'string' ? ing : (ing.name || ing.n);
    const name = rawName.toLowerCase().trim();
    const category_slug = typeof ing === 'object' && ing.category_slug ? ing.category_slug : getCategorySlug(name);
    return { name, category_slug };
  });

  const id = generateDeterministicUUID(normTitle);

  curatedRecipes.push({
    id,
    title: normTitle,
    country: r.country || r.c || 'España',
    cuisine_type: r.cuisine_type || r.cat || 'Mediterránea',
    prep_oven: r.prep_oven !== undefined ? r.prep_oven : (r.o || null),
    prep_airfryer: r.prep_airfryer !== undefined ? r.prep_airfryer : (r.a || null),
    prep_microwave: r.prep_microwave !== undefined ? r.prep_microwave : (r.m || null),
    is_global: true,
    environment_id: null,
    ingredients: processedIngredients
  });
}

// ------------------------------------------------------------------------------
// GENERACIÓN DE LOS 10 BLOQUES GASTRONÓMICOS CURADOS
// ------------------------------------------------------------------------------

// BLOQUE 1: Cocina Tradicional Española y Mediterránea (150 recetas)
const spanishBases = [
  { t: 'Tortilla de patatas tradicional', c: 'España', cat: 'Tradicional', o: null, a: 'Cocinar patatas y cebolla a 180°C durante 18 min antes de cuajar', m: null, ing: ['patata', 'huevo', 'cebolla', 'aceite de oliva virgen extra', 'sal fina'] },
  { t: 'Tortilla de patatas con cebolla caramelizada', c: 'España', cat: 'Tradicional', o: null, a: 'Dorar patatas y cebolla en airfryer a 180°C durante 20 min', m: null, ing: ['patata', 'cebolla', 'huevo', 'aceite de oliva virgen extra', 'sal fina'] },
  { t: 'Tortilla paisana con chorizo y pimientos', c: 'España', cat: 'Tradicional', o: null, a: null, m: null, ing: ['patata', 'huevo', 'chorizo', 'pimiento rojo', 'pimiento verde', 'guisantes', 'aceite de oliva virgen extra'] },
  { t: 'Paella valenciana tradicional', c: 'España', cat: 'Mediterránea', o: 'Reposo en horno caliente a 150°C 5 min para socarrat', a: null, m: null, ing: ['arroz bomba', 'pechuga de pollo', 'judías verdes', 'tomate triturado', 'aceite de oliva virgen extra', 'pimentón dulce'] },
  { t: 'Paella de marisco y langostinos', c: 'España', cat: 'Mediterránea', o: 'Gratinado final 3 min a 200°C', a: null, m: null, ing: ['arroz bomba', 'langostinos', 'mejillones', 'calamar', 'caldo de pescado', 'tomate triturado', 'aceite de oliva virgen extra'] },
  { t: 'Arroz negro con sepia y alioli', c: 'España', cat: 'Mediterránea', o: 'Horno suave a 160°C 4 min', a: null, m: null, ing: ['arroz bomba', 'sepia', 'caldo de pescado', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Arroz a banda con gambas', c: 'España', cat: 'Mediterránea', o: null, a: null, m: null, ing: ['arroz bomba', 'gambas', 'caldo de pescado', 'tomate triturado', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Arroz caldoso con bogavante', c: 'España', cat: 'Mediterránea', o: null, a: null, m: null, ing: ['arroz bomba', 'bogavante', 'caldo de pescado', 'tomate triturado', 'pimiento rojo', 'aceite de oliva virgen extra'] },
  { t: 'Arroz al horno valenciano', c: 'España', cat: 'Mediterránea', o: 'Hornear a 200°C durante 25-30 minutos en cazuela de barro', a: null, m: null, ing: ['arroz bomba', 'costillas de cerdo', 'morcilla', 'garbanzos cocidos', 'tomate', 'patata', 'diente de ajo'] },
  { t: 'Fideuá de marisco con alioli suave', c: 'España', cat: 'Mediterránea', o: 'Hornear a 200°C durante 5 min para levantar los fideos', a: null, m: null, ing: ['fideos de trigo', 'gambas', 'calamar', 'caldo de pescado', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Lentejas pardinas estofadas con verduras', c: 'España', cat: 'Tradicional', o: null, a: null, m: 'Calentar ración a 800W durante 3 min', ing: ['lentejas pardinas', 'zanahoria', 'patata', 'cebolla', 'pimiento verde', 'pimentón dulce', 'aceite de oliva virgen extra'] },
  { t: 'Lentejas con chorizo y costilla', c: 'España', cat: 'Tradicional', o: null, a: null, m: 'Regenerar en microondas a 750W durante 3 min', ing: ['lentejas pardinas', 'chorizo', 'costillas de cerdo', 'zanahoria', 'patata', 'diente de ajo', 'pimentón dulce'] },
  { t: 'Fabada asturiana tradicional', c: 'España', cat: 'Tradicional', o: null, a: null, m: null, ing: ['alubias blancas', 'chorizo', 'morcilla', 'tocino ahumado', 'pimentón dulce', 'aceite de oliva virgen extra'] },
  { t: 'Potaje de garbanzos con espinacas y bacalao', c: 'España', cat: 'Tradicional', o: null, a: null, m: 'Calentar a 800W durante 2 min', ing: ['garbanzos cocidos', 'espinacas frescas', 'lomo de bacalao', 'cebolla', 'diente de ajo', 'pimentón dulce'] },
  { t: 'Cocido madrileño completo', c: 'España', cat: 'Tradicional', o: null, a: null, m: null, ing: ['garbanzos cocidos', 'ternera picada', 'tocino ahumado', 'chorizo', 'morcilla', 'col', 'patata', 'zanahoria'] },
  { t: 'Albóndigas caseras en salsa española', c: 'España', cat: 'Tradicional', o: 'Hornear albóndigas a 190°C 15 min antes de guisar', a: 'Cocinar albóndigas en airfryer a 190°C durante 12 min', m: 'Recalentar en microondas a 700W 2 min', ing: ['carne picada mixta', 'huevo', 'pan rallado', 'cebolla', 'zanahoria', 'caldo de pollo', 'aceite de oliva virgen extra'] },
  { t: 'Albóndigas en salsa de tomate casero', c: 'España', cat: 'Tradicional', o: null, a: 'Dorado previo en airfryer a 180°C durante 10 min', m: null, ing: ['ternera picada', 'huevo', 'tomate triturado', 'cebolla', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Pollo al ajillo tradicional con patatas', c: 'España', cat: 'Tradicional', o: 'Asar a 200°C 30 min', a: 'Cocinar en airfryer a 190°C durante 20 min moviendo a mitad', m: null, ing: ['muslos de pollo', 'diente de ajo', 'patata', 'aceite de oliva virgen extra', 'perejil fresco', 'pimienta negra'] },
  { t: 'Pollo en pepitoria con almendras', c: 'España', cat: 'Tradicional', o: null, a: null, m: null, ing: ['pechuga de pollo', 'almendras', 'huevo', 'cebolla', 'diente de ajo', 'caldo de pollo', 'aceite de oliva virgen extra'] },
  { t: 'Pisto manchego con huevo a la plancha', c: 'España', cat: 'Mediterránea', o: 'Hornear verduras picadas a 190°C 25 min', a: 'Asar verduras en airfryer a 180°C 15 min', m: 'Cocinar huevo poché en taza con agua 1 min', ing: ['calabacín', 'berenjena', 'pimiento rojo', 'pimiento verde', 'tomate triturado', 'cebolla', 'huevo', 'aceite de oliva virgen extra'] },
  { t: 'Gazpacho andaluz tradicional', c: 'España', cat: 'Mediterránea', o: null, a: null, m: null, ing: ['tomate', 'pepino', 'pimiento verde', 'diente de ajo', 'pan integral', 'aceite de oliva virgen extra', 'vinagre de jerez'] },
  { t: 'Salmorejo cordobés con jamón y huevo duro', c: 'España', cat: 'Mediterránea', o: null, a: null, m: null, ing: ['tomate', 'pan de hogaza', 'aceite de oliva virgen extra', 'diente de ajo', 'jamón ibérico', 'huevo'] },
  { t: 'Ajoblanco malagueño con uvas', c: 'España', cat: 'Mediterránea', o: null, a: null, m: null, ing: ['almendras', 'pan de hogaza', 'diente de ajo', 'uvas', 'aceite de oliva virgen extra', 'vinagre de jerez'] },
  { t: 'Merluza en salsa verde con almejas', c: 'España', cat: 'Mediterránea', o: 'Hornear a 180°C 12 min', a: null, m: 'Cocinar lomos tapados con salsa 3 min a 750W', ing: ['filete de merluza', 'almejas', 'diente de ajo', 'perejil fresco', 'caldo de pescado', 'aceite de oliva virgen extra'] },
  { t: 'Bacalao al pil-pil tradicional', c: 'España', cat: 'Tradicional', o: null, a: null, m: null, ing: ['lomo de bacalao', 'diente de ajo', 'aceite de oliva virgen extra', 'chile rojo'] },
  { t: 'Bacalao a la vizcaína', c: 'España', cat: 'Tradicional', o: 'Terminar en horno a 180°C 10 min', a: null, m: null, ing: ['lomo de bacalao', 'pimiento rojo', 'cebolla', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Dorada a la sal con verduras', c: 'España', cat: 'Mediterránea', o: 'Hornear cubierta de sal a 200°C durante 25 minutos', a: null, m: null, ing: ['dorada', 'sal marina', 'calabacín', 'patata', 'aceite de oliva virgen extra'] },
  { t: 'Lubina a la espalda con ajos y guindilla', c: 'España', cat: 'Mediterránea', o: 'Hornear abierta a 200°C durante 15 minutos', a: 'Cocinar en airfryer a 190°C durante 12 min piel abajo', m: null, ing: ['lubina', 'diente de ajo', 'chile rojo', 'vinagre de manzana', 'aceite de oliva virgen extra'] },
  { t: 'Calamares en su tinta con arroz blanco', c: 'España', cat: 'Tradicional', o: null, a: null, m: 'Calentar arroz basmati 2 min a 800W', ing: ['calamar', 'cebolla', 'arroz basmati', 'tomate triturado', 'aceite de oliva virgen extra'] },
  { t: 'Sepia a la plancha con majado de ajo y perejil', c: 'España', cat: 'Mediterránea', o: null, a: 'Cocinar sepia limpia a 200°C 10 min en airfryer', m: null, ing: ['sepia', 'diente de ajo', 'perejil fresco', 'limón', 'aceite de oliva virgen extra'] },
  { t: 'Gambas al ajillo en cazuela', c: 'España', cat: 'Tradicional', o: 'Hornear en cazuela a 220°C 6 min', a: 'Cazuelita apta en airfryer a 200°C durante 5 min', m: null, ing: ['gambas', 'diente de ajo', 'chile rojo', 'aceite de oliva virgen extra', 'perejil fresco'] },
  { t: 'Mejillones al vapor con limón y laurel', c: 'España', cat: 'Mediterránea', o: null, a: null, m: 'Abrir tapados en microondas a máxima potencia 3 min', ing: ['mejillones', 'limón', 'pimienta negra', 'aceite de oliva virgen extra'] },
  { t: 'Pulpo a la gallega con patatas y pimentón', c: 'España', cat: 'Tradicional', o: null, a: 'Dorar patatas en airfryer 15 min a 180°C', m: 'Templar pulpo 40 segundos a 600W sin sobrecalentar', ing: ['pulpo cocido', 'patata', 'pimentón dulce', 'pimentón picante', 'sal marina', 'aceite de oliva virgen extra'] },
  { t: 'Carrilleras de cerdo ibérico al vino tinto', c: 'España', cat: 'Tradicional', o: 'Guisar tapado a 160°C 2 horas en horno', a: null, m: null, ing: ['lomo de cerdo', 'cebolla', 'zanahoria', 'puerro', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Solomillo de cerdo al Pedro Ximénez', c: 'España', cat: 'Tradicional', o: 'Terminar carne a 180°C 8 min', a: 'Marcar solomillo en airfryer a 190°C durante 10 min', m: null, ing: ['solomillo de cerdo', 'cebolla', 'pasas', 'aceite de oliva virgen extra', 'pimienta negra'] },
  { t: 'Croquetas caseras de jamón ibérico', c: 'España', cat: 'Tradicional', o: 'Hornear a 200°C 15 min pintadas con aceite', a: 'Cocinar en airfryer a 200°C durante 10 min pulverizando aceite', m: null, ing: ['jamón ibérico', 'leche entera', 'harina de trigo', 'mantequilla', 'huevo', 'pan rallado', 'aceite de oliva virgen extra'] },
  { t: 'Croquetas cremosas de boletus y queso', c: 'España', cat: 'Tradicional', o: 'Hornear a 200°C 14 min', a: 'Cocinar en airfryer a 195°C durante 9 min', m: null, ing: ['boletus', 'queso manchego', 'leche entera', 'harina de trigo', 'mantequilla', 'huevo', 'pan rallado'] },
  { t: 'Escalivada catalana de verduras asadas', c: 'España', cat: 'Mediterránea', o: 'Asar verduras enteras a 200°C durante 45 minutos', a: 'Asar en airfryer a 190°C durante 25 min girando a la mitad', m: null, ing: ['berenjena', 'pimiento rojo', 'cebolla', 'diente de ajo', 'aceite de oliva virgen extra', 'sal marina'] },
  { t: 'Espinacas a la catalana con pasas y piñones', c: 'España', cat: 'Mediterránea', o: null, a: null, m: 'Descongelar y cocer espinacas a 800W 3 min', ing: ['espinacas frescas', 'pasas', 'anacardos', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Zarzuela de pescado y marisco de la costa', c: 'España', cat: 'Mediterránea', o: 'Gratinado final 5 min a 200°C', a: null, m: null, ing: ['filete de merluza', 'calamar', 'gambas', 'mejillones', 'tomate triturado', 'almendras', 'caldo de pescado'] }
];

spanishBases.forEach(addRecipe);

// Expandir variantes mediterráneas tradicionales y regionales
const proteinSpanish = [
  { name: 'Pollo de corral', ing: 'pechuga de pollo', oven: 'Hornear a 190°C 35 min', air: 'Airfryer a 180°C 22 min' },
  { name: 'Conejo de monte', ing: 'conejo', oven: 'Hornear con hierbas a 190°C 30 min', air: 'Airfryer a 185°C 18 min' },
  { name: 'Ternera de la sierra', ing: 'filete de ternera', oven: 'Hornear suave a 180°C 15 min', air: 'Airfryer a 190°C 8 min' },
  { name: 'Costillejas adobadas', ing: 'costillas de cerdo', oven: 'Hornear a 180°C 40 min', air: 'Airfryer a 180°C 25 min' },
  { name: 'Lomo embuchado en salsa', ing: 'lomo de cerdo', oven: 'Hornear a 180°C 20 min', air: 'Airfryer a 180°C 14 min' },
  { name: 'Trucha de río', ing: 'trucha', oven: 'Hornear con jamón a 190°C 15 min', air: 'Airfryer a 180°C 10 min' },
  { name: 'Sardinas frescas', ing: 'sardinas', oven: 'Asar sobre sal a 210°C 10 min', air: 'Airfryer a 200°C 8 min sin humo' },
  { name: 'Boquerones fritos o plancha', ing: 'boquerones', oven: 'Hornear a 200°C 8 min', air: 'Airfryer a 195°C 7 min crujientes' },
  { name: 'Pescadilla de lonja', ing: 'pescadilla', oven: 'Hornear a 180°C 14 min', air: 'Airfryer a 180°C 10 min' }
];

const spanishSauces = [
  { sauce: 'al ajillo con vino blanco', ings: ['diente de ajo', 'aceite de oliva virgen extra', 'perejil fresco'] },
  { sauce: 'en salsa chilindrón con pimientos', ings: ['pimiento rojo', 'pimiento verde', 'cebolla', 'tomate triturado'] },
  { sauce: 'a la cazadora con champiñones', ings: ['champiñones', 'cebolla', 'zanahoria', 'diente de ajo'] },
  { sauce: 'con tomate frito casero y romero', ings: ['tomate triturado', 'cebolla', 'romero fresco', 'aceite de oliva virgen extra'] },
  { sauce: 'en salsa verde de la abuela', ings: ['diente de ajo', 'perejil fresco', 'caldo de verduras', 'aceite de oliva virgen extra'] },
  { sauce: 'al horno con patatas panadera', ings: ['patata', 'cebolla', 'pimiento verde', 'aceite de oliva virgen extra'] },
  { sauce: 'estofado con zanahorias y guisantes', ings: ['zanahoria', 'patata', 'cebolla', 'pimentón dulce'] },
  { sauce: 'a la riojana con chorizo y pimientos', ings: ['chorizo', 'pimiento rojo', 'diente de ajo', 'cebolla'] },
  { sauce: 'encebollado con toque de pimentón', ings: ['cebolla', 'pimentón dulce', 'aceite de oliva virgen extra', 'laurel'] },
  { sauce: 'en escabeche suave tradicional', ings: ['zanahoria', 'cebolla', 'vinagre de jerez', 'diente de ajo'] },
  { sauce: 'a la jardinera con hortalizas de huerta', ings: ['zanahoria', 'judías verdes', 'patata', 'cebolla'] },
  { sauce: 'al limón con hierbas provenzales', ings: ['limón', 'romero fresco', 'tomillo', 'aceite de oliva virgen extra'] }
];

proteinSpanish.forEach(p => {
  spanishSauces.forEach(s => {
    addRecipe({
      title: `${p.name} ${s.sauce}`,
      country: 'España',
      cuisine_type: 'Tradicional',
      prep_oven: p.oven,
      prep_airfryer: p.air,
      prep_microwave: 'Calentar ración a 750W durante 2-3 min',
      ingredients: [p.ing, ...s.ings, 'sal fina']
    });
  });
});

// BLOQUE 2: Cocina Italiana Tradicional & Creativa (130 recetas)
const italianBases = [
  { t: 'Spaghetti carbonara tradicional auténtica', c: 'Italia', cat: 'Italiana', o: null, a: null, m: null, ing: ['espaguetis', 'tocino ahumado', 'huevo', 'queso parmesano', 'pimienta negra'] },
  { t: 'Tagliatelle al ragù bolognese casero', c: 'Italia', cat: 'Italiana', o: null, a: null, m: 'Calentar a 800W durante 2 min', ing: ['tallarines', 'ternera picada', 'tomate triturado', 'zanahoria', 'apio', 'cebolla', 'queso parmesano'] },
  { t: 'Penne all arrabbiata picante', c: 'Italia', cat: 'Italiana', o: null, a: null, m: null, ing: ['macarrones', 'tomate triturado', 'diente de ajo', 'chile rojo', 'albahaca fresca', 'aceite de oliva virgen extra'] },
  { t: 'Spaghetti aglio olio e peperoncino', c: 'Italia', cat: 'Italiana', o: null, a: null, m: null, ing: ['espaguetis', 'diente de ajo', 'chile rojo', 'aceite de oliva virgen extra', 'perejil fresco'] },
  { t: 'Bucatini all amatriciana clásica', c: 'Italia', cat: 'Italiana', o: null, a: null, m: null, ing: ['espaguetis', 'tocino ahumado', 'tomate triturado', 'queso parmesano', 'chile rojo'] },
  { t: 'Trofie al pesto genovés auténtico', c: 'Italia', cat: 'Italiana', o: null, a: null, m: null, ing: ['espaguetis', 'albahaca fresca', 'queso parmesano', 'anacardos', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Lasaña boloñesa clásica gratinada', c: 'Italia', cat: 'Italiana', o: 'Hornear a 190°C durante 25-30 minutos hasta dorar', a: 'Hornear en molde apto a 180°C 18 min', m: 'Regenerar porción a 750W 4 min', ing: ['placas de lasaña', 'carne picada mixta', 'tomate triturado', 'leche entera', 'harina de trigo', 'mantequilla', 'queso mozzarella'] },
  { t: 'Lasaña vegetal de ricota y espinacas', c: 'Italia', cat: 'Italiana', o: 'Hornear a 190°C durante 25 minutos', a: 'Cocinar porción a 180°C 15 min en airfryer', m: 'Calentar a 700W 3 min', ing: ['placas de lasaña', 'espinacas frescas', 'queso ricotta', 'queso parmesano', 'tomate triturado', 'queso mozzarella'] },
  { t: 'Canelones de carne gratinados con bechamel', c: 'Italia', cat: 'Italiana', o: 'Hornear a 200°C durante 20 minutos con grill activado', a: 'Gratinar a 190°C 12 min', m: null, ing: ['placas de lasaña', 'ternera picada', 'leche entera', 'mantequilla', 'harina de trigo', 'queso gouda'] },
  { t: 'Parmigiana di melanzane tradicional', c: 'Italia', cat: 'Italiana', o: 'Hornear a 180°C durante 30 minutos', a: 'Hornear en airfryer a 180°C 20 min', m: null, ing: ['berenjena', 'tomate triturado', 'queso mozzarella', 'queso parmesano', 'albahaca fresca', 'aceite de oliva virgen extra'] },
  { t: 'Risotto alla milanese con azafrán y mantecatura', c: 'Italia', cat: 'Italiana', o: null, a: null, m: null, ing: ['arroz arborio', 'mantequilla', 'queso parmesano', 'cebolla', 'caldo de pollo'] },
  { t: 'Risotto ai funghi con boletus y parmesano', c: 'Italia', cat: 'Italiana', o: null, a: null, m: null, ing: ['arroz arborio', 'boletus', 'champiñones', 'mantequilla', 'queso parmesano', 'cebolla', 'caldo de verduras'] },
  { t: 'Risotto de calabaza asada y gorgonzola', c: 'Italia', cat: 'Italiana', o: 'Asar calabaza previamente a 200°C 20 min', a: 'Asar calabaza en airfryer a 190°C 12 min', m: null, ing: ['arroz arborio', 'calabaza', 'queso gorgonzola', 'cebolla', 'mantequilla', 'caldo de verduras'] },
  { t: 'Risotto al frutti di mare marinero', c: 'Italia', cat: 'Italiana', o: null, a: null, m: null, ing: ['arroz arborio', 'gambas', 'mejillones', 'calamar', 'caldo de pescado', 'diente de ajo', 'perejil fresco'] },
  { t: 'Gnocchi alla sorrentina gratinados con mozzarella', c: 'Italia', cat: 'Italiana', o: 'Gratinar a 200°C 10 minutos', a: 'Airfryer a 190°C durante 8 min hasta fundir queso', m: null, ing: ['patata', 'harina de trigo', 'tomate triturado', 'queso mozzarella', 'albahaca fresca', 'queso parmesano'] },
  { t: 'Gnocchi a los cuatro quesos cremosos', c: 'Italia', cat: 'Italiana', o: 'Gratinar a 210°C 8 min', a: null, m: 'Calentar a 750W 2 min', ing: ['patata', 'harina de trigo', 'queso gorgonzola', 'queso parmesano', 'queso mozzarella', 'nata para cocinar'] },
  { t: 'Focaccia artesanal con romero y tomatitos cherry', c: 'Italia', cat: 'Italiana', o: 'Hornear a 210°C durante 18-20 minutos', a: 'Cocinar masa en airfryer a 180°C 14 min', m: null, ing: ['harina de trigo', 'tomate cherry', 'romero fresco', 'aceite de oliva virgen extra', 'sal marina'] },
  { t: 'Calzone relleno de jamón, champiñones y mozzarella', c: 'Italia', cat: 'Italiana', o: 'Hornear a 220°C durante 15 minutos', a: 'Cocinar en airfryer a 190°C 12 min', m: null, ing: ['masa de pizza', 'jamón serrano', 'champiñones', 'queso mozzarella', 'tomate triturado'] },
  { t: 'Ossobuco a la milanesa con gremolata', c: 'Italia', cat: 'Italiana', o: 'Cocinar tapado a 160°C 1h 45 min en horno', a: null, m: null, ing: ['filete de ternera', 'cebolla', 'zanahoria', 'apio', 'tomate triturado', 'limón', 'perejil fresco', 'diente de ajo'] },
  { t: 'Saltimbocca alla romana con salvia y jamón', c: 'Italia', cat: 'Italiana', o: 'Terminar a 180°C 5 min', a: 'Cocinar en airfryer a 190°C 7 min', m: null, ing: ['filete de ternera', 'jamón serrano', 'mantequilla', 'aceite de oliva virgen extra'] }
];

italianBases.forEach(addRecipe);

// Generador de pastas y salsas italianas
const pastaTypes = ['Spaghetti', 'Penne rigate', 'Tagliatelle', 'Rigatoni', 'Fusilli', 'Farfalle', 'Gnocchi'];
const italianSauceCombinations = [
  { name: 'alla norma con berenjenas y ricotta salata', ings: ['berenjena', 'tomate triturado', 'queso ricotta', 'albahaca fresca', 'diente de ajo'] },
  { name: 'alfredo cremoso con parmesano y mantequilla', ings: ['nata para cocinar', 'mantequilla', 'queso parmesano', 'pimienta negra'] },
  { name: 'con setas silvestres y aceite de trufa', ings: ['champiñones', 'boletus', 'diente de ajo', 'perejil fresco', 'aceite de oliva virgen extra'] },
  { name: 'con gambas al ajillo y tomates secos', ings: ['gambas', 'diente de ajo', 'tomate cherry', 'chile rojo', 'aceite de oliva virgen extra'] },
  { name: 'con salmón fresco y salsa cremosa de eneldo', ings: ['lomo de salmón', 'nata para cocinar', 'cebolla', 'limón', 'pimienta negra'] },
  { name: 'con pesto rojo de tomates secos y almendras', ings: ['tomate triturado', 'almendras', 'queso parmesano', 'aceite de oliva virgen extra', 'diente de ajo'] },
  { name: 'con ragù de ternera y romero', ings: ['ternera picada', 'tomate triturado', 'zanahoria', 'cebolla', 'romero fresco'] },
  { name: 'con salsa cuatro quesos y nueces', ings: ['queso mozzarella', 'queso gorgonzola', 'queso parmesano', 'nueces', 'nata para cocinar'] },
  { name: 'con atún, alcaparras y aceitunas negras', ings: ['atún en conserva', 'tomate triturado', 'cebolla', 'diente de ajo', 'orégano'] },
  { name: 'alla putanesca con anchoas y guindilla', ings: ['tomate triturado', 'diente de ajo', 'chile rojo', 'aceite de oliva virgen extra'] },
  { name: 'con pollo dorado y brócoli al vapor', ings: ['pechuga de pollo', 'brócoli', 'diente de ajo', 'queso parmesano', 'aceite de oliva virgen extra'] },
  { name: 'con calabacín rallado, menta y limón', ings: ['calabacín', 'limón', 'menta fresca', 'queso parmesano', 'aceite de oliva virgen extra'] },
  { name: 'con salchicha italiana y semillas de hinojo', ings: ['carne picada mixta', 'cebolla', 'tomate triturado', 'pimiento rojo'] },
  { name: 'con crema de calabaza y speck crujiente', ings: ['calabaza', 'bacon', 'cebolla', 'queso parmesano', 'mantequilla'] },
  { name: 'con almejas frescas al vino blanco', ings: ['almejas', 'diente de ajo', 'perejil fresco', 'chile rojo', 'aceite de oliva virgen extra'] }
];

pastaTypes.forEach(pasta => {
  italianSauceCombinations.forEach(sc => {
    addRecipe({
      title: `${pasta} ${sc.name}`,
      country: 'Italia',
      cuisine_type: 'Italiana',
      prep_oven: 'Gratinar con queso a 200°C 6 min opcional',
      prep_airfryer: null,
      prep_microwave: 'Calentar plato servido a 750W 2 min',
      ingredients: [pasta.toLowerCase().includes('gnocchi') ? 'patata' : 'espaguetis', ...sc.ings, 'sal fina']
    });
  });
});

// BLOQUE 3: Cocina Asiática (Japón, China, Tailandia, India, Corea, Vietnam) (130 recetas)
const asianBases = [
  { t: 'Ramen de pollo shoyu con huevo marinado y bambú', c: 'Japón', cat: 'Asiática', o: null, a: null, m: 'Calentar caldo a 800W 3 min', ing: ['fideos de trigo', 'pechuga de pollo', 'huevo', 'cebolleta', 'salsa de soja', 'aceite de sésamo', 'jengibre fresco'] },
  { t: 'Ramen de miso con setas shiitake y maíz dulce', c: 'Japón', cat: 'Asiática', o: null, a: null, m: null, ing: ['fideos de trigo', 'setas shiitake', 'tofu', 'cebolleta', 'salsa de soja', 'aceite de sésamo'] },
  { t: 'Salmón teriyaki con sésamo tostado y arroz jazmín', c: 'Japón', cat: 'Asiática', o: 'Hornear salmón a 190°C 12 min lacando con salsa', a: 'Cocinar en airfryer a 180°C durante 9 min', m: 'Arroz al vapor a 800W 2 min', ing: ['lomo de salmón', 'arroz jazmín', 'salsa de soja', 'miel', 'semillas de sésamo', 'cebolleta', 'jengibre fresco'] },
  { t: 'Pollo teriyaki salteado con verduras crujientes', c: 'Japón', cat: 'Asiática', o: null, a: 'Pollo en airfryer a 190°C 14 min con salsa', m: null, ing: ['pechuga de pollo', 'pimiento rojo', 'cebolla', 'brócoli', 'salsa de soja', 'miel', 'semillas de sésamo'] },
  { t: 'Tataki de atún rojo en costra de sésamo', c: 'Japón', cat: 'Asiática', o: null, a: null, m: null, ing: ['atún fresco', 'semillas de sésamo', 'salsa de soja', 'aceite de sésamo', 'lima', 'jengibre fresco'] },
  { t: 'Pollo katsu crujiente con arroz y salsa curry', c: 'Japón', cat: 'Asiática', o: 'Hornear pollo empanado a 200°C 18 min', a: 'Cocinar pechuga empanada a 195°C 14 min en airfryer', m: null, ing: ['pechuga de pollo', 'pan rallado', 'huevo', 'arroz jazmín', 'zanahoria', 'cebolla', 'cúrcuma'] },
  { t: 'Gyozas japonesas de cerdo y col al vapor y plancha', c: 'Japón', cat: 'Asiática', o: 'Hornear a 190°C 12 min', a: 'Cocinar en airfryer a 185°C 8 min pulverizando aceite', m: 'Tapar con film húmedo a 750W 2 min', ing: ['obleas de empanadilla', 'lomo de cerdo', 'col', 'cebolleta', 'salsa de soja', 'aceite de sésamo', 'jengibre fresco'] },
  { t: 'Sopa de miso tradicional con tofu y alga wakame', c: 'Japón', cat: 'Asiática', o: null, a: null, m: 'Calentar caldo suavemente a 700W 2 min', ing: ['tofu', 'cebolleta', 'salsa de soja', 'diente de ajo', 'jengibre fresco'] },
  { t: 'Yakimeshi arroz frito japonés con verduras y huevo', c: 'Japón', cat: 'Asiática', o: null, a: null, m: 'Regenerar ración a 800W 2 min', ing: ['arroz jazmín', 'huevo', 'zanahoria', 'cebolleta', 'salsa de soja', 'aceite de sésamo'] },
  { t: 'Pad Thai tradicional con gambas, cacahuetes y lima', c: 'Tailandia', cat: 'Asiática', o: null, a: null, m: null, ing: ['noodles de arroz', 'gambas', 'huevo', 'cacahuetes', 'cebolleta', 'lima', 'salsa de soja'] },
  { t: 'Pad Thai vegetal con tofu marinado y brotes', c: 'Tailandia', cat: 'Asiática', o: null, a: null, m: null, ing: ['noodles de arroz', 'tofu', 'cacahuetes', 'cebolleta', 'lima', 'salsa de soja', 'zanahoria'] },
  { t: 'Curry rojo tailandés con pollo y leche de coco', c: 'Tailandia', cat: 'Asiática', o: null, a: null, m: 'Calentar a 750W 3 min', ing: ['pechuga de pollo', 'leche de coco', 'pasta de curry rojo', 'pimiento rojo', 'calabacín', 'arroz jazmín'] },
  { t: 'Curry verde tailandés con langostinos y bambú', c: 'Tailandia', cat: 'Asiática', o: null, a: null, m: null, ing: ['langostinos', 'leche de coco', 'pasta de curry verde', 'berenjena', 'lima', 'albahaca fresca'] },
  { t: 'Sopa Tom Yum de langostinos con lemongrass', c: 'Tailandia', cat: 'Asiática', o: null, a: null, m: 'Calentar caldo especiado a 800W 3 min', ing: ['langostinos', 'champiñones', 'tomate cherry', 'lima', 'chile rojo', 'cilantro fresco'] },
  { t: 'Pollo Tikka Masala cremoso con arroz basmati', c: 'India', cat: 'Asiática', o: 'Hornear brochetas de pollo marinado a 210°C 15 min', a: 'Dorar pollo marinado en airfryer a 200°C 10 min', m: 'Regenerar con salsa a 750W 3 min', ing: ['pechuga de pollo', 'yogur natural', 'tomate triturado', 'nata para cocinar', 'cebolla', 'cúrcuma', 'comino molido', 'arroz basmati'] },
  { t: 'Butter Chicken suave con pan naan', c: 'India', cat: 'Asiática', o: 'Asar pollo a 200°C 14 min', a: 'Pollo en airfryer a 195°C 11 min', m: null, ing: ['pechuga de pollo', 'mantequilla', 'tomate concentrado', 'nata para cocinar', 'pan naan', 'cúrcuma', 'jengibre fresco'] },
  { t: 'Dhal de lentejas rojas al curry con coco', c: 'India', cat: 'Asiática', o: null, a: null, m: 'Calentar en cuenco a 800W 3 min', ing: ['lentejas rojas', 'leche de coco', 'tomate triturado', 'cebolla', 'diente de ajo', 'cúrcuma', 'espinacas frescas'] },
  { t: 'Biryani especiado de pollo con frutos secos', c: 'India', cat: 'Asiática', o: 'Acabar arroz tapado al horno a 170°C 15 min', a: null, m: null, ing: ['arroz basmati', 'pechuga de pollo', 'cebolla', 'anacardos', 'pasas', 'yogur natural', 'cúrcuma'] },
  { t: 'Pollo Kung Pao con cacahuetes y pimientos secos', c: 'China', cat: 'Asiática', o: null, a: null, m: null, ing: ['pechuga de pollo', 'cacahuetes', 'pimiento rojo', 'cebolleta', 'salsa de soja', 'chile rojo', 'jengibre fresco'] },
  { t: 'Ternera salteada con salsa de ostras y brócoli', c: 'China', cat: 'Asiática', o: null, a: null, m: null, ing: ['filete de ternera', 'brócoli', 'cebolla', 'diente de ajo', 'salsa de soja', 'aceite de sésamo'] },
  { t: 'Arroz chaufa cantonés con pollo y verduras', c: 'China', cat: 'Asiática', o: null, a: null, m: 'Regenerar arroz a 800W 2 min', ing: ['arroz basmati', 'pechuga de pollo', 'huevo', 'cebolleta', 'pimiento rojo', 'salsa de soja'] },
  { t: 'Noodles Chow Mein salteados con verduras y cerdo', c: 'China', cat: 'Asiática', o: null, a: null, m: null, ing: ['fideos de trigo', 'lomo de cerdo', 'col', 'zanahoria', 'cebolleta', 'salsa de soja', 'aceite de sésamo'] },
  { t: 'Pho vietnamita de ternera con hierbas frescas', c: 'Vietnam', cat: 'Asiática', o: null, a: null, m: 'Caldo humeante a 800W 3 min', ing: ['noodles de arroz', 'filete de ternera', 'cebolleta', 'cilantro fresco', 'menta fresca', 'lima', 'jengibre fresco'] },
  { t: 'Bulgogi coreano de ternera marinada con sésamo', c: 'Corea', cat: 'Asiática', o: null, a: 'Cocinar tiras marinadas a 200°C 8 min en airfryer', m: null, ing: ['filete de ternera', 'salsa de soja', 'aceite de sésamo', 'diente de ajo', 'cebolleta', 'semillas de sésamo', 'pera'] }
];

asianBases.forEach(addRecipe);

// Generador de salteados Wok y Currys asiáticos
const wokProteins = [
  { name: 'Pollo marinado', ing: 'pechuga de pollo' },
  { name: 'Tiras de ternera', ing: 'filete de ternera' },
  { name: 'Lomo de cerdo magro', ing: 'lomo de cerdo' },
  { name: 'Langostinos pelados', ing: 'langostinos' },
  { name: 'Tacos de salmón', ing: 'lomo de salmón' },
  { name: 'Tofu firme dorado', ing: 'tofu' },
  { name: 'Calamar troceado', ing: 'calamar' },
  { name: 'Pechuga de pavo', ing: 'pechuga de pavo' }
];

const wokStyles = [
  { style: 'al wok con salsa teriyaki y sésamo', base: 'arroz basmati', veg: ['brócoli', 'zanahoria', 'cebolla', 'salsa de soja', 'miel'] },
  { style: 'salteado agridulce con piña y pimientos', base: 'arroz jazmín', veg: ['piña', 'pimiento rojo', 'pimiento verde', 'cebolla', 'tomate concentrado'] },
  { style: 'con salsa de cacahuete y leche de coco', base: 'noodles de arroz', veg: ['mantequilla de cacahuete', 'leche de coco', 'espinacas frescas', 'lima'] },
  { style: 'salteado al jengibre y cebolleta fresca', base: 'fideos udon', veg: ['jengibre fresco', 'cebolleta', 'setas shiitake', 'salsa de soja'] },
  { style: 'con curry amarillo suave y verduras crujientes', base: 'arroz basmati', veg: ['calabacín', 'zanahoria', 'cebolla', 'cúrcuma', 'leche de coco'] },
  { style: 'al estilo sichuan con chile picante y bambú', base: 'fideos de trigo', veg: ['chile rojo', 'diente de ajo', 'pimiento rojo', 'salsa de soja'] },
  { style: 'con espárragos trigueros y salsa de soja dulce', base: 'quinoa', veg: ['espárragos verdes', 'champiñones', 'diente de ajo', 'aceite de sésamo'] },
  { style: 'con anacardos tostados y salsa de ostras', base: 'arroz jazmín', veg: ['anacardos', 'cebolleta', 'pimiento amarillo', 'salsa de soja'] },
  { style: 'salteado con albahaca tailandesa y pimiento', base: 'arroz jazmín', veg: ['albahaca fresca', 'pimiento rojo', 'diente de ajo', 'chile rojo'] },
  { style: 'con salsa satay y brotes de soja', base: 'noodles de arroz', veg: ['mantequilla de cacahuete', 'lima', 'cebolleta', 'salsa de soja'] },
  { style: 'al wok con calabacín y champiñones al sésamo', base: 'fideos soba', veg: ['calabacín', 'champiñones', 'semillas de sésamo', 'aceite de sésamo'] },
  { style: 'con salsa de ciruela y cebollino', base: 'arroz jazmín', veg: ['cebolleta', 'zanahoria', 'pimiento rojo', 'salsa de soja'] }
];

wokProteins.forEach(p => {
  wokStyles.forEach(w => {
    addRecipe({
      title: `Wok de ${p.name} ${w.style}`,
      country: 'Internacional',
      cuisine_type: 'Asiática',
      prep_oven: null,
      prep_airfryer: 'Dorar proteína 10 min a 190°C antes de saltear',
      prep_microwave: 'Cocinar o calentar arroz base a 800W 2 min',
      ingredients: [p.ing, w.base, ...w.veg, 'sal fina']
    });
  });
});

// BLOQUE 4: Cocina Mexicana & Latina (110 recetas)
const mexicanBases = [
  { t: 'Tacos al pastor tradicionales con piña asada', c: 'México', cat: 'Mexicana', o: 'Hornear carne marinada a 200°C 20 min', a: 'Asar carne especiada en airfryer a 190°C 14 min', m: 'Calentar tortillas envueltas 30 seg a 600W', ing: ['tortillas de maíz', 'lomo de cerdo', 'piña', 'cebolla morada', 'cilantro fresco', 'lima'] },
  { t: 'Tacos de cochinita pibil con cebolla encurtida', c: 'México', cat: 'Mexicana', o: 'Cocinar envuelto en papel aluminio a 160°C 2h', a: null, m: 'Calentar carne deshebrada a 750W 2 min', ing: ['tortillas de maíz', 'lomo de cerdo', 'naranja', 'cebolla morada', 'lima', 'cilantro fresco'] },
  { t: 'Tacos de pollo deshebrado con chipotle y aguacate', c: 'México', cat: 'Mexicana', o: null, a: 'Pollo deshebrado crujiente a 180°C 8 min', m: 'Cocer pechuga tapada en caldo a 800W 5 min', ing: ['tortillas de maíz', 'pechuga de pollo', 'tomate triturado', 'aguacate', 'cebolla', 'cilantro fresco'] },
  { t: 'Tacos de pescado crujiente estilo Baja California', c: 'México', cat: 'Mexicana', o: 'Hornear pescado rebozado a 200°C 15 min', a: 'Cocinar pescado crujiente en airfryer a 195°C 10 min', m: null, ing: ['tortillas de maíz', 'filete de merluza', 'col lombarda', 'mayonesa casera', 'lima', 'cilantro fresco'] },
  { t: 'Fajitas de ternera con pimientos tricolor', c: 'México', cat: 'Mexicana', o: 'Asar tiras de carne y verduras a 210°C 15 min', a: 'Cocinar carne y pimientos en airfryer a 190°C 12 min', m: 'Templar tortillas 20 seg', ing: ['tortillas de trigo', 'filete de ternera', 'pimiento rojo', 'pimiento verde', 'pimiento amarillo', 'cebolla', 'comino molido'] },
  { t: 'Fajitas de pollo marinadas con lima y orégano', c: 'México', cat: 'Mexicana', o: 'Asar a 200°C 18 min en bandeja', a: 'Airfryer a 190°C durante 12 min moviendo a mitad', m: null, ing: ['tortillas de trigo', 'pechuga de pollo', 'pimiento rojo', 'cebolla', 'lima', 'aceite de oliva virgen extra'] },
  { t: 'Enchiladas verdes gratinadas con queso y pollo', c: 'México', cat: 'Mexicana', o: 'Gratinar a 200°C durante 12 minutos hasta dorar queso', a: 'Gratinar bandeja individual a 190°C 8 min', m: 'Calentar a 750W 3 min', ing: ['tortillas de maíz', 'pechuga de pollo', 'tomate triturado', 'queso fresco', 'cebolla', 'cilantro fresco'] },
  { t: 'Enchiladas rojas de ternera picada y frijoles', c: 'México', cat: 'Mexicana', o: 'Hornear a 190°C 15 min', a: null, m: null, ing: ['tortillas de maíz', 'ternera picada', 'frijoles negros', 'tomate triturado', 'queso cheddar', 'cebolla'] },
  { t: 'Quesadillas de champiñones al ajillo y queso fundido', c: 'México', cat: 'Mexicana', o: 'Dorar a 190°C 8 min', a: 'Tostar quesadilla en airfryer a 180°C 5 min', m: 'Fundir queso rápidamente a 700W 45 seg', ing: ['tortillas de trigo', 'queso mozzarella', 'champiñones', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Quesadillas sincronizadas de pavo y queso manchego', c: 'México', cat: 'Mexicana', o: null, a: 'Cocinar a 180°C 6 min hasta que dore la tortilla', m: null, ing: ['tortillas de trigo', 'pechuga de pavo', 'queso manchego', 'tomate cherry'] },
  { t: 'Guacamole tradicional mexicano con pico de gallo y totopos', c: 'México', cat: 'Mexicana', o: null, a: null, m: null, ing: ['aguacate', 'tomate', 'cebolla morada', 'lima', 'cilantro fresco', 'totopos', 'sal fina'] },
  { t: 'Chili con carne tradicional y frijoles negros', c: 'México', cat: 'Mexicana', o: null, a: null, m: 'Calentar ración a 800W durante 3 min', ing: ['ternera picada', 'frijoles negros', 'tomate triturado', 'pimiento rojo', 'cebolla', 'comino molido', 'pimentón dulce'] },
  { t: 'Chili vegano con soja texturizada y maíz', c: 'México', cat: 'Mexicana', o: null, a: null, m: 'Calentar a 750W 3 min', ing: ['soja texturizada', 'frijoles negros', 'tomate triturado', 'pimiento verde', 'cebolla', 'comino molido'] },
  { t: 'Ceviche clásico de corvina con maíz y boniato', c: 'Perú', cat: 'Latina', o: null, a: 'Asar boniato en airfryer a 190°C 20 min', m: 'Cocer boniato en microondas con piel 6 min', ing: ['lubina', 'lima', 'cebolla morada', 'boniato', 'cilantro fresco', 'chile rojo'] },
  { t: 'Ceviche mixto de langostinos y lubina', c: 'Perú', cat: 'Latina', o: null, a: null, m: null, ing: ['langostinos', 'lubina', 'lima', 'cebolla morada', 'cilantro fresco', 'sal marina'] },
  { t: 'Aguachile verde de langostinos con pepino', c: 'México', cat: 'Mexicana', o: null, a: null, m: null, ing: ['langostinos', 'pepino', 'cebolla morada', 'lima', 'cilantro fresco', 'jalapeño'] }
];

mexicanBases.forEach(addRecipe);

// Generador de Burritos, Tacos y Bowls Tex-Mex
const mexicanFillings = [
  { name: 'Pollo deshebrado con especias', ing: 'pechuga de pollo' },
  { name: 'Ternera salteada con jalapeños', ing: 'filete de ternera' },
  { name: 'Carnitas de cerdo doradas', ing: 'lomo de cerdo' },
  { name: 'Pechuga de pavo al comino', ing: 'pechuga de pavo' },
  { name: 'Langostinos a la diabla', ing: 'langostinos' },
  { name: 'Frijoles negros y guacamole', ing: 'frijoles negros' },
  { name: 'Soja especiada con chile', ing: 'soja texturizada' },
  { name: 'Salmón a la plancha con chipotle', ing: 'lomo de salmón' }
];

const mexicanFormats = [
  { fmt: 'Burrito enrollado con queso cheddar y arroz', base: 'tortillas de trigo', extra: ['arroz basmati', 'queso cheddar', 'tomate'] },
  { fmt: 'Burrito bowl ligero con quinoa y maíz', base: 'quinoa', extra: ['aguacate', 'tomate cherry', 'lima'] },
  { fmt: 'Tacos suaves con salsa verde y cilantro', base: 'tortillas de maíz', extra: ['cebolla morada', 'cilantro fresco', 'lima'] },
  { fmt: 'Tostada crujiente con base de frijol refrito', base: 'tortillas de maíz', extra: ['lechuga romana', 'queso fresco', 'tomate'] },
  { fmt: 'Nachos supremos gratinados con jalapeños', base: 'totopos', extra: ['queso mozzarella', 'jalapeño', 'tomate'] },
  { fmt: 'Ensalada tex-mex con aliño de lima y comino', base: 'canónigos', extra: ['pimiento rojo', 'cebolla', 'aceite de oliva virgen extra'] },
  { fmt: 'Fajita bowl con pimientos asados y pico de gallo', base: 'arroz integral', extra: ['pimiento verde', 'pimiento rojo', 'cebolla'] },
  { fmt: 'Quesadilla tostada con queso gouda fundido', base: 'tortillas de trigo', extra: ['queso gouda', 'champiñones', 'orégano'] },
  { fmt: 'Wrap integral con vegetales frescos y chipotle', base: 'tortillas de trigo', extra: ['espinacas frescas', 'zanahoria', 'yogur natural'] },
  { fmt: 'Cazuela gratinada al horno estilo enchilada', base: 'arroz basmati', extra: ['tomate triturado', 'queso cheddar', 'comino molido'] },
  { fmt: 'Guiso texano especiado con totopos', base: 'totopos', extra: ['frijoles negros', 'tomate triturado', 'pimentón picante'] },
  { fmt: 'Taco bowl proteico con huevo y aguacate', base: 'arroz integral', extra: ['huevo', 'aguacate', 'cebolleta'] }
];

mexicanFillings.forEach(f => {
  mexicanFormats.forEach(fmt => {
    addRecipe({
      title: `${fmt.fmt} de ${f.name}`,
      country: 'México',
      cuisine_type: 'Mexicana',
      prep_oven: 'Gratinar a 190°C 8 min si lleva queso',
      prep_airfryer: 'Cocinar en airfryer a 180°C 6 min para dorar la masa',
      prep_microwave: 'Calentar relleno a 750W 2 min',
      ingredients: [f.ing, fmt.base, ...fmt.extra, 'sal fina']
    });
  });
});

// BLOQUE 5: Fitness, Saludable, Dietas Proteicas & Cenas Ligeras (150 recetas)
const fitnessBases = [
  { t: 'Pechuga de pavo a la plancha con puré de boniato', c: 'Internacional', cat: 'Saludable', o: null, a: 'Boniato en bastones en airfryer a 190°C 15 min', m: 'Boniato al vapor tapado a 800W 5 min', ing: ['pechuga de pavo', 'boniato', 'aceite de oliva virgen extra', 'romero fresco', 'pimienta negra'] },
  { t: 'Pechuga de pollo a las finas hierbas con quinoa real', c: 'Internacional', cat: 'Saludable', o: 'Hornear pechuga a 190°C 18 min', a: 'Airfryer a 185°C durante 12 min', m: 'Cocer quinoa en agua a 750W 10 min', ing: ['pechuga de pollo', 'quinoa', 'calabacín', 'aceite de oliva virgen extra', 'orégano'] },
  { t: 'Poke bowl de salmón fresco, edamame y aguacate', c: 'Internacional', cat: 'Saludable', o: null, a: null, m: 'Templar arroz jazmín a 600W 1 min', ing: ['lomo de salmón', 'arroz basmati', 'edamame', 'aguacate', 'pepino', 'salsa de soja', 'semillas de sésamo'] },
  { t: 'Poke bowl de atún rojo marinado con mango y algas', c: 'Internacional', cat: 'Saludable', o: null, a: null, m: null, ing: ['atún fresco', 'arroz integral', 'mango', 'pepino', 'cebolla morada', 'salsa de soja', 'aceite de sésamo'] },
  { t: 'Revuelto de claras con gambas y espárragos trigueros', c: 'España', cat: 'Saludable', o: null, a: 'Asar espárragos en airfryer a 180°C 8 min', m: null, ing: ['clara de huevo', 'gambas', 'espárragos verdes', 'aceite de oliva virgen extra', 'diente de ajo'] },
  { t: 'Revuelto proteico de pavo, champiñones y espinacas', c: 'España', cat: 'Saludable', o: null, a: null, m: null, ing: ['huevo', 'pechuga de pavo', 'champiñones', 'espinacas frescas', 'aceite de oliva virgen extra'] },
  { t: 'Crema ligera de calabacín y puerro sin natas', c: 'España', cat: 'Saludable', o: null, a: null, m: 'Calentar a 800W 3 min', ing: ['calabacín', 'puerro', 'patata', 'aceite de oliva virgen extra', 'sal fina'] },
  { t: 'Crema depurativa de calabaza asada y jengibre', c: 'Internacional', cat: 'Saludable', o: 'Asar calabaza con piel a 200°C 30 min', a: 'Calabaza en dados a 190°C 15 min en airfryer', m: 'Triturar y calentar a 750W 2 min', ing: ['calabaza', 'zanahoria', 'cebolla', 'jengibre fresco', 'aceite de oliva virgen extra'] },
  { t: 'Crema verde detox de brócoli y espinacas', c: 'Internacional', cat: 'Saludable', o: null, a: null, m: 'Cocer brócoli al vapor en microondas 4 min', ing: ['brócoli', 'espinacas frescas', 'cebolla', 'aceite de oliva virgen extra', 'caldo de verduras'] },
  { t: 'Hamburguesas caseras de pollo y espinacas a la plancha', c: 'Internacional', cat: 'Saludable', o: 'Hornear a 190°C 15 min', a: 'Cocinar en airfryer a 185°C durante 10 min volteando a mitad', m: null, ing: ['pechuga de pollo', 'espinacas frescas', 'huevo', 'cebolla', 'aceite de oliva virgen extra'] },
  { t: 'Hamburguesas vegetarianas de lentejas y avena', c: 'Internacional', cat: 'Saludable', o: 'Hornear a 190°C 16 min sobre papel vegetal', a: 'Cocinar en airfryer a 180°C 10 min', m: null, ing: ['lentejas pardinas', 'copos de avena', 'zanahoria', 'cebolla', 'pimentón dulce'] },
  { t: 'Solomillo de pavo marinado con mostaza de dijon', c: 'Francia', cat: 'Saludable', o: 'Hornear a 180°C 15 min', a: 'Airfryer a 180°C durante 11 min', m: null, ing: ['solomillo de pavo', 'mostaza dijon', 'limón', 'aceite de oliva virgen extra', 'pimienta negra'] },
  { t: 'Ensalada César saludable con pollo y yogur griego', c: 'Internacional', cat: 'Saludable', o: 'Pechuga a la plancha o asada a 190°C 15 min', a: 'Cocinar picatostes y pollo en airfryer a 190°C 8 min', m: null, ing: ['lechuga romana', 'pechuga de pollo', 'yogur griego', 'queso parmesano', 'pan integral', 'limón'] },
  { t: 'Ensalada griega tradicional con queso feta y aceitunas', c: 'Grecia', cat: 'Mediterránea', o: null, a: null, m: null, ing: ['tomate cherry', 'pepino', 'cebolla morada', 'queso feta', 'orégano', 'aceite de oliva virgen extra'] },
  { t: 'Ensalada templada de garbanzos, espinacas y atún', c: 'España', cat: 'Saludable', o: null, a: null, m: 'Templar garbanzos 1 min a 600W', ing: ['garbanzos cocidos', 'espinacas frescas', 'atún en conserva', 'huevo', 'tomate cherry', 'aceite de oliva virgen extra'] },
  { t: 'Ensalada de quinoa con aguacate y nueces', c: 'Internacional', cat: 'Saludable', o: null, a: null, m: 'Cocer quinoa 10 min a 750W', ing: ['quinoa', 'aguacate', 'nueces', 'tomate cherry', 'canónigos', 'limón', 'aceite de oliva virgen extra'] },
  { t: 'Shakshuka de huevos escalfados en salsa de pimientos', c: 'Oriente Medio', cat: 'Mediterránea', o: 'Hornear cazuela a 190°C 10 min para cuajar claras', a: 'Cazuela individual en airfryer a 170°C 8 min', m: null, ing: ['huevo', 'tomate triturado', 'pimiento rojo', 'cebolla', 'diente de ajo', 'comino molido', 'aceite de oliva virgen extra'] }
];

fitnessBases.forEach(addRecipe);

// Generador de Combinaciones Fit (Proteína + Carbohidrato limpio + Verdura al vapor/plancha)
const fitProteins = [
  { name: 'Lomo de salmón salvaje', ing: 'lomo de salmón', oven: 'Hornear a 180°C 12 min', air: 'Airfryer a 180°C 8 min' },
  { name: 'Filete de merluza al vapor', ing: 'filete de merluza', oven: 'Papillote al horno a 180°C 12 min', air: 'Airfryer en papillote a 175°C 9 min' },
  { name: 'Pechuga de pollo a la plancha', ing: 'pechuga de pollo', oven: 'Hornear a 190°C 15 min', air: 'Airfryer a 185°C 11 min' },
  { name: 'Solomillo de pavo magro', ing: 'solomillo de pavo', oven: 'Hornear a 180°C 14 min', air: 'Airfryer a 180°C 10 min' },
  { name: 'Filete de ternera limpia', ing: 'filete de ternera', oven: 'Marcar y horno a 190°C 7 min', air: 'Airfryer a 190°C 6 min' },
  { name: 'Lomos de dorada fresca', ing: 'dorada', oven: 'Hornear a 190°C 12 min', air: 'Airfryer a 180°C 9 min' },
  { name: 'Lomos de lubina', ing: 'lubina', oven: 'Hornear a 190°C 12 min', air: 'Airfryer a 180°C 9 min' },
  { name: 'Tofu firme marinado', ing: 'tofu', oven: 'Hornear a 200°C 18 min', air: 'Airfryer crujiente a 195°C 12 min' },
  { name: 'Atún fresco marcado', ing: 'atún fresco', oven: null, air: 'Airfryer a 190°C 5 min' },
  { name: 'Sepia a la parrilla', ing: 'sepia', oven: null, air: 'Airfryer a 190°C 8 min' }
];

const fitCarbs = [
  { name: 'con quinoa y verduras asadas', carb: 'quinoa', veg: ['calabacín', 'pimiento rojo'] },
  { name: 'con boniato al horno y romero', carb: 'boniato', veg: ['romero fresco', 'cebolla'] },
  { name: 'con arroz basmati y brócoli al vapor', carb: 'arroz basmati', veg: ['brócoli', 'zanahoria'] },
  { name: 'con arroz integral y espárragos verdes', carb: 'arroz integral', veg: ['espárragos verdes', 'champiñones'] },
  { name: 'con garbanzos especiados crujientes', carb: 'garbanzos cocidos', veg: ['pimentón dulce', 'espinacas frescas'] },
  { name: 'con cuscús integral y tomatitos cherry', carb: 'cuscús', veg: ['tomate cherry', 'calabacín'] },
  { name: 'con puré rústico de patata y ajo asado', carb: 'patata', veg: ['diente de ajo', 'perejil fresco'] },
  { name: 'con fideos de arroz y tiras de pimiento', carb: 'noodles de arroz', veg: ['pimiento verde', 'cebolleta'] },
  { name: 'con lentejas pardinas y vinagreta suave', carb: 'lentejas pardinas', veg: ['tomate', 'pepino'] },
  { name: 'con ensalada fresca de rúcula y nueces', carb: 'nueces', veg: ['rúcula', 'tomate cherry'] },
  { name: 'con espinacas salteadas al ajillo', carb: 'patata', veg: ['espinacas frescas', 'diente de ajo'] },
  { name: 'con judías verdes cocidas y huevo duro', carb: 'huevo', veg: ['judías verdes', 'zanahoria'] },
  { name: 'con calabaza asada y semillas de lino', carb: 'calabaza', veg: ['semillas de lino', 'cebolla morada'] },
  { name: 'con salteado de setas shiitake y col', carb: 'arroz jazmín', veg: ['setas shiitake', 'col'] }
];

fitProteins.forEach(p => {
  fitCarbs.forEach(c => {
    addRecipe({
      title: `${p.name} saludable ${c.name}`,
      country: 'Internacional',
      cuisine_type: 'Saludable',
      prep_oven: p.oven,
      prep_airfryer: p.air,
      prep_microwave: 'Microondas al vapor con recipiente tapado a 750W 3 min',
      ingredients: [p.ing, c.carb, ...c.veg, 'aceite de oliva virgen extra', 'sal marina']
    });
  });
});

// BLOQUE 6: Especiales Airfryer (Freidora de Aire) (120 recetas)
const airfryerBases = [
  { t: 'Alitas de pollo extra crujientes en airfryer con pimentón', c: 'Internacional', cat: 'Airfryer', o: 'Hornear a 210°C 35 min', a: 'Cocinar en airfryer a 195°C durante 22 minutos agitando cada 7 minutos', m: null, ing: ['alitas de pollo', 'pimentón dulce', 'diente de ajo', 'aceite de oliva virgen extra', 'sal fina', 'pimienta negra'] },
  { t: 'Alitas de pollo marinadas con salsa barbacoa en airfryer', c: 'Estados Unidos', cat: 'Airfryer', o: 'Hornear a 200°C 30 min', a: 'Cocinar en airfryer a 190°C 18 min, pincelar con salsa y 4 min a 200°C', m: null, ing: ['alitas de pollo', 'tomate concentrado', 'miel', 'vinagre de manzana', 'pimentón picante'] },
  { t: 'Patatas gajo rústicas especiadas en airfryer', c: 'Internacional', cat: 'Airfryer', o: 'Hornear a 210°C 30 min', a: 'Cocinar en airfryer a 195°C durante 18 minutos moviendo el cestillo a mitad', m: 'Precocer patata con piel 4 min a 800W para reducir tiempo', ing: ['patata', 'pimentón dulce', 'orégano', 'diente de ajo', 'aceite de oliva virgen extra', 'sal marina'] },
  { t: 'Bastones de boniato crujientes en airfryer con romero', c: 'Internacional', cat: 'Airfryer', o: 'Hornear a 200°C 25 min', a: 'Cocinar en airfryer a 190°C durante 15 minutos en una sola capa', m: null, ing: ['boniato', 'romero fresco', 'almidón de maíz', 'aceite de oliva virgen extra', 'sal fina'] },
  { t: 'Nuggets caseros de pollo y copos de avena en airfryer', c: 'Internacional', cat: 'Airfryer', o: 'Hornear a 200°C 15 min', a: 'Cocinar en airfryer a 190°C durante 10 minutos pulverizando aceite', m: null, ing: ['pechuga de pollo', 'copos de avena', 'huevo', 'diente de ajo', 'queso crema', 'sal fina'] },
  { t: 'Fingers de queso mozzarella crujientes en airfryer', c: 'Estados Unidos', cat: 'Airfryer', o: 'Hornear a 210°C 8 min congelados', a: 'Cocinar en airfryer a 200°C durante 5 minutos precalentada', m: null, ing: ['queso mozzarella', 'pan rallado', 'huevo', 'harina de trigo', 'orégano'] },
  { t: 'Calabacín crujiente rebozado con parmesano en airfryer', c: 'Italia', cat: 'Airfryer', o: 'Hornear a 200°C 15 min', a: 'Cocinar en airfryer a 190°C durante 12 minutos hasta dorar', m: null, ing: ['calabacín', 'queso parmesano', 'pan rallado', 'huevo', 'aceite de oliva virgen extra'] },
  { t: 'Chips de berenjena con miel de caña en airfryer', c: 'España', cat: 'Airfryer', o: 'Hornear a 190°C 20 min', a: 'Cocinar láminas a 180°C durante 12 minutos agitando bien', m: null, ing: ['berenjena', 'harina de trigo', 'miel', 'aceite de oliva virgen extra', 'sal fina'] },
  { t: 'Pimientos del padrón asados en airfryer sin salpicaduras', c: 'España', cat: 'Airfryer', o: 'Asar a 210°C 12 min', a: 'Cocinar en airfryer a 200°C durante 8 minutos agitando al minuto 4', m: null, ing: ['pimiento verde', 'aceite de oliva virgen extra', 'sal marina'] },
  { t: 'Salmón con costra de mostaza y miel en airfryer', c: 'Internacional', cat: 'Airfryer', o: 'Hornear a 190°C 14 min', a: 'Cocinar en airfryer a 185°C durante 9 minutos', m: null, ing: ['lomo de salmón', 'mostaza dijon', 'miel', 'eneldo fresco', 'pimienta negra', 'sal fina'] },
  { t: 'Empanadillas caseras de atún y tomate en airfryer', c: 'España', cat: 'Airfryer', o: 'Hornear a 195°C 15 min pintadas con huevo', a: 'Cocinar en airfryer a 185°C durante 9 minutos hasta dorar la masa', m: null, ing: ['obleas de empanadilla', 'atún en conserva', 'tomate triturado', 'huevo', 'cebolla'] },
  { t: 'Muslos de pollo al limón con patatitas en airfryer', c: 'España', cat: 'Airfryer', o: 'Hornear a 200°C 35 min', a: 'Cocinar en airfryer a 185°C durante 24 minutos dando la vuelta a los 12 min', m: null, ing: ['muslos de pollo', 'patata', 'limón', 'romero fresco', 'aceite de oliva virgen extra', 'sal marina'] },
  { t: 'Falafel casero crujiente en airfryer con hierbas frescas', c: 'Oriente Medio', cat: 'Airfryer', o: 'Hornear a 200°C 18 min', a: 'Cocinar en airfryer a 190°C durante 12 minutos con toque de spray de aceite', m: null, ing: ['garbanzos cocidos', 'cebolla', 'diente de ajo', 'perejil fresco', 'cilantro fresco', 'comino molido', 'harina de garbanzo'] },
  { t: 'Tortilla de calabacín exprés en molde de airfryer', c: 'España', cat: 'Airfryer', o: 'Hornear molde a 180°C 20 min', a: 'Cocinar en molde de silicona a 170°C durante 15 minutos en airfryer', m: 'Precocer calabacín 3 min en microondas', ing: ['calabacín', 'huevo', 'cebolla', 'aceite de oliva virgen extra', 'sal fina'] },
  { t: 'Albóndigas de pollo y manzana doradas en airfryer', c: 'Internacional', cat: 'Airfryer', o: 'Hornear a 190°C 18 min', a: 'Cocinar en airfryer a 185°C durante 11 minutos', m: null, ing: ['pechuga de pollo', 'manzana', 'huevo', 'pan rallado', 'cebolleta', 'sal fina'] }
];

airfryerBases.forEach(addRecipe);

// Generador de recetas especializadas en freidora de aire
const airfryerIngredients = [
  { name: 'Brochetas de pollo y piña', ing: 'pechuga de pollo', side: 'piña', time: '12 min a 190°C' },
  { name: 'Brochetas de gambas marinadas', ing: 'gambas', side: 'tomate cherry', time: '6 min a 190°C' },
  { name: 'Tacos de merluza empanada', ing: 'filete de merluza', side: 'limón', time: '9 min a 190°C' },
  { name: 'Rollitos de jamón y queso crujientes', ing: 'jamón serrano', side: 'queso gouda', time: '7 min a 180°C' },
  { name: 'Dados de salmón cajún', ing: 'lomo de salmón', side: 'pimiento rojo', time: '8 min a 185°C' },
  { name: 'Champiñones rellenos de jamón', ing: 'champiñones', side: 'jamón ibérico', time: '10 min a 180°C' },
  { name: 'Espárragos envueltos en jamón serrano', ing: 'espárragos verdes', side: 'jamón serrano', time: '8 min a 190°C' },
  { name: 'Dados de tofu crujiente al pimentón', ing: 'tofu', side: 'salsa de soja', time: '13 min a 195°C' },
  { name: 'Costillitas barbacoa glaseadas', ing: 'costillas de cerdo', side: 'miel', time: '22 min a 180°C' },
  { name: 'Pechuga rellena de queso y espinacas', ing: 'pechuga de pollo', side: 'queso mozzarella', time: '16 min a 180°C' }
];

const airfryerStyles = [
  { seasoning: 'con toque provenzal de romero y ajo', extra: ['romero fresco', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { seasoning: 'estilo cajún especiado con pimentón', extra: ['pimentón picante', 'comino molido', 'aceite de oliva virgen extra'] },
  { seasoning: 'al limón y pimienta negra molida', extra: ['limón', 'pimienta negra', 'aceite de oliva virgen extra'] },
  { seasoning: 'con salsa teriyaki y sésamo dorado', extra: ['salsa de soja', 'semillas de sésamo', 'miel'] },
  { seasoning: 'con costra crujiente de queso parmesano', extra: ['queso parmesano', 'pan rallado', 'huevo'] },
  { seasoning: 'al pimentón de la Vera dulce y orégano', extra: ['pimentón dulce', 'orégano', 'aceite de oliva virgen extra'] },
  { seasoning: 'con glaseado de miel y mostaza', extra: ['mostaza dijon', 'miel', 'vinagre de manzana'] },
  { seasoning: 'con majado tradicional de ajo y perejil', extra: ['diente de ajo', 'perejil fresco', 'aceite de oliva virgen extra'] },
  { seasoning: 'con curry suave y cebollino fresco', extra: ['cúrcuma', 'cebolleta', 'aceite de oliva virgen extra'] },
  { seasoning: 'con aliño tex-mex de comino y lima', extra: ['comino molido', 'lima', 'chile rojo'] }
];

airfryerIngredients.forEach(ai => {
  airfryerStyles.forEach(as => {
    addRecipe({
      title: `${ai.name} en airfryer ${as.seasoning}`,
      country: 'Internacional',
      cuisine_type: 'Airfryer',
      prep_oven: 'Hornear a 200°C 18-20 min',
      prep_airfryer: `Cocinar en airfryer ${ai.time}, volteando a la mitad para dorado uniforme`,
      prep_microwave: null,
      ingredients: [ai.ing, ai.side, ...as.extra, 'sal fina']
    });
  });
});

// BLOQUE 7: Desayunos, Meriendas, Tostadas & Bowls Saludables (100 recetas)
const breakfastBases = [
  { t: 'Tostada de pan de centeno con aguacate y huevo poché', c: 'Internacional', cat: 'Desayunos', o: null, a: 'Tostar pan de centeno a 190°C 3 min en airfryer', m: 'Huevo poché en taza de agua 1 min a 700W', ing: ['pan de centeno', 'aguacate', 'huevo', 'aceite de oliva virgen extra', 'semillas de chía', 'sal marina'] },
  { t: 'Tostada con tomate rallado y jamón ibérico', c: 'España', cat: 'Desayunos', o: null, a: 'Tostar pan a 200°C 2 min', m: null, ing: ['pan de hogaza', 'tomate', 'jamón ibérico', 'aceite de oliva virgen extra', 'sal marina'] },
  { t: 'Tostada con queso ricotta, nueces y miel de flores', c: 'Italia', cat: 'Desayunos', o: null, a: null, m: null, ing: ['pan integral', 'queso ricotta', 'nueces', 'miel', 'canela en polvo'] },
  { t: 'Tostada dulce de plátano, crema de cacahuete y chía', c: 'Estados Unidos', cat: 'Desayunos', o: null, a: null, m: null, ing: ['pan de centeno', 'plátano', 'mantequilla de cacahuete', 'semillas de chía', 'canela en polvo'] },
  { t: 'Porridge de avena caliente con manzana y canela', c: 'Reino Unido', cat: 'Desayunos', o: null, a: null, m: 'Cocinar avena y leche a 750W durante 2 minutos removiendo', ing: ['copos de avena', 'leche entera', 'manzana', 'canela en polvo', 'miel'] },
  { t: 'Overnight oats fríos con chía, yogur y frutos rojos', c: 'Internacional', cat: 'Desayunos', o: null, a: null, m: null, ing: ['copos de avena', 'yogur natural', 'leche de almendras', 'semillas de chía', 'arándano', 'frambuesa'] },
  { t: 'Tortitas esponjosas de avena y plátano sin azúcar', c: 'Internacional', cat: 'Desayunos', o: 'Hornear en molde 180°C 12 min', a: 'Cocinar en moldes de silicona a 170°C 8 min', m: null, ing: ['harina de avena', 'plátano', 'huevo', 'leche entera', 'canela en polvo'] },
  { t: 'Tortitas de queso fresco batido y arándanos', c: 'Internacional', cat: 'Desayunos', o: null, a: null, m: null, ing: ['harina de avena', 'queso fresco', 'huevo', 'arándano', 'extracto de vainilla'] },
  { t: 'Chia pudding cremoso con leche de coco y mango', c: 'Internacional', cat: 'Desayunos', o: null, a: null, m: null, ing: ['semillas de chía', 'leche de coco', 'mango', 'lima', 'miel'] },
  { t: 'Smoothie bowl de frutos rojos, yogur griego y granola', c: 'Internacional', cat: 'Desayunos', o: null, a: null, m: null, ing: ['arándano', 'fresa', 'yogur griego', 'plátano', 'nueces', 'semillas de lino'] },
  { t: 'French toast saludable de canela con frutos del bosque', c: 'Francia', cat: 'Desayunos', o: 'Hornear a 190°C 10 min', a: 'Cocinar en airfryer a 180°C durante 6 minutos volteando', m: null, ing: ['pan de molde', 'huevo', 'leche entera', 'canela en polvo', 'fresa', 'miel'] },
  { t: 'Huevos revueltos cremosos con salmón ahumado y cebollino', c: 'Internacional', cat: 'Desayunos', o: null, a: null, m: 'Cuajar huevos batidos con mantequilla en microondas a 600W 1 min', ing: ['huevo', 'mantequilla', 'lomo de salmón', 'cebolleta', 'pimienta negra', 'sal fina'] },
  { t: 'Huevos benedictinos con pavo sobre pan de molde tostado', c: 'Estados Unidos', cat: 'Desayunos', o: null, a: 'Tostar pan en airfryer 3 min a 190°C', m: 'Poché al microondas 1 min', ing: ['huevo', 'pechuga de pavo', 'pan de molde', 'mantequilla', 'limón'] },
  { t: 'Yogur griego con nueces, semillas de lino y miel', c: 'Grecia', cat: 'Desayunos', o: null, a: null, m: null, ing: ['yogur griego', 'nueces', 'semillas de lino', 'miel'] },
  { t: 'Batido proteico de plátano, avena y cacao puro', c: 'Internacional', cat: 'Desayunos', o: null, a: null, m: null, ing: ['plátano', 'leche entera', 'copos de avena', 'cacao en polvo puro', 'mantequilla de cacahuete'] }
];

breakfastBases.forEach(addRecipe);

// Generador de Tostadas, Bowls y Batidos
const breakfastBasesList = [
  { type: 'Tostada de pan de masa madre', carb: 'pan de hogaza' },
  { type: 'Tostada de pan de centeno 100%', carb: 'pan de centeno' },
  { type: 'Tostada de pan de semillas integral', carb: 'pan integral' },
  { type: 'Bowl de avena y yogur cremoso', carb: 'copos de avena' },
  { type: 'Pudding de semillas de chía hidratado', carb: 'semillas de chía' },
  { type: 'Tortitas caseras de avena', carb: 'harina de avena' },
  { type: 'Smoothie bowl energizante', carb: 'plátano' }
];

const breakfastToppings = [
  { name: 'con fresas frescas, queso ricotta y menta', ings: ['fresa', 'queso ricotta', 'menta fresca', 'miel'] },
  { name: 'con manzana asada, nueces y canela en polvo', ings: ['manzana', 'nueces', 'canela en polvo', 'miel'] },
  { name: 'con arándanos silvestres, almendras y yogur', ings: ['arándano', 'almendras', 'yogur griego'] },
  { name: 'con aguacate laminado, huevo y sésamo', ings: ['aguacate', 'huevo', 'semillas de sésamo', 'aceite de oliva virgen extra'] },
  { name: 'con salmón ahumado, queso crema y eneldo', ings: ['lomo de salmón', 'queso crema', 'pepino', 'pimienta negra'] },
  { name: 'con jamón ibérico, tomate cherry y aceite de oliva', ings: ['jamón ibérico', 'tomate cherry', 'aceite de oliva virgen extra'] },
  { name: 'con crema de cacahuete, plátano y cacao puro', ings: ['mantequilla de cacahuete', 'plátano', 'cacao en polvo puro'] },
  { name: 'con kiwi troceado, semillas de lino y yogur natural', ings: ['kiwi', 'semillas de lino', 'yogur natural', 'miel'] },
  { name: 'con melocotón asado, queso fresco y miel', ings: ['melocotón', 'queso fresco', 'miel', 'nueces'] },
  { name: 'con frambuesas frescas, chocolate negro 85% y avellanas', ings: ['frambuesa', 'chocolate negro 85%', 'avellanas'] },
  { name: 'con revuelto de claras, pavo y orégano', ings: ['clara de huevo', 'pechuga de pavo', 'orégano', 'aceite de oliva virgen extra'] },
  { name: 'con queso fresco de cabra, nueces y pasas', ings: ['queso de cabra', 'nueces', 'pasas', 'miel'] }
];

breakfastBasesList.forEach(bb => {
  breakfastToppings.forEach(bt => {
    addRecipe({
      title: `${bb.type} ${bt.name}`,
      country: 'Internacional',
      cuisine_type: 'Desayunos',
      prep_oven: null,
      prep_airfryer: 'Tostar o gratinar en airfryer 3-4 min a 180°C',
      prep_microwave: 'Microondas 1-2 min si requiere calentar avena o fruta',
      ingredients: [bb.carb, ...bt.ings, 'sal fina']
    });
  });
});

// BLOQUE 8: Bocadillos, Sandwiches Gourmet, Wraps & Hamburguesas Caseras (90 recetas)
const burgerBases = [
  { t: 'Hamburguesa gourmet de ternera con queso cheddar y cebolla caramelizada', c: 'Estados Unidos', cat: 'Hamburguesas', o: 'Fundir queso a 190°C 3 min', a: 'Cocinar hamburguesa en airfryer a 195°C durante 9 min', m: null, ing: ['pan de hamburguesa', 'ternera picada', 'queso cheddar', 'cebolla', 'tomate', 'lechuga romana', 'aceite de oliva virgen extra'] },
  { t: 'Hamburguesa de pollo crujiente estilo sureño con salsa suave', c: 'Estados Unidos', cat: 'Hamburguesas', o: 'Hornear pollo empanado a 200°C 18 min', a: 'Cocinar pechuga empanada en airfryer a 190°C durante 12 min', m: null, ing: ['pan de hamburguesa', 'pechuga de pollo', 'pan rallado', 'huevo', 'lechuga romana', 'mayonesa casera', 'pepino'] },
  { t: 'Hamburguesa casera de salmón fresco con salsa de eneldo y yogur', c: 'Internacional', cat: 'Hamburguesas', o: null, a: 'Cocinar hamburguesa de salmón a 180°C 8 min', m: null, ing: ['pan de hamburguesa', 'lomo de salmón', 'yogur griego', 'limón', 'eneldo fresco', 'rúcula'] },
  { t: 'Sandwich club tradicional de tres pisos con pollo y bacon crujiente', c: 'Estados Unidos', cat: 'Sandwiches', o: 'Tostar a 200°C 5 min', a: 'Bacon extra crujiente en airfryer a 200°C durante 5 min', m: null, ing: ['pan de molde', 'pechuga de pollo', 'bacon', 'queso gouda', 'tomate', 'lechuga romana', 'mayonesa casera'] },
  { t: 'Sandwich mixto clásico con jamón dulce y queso emmental fundido', c: 'Francia', cat: 'Sandwiches', o: 'Hornear a 200°C 6 min', a: 'Tostar en airfryer a 180°C durante 5 minutos volteando', m: 'Fundir a 650W 1 min', ing: ['pan de molde', 'mantequilla', 'jamón serrano', 'queso emmental'] },
  { t: 'Croque Monsieur tradicional francés con bechamel gratinada', c: 'Francia', cat: 'Sandwiches', o: 'Gratinar a 210°C durante 8 minutos hasta dorar', a: 'Gratinar en airfryer a 190°C durante 6 minutos', m: null, ing: ['pan de molde', 'jamón serrano', 'leche entera', 'harina de trigo', 'mantequilla', 'queso emmental'] },
  { t: 'Bocadillo de lomo ibérico con queso manchego y pimientos verdes', c: 'España', cat: 'Bocadillos', o: 'Hornear pan relleno a 190°C 6 min', a: 'Pimientos y lomo a 190°C 10 min en airfryer', m: null, ing: ['pan de hogaza', 'lomo de cerdo', 'queso manchego', 'pimiento verde', 'aceite de oliva virgen extra'] },
  { t: 'Bocadillo de calamares crujientes con alioli casero', c: 'España', cat: 'Bocadillos', o: 'Hornear calamares a 200°C 14 min', a: 'Calamares crujientes en airfryer a 195°C durante 10 min', m: null, ing: ['pan de hogaza', 'calamar', 'harina de trigo', 'diente de ajo', 'huevo', 'limón', 'aceite de oliva virgen extra'] },
  { t: 'Bocadillo de tortilla francesa con jamón ibérico y tomate', c: 'España', cat: 'Bocadillos', o: null, a: null, m: null, ing: ['pan de hogaza', 'huevo', 'jamón ibérico', 'tomate', 'aceite de oliva virgen extra'] },
  { t: 'Wrap de pollo asado con aguacate, espinacas y queso feta', c: 'Internacional', cat: 'Wraps', o: null, a: 'Dorar el wrap enrollado a 180°C 4 min en airfryer', m: 'Templar tortilla 15 seg a 600W', ing: ['tortillas de trigo', 'pechuga de pollo', 'aguacate', 'espinacas frescas', 'queso feta', 'tomate cherry'] },
  { t: 'Wrap integral de atún, huevo duro, canónigos y mayonesa suave', c: 'Internacional', cat: 'Wraps', o: null, a: null, m: null, ing: ['tortillas de trigo', 'atún en conserva', 'huevo', 'canónigos', 'tomate', 'mayonesa casera'] }
];

burgerBases.forEach(addRecipe);

// Generador de Sandwiches, Wraps y Bocadillos Combinados
const breadFormats = [
  { name: 'Bocadillo en pan rústico crujiente', bread: 'pan de hogaza' },
  { name: 'Sandwich gourmet en pan de centeno', bread: 'pan de centeno' },
  { name: 'Wrap enrollado integral', bread: 'tortillas de trigo' },
  { name: 'Pan de pita relleno mediterráneo', bread: 'pan de pita' },
  { name: 'Hamburguesa casera en pan brioche', bread: 'pan de hamburguesa' },
  { name: 'Sandwich tostado de tres pisos', bread: 'pan de molde' }
];

const fillingGourmet = [
  { title: 'de pollo marinado con aguacate y mostaza dijon', ings: ['pechuga de pollo', 'aguacate', 'mostaza dijon', 'canónigos'] },
  { title: 'de ternera asada con queso brie y rúcula', ings: ['filete de ternera', 'queso de cabra', 'rúcula', 'tomate'] },
  { title: 'de salmón ahumado con queso fresco y pepino', ings: ['lomo de salmón', 'queso fresco', 'pepino', 'eneldo fresco'] },
  { title: 'de solomillo de pavo con cebolla morada y queso gouda', ings: ['solomillo de pavo', 'cebolla morada', 'queso gouda', 'tomate cherry'] },
  { title: 'de atún con huevo duro, pimientos asados y aceitunas', ings: ['atún en conserva', 'huevo', 'pimiento rojo', 'aceite de oliva virgen extra'] },
  { title: 'de jamón serrano con queso manchego y tomate untado', ings: ['jamón serrano', 'queso manchego', 'tomate', 'aceite de oliva virgen extra'] },
  { title: 'vegetariano de calabacín asado, mozzarella y pesto', ings: ['calabacín', 'queso mozzarella', 'albahaca fresca', 'aceite de oliva virgen extra'] },
  { title: 'de pechuga crujiente con bacon y queso cheddar fundido', ings: ['pechuga de pollo', 'bacon', 'queso cheddar', 'lechuga romana'] },
  { title: 'de lomo a la plancha con pimientos y alioli', ings: ['lomo de cerdo', 'pimiento verde', 'diente de ajo', 'mayonesa casera'] },
  { title: 'de revuelto cremoso con champiñones y queso feta', ings: ['huevo', 'champiñones', 'queso feta', 'espinacas frescas'] },
  { title: 'de falafel con salsa de yogur y menta fresca', ings: ['garbanzos cocidos', 'yogur griego', 'menta fresca', 'pepino'] },
  { title: 'de pulled pork con salsa barbacoa y col morada', ings: ['lomo de cerdo', 'col lombarda', 'tomate concentrado', 'vinagre de manzana'] }
];

breadFormats.forEach(b => {
  fillingGourmet.forEach(f => {
    addRecipe({
      title: `${b.name} ${f.title}`,
      country: 'Internacional',
      cuisine_type: 'Rápida',
      prep_oven: 'Tostar a 190°C durante 6 minutos',
      prep_airfryer: 'Tostar en airfryer a 180°C durante 4-5 minutos hasta que dore',
      prep_microwave: null,
      ingredients: [b.bread, ...f.ings, 'sal fina']
    });
  });
});

// BLOQUE 9: Asados al Horno, Gratens & Cocina Familiar al Horno (90 recetas)
const ovenRoastBases = [
  { t: 'Pollo asado entero al horno con limón, romero y patatas', c: 'España', cat: 'Horno', o: 'Hornear a 190°C durante 60-70 minutos regando con sus jugos', a: 'Asar pollo entero en airfryer de gran capacidad a 180°C 50 min', m: null, ing: ['muslos de pollo', 'patata', 'limón', 'romero fresco', 'cebolla', 'aceite de oliva virgen extra'] },
  { t: 'Costillas de cerdo al horno con miel y mostaza', c: 'España', cat: 'Horno', o: 'Hornear a 170°C tapado 50 min y 15 min a 200°C destapado para lacar', a: 'Cocinar en airfryer a 180°C 25 min pincelando con salsa', m: null, ing: ['costillas de cerdo', 'miel', 'mostaza dijon', 'diente de ajo', 'vinagre de manzana', 'pimentón dulce'] },
  { t: 'Solomillo de ternera al horno con salsa de champiñones y nata', c: 'Francia', cat: 'Horno', o: 'Sellar en sartén y terminar al horno a 180°C durante 12-15 minutos', a: null, m: null, ing: ['solomillo de ternera', 'champiñones', 'nata para cocinar', 'cebolla', 'pimienta negra', 'mantequilla'] },
  { t: 'Dorada al horno sobre cama de patatas panadera y cebolla', c: 'España', cat: 'Horno', o: 'Hornear a 190°C durante 25-30 minutos', a: 'Cocinar patatas 15 min y dorada 10 min a 180°C', m: null, ing: ['dorada', 'patata', 'cebolla', 'pimiento verde', 'aceite de oliva virgen extra', 'vinagre de vino'] },
  { t: 'Lubina al horno con verduritas juliana y vino blanco', c: 'España', cat: 'Horno', o: 'Hornear a 190°C durante 20 minutos', a: 'Cocinar en airfryer a 180°C 12 min', m: null, ing: ['lubina', 'zanahoria', 'calabacín', 'puerro', 'aceite de oliva virgen extra', 'limón'] },
  { t: 'Salmón al horno con costra de hierbas y patatas asadas', c: 'Internacional', cat: 'Horno', o: 'Hornear a 190°C durante 16-18 minutos', a: 'Airfryer a 180°C durante 10 min', m: null, ing: ['lomo de salmón', 'pan rallado', 'perejil fresco', 'diente de ajo', 'patata', 'aceite de oliva virgen extra'] },
  { t: 'Gratinado de patatas dauphinoise tradicional con queso', c: 'Francia', cat: 'Horno', o: 'Hornear a 170°C durante 45 minutos hasta que la patata esté tierna y dorada', a: 'Hornear molde en airfryer a 160°C 30 min', m: null, ing: ['patata', 'nata para cocinar', 'leche entera', 'queso gouda', 'diente de ajo', 'mantequilla'] },
  { t: 'Quiche Lorraine casera de bacon y puerro', c: 'Francia', cat: 'Horno', o: 'Hornear masa previa 10 min y con relleno a 180°C durante 25 minutos', a: 'Cocinar en molde en airfryer a 170°C 18 min', m: null, ing: ['masa quebrada', 'bacon', 'puerro', 'huevo', 'nata para cocinar', 'queso emmental'] },
  { t: 'Quiche de espinacas, queso de cabra y nueces', c: 'Francia', cat: 'Horno', o: 'Hornear a 180°C durante 25 minutos', a: 'Cocinar molde en airfryer a 170°C 18 min', m: null, ing: ['masa quebrada', 'espinacas frescas', 'queso de cabra', 'huevo', 'nata para cocinar', 'nueces'] }
];

ovenRoastBases.forEach(addRecipe);

// Generador de Asados de Carnes y Pescados al Horno
const roastProteins = [
  { name: 'Paletilla de cordero lechal', ing: 'chuletas de cordero', temp: '160°C 60 min y 200°C 15 min' },
  { name: 'Lomo de cerdo asado con manzana', ing: 'lomo de cerdo', temp: '180°C durante 40 min' },
  { name: 'Muslos de pollo con hierbas del campo', ing: 'muslos de pollo', temp: '190°C durante 35 min' },
  { name: 'Rodajas de merluza con patatas panadera', ing: 'filete de merluza', temp: '180°C durante 18 min' },
  { name: 'Lomos de bacalao con alioli gratinado', ing: 'lomo de bacalao', temp: '200°C durante 14 min con grill' },
  { name: 'Lomo de salmón en papillote', ing: 'lomo de salmón', temp: '190°C durante 15 min envuelto' },
  { name: 'Solomillo de cerdo con costra de mostaza', ing: 'solomillo de cerdo', temp: '190°C durante 20 min' },
  { name: 'Pechuga de pavo asada rellena', ing: 'pechuga de pavo', temp: '180°C durante 30 min' }
];

const roastGarnish = [
  { name: 'con patatas panadera y cebolla pochada', ings: ['patata', 'cebolla', 'aceite de oliva virgen extra'] },
  { name: 'con verduras asadas de temporada (calabacín, pimiento y berenjena)', ings: ['calabacín', 'pimiento rojo', 'berenjena'] },
  { name: 'con boniato caramelizado y romero fresco', ings: ['boniato', 'romero fresco', 'aceite de oliva virgen extra'] },
  { name: 'con champiñones al ajillo y perejil fresco', ings: ['champiñones', 'diente de ajo', 'perejil fresco'] },
  { name: 'con tomates asados y orégano silvestre', ings: ['tomate', 'tomate cherry', 'orégano'] },
  { name: 'con calabaza asada y cebolla morada', ings: ['calabaza', 'cebolla morada', 'tomillo'] },
  { name: 'con manzana asada y cebollitas glaseadas', ings: ['manzana', 'cebolla', 'canela en polvo'] },
  { name: 'con espárragos trigueros y zanahorias baby', ings: ['espárragos verdes', 'zanahoria', 'diente de ajo'] },
  { name: 'con pimientos asados al aroma de ajo', ings: ['pimiento rojo', 'pimiento verde', 'diente de ajo'] },
  { name: 'con gratén de coliflor a la bechamel', ings: ['coliflor', 'leche entera', 'queso gouda'] },
  { name: 'con arroz al horno con pimentón', ings: ['arroz bomba', 'pimentón dulce', 'diente de ajo'] }
];

roastProteins.forEach(rp => {
  roastGarnish.forEach(rg => {
    addRecipe({
      title: `${rp.name} al horno ${rg.name}`,
      country: 'España',
      cuisine_type: 'Horno',
      prep_oven: `Precalentar el horno a 190°C. Hornear ${rp.temp}`,
      prep_airfryer: 'Adaptar ración en airfryer a 180°C durante 18 minutos',
      prep_microwave: null,
      ingredients: [rp.ing, ...rg.ings, 'aceite de oliva virgen extra', 'sal marina']
    });
  });
});

// BLOQUE 10: Repostería Casera Rápida, Postres Saludables & Snacks Dulces (60 recetas)
const dessertBases = [
  { t: 'Bizcocho clásico de yogur casero con limón', c: 'España', cat: 'Repostería', o: 'Hornear a 180°C durante 35-40 minutos sin abrir la puerta', a: 'Hornear en molde de airfryer a 160°C 28 min', m: null, ing: ['yogur natural', 'harina de trigo', 'huevo', 'limón', 'aceite de girasol'] },
  { t: 'Bizcocho de avena, plátano y nueces sin azúcar', c: 'Internacional', cat: 'Repostería', o: 'Hornear a 180°C durante 30 minutos', a: 'Hornear en molde en airfryer a 165°C 22 min', m: null, ing: ['harina de avena', 'plátano', 'huevo', 'nueces', 'canela en polvo'] },
  { t: 'Mug cake de chocolate y avena en 2 minutos', c: 'Internacional', cat: 'Repostería', o: null, a: null, m: 'Cocinar en taza en microondas a 750W durante 1 minuto y medio', ing: ['harina de avena', 'cacao en polvo puro', 'huevo', 'leche entera', 'miel'] },
  { t: 'Mug cake de plátano y canela al microondas', c: 'Internacional', cat: 'Repostería', o: null, a: null, m: 'Cocinar en taza a 800W durante 80 segundos', ing: ['plátano', 'huevo', 'harina de trigo', 'canela en polvo', 'leche entera'] },
  { t: 'Galletas caseras de avena, plátano y chips de chocolate', c: 'Internacional', cat: 'Repostería', o: 'Hornear a 180°C durante 15 minutos', a: 'Cocinar en airfryer a 170°C durante 9 minutos', m: null, ing: ['copos de avena', 'plátano', 'chocolate negro 85%', 'canela en polvo'] },
  { t: 'Galletas de mantequilla tradicionales', c: 'Reino Unido', cat: 'Repostería', o: 'Hornear a 180°C durante 12-14 minutos hasta que los bordes doren', a: 'Airfryer a 170°C 8 min', m: null, ing: ['harina de trigo', 'mantequilla', 'huevo', 'extracto de vainilla'] },
  { t: 'Tarta de manzana clásica sobre masa hojaldrada', c: 'Francia', cat: 'Repostería', o: 'Hornear a 190°C durante 30 minutos', a: 'Cocinar molde en airfryer a 175°C 20 min', m: null, ing: ['masa de hojaldre', 'manzana', 'mantequilla', 'miel', 'canela en polvo'] },
  { t: 'Tarta de queso cremosa estilo La Viña', c: 'España', cat: 'Repostería', o: 'Hornear a 210°C durante 35 minutos', a: 'Hornear molde en airfryer a 180°C 25 min', m: null, ing: ['queso crema', 'nata para cocinar', 'huevo', 'harina de trigo'] },
  { t: 'Manzanas asadas al horno con canela y nueces', c: 'España', cat: 'Repostería', o: 'Asar a 190°C durante 25-30 minutos', a: 'Cocinar en airfryer a 180°C durante 15 minutos', m: 'Cocinar tapadas a 800W durante 5 minutos', ing: ['manzana', 'canela en polvo', 'nueces', 'miel', 'mantequilla'] },
  { t: 'Arroz con leche tradicional cremoso con canela', c: 'España', cat: 'Tradicional', o: null, a: null, m: null, ing: ['arroz bomba', 'leche entera', 'limón', 'canela en polvo'] },
  { t: 'Natillas caseras con galleta y canela', c: 'España', cat: 'Tradicional', o: null, a: null, m: 'Cocer crema en microondas removiendo cada minuto 4 min', ing: ['leche entera', 'huevo', 'almidón de maíz', 'canela en polvo', 'biscotes'] },
  { t: 'Panna cotta italiana con coulis de frutos rojos', c: 'Italia', cat: 'Repostería', o: null, a: null, m: 'Calentar nata y leche 2 min a 700W sin hervir', ing: ['nata para cocinar', 'leche entera', 'arándano', 'frambuesa', 'extracto de vainilla'] },
  { t: 'Crepes caseras tradicionales con miel y frutas', c: 'Francia', cat: 'Repostería', o: null, a: null, m: null, ing: ['harina de trigo', 'huevo', 'leche entera', 'mantequilla', 'fresa', 'miel'] }
];

dessertBases.forEach(addRecipe);

// Variaciones de repostería saludable y bizcochos
const dessertTypes = [
  { name: 'Bizcocho esponjoso', ing: 'harina de avena', timeOven: '30 min a 180°C', timeAir: '20 min a 165°C' },
  { name: 'Muffins individuales', ing: 'harina de trigo', timeOven: '20 min a 180°C', timeAir: '14 min a 170°C' },
  { name: 'Tarta rústica casera', ing: 'masa quebrada', timeOven: '32 min a 185°C', timeAir: '22 min a 175°C' },
  { name: 'Galletas crujientes', ing: 'copos de avena', timeOven: '14 min a 180°C', timeAir: '9 min a 170°C' },
  { name: 'Compota templada', ing: 'manzana', timeOven: '25 min a 190°C', timeAir: '15 min a 180°C' }
];

const dessertFlavors = [
  { flavor: 'de manzana y canela', ings: ['manzana', 'canela en polvo', 'huevo', 'miel'] },
  { flavor: 'de plátano maduro y cacao puro', ings: ['plátano', 'cacao en polvo puro', 'huevo', 'nueces'] },
  { flavor: 'de zanahoria especiada y nueces', ings: ['zanahoria', 'nueces', 'canela en polvo', 'huevo'] },
  { flavor: 'de limón fresco y yogur griego', ings: ['limón', 'yogur griego', 'huevo', 'mantequilla'] },
  { flavor: 'de arándanos y queso crema', ings: ['arándano', 'queso crema', 'huevo', 'extracto de vainilla'] },
  { flavor: 'de pera conferencia y chocolate negro', ings: ['pera', 'chocolate negro 85%', 'huevo', 'avellanas'] },
  { flavor: 'de naranja y almendras molidas', ings: ['naranja', 'almendras', 'huevo', 'miel'] },
  { flavor: 'de frutos rojos y coco rallado', ings: ['frambuesa', 'arándano', 'huevo', 'miel'] }
];

dessertTypes.forEach(dt => {
  dessertFlavors.forEach(df => {
    addRecipe({
      title: `${dt.name} casero ${df.flavor}`,
      country: 'Internacional',
      cuisine_type: 'Repostería',
      prep_oven: `Hornear a ${dt.timeOven}`,
      prep_airfryer: `Cocinar en airfryer en molde adecuado ${dt.timeAir}`,
      prep_microwave: 'Porción individual a 700W 1 min',
      ingredients: [dt.ing, ...df.ings, 'sal fina']
    });
  });
});

console.log(`Total recetas generadas hasta el momento: ${curatedRecipes.length}`);

// Si faltan para redondear exactamente a ~1.000 recetas (entre 980 y 1.020),
// completamos con platos gastronómicos internacionales específicos y únicos
const internationalSpecialties = [
  // Platos Griegos y Mediterráneos Orientales
  { t: 'Moussaka tradicional griega con carne picada y bechamel', c: 'Grecia', cat: 'Mediterránea', o: 'Hornear a 180°C durante 35 minutos', a: null, m: null, ing: ['berenjena', 'ternera picada', 'patata', 'tomate triturado', 'leche entera', 'harina de trigo', 'mantequilla', 'queso gouda'] },
  { t: 'Souvlaki de pollo marinado con salsa tzatziki y pan pita', c: 'Grecia', cat: 'Mediterránea', o: 'Hornear brochetas a 200°C 15 min', a: 'Cocinar en airfryer a 190°C 12 min', m: null, ing: ['pechuga de pollo', 'pan de pita', 'yogur griego', 'pepino', 'diente de ajo', 'limón', 'aceite de oliva virgen extra'] },
  { t: 'Hummus tradicional de garbanzos con pimentón y crudités', c: 'Líbano', cat: 'Mediterránea', o: null, a: null, m: null, ing: ['garbanzos cocidos', 'limón', 'diente de ajo', 'comino molido', 'pimentón dulce', 'zanahoria', 'pepino', 'aceite de oliva virgen extra'] },
  { t: 'Hummus de remolacha y queso feta con pan de pita', c: 'Líbano', cat: 'Mediterránea', o: null, a: null, m: null, ing: ['garbanzos cocidos', 'queso feta', 'pan de pita', 'limón', 'diente de ajo', 'aceite de oliva virgen extra'] },
  { t: 'Tabulé libanés de cuscús con hierbabuena fresca y tomate', c: 'Líbano', cat: 'Mediterránea', o: null, a: null, m: null, ing: ['cuscús', 'tomate', 'cebolleta', 'menta fresca', 'perejil fresco', 'limón', 'aceite de oliva virgen extra'] },
  { t: 'Koftas de ternera especiadas a la parrilla con yogur', c: 'Turquía', cat: 'Mediterránea', o: 'Hornear a 200°C 14 min', a: 'Cocinar en airfryer a 190°C 10 min', m: null, ing: ['ternera picada', 'cebolla', 'comino molido', 'perejil fresco', 'yogur griego', 'pan de pita'] },
  // Platos Franceses
  { t: 'Ratatouille tradicional provenzal al horno', c: 'Francia', cat: 'Mediterránea', o: 'Hornear en capas finas a 180°C durante 40 minutos', a: 'Verduras en airfryer a 175°C 20 min', m: null, ing: ['calabacín', 'berenjena', 'tomate', 'pimiento rojo', 'cebolla', 'diente de ajo', 'tomillo', 'aceite de oliva virgen extra'] },
  { t: 'Boeuf Bourguignon estofado al vino tinto y setas', c: 'Francia', cat: 'Tradicional', o: 'Cocinar tapado en horno a 150°C durante 2 horas', a: null, m: null, ing: ['filete de ternera', 'champiñones', 'zanahoria', 'cebolla', 'tocino ahumado', 'diente de ajo', 'tomillo'] },
  { t: 'Sopa francesa de cebolla gratinada con queso gruyere', c: 'Francia', cat: 'Tradicional', o: 'Gratinar a 220°C durante 6 minutos', a: null, m: null, ing: ['cebolla', 'caldo de pollo', 'pan de hogaza', 'queso gouda', 'mantequilla', 'aceite de oliva virgen extra'] },
  // Platos del Norte y Centro de Europa
  { t: 'Goulash húngaro tradicional de ternera con pimentón', c: 'Hungría', cat: 'Tradicional', o: null, a: null, m: 'Calentar a 800W 3 min', ing: ['filete de ternera', 'cebolla', 'pimiento rojo', 'tomate triturado', 'pimentón dulce', 'patata', 'comino molido'] },
  { t: 'Wiener Schnitzel escalope vienés crujiente con limón', c: 'Austria', cat: 'Tradicional', o: 'Hornear a 200°C 14 min', a: 'Cocinar en airfryer a 195°C durante 9 minutos', m: null, ing: ['filete de ternera', 'huevo', 'harina de trigo', 'pan rallado', 'mantequilla', 'limón', 'patata'] },
  { t: 'Albóndigas suecas tradicionales con salsa cremosa y puré', c: 'Suecia', cat: 'Tradicional', o: 'Hornear a 190°C 15 min', a: 'Cocinar en airfryer a 185°C 11 min', m: null, ing: ['carne picada mixta', 'cebolla', 'huevo', 'nata para cocinar', 'patata', 'mantequilla', 'pimienta negra'] },
  { t: 'Fish and chips británico tradicional con patatas gajo', c: 'Reino Unido', cat: 'Tradicional', o: 'Hornear a 210°C 20 min', a: 'Cocinar bacalao rebozado a 195°C 12 min y patatas a 195°C 18 min en airfryer', m: null, ing: ['lomo de bacalao', 'harina de trigo', 'patata', 'aceite de girasol', 'limón', 'sal marina'] },
  { t: 'Shepherd s pie pastel de carne picada y puré de patatas', c: 'Reino Unido', cat: 'Tradicional', o: 'Gratinar a 200°C durante 20 minutos hasta dorar el puré', a: null, m: null, ing: ['ternera picada', 'patata', 'zanahoria', 'cebolla', 'leche entera', 'mantequilla', 'queso cheddar'] }
];

internationalSpecialties.forEach(addRecipe);

// Si aún necesitamos completar para llegar a ~1.000 recetas,
// generamos combinaciones sistemáticas de platos de la huerta, pescados de mercado y woks cotidianos
const dailyProteins = [
  'Pollo campero', 'Pechuga de pavo', 'Lomo de cerdo ibérico', 'Ternera tierna',
  'Salmón atlántico', 'Merluza fresca', 'Bacalao desalado', 'Lubina salvaje',
  'Dorada real', 'Sepia limpia', 'Calamar nacional', 'Langostinos tigres',
  'Huevos camperos', 'Tofu ecológico'
];

const dailyPreparations = [
  { prep: 'a la plancha con ajo y perejil fresco', oven: 'Hornear a 190°C 15 min', air: 'Airfryer a 180°C 10 min', micro: 'Cocinar tapado 3 min a 750W', ings: ['diente de ajo', 'perejil fresco', 'aceite de oliva virgen extra'] },
  { prep: 'al limón con romero silvestre', oven: 'Hornear a 190°C 18 min', air: 'Airfryer a 185°C 12 min', micro: null, ings: ['limón', 'romero fresco', 'aceite de oliva virgen extra'] },
  { prep: 'con salteado de verduras de temporada', oven: 'Hornear a 180°C 20 min', air: 'Airfryer a 180°C 14 min', micro: null, ings: ['calabacín', 'zanahoria', 'cebolla'] },
  { prep: 'al curry suave con leche de coco', oven: null, air: null, micro: 'Calentar salsa a 750W 2 min', ings: ['leche de coco', 'cúrcuma', 'cebolla'] },
  { prep: 'a la mostaza antigua con miel', oven: 'Hornear a 180°C 16 min', air: 'Airfryer a 180°C 11 min', micro: null, ings: ['mostaza dijon', 'miel', 'vinagre de manzana'] },
  { prep: 'al pimentón dulce con patata cocida', oven: null, air: 'Patata en airfryer a 190°C 15 min', micro: 'Patata en microondas 5 min a 800W', ings: ['patata', 'pimentón dulce', 'aceite de oliva virgen extra'] },
  { prep: 'con salsa de tomate casero y orégano', oven: 'Hornear cazuela a 190°C 15 min', air: 'Airfryer a 180°C 10 min', micro: 'Regenerar ración a 750W 2 min', ings: ['tomate triturado', 'cebolla', 'orégano'] },
  { prep: 'en papillote con verduras en juliana', oven: 'Hornear en papillote a 180°C 16 min', air: 'Papillote en airfryer a 175°C 12 min', micro: 'Papillote apto a 750W 4 min', ings: ['zanahoria', 'puerro', 'calabacín'] },
  { prep: 'con crema ligera de champiñones', oven: null, air: null, micro: 'Calentar a 700W 2 min', ings: ['champiñones', 'cebolla', 'nata para cocinar'] },
  { prep: 'al ajillo con guindilla picante', oven: null, air: 'Airfryer a 190°C 9 min', micro: null, ings: ['diente de ajo', 'chile rojo', 'aceite de oliva virgen extra'] }
];

const dailySides = [
  { name: 'y ensalada verde con vinagreta', ing: 'lechuga romana' },
  { name: 'y arroz basmati aromático', ing: 'arroz basmati' },
  { name: 'y puré cremoso de patata', ing: 'patata' },
  { name: 'y quinoa real al vapor', ing: 'quinoa' },
  { name: 'y boniato asado en bastones', ing: 'boniato' },
  { name: 'y espárragos trigueros a la parrilla', ing: 'espárragos verdes' },
  { name: 'y cuscús con hierbabuena', ing: 'cuscús' },
  { name: 'y judías verdes con patata', ing: 'judías verdes' }
];

let targetCount = 1000;
for (let p of dailyProteins) {
  if (curatedRecipes.length >= targetCount) break;
  for (let dp of dailyPreparations) {
    if (curatedRecipes.length >= targetCount) break;
    for (let ds of dailySides) {
      if (curatedRecipes.length >= targetCount) break;
      const title = `${p} ${dp.prep} ${ds.name}`;
      const mainIng = p.toLowerCase().includes('pollo') ? 'pechuga de pollo' :
                      p.toLowerCase().includes('pavo') ? 'pechuga de pavo' :
                      p.toLowerCase().includes('cerdo') ? 'lomo de cerdo' :
                      p.toLowerCase().includes('ternera') ? 'filete de ternera' :
                      p.toLowerCase().includes('salmón') ? 'lomo de salmón' :
                      p.toLowerCase().includes('merluza') ? 'filete de merluza' :
                      p.toLowerCase().includes('bacalao') ? 'lomo de bacalao' :
                      p.toLowerCase().includes('lubina') ? 'lubina' :
                      p.toLowerCase().includes('dorada') ? 'dorada' :
                      p.toLowerCase().includes('sepia') ? 'sepia' :
                      p.toLowerCase().includes('calamar') ? 'calamar' :
                      p.toLowerCase().includes('langostino') ? 'langostinos' :
                      p.toLowerCase().includes('huevo') ? 'huevo' : 'tofu';

      addRecipe({
        title,
        country: 'España',
        cuisine_type: 'Mediterránea',
        prep_oven: dp.oven,
        prep_airfryer: dp.air,
        prep_microwave: dp.micro,
        ingredients: [mainIng, ...dp.ings, ds.ing, 'sal fina']
      });
    }
  }
}

console.log(`\n==============================================`);
console.log(`TOTAL RECETAS CURADAS FINALES: ${curatedRecipes.length}`);
console.log(`==============================================\n`);

// 4. Estadísticas del catálogo
const cuisineStats = {};
const countryStats = {};
let withOven = 0;
let withAirfryer = 0;
let withMicrowave = 0;
let totalIngredientsCount = 0;
const uniqueIngredients = new Set();
const categoryCount = {};

curatedRecipes.forEach(r => {
  cuisineStats[r.cuisine_type] = (cuisineStats[r.cuisine_type] || 0) + 1;
  countryStats[r.country] = (countryStats[r.country] || 0) + 1;
  if (r.prep_oven) withOven++;
  if (r.prep_airfryer) withAirfryer++;
  if (r.prep_microwave) withMicrowave++;

  r.ingredients.forEach(i => {
    totalIngredientsCount++;
    uniqueIngredients.add(i.name);
    categoryCount[i.category_slug] = (categoryCount[i.category_slug] || 0) + 1;
  });
});

console.log('--- Estadísticas por Tipo de Cocina ---');
console.table(cuisineStats);

console.log('--- Métodos de Cocción Curados ---');
console.log(`Recetas con Horno (prep_oven): ${withOven} (${((withOven/curatedRecipes.length)*100).toFixed(1)}%)`);
console.log(`Recetas con Airfryer (prep_airfryer): ${withAirfryer} (${((withAirfryer/curatedRecipes.length)*100).toFixed(1)}%)`);
console.log(`Recetas con Microondas (prep_microwave): ${withMicrowave} (${((withMicrowave/curatedRecipes.length)*100).toFixed(1)}%)`);

console.log('\n--- Ingredientes ---');
console.log(`Total asignaciones de ingredientes: ${totalIngredientsCount}`);
console.log(`Ingredientes únicos normalizados: ${uniqueIngredients.size}`);
console.log('Distribución por categoría taxonómica:');
console.table(categoryCount);

// 5. Generar archivo SQL de Seed optimizado e idempotente
console.log('\nGenerando archivo SQL supabase/seed_food_module.sql...');

function escapeSql(str) {
  if (str === null || str === undefined) return 'NULL';
  return "'" + str.replace(/'/g, "''") + "'";
}

let sqlContent = `-- ==============================================================================
-- SEED DE ALIMENTACIÓN CURADO: ~1.000 RECETAS GLOBALES PARA MARTHAPP
-- Generado automáticamente con métodos de cocción e ingredientes categorizados
-- ==============================================================================

BEGIN;

-- 1. Asegurar categorías maestras (idempotente)
INSERT INTO public.food_categories (id, name, icon_slug)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Lácteos y Derivados', 'dairy'),
  ('00000000-0000-0000-0000-000000000002', 'Frutas', 'fruit'),
  ('00000000-0000-0000-0000-000000000003', 'Verduras y Hortalizas', 'vegetable'),
  ('00000000-0000-0000-0000-000000000004', 'Carnes y Aves', 'meat'),
  ('00000000-0000-0000-0000-000000000005', 'Pescados y Mariscos', 'fish'),
  ('00000000-0000-0000-0000-000000000006', 'Cereales, Legumbres y Pastas', 'grain'),
  ('00000000-0000-0000-0000-000000000007', 'Panadería y Masas', 'bakery'),
  ('00000000-0000-0000-0000-000000000008', 'Snacks y Dulces', 'snack'),
  ('00000000-0000-0000-0000-000000000009', 'Limpieza y Hogar', 'cleaning')
ON CONFLICT (icon_slug) DO UPDATE SET name = EXCLUDED.name;

`;

// Insertar recetas en lotes (chunks) de 100 para máxima velocidad y evitar desbordamiento de transacciones
const RECIPE_CHUNK_SIZE = 100;
for (let i = 0; i < curatedRecipes.length; i += RECIPE_CHUNK_SIZE) {
  const chunk = curatedRecipes.slice(i, i + RECIPE_CHUNK_SIZE);

  sqlContent += `\n-- Inserción de lote de recetas (${i + 1} a ${i + chunk.length})\n`;
  sqlContent += `INSERT INTO public.recipes (id, title, country, cuisine_type, prep_oven, prep_airfryer, prep_microwave, is_global, environment_id)\nVALUES\n`;

  const valuesRows = chunk.map(r => {
    return `  (${escapeSql(r.id)}, ${escapeSql(r.title)}, ${escapeSql(r.country)}, ${escapeSql(r.cuisine_type)}, ${escapeSql(r.prep_oven)}, ${escapeSql(r.prep_airfryer)}, ${escapeSql(r.prep_microwave)}, true, NULL)`;
  }).join(',\n');

  sqlContent += valuesRows + `\nON CONFLICT (id) DO UPDATE SET\n  title = EXCLUDED.title,\n  prep_oven = EXCLUDED.prep_oven,\n  prep_airfryer = EXCLUDED.prep_airfryer,\n  prep_microwave = EXCLUDED.prep_microwave;\n`;
}

// Insertar ingredientes de recetas en lotes
sqlContent += `\n-- 2. Inserción de ingredientes asociados a las recetas\n`;

const allIngredients = [];
curatedRecipes.forEach(r => {
  r.ingredients.forEach(ing => {
    const cat = CATEGORIES[ing.category_slug] || CATEGORIES.vegetable;
    allIngredients.push({
      recipe_id: r.id,
      name: ing.name.toLowerCase().trim(),
      category_id: cat.id
    });
  });
});

const ING_CHUNK_SIZE = 250;
for (let i = 0; i < allIngredients.length; i += ING_CHUNK_SIZE) {
  const chunk = allIngredients.slice(i, i + ING_CHUNK_SIZE);
  sqlContent += `INSERT INTO public.recipe_ingredients (recipe_id, name, category_id)\nVALUES\n`;
  const ingRows = chunk.map(ing => {
    return `  (${escapeSql(ing.recipe_id)}, ${escapeSql(ing.name)}, ${escapeSql(ing.category_id)})`;
  }).join(',\n');
  sqlContent += ingRows + `;\n`;
}

sqlContent += `\nCOMMIT;\n`;

const sqlFilePath = path.join(__dirname, '..', 'supabase', 'seed_food_module.sql');
fs.writeFileSync(sqlFilePath, sqlContent, 'utf8');

console.log(`Archivo SQL generado con éxito: ${sqlFilePath}`);
console.log(`Tamaño del archivo SQL: ${(fs.statSync(sqlFilePath).size / (1024 * 1024)).toFixed(2)} MB`);

// También exportar un archivo JSON si es requerido para importaciones programmaticas
const jsonFilePath = path.join(__dirname, '..', 'supabase', 'seed_food_catalog.json');
fs.writeFileSync(jsonFilePath, JSON.stringify(curatedRecipes, null, 2), 'utf8');
console.log(`Archivo JSON generado con éxito: ${jsonFilePath}`);

console.log('\nSeed generado completamente con éxito.');
