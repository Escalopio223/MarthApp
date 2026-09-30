import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/food/domain/models/active_calendar_slot_model.dart';
import 'package:marth_app/features/food/domain/models/food_category_model.dart';
import 'package:marth_app/features/food/domain/models/food_favorite_model.dart';
import 'package:marth_app/features/food/domain/models/recipe_ingredient_model.dart';
import 'package:marth_app/features/food/domain/models/recipe_model.dart';
import 'package:marth_app/features/food/domain/models/saved_weekly_menu_model.dart';
import 'package:marth_app/features/food/domain/models/saved_weekly_menu_slot_model.dart';
import 'package:marth_app/features/food/domain/models/shopping_list_item_model.dart';

void main() {
  group('Módulo Food - FoodCategoryModel', () {
    test('Parsea correctamente todas las categorías y slugs oficiales', () {
      final category = FoodCategoryModel.fromJson({
        'id': '00000000-0000-0000-0000-000000000001',
        'name': 'Lácteos y Derivados',
        'icon_slug': 'dairy',
        'created_at': '2026-09-30T10:00:00Z',
      });

      expect(category.id, '00000000-0000-0000-0000-000000000001');
      expect(category.iconSlug, FoodCategorySlug.dairy);
      expect(category.iconSlug.displayName, 'Lácteos y Derivados');
      expect(category.iconSlug.iconData, isNotNull);
      expect(category.iconSlug.color, isNotNull);

      final json = category.toJson();
      expect(json['icon_slug'], 'dairy');
    });

    test('Mapea slug desconocido a vegetable por fallback', () {
      final fallback = FoodCategorySlug.fromString('desconocido');
      expect(fallback, FoodCategorySlug.vegetable);
    });
  });

  group('Módulo Food - RecipeModel & RecipeIngredientModel', () {
    test('Serializa y deserializa una receta completa con ingredientes y métodos de cocción', () {
      final recipeJson = {
        'id': 'rec-123',
        'title': 'Salmón crujiente en airfryer con verduras',
        'country': 'España',
        'cuisine_type': 'Mediterránea',
        'prep_oven': 'Hornear a 190°C durante 15 minutos',
        'prep_airfryer': 'Cocinar a 180°C durante 9 minutos en airfryer',
        'prep_microwave': null,
        'is_global': true,
        'environment_id': null,
        'created_at': '2026-09-30T12:00:00Z',
        'recipe_ingredients': [
          {
            'id': 'ing-1',
            'recipe_id': 'rec-123',
            'name': 'Lomo De Salmón ',
            'category_id': '00000000-0000-0000-0000-000000000005',
            'created_at': '2026-09-30T12:00:00Z',
            'food_categories': {
              'id': '00000000-0000-0000-0000-000000000005',
              'name': 'Pescados y Mariscos',
              'icon_slug': 'fish',
              'created_at': '2026-09-30T10:00:00Z',
            }
          },
          {
            'id': 'ing-2',
            'recipe_id': 'rec-123',
            'name': 'espárragos verdes',
            'category_id': '00000000-0000-0000-0000-000000000003',
            'created_at': '2026-09-30T12:00:00Z',
          }
        ]
      };

      final recipe = RecipeModel.fromJson(recipeJson);

      expect(recipe.id, 'rec-123');
      expect(recipe.hasAirfryer, isTrue);
      expect(recipe.hasOven, isTrue);
      expect(recipe.hasMicrowave, isFalse);
      expect(recipe.isGlobal, isTrue);
      expect(recipe.ingredients.length, 2);

      // Verificación de normalización en minúsculas y trim
      expect(recipe.ingredients.first.name, 'lomo de salmón');
      expect(recipe.ingredients.first.category?.iconSlug, FoodCategorySlug.fish);

      final outJson = recipe.toJson();
      expect(outJson['title'], recipe.title);
      expect(outJson['is_global'], isTrue);
    });
  });

  group('Módulo Food - FoodFavoriteModel', () {
    test('Maneja favoritos de tipo receta e ingrediente', () {
      final favRecipe = FoodFavoriteModel.fromJson({
        'id': 'fav-1',
        'environment_id': 'env-123',
        'item_type': 'recipe',
        'recipe_id': 'rec-123',
        'ingredient_name': null,
        'created_at': '2026-09-30T12:00:00Z',
        'recipes': {
          'id': 'rec-123',
          'title': 'Tortilla de patatas tradicional',
          'country': 'España',
          'cuisine_type': 'Tradicional',
          'created_at': '2026-09-30T12:00:00Z',
        }
      });

      expect(favRecipe.isRecipe, isTrue);
      expect(favRecipe.displayName, 'Tortilla de patatas tradicional');

      final favIng = FoodFavoriteModel.fromJson({
        'id': 'fav-2',
        'environment_id': 'env-123',
        'item_type': 'ingredient',
        'recipe_id': null,
        'ingredient_name': 'aguacate',
        'created_at': '2026-09-30T12:00:00Z',
      });

      expect(favIng.isIngredient, isTrue);
      expect(favIng.displayName, 'Aguacate');
    });
  });

  group('Módulo Food - SavedWeeklyMenuModel & Slots', () {
    test('Parsea plantilla de menú semanal con ranuras por día y tipo de comida', () {
      final menu = SavedWeeklyMenuModel.fromJson({
        'id': 'menu-1',
        'environment_id': 'env-123',
        'name': 'Menú exprés airfryer',
        'description': 'Semana rápida baja en aceite',
        'created_at': '2026-09-30T12:00:00Z',
        'saved_weekly_menu_slots': [
          {
            'id': 'slot-1',
            'saved_menu_id': 'menu-1',
            'day_of_week': 1,
            'meal_type': 'lunch',
            'item_type': 'recipe',
            'recipe_id': 'rec-1',
            'recipes': {
              'id': 'rec-1',
              'title': 'Pollo al ajillo con patatas',
              'country': 'España',
              'cuisine_type': 'Tradicional',
              'created_at': '2026-09-30T12:00:00Z',
            }
          },
          {
            'id': 'slot-2',
            'saved_menu_id': 'menu-1',
            'day_of_week': 1,
            'meal_type': 'dinner',
            'item_type': 'single_ingredient',
            'custom_name': 'Yogur griego con nueces',
          }
        ]
      });

      expect(menu.name, 'Menú exprés airfryer');
      expect(menu.slots.length, 2);

      final lunchSlot = menu.slots.first;
      expect(lunchSlot.dayOfWeek, 1);
      expect(lunchSlot.dayName, 'Lunes');
      expect(lunchSlot.mealType, MealType.lunch);
      expect(lunchSlot.mealType.displayName, 'Comida');
      expect(lunchSlot.displayTitle, 'Pollo al ajillo con patatas');

      final dinnerSlot = menu.slots[1];
      expect(dinnerSlot.mealType, MealType.dinner);
      expect(dinnerSlot.displayTitle, 'Yogur griego con nueces');
    });
  });

  group('Módulo Food - ActiveCalendarSlotModel & ShoppingListItemModel', () {
    test('Crea y formatea correctamente slots de calendario activo', () {
      final slot = ActiveCalendarSlotModel.fromJson({
        'id': 'cal-1',
        'environment_id': 'env-123',
        'date': '2026-10-05',
        'meal_type': 'lunch',
        'item_type': 'recipe',
        'recipe_id': 'rec-1',
        'custom_name': null,
      });

      expect(slot.dateString, '2026-10-05');
      expect(slot.mealType, MealType.lunch);
      expect(slot.itemType, SlotItemType.recipe);
    });

    test('ShoppingListItemModel maneja contadores, check y categorías', () {
      final item = ShoppingListItemModel.fromJson({
        'id': 'shop-1',
        'environment_id': 'env-123',
        'name': 'aceite de oliva virgen extra',
        'occurrences_count': 3,
        'category_id': '00000000-0000-0000-0000-000000000003',
        'is_checked': false,
        'is_manual': false,
        'created_at': '2026-09-30T12:00:00Z',
        'updated_at': '2026-09-30T12:00:00Z',
      });

      expect(item.displayName, 'Aceite de oliva virgen extra');
      expect(item.occurrencesCount, 3);
      expect(item.isChecked, isFalse);

      final checked = item.copyWith(isChecked: true);
      expect(checked.isChecked, isTrue);
    });
  });
}
