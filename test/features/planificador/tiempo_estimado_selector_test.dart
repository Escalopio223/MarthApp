import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/planificador/presentation/widgets/tiempo_estimado_selector.dart';

void main() {
  group('TiempoEstimadoSelector Tests', () {
    testWidgets('renders properly with initialMinutes = 0 and toggles correctly',
        (tester) async {
      int ultimoCambio = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TiempoEstimadoSelector(
              initialMinutes: 0,
              onChanged: (val) => ultimoCambio = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el label Tiempo y el chip Sin tiempo
      expect(find.text('Tiempo'), findsOneWidget);
      expect(find.text('Sin tiempo'), findsOneWidget);
      expect(find.text('Tarea sin estimación de duración'), findsOneWidget);

      // Al alternar el chip "Sin tiempo", debe activar el tiempo estimado (15 min por defecto)
      await tester.tap(find.text('Sin tiempo'));
      await tester.pumpAndSettle();

      expect(ultimoCambio, equals(15));
      expect(find.text('Duración estimada: 15 min'), findsOneWidget);
    });

    testWidgets('allows typing custom number 1-60 and switching to Horas',
        (tester) async {
      int ultimoCambio = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TiempoEstimadoSelector(
              initialMinutes: 20,
              onChanged: (val) => ultimoCambio = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Duración estimada: 20 min'), findsOneWidget);

      // Escribir 30 en el campo de número
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, '30');
      await tester.pumpAndSettle();

      expect(ultimoCambio, equals(30));
      expect(find.text('Duración estimada: 30 min'), findsOneWidget);

      // Cambiar unidad a Horas
      await tester.tap(find.byType(DropdownButton<UnidadTiempo>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Horas').last);
      await tester.pumpAndSettle();

      // 30 horas = 1800 minutos
      expect(ultimoCambio, equals(30 * 60));
      expect(find.text('Duración estimada: 30 horas (1800 min)'), findsOneWidget);
    });

    testWidgets('initializes correctly with exact hours e.g. 120 minutes = 2 horas',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TiempoEstimadoSelector(
              initialMinutes: 120,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Duración estimada: 2 horas (120 min)'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('2'));
    });

    testWidgets('selecting number from popup menu updates minutes',
        (tester) async {
      int ultimoCambio = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TiempoEstimadoSelector(
              initialMinutes: 10,
              onChanged: (val) => ultimoCambio = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir PopupMenuButton de opciones 1 al 60
      final popupButton = find.byType(PopupMenuButton<int>);
      expect(popupButton, findsOneWidget);
      await tester.tap(popupButton);
      await tester.pumpAndSettle();

      // Debe contener opciones del 1 al 60. Buscamos y pulsamos '5'
      final opcion5 = find.text('5');
      expect(opcion5, findsOneWidget);
      await tester.tap(opcion5);
      await tester.pumpAndSettle();

      expect(ultimoCambio, equals(5));
      expect(find.text('Duración estimada: 5 min'), findsOneWidget);
    });
  });
}
