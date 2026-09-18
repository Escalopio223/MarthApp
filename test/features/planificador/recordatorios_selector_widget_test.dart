import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/planificador/domain/models/recordatorio_tarea_model.dart';
import 'package:marth_app/features/planificador/presentation/widgets/recordatorios_selector_widget.dart';

void main() {
  group('RecordatoriosSelectorWidget Tests', () {
    testWidgets('Renderiza chips rápidos correctamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordatoriosSelectorWidget(
              recordatoriosIniciales: const [],
              fechaLimite: DateTime(2026, 9, 25),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('RECORDATORIOS PROGRAMADOS'), findsOneWidget);
      expect(find.text('El mismo día'), findsOneWidget);
      expect(find.text('El día antes'), findsOneWidget);
      expect(find.text('3 días antes'), findsOneWidget);
      expect(find.text('1 semana antes'), findsOneWidget);
      expect(find.text('Personalizado...'), findsOneWidget);
    });

    testWidgets('Muestra recordatorios existentes y permite eliminarlos', (tester) async {
      List<RecordatorioTareaModel> currentList = [
        RecordatorioTareaModel(
          id: 'rec_1',
          tareaId: 't1',
          fechaNotificacion: DateTime(2026, 9, 24),
          horaNotificacion: '10:00',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return RecordatoriosSelectorWidget(
                  recordatoriosIniciales: currentList,
                  fechaLimite: DateTime(2026, 9, 25),
                  onChanged: (newList) {
                    setState(() {
                      currentList = List.from(newList);
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('El día antes (10:00)'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Pulsar eliminar
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(currentList.isEmpty, isTrue);
    });
  });
}
