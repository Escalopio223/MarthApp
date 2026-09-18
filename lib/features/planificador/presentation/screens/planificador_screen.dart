import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_container.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../environments/presentation/controllers/environment_controller.dart';
import '../../domain/models/checklist_item_model.dart';
import '../controllers/planificador_controller.dart';
import '../widgets/checklist_editor_section.dart';
import '../widgets/crear_tarea_rapida_dialog.dart';
import '../widgets/planificador_hoy_view.dart';
import '../widgets/planificador_planificacion_view.dart';

/// Pantalla contenedora principal del módulo Planificador:
/// - Estructura ágil unificada en 2 vistas:
///   1. "Hoy": Foco diario ("¿Qué hay que hacer hoy y quién lo hace?")
///   2. "Planificación": Calendario visual, proyectos del hogar y reparto equitativo
class PlanificadorScreen extends StatefulWidget {
  final PlanificadorController? controller;
  final EnvironmentController? environmentController;
  final String? currentUserId;
  final bool asTab;

  const PlanificadorScreen({
    super.key,
    this.controller,
    this.environmentController,
    this.currentUserId,
    this.asTab = false,
  });

  @override
  State<PlanificadorScreen> createState() => _PlanificadorScreenState();
}

class _PlanificadorScreenState extends State<PlanificadorScreen> {
  late final PlanificadorController _controller;
  EnvironmentController? _environmentController;
  List<EnvironmentMemberModel> _miembros = const [];

  // 0 = Hoy, 1 = Planificación
  int _currentSectionIndex = 0;

