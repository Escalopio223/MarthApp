import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:marth_app/features/planificador/domain/models/agenda_item_model.dart';
import 'package:marth_app/features/planificador/domain/models/checklist_item_model.dart';
import 'package:marth_app/features/planificador/domain/models/comentario_tarea_model.dart';
import 'package:marth_app/features/planificador/domain/models/evento_model.dart';
import 'package:marth_app/features/planificador/domain/models/proyecto_model.dart';
import 'package:marth_app/features/planificador/domain/models/recordatorio_tarea_model.dart';
import 'package:marth_app/features/planificador/domain/models/sesion_reparto_model.dart';
import 'package:marth_app/features/planificador/domain/models/tarea_model.dart';
import 'package:marth_app/features/planificador/domain/repositories/i_planificador_repository.dart';
import 'package:marth_app/features/planificador/presentation/controllers/planificador_controller.dart';
import 'package:marth_app/features/planificador/presentation/screens/planificador_screen.dart';
import 'package:marth_app/features/planificador/presentation/widgets/flat_calendar_header.dart';
import 'package:marth_app/features/planificador/presentation/widgets/flat_create_item_sheet.dart';
import 'package:marth_app/features/planificador/presentation/widgets/flat_event_card.dart';
import 'package:marth_app/features/planificador/presentation/widgets/flat_task_card.dart';
import 'package:marth_app/features/planificador/presentation/widgets/recordatorios_selector_widget.dart';
import 'package:marth_app/features/planificador/presentation/widgets/subtask_list.dart';
import 'package:marth_app/features/planificador/presentation/widgets/tiempo_estimado_selector.dart';
import 'package:marth_app/features/profile/domain/models/avatar_data.dart';
import 'package:marth_app/features/profile/presentation/widgets/user_avatar.dart';

class MockPlanificadorRepository implements IPlanificadorRepository {
  final StreamController<List<ProyectoModel>> proyectosCtrl =
      StreamController<List<ProyectoModel>>.broadcast();
  final StreamController<List<TareaModel>> tareasCtrl =
      StreamController<List<TareaModel>>.broadcast();
  final StreamController<List<EventoModel>> eventosCtrl =
      StreamController<List<EventoModel>>.broadcast();

  List<ProyectoModel> proyectos = [];
  List<TareaModel> tareas = [];
  List<EventoModel> eventos = [];

  void emitAll() {
    proyectosCtrl.add(List.from(proyectos));
    tareasCtrl.add(List.from(tareas));
    eventosCtrl.add(List.from(eventos));
  }

  @override
  Stream<List<ProyectoModel>> streamProyectos(String entornoId) =>
      proyectosCtrl.stream;

  @override
  Stream<List<TareaModel>> streamTareas(String entornoId) => tareasCtrl.stream;

  @override
  Stream<List<EventoModel>> streamEventos(String entornoId) =>
      eventosCtrl.stream;

