import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/etiqueta_tarea.dart';
import '../../domain/models/recordatorio_tarea_model.dart';
import '../controllers/planificador_controller.dart';
import 'checklist_editor_section.dart';
import 'recordatorios_selector_widget.dart';
import 'tiempo_estimado_selector.dart';

/// Modal bottom sheet ultra-rápido para crear tareas del hogar en menos de 5 segundos:
/// - Un único campo enfocado automáticamente ("¿Qué hay que hacer?")
/// - Selector inmediato de fecha táctil: Hoy / Mañana / Sin fecha (Backlog)
/// - Selector de categoría o etiqueta rápida (opcional)
/// - Selector opcional de responsable con avatares compactos de los convivientes
/// - Creación ágil de subtareas / checklist
/// - Duración estándar implícita de 15 minutos (cero fricción de estimación manual)
class CrearTareaRapidaDialog extends StatefulWidget {
  final PlanificadorController controller;
  final List<EnvironmentMemberModel> miembros;
  final String? usuarioActualId;
  final DateTime? fechaInicial;
  final String? proyectoIdInicial;

  const CrearTareaRapidaDialog({
    super.key,
    required this.controller,
    this.miembros = const [],
    this.usuarioActualId,
    this.fechaInicial,
    this.proyectoIdInicial,
  });

  static Future<void> show(
    BuildContext context, {
    required PlanificadorController controller,
    List<EnvironmentMemberModel> miembros = const [],
    String? usuarioActualId,
    DateTime? fechaInicial,
    String? proyectoIdInicial,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrearTareaRapidaDialog(
        controller: controller,
        miembros: miembros,
        usuarioActualId: usuarioActualId,
        fechaInicial: fechaInicial,
        proyectoIdInicial: proyectoIdInicial,
      ),
    );
  }

  @override
  State<CrearTareaRapidaDialog> createState() => _CrearTareaRapidaDialogState();
}

enum _OpcionFechaRapida { hoy, manana, personalizada, sinFecha }