  String? get _currentUserId {
    if (widget.currentUserId != null) return widget.currentUserId;
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PlanificadorController();
    _controller.addListener(_onControllerChanged);

    _environmentController = widget.environmentController;
    _environmentController?.addListener(_onEnvironmentChanged);

    // Configurar entorno inicial
    final activeEnv = _environmentController?.activeEnvironment;
    if (activeEnv != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.setEntorno(activeEnv.id);
        _cargarMiembros(activeEnv.id);
        _registrarTokenFcmSiExiste(activeEnv.id);
      });
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
          backgroundColor: AppTheme.accentCoral,
        ),
      );
      _controller.clearMessages();
    } else if (_controller.successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.successMessage!),
          backgroundColor: AppTheme.accentEmerald,
        ),
      );
      _controller.clearMessages();
    }

    setState(() {});
  }

  void _onEnvironmentChanged() {
    final activeEnv = _environmentController?.activeEnvironment;
    if (activeEnv != null) {
      _controller.setEntorno(activeEnv.id);
      _cargarMiembros(activeEnv.id);
      _registrarTokenFcmSiExiste(activeEnv.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _cargarMiembros(String envId) async {
    final repo = _environmentController?.repository;
    if (repo != null) {
      try {
        final m = await repo.getEnvironmentMembers(envId);
        if (mounted) setState(() => _miembros = m);
      } catch (_) {}
    }
  }

  Future<void> _registrarTokenFcmSiExiste(String entornoId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _controller.registrarFcmToken(
          token,
          infoDispositivo: 'Flutter App',
        );
      }
    } catch (_) {
      // Ignorar silenciosamente si FCM no está disponible en la plataforma actual
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _environmentController?.removeListener(_onEnvironmentChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = _miembros;
    final userId = _currentUserId;

    Widget bodyContent = Column(
      children: [
        _buildSectionTabs(context),
        const SizedBox(height: 4),
        Expanded(
          child: IndexedStack(
            index: _currentSectionIndex,
            children: [
              // Vista 1: "Hoy" (Foco diario y rutinas)
              PlanificadorHoyView(
                controller: _controller,
                miembros: members,
                usuarioActualId: userId,
                onIrAPlanificacion: () =>
                    setState(() => _currentSectionIndex = 1),
              ),

              // Vista 2: "Planificación" (Calendario, proyectos y reparto)
              PlanificadorPlanificacionView(
                controller: _controller,
                miembros: members,
                usuarioActualId: userId,
                onCrearTarea: () => _mostrarDialogoCrearTarea(context),
                onCrearEvento: () => _mostrarDialogoCrearEvento(context),
                onCrearProyecto: () => _mostrarDialogoCrearProyecto(context),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.asTab) {
      return SafeArea(
        child: bodyContent,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Planificador',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: bodyContent,
        ),
      ),
    );
  }

  // ===========================================================================
  // Selector de Sección Superior (Hoy vs Planificación)
  // ===========================================================================

  Widget _buildSectionTabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: AppContainer(
        borderRadius: 22,
        padding: const EdgeInsets.all(4),
        baseColor: AppTheme.surfaceDark,
        child: Row(
          children: [
            _buildSectionButton(
              title: 'Hoy',
              icon: Icons.wb_sunny_rounded,
              index: 0,
            ),
            _buildSectionButton(
              title: 'Planificación',
              icon: Icons.calendar_month_rounded,
              index: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionButton({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _currentSectionIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentSectionIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.actionGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    isSelected ? AppTheme.ctaTextColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color:
                      isSelected ? AppTheme.ctaTextColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Modales de Creación Rápida
  // ===========================================================================

  void _mostrarDialogoCrearTarea(BuildContext context) {
    CrearTareaRapidaDialog.show(
      context,
      controller: _controller,
      usuarioActualId: _currentUserId,
      miembros: _miembros,
      fechaInicial: _controller.selectedDate,
    );
  }

  void _mostrarDialogoCrearProyecto(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nuevo Proyecto',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nombre del proyecto...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Objetivo o descripción...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              if (title.isEmpty) return;

                              setModalState(() => isSaving = true);
                              try {
                                await _controller.crearProyecto(
                                  nombre: title,
                                  descripcion: descController.text.trim().isEmpty
                                      ? null
                                      : descController.text.trim(),
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded,
                                              color: Colors.greenAccent, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text('Proyecto "$title" creado'),
                                          ),
                                        ],
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  setModalState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al crear proyecto: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLiquid,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Crear Proyecto',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoCrearEvento(BuildContext context) {
    final titleController = TextEditingController();
    final personaController = TextEditingController();
    final ideasController = TextEditingController();
    String tipo = 'evento_general';
    List<ChecklistItemModel> checklist = [];
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nuevo Evento / Cumpleaños',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Evento'),
                          selected: tipo == 'evento_general',
                          onSelected: (_) =>
                              setModalState(() => tipo = 'evento_general'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('🎂 Cumpleaños'),
                          selected: tipo == 'cumpleanos',
                          onSelected: (_) =>
                              setModalState(() => tipo = 'cumpleanos'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: tipo == 'cumpleanos'
                            ? 'Título (ej. Cumple de Carlos)'
                            : 'Nombre del evento (ej. Ir al médico)...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.darkBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (tipo == 'cumpleanos') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: personaController,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Nombre de la persona homenajeada...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.darkBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: ideasController,
                        maxLines: 2,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Ideas de regalo...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.darkBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ChecklistEditorSection(
                      items: checklist,
                      title: 'Subtareas',
                      hintText: 'Añadir elemento (ej. Coger cartilla)...',
                      onChanged: (nuevos) {
                        setModalState(() => checklist = nuevos);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                if (title.isEmpty) return;

                                setModalState(() => isSaving = true);
                                try {
                                  await _controller.crearEvento(
                                    titulo: title,
                                    tipo: tipo,
                                    fechaInicio: _controller.selectedDate,
                                    personaCumpleanos: tipo == 'cumpleanos'
                                        ? personaController.text.trim()
                                        : null,
                                    ideasRegalo: tipo == 'cumpleanos'
                                        ? ideasController.text.trim()
                                        : null,
                                    checklist: checklist,
                                  );

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded,
                                                color: Colors.greenAccent, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text('Evento "$title" guardado'),
                                            ),
                                          ],
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setModalState(() => isSaving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error al guardar evento: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryLiquid,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Guardar Evento',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
