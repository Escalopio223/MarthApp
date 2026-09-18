import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/planificador/domain/models/agenda_item_model.dart';
import 'package:marth_app/features/planificador/domain/models/checklist_item_model.dart';
import 'package:marth_app/features/planificador/domain/models/evento_model.dart';
import 'package:marth_app/features/planificador/domain/models/proyecto_model.dart';
import 'package:marth_app/features/planificador/domain/models/sesion_reparto_model.dart';
import 'package:marth_app/features/planificador/domain/models/tarea_model.dart';

void main() {
  group('ChecklistItemModel Tests', () {
    test('fromJson and toJson work correctly', () {
      final json = {
        'id': 'chk-1',
        'titulo': 'Comprar leche',
        'completado': true,
      };

      final item = ChecklistItemModel.fromJson(json);
      expect(item.id, equals('chk-1'));
      expect(item.titulo, equals('Comprar leche'));
      expect(item.completado, isTrue);

      final exported = item.toJson();
      expect(exported['id'], equals('chk-1'));
      expect(exported['completado'], isTrue);
    });

    test('copyWith updates fields immutably', () {
      const item = ChecklistItemModel(id: 'chk-1', titulo: 'Comprar pan');
      final updated = item.copyWith(completado: true);

      expect(item.completado, isFalse);
      expect(updated.completado, isTrue);
      expect(updated.id, equals(item.id));
    });
  });

  group('ProyectoModel Tests', () {
    test('fromJson handles defaults correctly', () {
      final json = {
        'id': 'proj-1',
        'entorno_id': 'env-123',
        'nombre': 'Limpieza General',
        'created_by': 'usr-1',
      };

      final proj = ProyectoModel.fromJson(json);
      expect(proj.id, equals('proj-1'));
      expect(proj.entornoId, equals('env-123'));
      expect(proj.nombre, equals('Limpieza General'));
      expect(proj.icono, equals('folder'));
      expect(proj.colorHex, equals('#6366F1'));
    });

    test('toJson serializes appropriately', () {
      final proj = ProyectoModel(
        id: 'proj-2',
        entornoId: 'env-1',
        nombre: 'Vacaciones',
        descripcion: 'Plan de verano',
        icono: 'beach',
        colorHex: '#10B981',
        createdBy: 'usr-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      final map = proj.toJson();
      expect(map['id'], equals('proj-2'));
      expect(map['descripcion'], equals('Plan de verano'));
      expect(map['icono'], equals('beach'));
    });
  });

  group('TareaModel Tests', () {
    test('Safe parsing of checklist from List and String', () {
      final jsonWithList = {
        'id': 'task-1',
        'entorno_id': 'env-1',
        'titulo': 'Cocinar cena',
        'tiempo_estimado_minutos': 30,
        'estado': 'pendiente',
        'checklist': [
          {'id': 'c1', 'titulo': 'Cortar cebolla', 'completado': true},
          {'id': 'c2', 'titulo': 'Freír carne', 'completado': false},
        ],
      };

      final tareaList = TareaModel.fromJson(jsonWithList);
      expect(tareaList.checklist.length, equals(2));
      expect(tareaList.checklist[0].completado, isTrue);
      expect(tareaList.checklist[1].completado, isFalse);
      expect(tareaList.porcentajeProgreso, equals(0.5));

      final jsonWithString = {
        'id': 'task-2',
        'entorno_id': 'env-1',
        'titulo': 'Lavar ropa',
        'checklist':
            '[{"id":"c3","titulo":"Poner detergente","completado":true}]',
      };

      final tareaString = TareaModel.fromJson(jsonWithString);
      expect(tareaString.checklist.length, equals(1));
      expect(tareaString.checklist.first.titulo, equals('Poner detergente'));
      expect(tareaString.porcentajeProgreso, equals(1.0));
    });

    test('porcentajeProgreso reflects state accurately', () {
      final tareaDone = TareaModel(
        id: 't-done',
        entornoId: 'env-1',
        titulo: 'Terminada',
        estado: 'completada',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(tareaDone.porcentajeProgreso, equals(1.0));

      final tareaPendiente = TareaModel(
        id: 't-pending',
        entornoId: 'env-1',
        titulo: 'Pendiente',
        estado: 'pendiente',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(tareaPendiente.porcentajeProgreso, equals(0.0));
    });
  });

  group('EventoModel Tests', () {
    test('detects birthday correctly and calculates remaining days', () {
      final today = DateTime.now();
      final eventoCumple = EventoModel(
        id: 'ev-1',
        entornoId: 'env-1',
        titulo: 'Cumpleaños de Laura',
        tipo: 'cumpleanos',
        fechaInicio: DateTime(1998, today.month, today.day),
        personaCumpleanos: 'Laura',
        ideasRegalo: 'Un libro de suspense',
        createdBy: 'usr-1',
        createdAt: DateTime.now(),
      );

      expect(eventoCumple.esCumpleanos, isTrue);
      expect(eventoCumple.esEventoGeneral, isFalse);
      expect(eventoCumple.diasParaCumpleanos, equals(0));
      expect(eventoCumple.ideasRegalo, contains('libro'));
    });

    test('EventoModel supports checklist, calculates progress and handles json', () {
      final json = {
        'id': 'ev-medico',
        'entorno_id': 'env-1',
        'titulo': 'Cita Médica',
        'tipo': 'general',
        'fecha_inicio': '2026-09-17T10:00:00Z',
        'checklist': [
          {'id': 'c1', 'titulo': 'Coger cartilla sanitaria', 'completado': true},
          {'id': 'c2', 'titulo': 'Preguntar por análisis de sangre', 'completado': false},
        ],
        'created_by': 'usr-1',
        'created_at': '2026-09-17T08:00:00Z',
      };

      final evento = EventoModel.fromJson(json);
      expect(evento.checklist.length, equals(2));
      expect(evento.checklistItemsTotales, equals(2));
      expect(evento.checklistItemsCompletados, equals(1));
      expect(evento.porcentajeProgreso, equals(0.5));

      final serialized = evento.toJson();
      expect(serialized['checklist'], isA<List>());
      expect((serialized['checklist'] as List).length, equals(2));
    });
  });

  group('Reparto Models Tests', () {
    test('SesionRepartoModel and ItemRepartoModel parse correctly', () {
      final json = {
        'id': 'ses-1',
        'entorno_id': 'env-1',
        'fecha_sesion': '2026-09-16',
        'usuarios_participantes': ['u1', 'u2'],
        'minutos_totales': 75,
        'items': [
          {
            'id': 'it-1',
            'sesion_id': 'ses-1',
            'tarea_id': 't-1',
            'usuario_asignado_inicial': 'u1',
            'usuario_asignado_final': 'u2',
            'tiempo_minutos': 45,
          },
          {
            'id': 'it-2',
            'sesion_id': 'ses-1',
            'tarea_id': 't-2',
            'usuario_asignado_inicial': 'u2',
            'usuario_asignado_final': 'u1',
            'tiempo_minutos': 30,
          },
        ],
      };

      final sesion = SesionRepartoModel.fromJson(json);
      expect(sesion.id, equals('ses-1'));
      expect(sesion.minutosTotales, equals(75));
      expect(sesion.usuariosParticipantes, equals(['u1', 'u2']));
      expect(sesion.items.length, equals(2));
      expect(sesion.items[0].usuarioAsignadoFinal, equals('u2'));
      expect(sesion.items[1].tiempoMinutos, equals(30));
    });
  });

  group('AgendaItemModel Tests', () {
    test('Unifies events and tasks with proper sorting', () {
      final now = DateTime.now();
      final evento = EventoModel(
        id: 'e1',
        entornoId: 'env-1',
        titulo: 'Reunión familiar',
        tipo: 'evento_general',
        fechaInicio: now.add(const Duration(hours: 4)),
        createdBy: 'usr-1',
        createdAt: now,
      );

      final tarea = TareaModel(
        id: 't1',
        entornoId: 'env-1',
        titulo: 'Sacar la basura',
        fechaLimite: now.add(const Duration(hours: 1)),
        createdAt: now,
        updatedAt: now,
      );

      final itemEvento = AgendaItemModel.fromEvento(evento);
      final itemTarea = AgendaItemModel.fromTarea(tarea);

      expect(itemEvento.esEventoGeneral, isTrue);
      expect(itemTarea.esTarea, isTrue);

      final list = [itemEvento, itemTarea]..sort();
      expect(list.first.id, equals('t1')); // Earlier deadline first
      expect(list.last.id, equals('e1'));
    });
  });
}