class _CrearTareaRapidaDialogState extends State<CrearTareaRapidaDialog> {
  final TextEditingController _tituloController = TextEditingController();
  _OpcionFechaRapida _fechaSeleccionada = _OpcionFechaRapida.hoy;
  DateTime? _fechaPersonalizada;
  String? _responsableSeleccionadoId;
  String? _etiquetaSeleccionada;
  String? _proyectoSeleccionadoId;
  int _tiempoMinutos = 0; // Por defecto: Sin tiempo
  List<ChecklistItemModel> _checklist = [];
  List<RecordatorioTareaModel> _recordatorios = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _proyectoSeleccionadoId = widget.proyectoIdInicial;
    // Por defecto sugerir al usuario actual si existe entre los miembros
    _responsableSeleccionadoId = widget.usuarioActualId;
    if (widget.fechaInicial != null) {
      final now = DateTime.now();
      final init = widget.fechaInicial!;
      if (init.year == now.year && init.month == now.month && init.day == now.day) {
        _fechaSeleccionada = _OpcionFechaRapida.hoy;
      } else {
        final manana = now.add(const Duration(days: 1));
        if (init.year == manana.year && init.month == manana.month && init.day == manana.day) {
          _fechaSeleccionada = _OpcionFechaRapida.manana;
        } else {
          _fechaSeleccionada = _OpcionFechaRapida.personalizada;
          _fechaPersonalizada = init;
        }
      }
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  DateTime? _calcularFechaLimite() {
    final now = DateTime.now();
    switch (_fechaSeleccionada) {
      case _OpcionFechaRapida.hoy:
        return DateTime(now.year, now.month, now.day, 12, 0);
      case _OpcionFechaRapida.manana:
        final manana = now.add(const Duration(days: 1));
        return DateTime(manana.year, manana.month, manana.day, 12, 0);
      case _OpcionFechaRapida.personalizada:
        final d = _fechaPersonalizada ?? widget.fechaInicial ?? now;
        return DateTime(d.year, d.month, d.day, 12, 0);
      case _OpcionFechaRapida.sinFecha:
        return null;
    }
  }

  Future<void> _guardar() async {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await widget.controller.crearTarea(
        proyectoId: _proyectoSeleccionadoId,
        titulo: titulo,
        descripcion: _etiquetaSeleccionada,
        fechaLimite: _calcularFechaLimite(),
        asignadoA: _responsableSeleccionadoId,
        tiempoEstimadoMinutos: _tiempoMinutos,
        checklist: _checklist,
        recordatorios: _recordatorios,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Tarea "$titulo" guardada')),
              ],
            ),
            backgroundColor: AppTheme.surfaceDark,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar tarea: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: AppTheme.primaryLiquid.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + math.max(bottomSafeArea, 20.0)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tirador decorativo superior
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Título y botón cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.actionGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.flash_on_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Nueva Tarea Rápida',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppTheme.textSecondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Campo de texto principal con autoenfoque
          TextField(
            controller: _tituloController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '¿Qué hay que hacer en casa?',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
              filled: true,
              fillColor: AppTheme.darkBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppTheme.cardBorderColor,
                  width: 0.8,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppTheme.primaryLiquid,
                  width: 1.4,
                ),
              ),
            ),
            onSubmitted: (_) => _guardar(),
          ),
          const SizedBox(height: 14),

          // Selector táctil de fecha: Hoy / Mañana / Sin fecha
          Text(
            'Fecha',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFechaChip(
                label: 'Hoy',
                icon: Icons.wb_sunny_rounded,
                opcion: _OpcionFechaRapida.hoy,
              ),
              const SizedBox(width: 8),
              _buildFechaChip(
                label: 'Mañana',
                icon: Icons.next_plan_rounded,
                opcion: _OpcionFechaRapida.manana,
              ),
              if (_fechaPersonalizada != null) ...[
                const SizedBox(width: 8),
                _buildFechaChip(
                  label: '${_fechaPersonalizada!.day}/${_fechaPersonalizada!.month}',
                  icon: Icons.event_available_rounded,
                  opcion: _OpcionFechaRapida.personalizada,
                ),
              ],
              const SizedBox(width: 8),
              _buildFechaChip(
                label: 'Sin fecha',
                icon: Icons.inbox_rounded,
                opcion: _OpcionFechaRapida.sinFecha,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector opcional de etiqueta
          Text(
            'Categoría',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildEtiquetasSelector(),
          const SizedBox(height: 14),

          // Selector opcional de Proyecto (si existen proyectos en el entorno)
          if (widget.controller.proyectos.isNotEmpty) ...[
            Text(
              'Proyecto',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildProyectoSelector(),
            const SizedBox(height: 14),
          ],

          // Selector interactivo de tiempo estimado (1-60 + minutos/horas o sin tiempo)
          TiempoEstimadoSelector(
            initialMinutes: _tiempoMinutos,
            onChanged: (minutos) {
              setState(() => _tiempoMinutos = minutos);
            },
          ),
          const SizedBox(height: 14),

          // Selector de responsable (opcional)
          if (widget.miembros.isNotEmpty) ...[
            Text(
              'Asignación',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildResponsableChip(
                    userId: null,
                    nombre: 'Cualquiera',
                    esCualquiera: true,
                  ),
                  const SizedBox(width: 8),
                  ...widget.miembros.map((m) {
                    final esYo = widget.usuarioActualId == m.userId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildResponsableChip(
                        userId: m.userId,
                        nombre: esYo ? 'Yo' : m.username,
                        avatarData: m.avatarData,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Selector opcional de subtareas / checklist
            ChecklistEditorSection(
              items: _checklist,
              title: 'Subtareas',
              hintText: 'Añadir elemento (ej: Comprar pan)...',
              onChanged: (items) {
                setState(() => _checklist = items);
              },
            ),
            const SizedBox(height: 16),

            // Selector de recordatorios programados
            RecordatoriosSelectorWidget(
              recordatoriosIniciales: _recordatorios,
              fechaLimite: _calcularFechaLimite(),
              onChanged: (recs) {
                setState(() => _recordatorios = List.from(recs));
              },
            ),
            const SizedBox(height: 18),

            // Botón de confirmación
            AppButton(
              text: _isSaving ? 'Guardando...' : 'Crear Tarea',
              icon: Icons.check_circle_rounded,
              gradient: AppTheme.actionGradient,
              isLoading: _isSaving,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFechaChip({
    required String label,
    required IconData icon,
    required _OpcionFechaRapida opcion,
  }) {
    final isSelected = _fechaSeleccionada == opcion;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _fechaSeleccionada = opcion);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryLiquid.withValues(alpha: 0.16)
                : AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryLiquid
                  : AppTheme.cardBorderColor,
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppTheme.primaryLiquid
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primaryLiquid
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsableChip({
    required String? userId,
    required String nombre,
    AvatarData? avatarData,
    bool esCualquiera = false,
  }) {
    final isSelected = _responsableSeleccionadoId == userId;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _responsableSeleccionadoId = userId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.secondaryAccent.withValues(alpha: 0.18)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.secondaryAccent
                : AppTheme.cardBorderColor,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (esCualquiera)
              Icon(
                Icons.people_outline_rounded,
                size: 16,
                color: isSelected
                    ? AppTheme.secondaryAccent
                    : AppTheme.textSecondary,
              )
            else ...[
              UserAvatar(
                avatarData: avatarData ?? const AvatarData.initials(),
                username: nombre,
                size: 18,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              nombre,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppTheme.secondaryAccent
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtiquetasSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildEtiquetaChip(
            nombre: 'Sin etiqueta',
            icono: Icons.label_off_outlined,
            color: AppTheme.textSecondary,
            isSelected: _etiquetaSeleccionada == null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _etiquetaSeleccionada = null);
            },
          ),
          const SizedBox(width: 8),
          ...EtiquetaTarea.etiquetasPredeterminadas.map((etiqueta) {
            final isSelected = _etiquetaSeleccionada?.toLowerCase() ==
                etiqueta.nombre.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildEtiquetaChip(
                nombre: etiqueta.nombre,
                icono: etiqueta.icono,
                color: etiqueta.color,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _etiquetaSeleccionada =
                        isSelected ? null : etiqueta.nombre;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEtiquetaChip({
    required String nombre,
    required IconData icono,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorderColor,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 14,
              color: isSelected ? color : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              nombre,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseProjectColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryLiquid;
    }
  }

  IconData _getProjectIcon(String iconoKey) {
    switch (iconoKey) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'build':
        return Icons.build_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'folder':
      default:
        return Icons.folder_rounded;
    }
  }

  Widget _buildProyectoSelector() {
    final proyectos = widget.controller.proyectos;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildProyectoChip(
            nombre: 'Sin proyecto',
            icono: Icons.inbox_rounded,
            color: AppTheme.textSecondary,
            isSelected: _proyectoSeleccionadoId == null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _proyectoSeleccionadoId = null);
            },
          ),
          const SizedBox(width: 8),
          ...proyectos.map((p) {
            final isSelected = _proyectoSeleccionadoId == p.id;
            final pColor = _parseProjectColor(p.colorHex);
            final pIcon = _getProjectIcon(p.icono);
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildProyectoChip(
                nombre: p.nombre,
                icono: pIcon,
                color: pColor,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _proyectoSeleccionadoId = isSelected ? null : p.id;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProyectoChip({
    required String nombre,
    required IconData icono,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorderColor,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 14,
              color: isSelected ? color : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              nombre,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