  @override
  Future<List<AgendaItemModel>> getAgendaItems(
    String entornoId, {
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final List<AgendaItemModel> items = [];
    for (final e in eventos) {
      items.add(AgendaItemModel.fromEvento(e));
    }
    for (final t in tareas) {
      if (t.fechaLimite != null) {
        items.add(AgendaItemModel.fromTarea(t));
      }
    }
    items.sort();
    return items;
  }

  @override
  Future<ProyectoModel> crearProyecto({
    required String entornoId,
    required String nombre,
    String? descripcion,
    String icono = 'folder',
    String colorHex = '#6366F1',
  }) async {
    final p = ProyectoModel(
      id: 'proj-${proyectos.length + 1}',
      entornoId: entornoId,
      nombre: nombre,
      descripcion: descripcion,
      icono: icono,
      colorHex: colorHex,
      createdBy: 'user-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    proyectos.add(p);
    emitAll();
    return p;
  }

  @override
  Future<void> actualizarProyecto(ProyectoModel proyecto) async {
    final idx = proyectos.indexWhere((p) => p.id == proyecto.id);
    if (idx != -1) {
      proyectos[idx] = proyecto;
      emitAll();
    }
  }

  @override
  Future<void> eliminarProyecto(String proyectoId) async {
    proyectos.removeWhere((p) => p.id == proyectoId);
    emitAll();
  }

  @override
  Future<TareaModel> crearTarea({
    required String entornoId,
    String? proyectoId,
    required String titulo,
    String? descripcion,
    DateTime? fechaLimite,
    String? asignadoA,
    int tiempoEstimadoMinutos = 15,
    List<ChecklistItemModel> checklist = const [],
    List<RecordatorioTareaModel> recordatorios = const [],
  }) async {
    final t = TareaModel(
      id: 'task-${tareas.length + 1}',
      entornoId: entornoId,
      proyectoId: proyectoId,
      titulo: titulo,
      descripcion: descripcion,
      fechaLimite: fechaLimite,
      asignadoA: asignadoA,
      tiempoEstimadoMinutos: tiempoEstimadoMinutos,
      checklist: checklist,
      recordatorios: recordatorios,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    tareas.add(t);
    emitAll();
    return t;
  }

  @override
  Future<void> actualizarTarea(TareaModel tarea) async {
    final idx = tareas.indexWhere((t) => t.id == tarea.id);
    if (idx != -1) {
      tareas[idx] = tarea;
      emitAll();
    }
  }

  @override
  Future<void> cambiarEstadoTarea(String tareaId, String nuevoEstado) async {
    final idx = tareas.indexWhere((t) => t.id == tareaId);
    if (idx != -1) {
      tareas[idx] = tareas[idx].copyWith(estado: nuevoEstado);
      emitAll();
    }
  }

  @override
  Future<void> toggleChecklistItem(String tareaId, String itemId) async {
    final idx = tareas.indexWhere((t) => t.id == tareaId);
    if (idx != -1) {
      final updated = tareas[idx].checklist.map((item) {
        if (item.id == itemId) {
          return item.copyWith(completado: !item.completado);
        }
        return item;
      }).toList();
      tareas[idx] = tareas[idx].copyWith(checklist: updated);
      emitAll();
    }
  }

  @override
  Future<void> agregarComentarioTarea({
    required String tareaId,
    required ComentarioTareaModel comentario,
  }) async {
    final idx = tareas.indexWhere((t) => t.id == tareaId);
    if (idx != -1) {
      tareas[idx] = tareas[idx].copyWith(
        comentarios: [...tareas[idx].comentarios, comentario],
      );
      emitAll();
    }
  }

  @override
  Future<List<RecordatorioTareaModel>> obtenerRecordatoriosTarea(
    String tareaId,
  ) async {
    return const [];
  }

  @override
  Future<void> guardarRecordatoriosTarea(
    String tareaId,
    List<RecordatorioTareaModel> recordatorios,
  ) async {}

  @override
  Future<void> eliminarTarea(String tareaId) async {
    tareas.removeWhere((t) => t.id == tareaId);
    emitAll();
  }

  @override
  Future<EventoModel> crearEvento({
    required String entornoId,
    required String titulo,
    String? descripcion,
    required String tipo,
    required DateTime fechaInicio,
    DateTime? fechaFin,
    bool esTodoElDia = false,
    String? personaCumpleanos,
    String? ideasRegalo,
    List<ChecklistItemModel> checklist = const [],
    List<RecordatorioTareaModel> recordatorios = const [],
  }) async {
    final e = EventoModel(
      id: 'ev-${eventos.length + 1}',
      entornoId: entornoId,
      titulo: titulo,
      descripcion: descripcion,
      tipo: tipo,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      esTodoElDia: esTodoElDia,
      personaCumpleanos: personaCumpleanos,
      ideasRegalo: ideasRegalo,
      checklist: checklist,
      recordatorios: recordatorios,
      createdBy: 'user-1',
      createdAt: DateTime.now(),
    );
    eventos.add(e);
    emitAll();
    return e;
  }

  @override
  Future<void> actualizarEvento(EventoModel evento) async {
    final idx = eventos.indexWhere((e) => e.id == evento.id);
    if (idx != -1) {
      eventos[idx] = evento;
      emitAll();
    }
  }

  @override
  Future<void> toggleEventoChecklistItem(String eventoId, String itemId) async {
    final idx = eventos.indexWhere((e) => e.id == eventoId);
    if (idx != -1) {
      final updated = eventos[idx].checklist.map((item) {
        if (item.id == itemId) {
          return item.copyWith(completado: !item.completado);
        }
        return item;
      }).toList();
      eventos[idx] = eventos[idx].copyWith(checklist: updated);
      emitAll();
    }
  }

  @override
  Future<void> eliminarEvento(String eventoId) async {
    eventos.removeWhere((e) => e.id == eventoId);
    emitAll();
  }

  @override
  Future<SesionRepartoModel> ejecutarRepartoAutomatico({
    required String entornoId,
    required List<String> usuariosParticipantes,
    List<String>? tareaIds,
  }) async {
    return SesionRepartoModel(
      id: 'sesion-1',
      entornoId: entornoId,
      fechaSesion: DateTime.now(),
      usuariosParticipantes: usuariosParticipantes,
      minutosTotales: 60,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<SesionRepartoModel> guardarSesionRepartoManual({
    required String entornoId,
    required List<String> usuariosParticipantes,
    required Map<String, String> asignacionesFinales,
    required List<TareaModel> todasLasTareas,
  }) async {
    return SesionRepartoModel(
      id: 'sesion-manual',
      entornoId: entornoId,
      fechaSesion: DateTime.now(),
      usuariosParticipantes: usuariosParticipantes,
      minutosTotales: 30,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> registrarActualizarFcmToken({
    required String entornoId,
    required String fcmToken,
    String? dispositivoInfo,
  }) async {}
}

void main() {
  late MockPlanificadorRepository mockRepo;
  late PlanificadorController controller;

  setUp(() {
    mockRepo = MockPlanificadorRepository();
    controller = PlanificadorController(repository: mockRepo);
  });

  tearDown(() {
    controller.dispose();
    mockRepo.proyectosCtrl.close();
    mockRepo.tareasCtrl.close();
    mockRepo.eventosCtrl.close();
  });

  group('PlanificadorController Tests', () {
    test('setEntorno subscribes and updates state when stream emits', () async {
      final today = DateTime.now();
      mockRepo.proyectos = [
        ProyectoModel(
          id: 'p1',
          entornoId: 'env-1',
          nombre: 'Reforma Cocina',
          createdBy: 'u1',
          createdAt: today,
          updatedAt: today,
        ),
      ];
      mockRepo.tareas = [
        TareaModel(
          id: 't1',
          entornoId: 'env-1',
          titulo: 'Comprar pintura',
          tiempoEstimadoMinutos: 45,
          fechaLimite: today,
          createdAt: today,
          updatedAt: today,
        ),
      ];
      mockRepo.eventos = [
        EventoModel(
          id: 'e1',
          entornoId: 'env-1',
          titulo: 'Cumple de Ana',
          tipo: 'cumpleanos',
          fechaInicio: today,
          personaCumpleanos: 'Ana',
          createdBy: 'u1',
          createdAt: today,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.proyectos.length, equals(1));
      expect(controller.tareas.length, equals(1));
      expect(controller.eventos.length, equals(1));
      expect(controller.eventosForSelectedDate.length, equals(1));
      expect(controller.tareasForSelectedDate.length, equals(1));
      expect(controller.diaTieneItems(today), isTrue);
    });

    test(
      'toggleTarea updates state optimistically and calls repository',
      () async {
        final now = DateTime.now();
        mockRepo.tareas = [
          TareaModel(
            id: 't1',
            entornoId: 'env-1',
            titulo: 'Barrer la casa',
            estado: 'pendiente',
            createdAt: now,
            updatedAt: now,
          ),
        ];

        controller.setEntorno('env-1');
        mockRepo.emitAll();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await controller.toggleTarea('t1');

        expect(controller.tareas.first.estaCompletada, isTrue);
      },
    );
  });

  group('Flat Design 2.0 Widget Tests', () {
    testWidgets(
      'FlatCalendarHeader renders 7 weekdays in week mode and expands to month grid',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final selected = DateTime(2026, 11, 8); // Domingo

        DateTime? clickedDate;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FlatCalendarHeader(
                selectedDate: selected,
                onDateSelected: (d) => clickedDate = d,
                hasItemsOnDate: (d) => d.day == 8,
              ),
            ),
          ),
        );
        await tester.pump();

        // Verificar que se renderizan las etiquetas de los 7 días
        expect(find.text('L'), findsWidgets);
        expect(find.text('M'), findsWidgets);
        expect(find.text('X'), findsWidgets);
        expect(find.text('J'), findsWidgets);
        expect(find.text('V'), findsWidgets);
        expect(find.text('S'), findsWidgets);
        expect(find.text('D'), findsWidgets);

        // Tocar en el botón del mes para expandir al modo mes
        await tester.tap(find.textContaining('Noviembre 2026'));
        await tester.pumpAndSettle();

        // Encontrar días del mes
        expect(find.text('15'), findsWidgets);

        // Tocar el día 15 en la cuadrícula mensual: debe llamar al callback y colapsarse a modo semana
        await tester.tap(find.text('15').first);
        await tester.pumpAndSettle();

        expect(clickedDate, isNotNull);
        expect(clickedDate!.day, equals(15));
      },
    );

    testWidgets(
      'FlatEventCard renders appointment and birthday card with subtle pastel styling',
      (tester) async {
        final now = DateTime(2026, 11, 8, 10, 30);

        final citaMedica = EventoModel(
          id: 'ev-1',
          entornoId: 'env-1',
          titulo: 'Consulta Médica',
          tipo: 'evento_general',
          fechaInicio: now,
          createdBy: 'u-1',
          createdAt: now,
        );

        final cumpleanos = EventoModel(
          id: 'ev-2',
          entornoId: 'env-1',
          titulo: 'Cumpleaños de Laura',
          tipo: 'cumpleanos',
          fechaInicio: now,
          personaCumpleanos: 'Laura',
          ideasRegalo: 'Libro de diseño',
          createdBy: 'u-1',
          createdAt: now,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FlatEventCard(evento: citaMedica),
                  FlatEventCard(evento: cumpleanos),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        // Cita médica
        expect(find.text('Consulta Médica'), findsOneWidget);
        expect(find.text('10:30'), findsOneWidget);

        // Cumpleaños con regalo y pastel
        expect(find.text('Cumpleaños de Laura'), findsOneWidget);
        expect(find.text('Regalo: Libro de diseño'), findsOneWidget);
        expect(find.text('Cumpleaños'), findsOneWidget);
        expect(find.byIcon(Icons.cake_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'FlatTaskCard renders checkbox, title, estimated time chip and member avatar',
      (tester) async {
        final now = DateTime.now();

        final tarea = TareaModel(
          id: 't-1',
          entornoId: 'env-1',
          titulo: 'Fregar los platos',
          tiempoEstimadoMinutos: 15,
          estado: 'pendiente',
          asignadoA: 'u-1',
          createdAt: now,
          updatedAt: now,
        );

        final miembro = EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'u-1',
          role: 'member',
          joinedAt: now,
          username: 'Alba',
          avatarData: const AvatarData.initials(),
        );

        bool toggleCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FlatTaskCard(
                tarea: tarea,
                asignado: miembro,
                onToggle: () => toggleCalled = true,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Fregar los platos'), findsOneWidget);
        expect(find.text('15m'), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);

        // Tocar checkbox atómico
        await tester.tap(find.byKey(const ValueKey('task_card_checkbox')));
        await tester.pump();

        expect(toggleCalled, isTrue);
      },
    );

    testWidgets('FlatCreateItemSheet switches between Tarea and Evento tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? createdTaskTitle;
      String? createdEventTitle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlatCreateItemSheet(
              defaultDate: DateTime.now(),
              miembros: const [],
              onCreateTask:
                  ({
                    required String titulo,
                    DateTime? fechaLimite,
                    String? asignadoA,
                    int tiempoEstimadoMinutos = 15,
                    String? proyectoId,
                    String? descripcion,
                    List<ChecklistItemModel> checklist = const [],
                    List<RecordatorioTareaModel> recordatorios = const [],
                  }) async {
                    createdTaskTitle = titulo;
                  },
              onCreateEvent:
                  ({
                    required String titulo,
                    required DateTime fechaInicio,
                    DateTime? fechaFin,
                    bool esTodoElDia = false,
                    String tipo = 'evento_general',
                    String? personaCumpleanos,
                    String? ideasRegalo,
                    List<ChecklistItemModel> checklist = const [],
                    List<RecordatorioTareaModel> recordatorios = const [],
                  }) async {
                    createdEventTitle = titulo;
                  },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab Tarea activa por defecto con Smart Canvas
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('¿Qué hay que hacer?'), findsOneWidget);
      expect(find.text('Guardar Tarea'), findsOneWidget);

      // Conmutar a tab Evento
      await tester.tap(find.text('Evento / Cita'));
      await tester.pumpAndSettle();

      expect(find.text('Título del evento'), findsOneWidget);
      expect(find.text('Guardar Evento'), findsOneWidget);

      // Conmutar de vuelta a tab Tarea
      await tester.tap(find.text('Tarea'));
      await tester.pumpAndSettle();

      // Escribir título de tarea y guardar
      await tester.enterText(find.byType(TextField).first, 'Pasear al perro');
      await tester.tap(find.text('Guardar Tarea'));
      await tester.pumpAndSettle();

      expect(createdTaskTitle, equals('Pasear al perro'));
    });

    testWidgets('FlatCreateItemSheet handles configurable estimated time, advanced task options and birthday gift ideas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? createdEventTitle;
      String? createdGiftIdeas;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlatCreateItemSheet(
              defaultDate: DateTime.now(),
              miembros: const [],
              onCreateTask:
                  ({
                    required String titulo,
                    DateTime? fechaLimite,
                    String? asignadoA,
                    int tiempoEstimadoMinutos = 15,
                    String? proyectoId,
                    String? descripcion,
                    List<ChecklistItemModel> checklist = const [],
                    List<RecordatorioTareaModel> recordatorios = const [],
                  }) async {},
              onCreateEvent:
                  ({
                    required String titulo,
                    required DateTime fechaInicio,
                    DateTime? fechaFin,
                    bool esTodoElDia = false,
                    String tipo = 'evento_general',
                    String? personaCumpleanos,
                    String? ideasRegalo,
                    List<ChecklistItemModel> checklist = const [],
                    List<RecordatorioTareaModel> recordatorios = const [],
                  }) async {
                    createdEventTitle = titulo;
                    createdGiftIdeas = ideasRegalo;
                  },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que las píldoras de estado del Smart Canvas están presentes
      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('No se repite'), findsOneWidget);
      expect(find.text('Sin avisos'), findsOneWidget);
      expect(find.text('+ Subtareas'), findsOneWidget);

      // Abrir bandeja de duración y cambiar a 30 min
      await tester.tap(find.text('15 min'));
      await tester.pumpAndSettle();
      expect(find.text('Media (30 min)'), findsOneWidget);
      await tester.tap(find.text('Media (30 min)'));
      await tester.pumpAndSettle();
      expect(find.text('30 min'), findsOneWidget);

      // Abrir bandeja de recordatorios
      await tester.tap(find.text('Sin avisos'));
      await tester.pumpAndSettle();
      expect(find.text('1 día antes'), findsOneWidget);
      expect(find.text('3 días antes'), findsOneWidget);
      expect(find.text('1 semana antes'), findsOneWidget);

      // Abrir subtareas usando el finder del texto
      final subtareasFinder = find.widgetWithText(InkWell, '+ Subtareas');
      await tester.scrollUntilVisible(subtareasFinder, 100, scrollable: find.byType(Scrollable).last);
      await tester.tap(subtareasFinder);
      await tester.pumpAndSettle();
      expect(find.byType(SubtaskList), findsOneWidget);

      // Conmutar a tab Evento
      await tester.tap(find.text('Evento / Cita'));
      await tester.pumpAndSettle();

      // Seleccionar tipo Cumpleaños
      await tester.tap(find.text('🎂 Cumpleaños'));
      await tester.pumpAndSettle();

      // Verificar que la sección de ideas de regalo reordenable y editable aparece
      expect(find.text('Ideas de Regalo'), findsOneWidget);
      expect(find.text('Añadir'), findsOneWidget);

      // Añadir una idea de regalo
      await tester.enterText(find.widgetWithText(TextField, 'Ej. Libro de cocina, zapatillas...'), 'Bicicleta de montaña');
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();

      expect(find.text('Bicicleta de montaña'), findsOneWidget);

      // Guardar cumpleaños
      await tester.enterText(find.widgetWithText(TextField, 'Ej. Lucas, Mamá, Juan...'), 'Carlos');
      await tester.tap(find.text('Guardar Cumpleaños'));
      await tester.pumpAndSettle();

      expect(createdEventTitle, equals('Carlos'));
      expect(createdGiftIdeas, contains('Bicicleta de montaña'));
    });

    testWidgets(
      'PlanificadorScreen renders dynamic calendar, empty state and FAB',
      (tester) async {
        controller.setEntorno('env-1');
        mockRepo.emitAll();

        await tester.pumpWidget(
          MaterialApp(home: PlanificadorScreen(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Cabecera de calendario presente
        expect(find.byType(FlatCalendarHeader), findsOneWidget);

        // Barra de búsqueda debajo del calendario presente
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);
        expect(find.text('Buscar tareas, eventos, notas...'), findsOneWidget);

        // Estado vacío inicial presente
        expect(find.text('Día despejado'), findsOneWidget);

        // Probar filtrado con el buscador
        await tester.enterText(
          find.widgetWithText(TextField, 'Buscar tareas, eventos, notas...'),
          'cocina',
        );
        await tester.pumpAndSettle();

        expect(find.text('Resultados para "cocina"'), findsOneWidget);
        expect(find.text('Sin resultados'), findsOneWidget);

        // Limpiar búsqueda
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Día despejado'), findsOneWidget);

        // Botón flotante presente
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );
  });
}
