import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/food/domain/models/food_category_model.dart';
import 'package:marth_app/features/food/domain/models/recipe_ingredient_model.dart';
import 'package:marth_app/features/food/domain/models/recipe_model.dart';
import 'package:marth_app/features/food/presentation/controllers/food_catalog_controller.dart';
import 'package:marth_app/features/food/presentation/screens/food_catalog_screen.dart';
import 'package:marth_app/features/food/presentation/widgets/quick_recipe_modal.dart';
import 'package:marth_app/features/food/presentation/widgets/recipe_card.dart';
import 'package:marth_app/features/food/presentation/widgets/recipe_detail_sheet.dart';

import 'food_catalog_controller_test.dart';

void main() {
  final sampleRecipe = RecipeModel(
    id: 'rec-test-1',
    title: 'Salmón crujiente al horno y airfryer',
    country: 'España',
    cuisineType: 'Mediterránea',
    prepOven: 'Hornear a 190°C durante 15 minutos',
    prepAirfryer: 'Cocinar a 180°C durante 9 minutos',
    prepMicrowave: 'Calentar 2 minutos a 750W',
    isGlobal: true,
    createdAt: DateTime.now(),
    ingredients: [
      RecipeIngredientModel(
        id: 'ing-1',
        recipeId: 'rec-test-1',
        name: 'lomo de salmón',
        categoryId: '00000000-0000-0000-0000-000000000005',
        createdAt: DateTime.now(),
        category: FoodCategoryModel(
          id: '00000000-0000-0000-0000-000000000005',
          name: 'Pescados y Mariscos',
          iconSlug: FoodCategorySlug.fish,
          createdAt: DateTime.now(),
        ),
      ),
      RecipeIngredientModel(
        id: 'ing-2',
        recipeId: 'rec-test-1',
        name: 'espárragos verdes',
        categoryId: '00000000-0000-0000-0000-000000000003',
        createdAt: DateTime.now(),
        category: FoodCategoryModel(
          id: '00000000-0000-0000-0000-000000000003',
          name: 'Verduras',
          iconSlug: FoodCategorySlug.vegetable,
          createdAt: DateTime.now(),
        ),
      ),
    ],
  );

  group('RecipeCard Widget', () {
    testWidgets('Renderiza título, país, badges de electrodomésticos y botón de estrella', (tester) async {
      bool favoriteToggled = false;
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeCard(
              recipe: sampleRecipe,
              isFavorite: false,
              onTap: () => cardTapped = true,
              onToggleFavorite: () => favoriteToggled = true,
            ),
          ),
        ),
      );

      expect(find.text('Salmón crujiente al horno y airfryer'), findsOneWidget);
      expect(find.text('España'), findsOneWidget);
      expect(find.text('Airfryer'), findsOneWidget);
      expect(find.text('Horno'), findsOneWidget);
      expect(find.text('Micro'), findsOneWidget);
      expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);

      // Tap en favorito
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(favoriteToggled, isTrue);

      // Tap en tarjeta
      await tester.tap(find.text('Salmón crujiente al horno y airfryer'));
      await tester.pump();
      expect(cardTapped, isTrue);
    });
  });

  group('RecipeDetailSheet Widget', () {
    testWidgets('Muestra ingredientes clasificados e instrucciones por pestañas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeDetailSheet(
              recipe: sampleRecipe,
              isFavorite: true,
              onToggleFavorite: () {},
            ),
          ),
        ),
      );

      expect(find.text('Salmón crujiente al horno y airfryer'), findsOneWidget);
      expect(find.text('Ingredientes'), findsOneWidget);
      expect(find.text('Airfryer'), findsOneWidget);
      expect(find.text('Horno'), findsOneWidget);
      expect(find.text('Microondas'), findsOneWidget);

      // En pestaña Ingredientes
      expect(find.text('Lomo de salmón'), findsOneWidget);
      expect(find.text('Pescados y Mariscos'), findsOneWidget);

      // Cambiar a pestaña Airfryer
      await tester.tap(find.text('Airfryer'));
      await tester.pumpAndSettle();

      expect(find.text('Freidora de Aire (Airfryer)'), findsOneWidget);
      expect(find.text('Cocinar a 180°C durante 9 minutos'), findsOneWidget);
    });
  });

  group('QuickRecipeModal Widget', () {
    testWidgets('Permite ingresar plato, tags de ingredientes y guardar', (tester) async {
      final mockRepo = MockFoodRepository();
      final controller = FoodCatalogController(repository: mockRepo);
      await controller.initialize(environmentId: 'env-test', userId: 'user-test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickRecipeModal(controller: controller),
          ),
        ),
      );

      expect(find.text('Nueva Receta Casera'), findsOneWidget);

      // Ingresar nombre de plato
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del plato *'),
        'Tortilla de patatas casera',
      );

      // Ingresar tag de ingrediente
      final ingredientField = find.widgetWithText(TextField, 'Añadir ingrediente (ej. calabacín, huevo...)');
      await tester.enterText(ingredientField, 'patata,');
      await tester.pump();

      expect(find.text('Patata'), findsOneWidget);

      controller.dispose();
    });
  });

  group('FoodCatalogScreen Widget', () {
    testWidgets('Renderiza buscador, selector de vista y chips de filtros', (tester) async {
      final mockRepo = MockFoodRepository();
      final controller = FoodCatalogController(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodCatalogScreen(
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Explorar Catálogo'), findsOneWidget);
      expect(find.text('Favoritos Rápidos'), findsOneWidget);
      expect(find.text('Airfryer'), findsAtLeast(1));
      expect(find.text('Horno'), findsAtLeast(1));

      // Cambiar a pestaña Favoritos
      await tester.tap(find.text('Favoritos Rápidos'));
      await tester.pumpAndSettle();

      expect(find.text('Ingredientes Rápidos de 1-Tap'), findsOneWidget);

      controller.dispose();
    });
  });
}
