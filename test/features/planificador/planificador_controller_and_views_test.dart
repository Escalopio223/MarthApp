import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:marth_app/features/planificador/domain/models/agenda_item_model.dart';
import 'package:marth_app/features/planificador/domain/models/checklist_item_model.dart';
import 'package:marth_app/features/planificador/domain/models/comentario_tarea_model.dart';
import 'package:marth_app/features/planificador/domain/models/evento_model.dart';
import 'package:marth_app/features/planificador/domain/models/item_reparto_model.dart';
import 'package:marth_app/features/planificador/domain/models/proyecto_model.dart';
import 'package:marth_app/features/planificador/domain/models/recordatorio_tarea_model.dart';
import 'package:marth_app/features/planificador/domain/models/sesion_reparto_model.dart';
import 'package:marth_app/features/planificador/domain/models/tarea_model.dart';
import 'package:marth_app/features/planificador/domain/repositories/i_planificador_repository.dart';
import 'package:marth_app/features/planificador/presentation/controllers/planificador_controller.dart';
import 'package:marth_app/features/planificador/presentation/widgets/agenda_calendar_view.dart';
import 'package:marth_app/features/planificador/presentation/widgets/crear_tarea_rapida_dialog.dart';
import 'package:marth_app/features/planificador/presentation/widgets/editar_tarea_dialog.dart';
import 'package:marth_app/features/planificador/presentation/widgets/planificador_hoy_view.dart';
import 'package:marth_app/features/planificador/presentation/widgets/proyectos_backlog_view.dart';
import 'package:marth_app/features/planificador/presentation/widgets/reparto_tareas_board_view.dart';
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
  Future<void> actualizarProyecto(ProyectoModel proyecto) async {}

  @override
  Future<void> eliminarProyecto(String proyectoId) async {}

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
  Future<void> toggleChecklistItem(String tareaId, String itemId) async {}

  @override
  Future<void> agregarComentarioTarea({
    required String tareaId,
    required ComentarioTareaModel comentario,
  }) async {
    final idx = tareas.indexWhere((t) => t.id == tareaId);
    if (idx != -1) {
      final exists = tareas[idx].comentarios.any(
        (c) => c.id == comentario.id || (c.texto == comentario.texto && c.autorId == comentario.autorId),
      );
      if (!exists) {
        tareas[idx] = tareas[idx].copyWith(
          comentarios: [...tareas[idx].comentarios, comentario],
        );
      }
      emitAll();
    }
  }

  @override
  Future<List<RecordatorioTareaModel>> obtenerRecordatoriosTarea(String tareaId) async {
    final t = tareas.firstWhere((element) => element.id == tareaId, orElse: () => tareas.first);
    return t.recordatorios;
  }

  @override
  Future<void> guardarRecordatoriosTarea(
    String tareaId,
    List<RecordatorioTareaModel> recordatorios,
  ) async {
    final idx = tareas.indexWhere((t) => t.id == tareaId);
    if (idx != -1) {
      tareas[idx] = tareas[idx].copyWith(recordatorios: recordatorios);
      emitAll();
    }
  }

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
      createdBy: 'user-1',
      createdAt: DateTime.now(),
    );
    eventos.add(e);
    emitAll();
    return e;
  }

  @override
  Future<void> actualizarEvento(EventoModel evento) async {}

  @override
  Future<void> eliminarEvento(String eventoId) async {}

  @override
  Future<void> toggleEventoChecklistItem(String eventoId, String itemId) async {}

  @override
  Future<SesionRepartoModel> ejecutarRepartoAutomatico({
    required String entornoId,
    required List<String> usuariosParticipantes,
    List<String>? tareaIds,
  }) async {
    return SesionRepartoModel(
      id: 'ses-mock',
      entornoId: entornoId,
      fechaSesion: DateTime.now(),
      usuariosParticipantes: usuariosParticipantes,
      minutosTotales: 60,
      items: [
        ItemRepartoModel(
          id: 'item-1',
          sesionId: 'ses-mock',
          tareaId: 'task-1',
          usuarioAsignadoInicial: usuariosParticipantes[0],
          usuarioAsignadoFinal: usuariosParticipantes[0],
          tiempoMinutos: 30,
        ),
      ],
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
      id: 'ses-manual',
      entornoId: entornoId,
      fechaSesion: DateTime.now(),
      usuariosParticipantes: usuariosParticipantes,
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

      // Permitir que los streams emitan
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.proyectos.length, equals(1));
      expect(controller.tareas.length, equals(1));
      expect(controller.eventos.length, equals(1));
      expect(controller.tareasSueltas.length, equals(1));
      expect(controller.agendaItemsForSelectedDate.length, equals(2));
      expect(controller.diaTieneItems(today), isTrue);
    });

    test('Reparto Drag & Drop state and dynamic minutes accumulation', () async {
      final now = DateTime.now();
      mockRepo.tareas = [
        TareaModel(
          id: 't1',
          entornoId: 'env-1',
          titulo: 'Limpiar sala',
          tiempoEstimadoMinutos: 30,
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't2',
          entornoId: 'env-1',
          titulo: 'Fregar platos',
          tiempoEstimadoMinutos: 20,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      controller.setParticipantes(['u1', 'u2']);
      controller.seleccionarTodasLasTareasReparto();

      // Por defecto asigna a u1
      expect(controller.getMinutosUsuarioEnReparto('u1'), equals(50));
      expect(controller.getMinutosUsuarioEnReparto('u2'), equals(0));

      // Mover t2 a u2 vía drag and drop
      controller.moverTareaEnReparto('t2', 'u2');

      // Comprobar recálculo dinámico inmediato de minutos
      expect(controller.getMinutosUsuarioEnReparto('u1'), equals(30));
      expect(controller.getMinutosUsuarioEnReparto('u2'), equals(20));
      expect(controller.getTareasDeUsuarioEnReparto('u2').first.id, equals('t2'));
    });
  });

  group('Planificador Widget Views Tests', () {
    testWidgets('AgendaCalendarView renders days, task and birthday card',
        (tester) async {
      final today = DateTime.now();
      mockRepo.tareas = [
        TareaModel(
          id: 't1',
          entornoId: 'env-1',
          titulo: 'Pagar facturas',
          tiempoEstimadoMinutos: 15,
          fechaLimite: today,
          createdAt: today,
          updatedAt: today,
        ),
      ];
      mockRepo.eventos = [
        EventoModel(
          id: 'e1',
          entornoId: 'env-1',
          titulo: 'Cumpleaños de Roberto',
          tipo: 'cumpleanos',
          fechaInicio: today,
          personaCumpleanos: 'Roberto',
          ideasRegalo: 'Zapatillas deportivas',
          createdBy: 'u1',
          createdAt: today,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgendaCalendarView(controller: controller),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Lun'), findsOneWidget);
      expect(find.text('Pagar facturas'), findsOneWidget);
      expect(find.text('Roberto'), findsOneWidget);
      expect(find.text('Ideas: Zapatillas deportivas'), findsOneWidget);
      expect(find.byIcon(Icons.cake_rounded), findsOneWidget);
    });

    testWidgets('ProyectosBacklogView renders projects and switches to backlog',
        (tester) async {
      final now = DateTime.now();
      mockRepo.proyectos = [
        ProyectoModel(
          id: 'p1',
          entornoId: 'env-1',
          nombre: 'Pintar Casa',
          createdBy: 'u1',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      mockRepo.tareas = [
        TareaModel(
          id: 't1',
          entornoId: 'env-1',
          proyectoId: 'p1',
          titulo: 'Comprar rodillos',
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't2',
          entornoId: 'env-1',
          titulo: 'Tarea sin proyecto',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProyectosBacklogView(controller: controller),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pintar Casa'), findsOneWidget);
      expect(find.text('0/1 (0%)'), findsOneWidget);

      // Cambiar a pestaña tareas sueltas
      await tester.tap(find.textContaining('Tareas sueltas'));
      await tester.pump();

      expect(find.text('Tarea sin proyecto'), findsOneWidget);
    });

    testWidgets('RepartoTareasBoardView renders member columns with minute counter',
        (tester) async {
      final now = DateTime.now();
      mockRepo.tareas = [
        TareaModel(
          id: 't1',
          entornoId: 'env-1',
          titulo: 'Barrer terraza',
          tiempoEstimadoMinutos: 40,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final miembros = [
        EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'usr-alberto',
          role: 'owner',
          joinedAt: now,
          username: 'Alberto',
          avatarData: const AvatarData.initials(),
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      controller.setParticipantes(['usr-alberto']);
      controller.seleccionarTodasLasTareasReparto();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepartoTareasBoardView(
              controller: controller,
              miembros: miembros,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Alberto'), findsNWidgets(2)); // Barra de participantes + cabecera columna
      expect(find.text('40 min'), findsOneWidget);
      expect(find.text('Barrer terraza'), findsOneWidget);
      expect(find.text('Reparto automático balanceado'), findsOneWidget);
      expect(find.text('Guardar y Aplicar'), findsOneWidget);
    });

    testWidgets(
        'RepartoTareasBoardView renders all environment members when 2+ members exist',
        (tester) async {
      final now = DateTime.now();
      mockRepo.tareas = [
        TareaModel(
          id: 't1',
          entornoId: 'env-1',
          titulo: 'Limpiar cristales',
          tiempoEstimadoMinutos: 45,
          asignadoA: 'usr-alberto',
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't2',
          entornoId: 'env-1',
          titulo: 'Pasar la aspiradora',
          tiempoEstimadoMinutos: 30,
          asignadoA: 'usr-beatriz',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final miembros = [
        EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'usr-alberto',
          role: 'owner',
          joinedAt: now,
          username: 'Alberto',
          avatarData: const AvatarData.initials(),
        ),
        EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'usr-beatriz',
          role: 'member',
          joinedAt: now,
          username: 'Beatriz',
          avatarData: const AvatarData.initials(),
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      // Montar vista con los 2 miembros
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepartoTareasBoardView(
              controller: controller,
              miembros: miembros,
            ),
          ),
        ),
      );
      await tester.pump();

      // Ambos participantes deben ser reconocidos automáticamente
      expect(controller.participantesIds, containsAll(['usr-alberto', 'usr-beatriz']));

      // Comprobar que en la UI aparecen tanto Alberto como Beatriz (en chips de participantes y en columnas)
      expect(find.text('Alberto'), findsNWidgets(2));
      expect(find.text('Beatriz'), findsNWidgets(2));
      expect(find.text('PARTICIPANTES EN EL REPARTO'), findsOneWidget);
      expect(find.text('2/2'), findsNWidgets(2)); // 2/2 participantes y 2/2 tareas seleccionadas

      // Comprobar que las tareas aparecen en el tablero
      expect(find.text('Limpiar cristales'), findsOneWidget);
      expect(find.text('Pasar la aspiradora'), findsOneWidget);

      // Botón de reasignación rápida presente cuando hay más de 1 participante
      expect(find.byIcon(Icons.swap_horiz_rounded), findsWidgets);

      // Probar toggle de participante en controller
      controller.toggleParticipante('usr-beatriz');
      await tester.pump();

      expect(controller.participantesIds, equals(['usr-alberto']));
      // Las tareas de Beatriz deben reasignarse a Alberto
      expect(controller.repartoAsignaciones['t2'], equals('usr-alberto'));
    });

    testWidgets('PlanificadorHoyView renders critical alerts, routines and task feed',
        (tester) async {
      final now = DateTime.now();
      // Cumpleaños mañana
      final manana = now.add(const Duration(days: 1));
      mockRepo.eventos = [
        EventoModel(
          id: 'ev-cumple',
          entornoId: 'env-1',
          titulo: 'Cumpleaños de Laura',
          fechaInicio: DateTime(now.year, manana.month, manana.day, 10, 0),
          tipo: 'cumpleanos',
          ideasRegalo: '1 ideas',
          personaCumpleanos: 'Laura',
          createdBy: 'user-1',
          createdAt: now,
        ),
      ];

      mockRepo.tareas = [
        TareaModel(
          id: 't-hoy',
          entornoId: 'env-1',
          titulo: 'Pasear a Max',
          asignadoA: 'usr-1',
          fechaLimite: now,
          estado: 'pendiente',
          tiempoEstimadoMinutos: 15,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      final miembros = [
        EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'usr-1',
          role: 'owner',
          joinedAt: now,
          username: 'Yo',
          avatarData: const AvatarData.initials(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanificadorHoyView(
              controller: controller,
              usuarioActualId: 'usr-1',
              miembros: miembros,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verifica alerta crítica de cumpleaños
      expect(find.text('Laura'), findsOneWidget);
      expect(find.text('¡MAÑANA ES SU CUMPLEAÑOS!'), findsOneWidget);

      // Verifica carrusel de rutinas rápidas
      expect(find.text('Fregar platos'), findsOneWidget);
      expect(find.text('Poner lavadora'), findsOneWidget);

      // Verifica tarea de hoy
      expect(find.text('Pasear a Max'), findsOneWidget);

      // Tap en plantilla rápida de rutina
      await tester.tap(find.text('Fregar platos'));
      await tester.pump(const Duration(milliseconds: 50));

      // Comprobar que se creó la tarea en el repositorio
      expect(mockRepo.tareas.any((t) => t.titulo == 'Fregar platos'), isTrue);
    });

    testWidgets('CrearTareaRapidaDialog submits task with selected chips',
        (tester) async {
      final now = DateTime.now();
      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      final miembros = [
        EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'usr-1',
          role: 'owner',
          joinedAt: now,
          username: 'Yo',
          avatarData: const AvatarData.initials(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => CrearTareaRapidaDialog.show(
                  ctx,
                  controller: controller,
                  usuarioActualId: 'usr-1',
                  miembros: miembros,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva Tarea Rápida'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Mañana'), findsOneWidget);

      // Escribir texto de la tarea
      await tester.enterText(find.byType(TextField).first, 'Comprar leche desnatada');
      await tester.pump();

      // Tap en botón de crear (AppButton con 'Crear Tarea')
      await tester.ensureVisible(find.text('Crear Tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear Tarea'));
      await tester.pumpAndSettle();

      // Debe haber creado la tarea con tiempo 0 (Sin tiempo) por defecto
      expect(mockRepo.tareas.any((t) => t.titulo == 'Comprar leche desnatada'), isTrue);
      final tareaCreada = mockRepo.tareas.firstWhere((t) => t.titulo == 'Comprar leche desnatada');
      expect(tareaCreada.tiempoEstimadoMinutos, equals(0));
    });

    testWidgets('EditarTareaDialog allows renaming, setting etiqueta, and saving',
        (tester) async {
      final now = DateTime.now();
      controller.setEntorno('env-1');

      final tareaOriginal = TareaModel(
        id: 't-fregar',
        entornoId: 'env-1',
        titulo: 'Fregar platos',
        fechaLimite: now,
        estado: 'pendiente',
        tiempoEstimadoMinutos: 15,
        createdAt: now,
        updatedAt: now,
      );

      mockRepo.tareas = [tareaOriginal];
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      final miembros = [
        EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'usr-1',
          role: 'owner',
          joinedAt: now,
          username: 'Yo',
          avatarData: const AvatarData.initials(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => EditarTareaDialog.show(
                  ctx,
                  tarea: tareaOriginal,
                  controller: controller,
                  usuarioActualId: 'usr-1',
                  miembros: miembros,
                ),
                child: const Text('Abrir Editar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Tarea'), findsOneWidget);
      expect(find.text('Categoría'), findsOneWidget);
      expect(find.text('Fecha'), findsOneWidget);
      expect(find.text('Asignación'), findsOneWidget);
      expect(find.text('Tiempo'), findsOneWidget);
      expect(find.text('Postergar para mañana'), findsNothing);

      // Renombrar tarea y seleccionar etiqueta Cocina
      await tester.enterText(find.byType(TextField).first, 'Fregar platos y sartenes');
      await tester.pump();

      await tester.tap(find.text('Cocina'));
      await tester.pump();

      // Guardar cambios
      await tester.ensureVisible(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(mockRepo.tareas.any((t) => t.titulo == 'Fregar platos y sartenes'), isTrue);
      final tareaGuardada = mockRepo.tareas.firstWhere((t) => t.id == 't-fregar');
      expect(tareaGuardada.etiqueta, equals('Cocina'));

      // Probar eliminar tarea en controller
      await controller.eliminarTarea('t-fregar');
      await tester.pump(const Duration(milliseconds: 50));
      expect(mockRepo.tareas.any((t) => t.id == 't-fregar'), isFalse);
    });

    test('PlanificadorController tag filtering and grouping works properly', () async {
      final now = DateTime.now();
      controller.setEntorno('env-1');

      final t1 = TareaModel(
        id: 't-1',
        entornoId: 'env-1',
        titulo: 'Limpiar baño',
        descripcion: 'Limpieza',
        fechaLimite: now,
        estado: 'pendiente',
        createdAt: now,
        updatedAt: now,
      );
      final t2 = TareaModel(
        id: 't-2',
        entornoId: 'env-1',
        titulo: 'Cocinar cena',
        descripcion: 'Cocina',
        fechaLimite: now,
        estado: 'pendiente',
        createdAt: now,
        updatedAt: now,
      );
      final t3 = TareaModel(
        id: 't-3',
        entornoId: 'env-1',
        titulo: 'Hacer llamada',
        fechaLimite: now,
        estado: 'pendiente',
        createdAt: now,
        updatedAt: now,
      );

      mockRepo.tareas = [t1, t2, t3];
      mockRepo.emitAll();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.tareasDeHoy.length, equals(3));
      expect(controller.etiquetasDisponibles, containsAll(['Limpieza', 'Cocina']));

      // Filtro por etiqueta
      controller.setFiltroEtiqueta('Limpieza');
      expect(controller.tareasDeHoy.length, equals(1));
      expect(controller.tareasDeHoy.first.titulo, equals('Limpiar baño'));

      controller.setFiltroEtiqueta(null);
      expect(controller.tareasDeHoy.length, equals(3));

      // Agrupación por etiqueta
      final agrupadas = controller.tareasDeHoyAgrupadasPorEtiqueta;
      expect(agrupadas.containsKey('Limpieza'), isTrue);
      expect(agrupadas.containsKey('Cocina'), isTrue);
      expect(agrupadas.containsKey('Sin etiqueta'), isTrue);
      expect(agrupadas['Limpieza']!.length, equals(1));
      expect(agrupadas['Cocina']!.length, equals(1));
      expect(agrupadas['Sin etiqueta']!.length, equals(1));

      // Toggle agrupación
      expect(controller.agruparPorEtiqueta, isFalse);
      controller.toggleAgruparPorEtiqueta();
      expect(controller.agruparPorEtiqueta, isTrue);
    });

    testWidgets('Checklist items in tasks and events can be viewed and toggled in controller and UI',
        (tester) async {
      final now = DateTime.now();
      controller.setEntorno('env-1');

      final taskWithChecklist = TareaModel(
        id: 'task-chk-1',
        entornoId: 'env-1',
        titulo: 'Hacer compra semanal',
        fechaLimite: now,
        checklist: const [
          ChecklistItemModel(id: 'chk-1', titulo: 'Manzanas', completado: false),
          ChecklistItemModel(id: 'chk-2', titulo: 'Leche de avena', completado: true),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final eventWithChecklist = EventoModel(
        id: 'ev-chk-1',
        entornoId: 'env-1',
        titulo: 'Visita al médico',
        tipo: 'general',
        fechaInicio: now,
        checklist: const [
          ChecklistItemModel(id: 'echk-1', titulo: 'Coger cartilla médica', completado: false),
        ],
        createdBy: 'usr-1',
        createdAt: now,
      );

      mockRepo.tareas = [taskWithChecklist];
      mockRepo.eventos = [eventWithChecklist];
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.tareasDeHoy.first.checklist.length, equals(2));
      expect(controller.eventos.first.checklist.length, equals(1));

      // Test optimistic toggle on task checklist
      await controller.toggleChecklistItem('task-chk-1', 'chk-1');
      expect(controller.tareasDeHoy.first.checklist.firstWhere((i) => i.id == 'chk-1').completado, isTrue);

      // Test optimistic toggle on event checklist
      await controller.toggleEventoChecklistItem('ev-chk-1', 'echk-1');
      expect(controller.eventos.first.checklist.firstWhere((i) => i.id == 'echk-1').completado, isTrue);

      // Render PlanificadorHoyView to verify UI displays subitems
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanificadorHoyView(
              controller: controller,
              usuarioActualId: 'usr-1',
              miembros: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manzanas'), findsOneWidget);
      expect(find.text('Leche de avena'), findsOneWidget);
      expect(find.text('Coger cartilla médica'), findsOneWidget);

      // Tap on item 'Manzanas' in UI
      await tester.tap(find.text('Manzanas'));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap on event item 'Coger cartilla médica' in UI
      await tester.tap(find.text('Coger cartilla médica'));
      await tester.pump(const Duration(milliseconds: 50));
    });

    test('TareaModel decodes checklist and comentarios with dynamic maps properly', () {
      final json = <String, dynamic>{
        'id': 't-test',
        'entorno_id': 'env-1',
        'titulo': 'Test subtareas y comentarios',
        'checklist': <dynamic>[
          <dynamic, dynamic>{'id': 'c-1', 'titulo': 'Sub 1', 'completado': false},
          <dynamic, dynamic>{'id': 'c-2', 'titulo': 'Sub 2', 'completado': true},
        ],
        'comentarios': <dynamic>[
          <dynamic, dynamic>{
            'id': 'com-1',
            'autor_id': 'usr-1',
            'autor_nombre': 'Carlos',
            'texto': 'Ya compré las cosas',
            'created_at': DateTime.now().toIso8601String(),
          },
        ],
      };

      final tarea = TareaModel.fromJson(json);
      expect(tarea.checklist.length, equals(2));
      expect(tarea.checklist.first.titulo, equals('Sub 1'));
      expect(tarea.comentarios.length, equals(1));
      expect(tarea.comentarios.first.texto, equals('Ya compré las cosas'));
    });

    testWidgets('Comments can be added to task and EditarTareaDialog displays subtareas and comments', (tester) async {
      controller.setEntorno('env-1');

      final task = TareaModel(
        id: 't-comm-1',
        entornoId: 'env-1',
        titulo: 'Tarea con comentarios',
        checklist: const [
          ChecklistItemModel(id: 'chk-1', titulo: 'Comprar pan'),
        ],
        comentarios: [
          ComentarioTareaModel(
            id: 'c-1',
            autorId: 'usr-1',
            autorNombre: 'Marta',
            texto: 'Por favor pan integral',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      mockRepo.tareas = [task];
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 30));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarTareaDialog(
              tarea: task,
              controller: controller,
              usuarioActualId: 'usr-1',
              miembros: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check Subtareas title and item
      expect(find.text('Subtareas'), findsOneWidget);
      expect(find.text('Comprar pan'), findsOneWidget);

      // Check Comentarios title and existing comment
      expect(find.text('COMENTARIOS (1)'), findsOneWidget);
      expect(find.text('Por favor pan integral'), findsOneWidget);

      // Add a new comment via controller
      await controller.agregarComentario(
        tareaId: 't-comm-1',
        texto: 'Listo, compré el integral',
        autorId: 'usr-2',
        autorNombre: 'Juan',
      );

      final updatedTask = controller.tareas.firstWhere((t) => t.id == 't-comm-1');
      expect(updatedTask.comentarios.length, equals(2));
      expect(updatedTask.comentarios.last.texto, equals('Listo, compré el integral'));
    });

    testWidgets('AgendaCalendarView renders subtareas and comments badges, and tapping opens EditarTareaDialog', (tester) async {
      final now = DateTime.now();
      controller.setEntorno('env-1');
      controller.selectDate(now);

      final task = TareaModel(
        id: 't-agenda-1',
        entornoId: 'env-1',
        titulo: 'Llevar coche a revisión',
        fechaLimite: now,
        checklist: const [
          ChecklistItemModel(id: 'c-1', titulo: 'Mirar frenos'),
        ],
        comentarios: [
          ComentarioTareaModel(
            id: 'c-1',
            autorId: 'u1',
            autorNombre: 'Ana',
            texto: 'Llamé al taller',
            createdAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      mockRepo.tareas = [task];
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 30));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgendaCalendarView(
              controller: controller,
              usuarioActualId: 'usr-1',
              miembros: const [],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Llevar coche a revisión'), findsOneWidget);
      expect(find.text('0/1 subtareas'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // Comment badge counter

      // Tap on the task card to open EditarTareaDialog
      await tester.tap(find.text('Llevar coche a revisión'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify EditarTareaDialog is displayed
      expect(find.text('Editar Tarea'), findsOneWidget);
      expect(find.text('Subtareas'), findsOneWidget);
    });

    testWidgets('Reparto allows selecting and deselecting participants, and shows/hides columns', (tester) async {
      final now = DateTime.now();
      controller.setEntorno('env-1');

      final miembros = [
        EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'usr-alberto',
          role: 'owner',
          joinedAt: now,
          username: 'Alberto',
          avatarData: const AvatarData.initials(),
        ),
        EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'usr-beatriz',
          role: 'member',
          joinedAt: now,
          username: 'Beatriz',
          avatarData: const AvatarData.initials(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepartoTareasBoardView(
              controller: controller,
              miembros: miembros,
            ),
          ),
        ),
      );
      await tester.pump();

      // Inicialmente ambos están seleccionados
      expect(controller.participantesIds, containsAll(['usr-alberto', 'usr-beatriz']));
      expect(find.text('2/2'), findsWidgets);

      // Deseleccionar a Beatriz tocando su chip en la barra de participantes
      final chipBeatriz = find.text('Beatriz').first;
      await tester.tap(chipBeatriz);
      await tester.pump();

      // Ahora solo Alberto participa
      expect(controller.participantesIds, equals(['usr-alberto']));
      expect(find.text('1/2'), findsWidgets);

      // Volver a seleccionar a Beatriz tocando de nuevo
      await tester.tap(chipBeatriz);
      await tester.pump();

      expect(controller.participantesIds, containsAll(['usr-alberto', 'usr-beatriz']));
      expect(find.text('2/2'), findsWidgets);

      // Probar Deseleccionar todos
      await tester.tap(find.text('Deseleccionar todos'));
      await tester.pump();

      expect(controller.participantesIds, isEmpty);
      expect(find.text('No hay miembros participantes seleccionados'), findsOneWidget);

      // Probar Seleccionar todos
      await tester.tap(find.text('Seleccionar todos'));
      await tester.pump();

      expect(controller.participantesIds.length, equals(2));
    });

    testWidgets('Hoy view renders responsible logo on card and EditarTareaDialog displays responsible banner with logo and name', (tester) async {
      final now = DateTime.now();
      controller.setEntorno('env-1');

      final miembros = [
        EnvironmentMemberModel(
          environmentId: 'env-1',
          userId: 'usr-alberto',
          role: 'owner',
          joinedAt: now,
          username: 'Alberto',
          avatarData: const AvatarData.initials(),
        ),
      ];

      final tareaAsignada = TareaModel(
        id: 't-asig-1',
        entornoId: 'env-1',
        titulo: 'Fregar los platos',
        tiempoEstimadoMinutos: 15,
        asignadoA: 'usr-alberto',
        createdAt: now,
        updatedAt: now,
      );

      mockRepo.tareas = [tareaAsignada];
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 30));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanificadorHoyView(
              controller: controller,
              miembros: miembros,
              usuarioActualId: 'usr-alberto',
            ),
          ),
        ),
      );
      await tester.pump();

      // Comprobar previsualización del card en Hoy: título y logo del responsable
      expect(find.text('Fregar los platos'), findsOneWidget);
      expect(find.byType(UserAvatar), findsWidgets); // Mini avatar + logo en previsualización

      // Abrir la tarea para editar
      await tester.tap(find.text('Fregar los platos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Comprobar que en EditarTareaDialog aparece el banner del responsable con logo y nombre
      expect(find.text('RESPONSABLE DE LA TAREA'), findsOneWidget);
      expect(find.text('Alberto (Tú)'), findsOneWidget);
      expect(find.text('Asignada'), findsOneWidget);
    });
  });
}
