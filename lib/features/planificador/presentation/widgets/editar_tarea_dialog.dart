import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/comentario_tarea_model.dart';
import '../../domain/models/etiqueta_tarea.dart';
import '../../domain/models/recordatorio_tarea_model.dart';
import '../../domain/models/tarea_model.dart';
import '../controllers/planificador_controller.dart';
import 'checklist_editor_section.dart';
import 'recordatorios_selector_widget.dart';

/// Modal bottom sheet para editar y eliminar tareas del Planificador:
/// - Permite renombrar la tarea (ej: cambiar "fregar platos")
/// - Permite asignar o cambiar su etiqueta / categoría visual
/// - Permite cambiar a Hoy / Mañana / Sin fecha
/// - Permite gestionar su lista de subtareas / checklist
/// - Permite reasignar el conviviente responsable
/// - Permite eliminar la tarea definitivamente con confirmación
class EditarTareaDialog extends StatefulWidget {
  final TareaModel tarea;
  final PlanificadorController controller;
  final List<EnvironmentMemberModel> miembros;
  final String? usuarioActualId;

  const EditarTareaDialog({
    super.key,
    required this.tarea,
    required this.controller,
    this.miembros = const [],
    this.usuarioActualId,
  });

  static Future<void> show(
    BuildContext context, {
    required TareaModel tarea,
    required PlanificadorController controller,
    List<EnvironmentMemberModel> miembros = const [],
    String? usuarioActualId,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditarTareaDialog(
        tarea: tarea,
        controller: controller,
        miembros: miembros,
        usuarioActualId: usuarioActualId,
      ),
    );
  }

  @override
  State<EditarTareaDialog> createState() => _EditarTareaDialogState();
}

enum _OpcionFecha { hoy, manana, sinFecha, otra }

class _EditarTareaDialogState extends State<EditarTareaDialog> {
  late final TextEditingController _tituloController;
  final TextEditingController _comentarioController = TextEditingController();
  late _OpcionFecha _opcionFecha;
  DateTime? _fechaPersonalizada;
  String? _asignadoAId;
  String? _etiquetaSeleccionada;
  late int _tiempoMinutos;
  late List<ChecklistItemModel> _checklist;
  late List<ComentarioTareaModel> _comentarios;
  List<RecordatorioTareaModel> _recordatorios = [];
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isAddingComment = false;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.tarea.titulo);
    _asignadoAId = widget.tarea.asignadoA;
    _etiquetaSeleccionada = widget.tarea.etiqueta;
    _tiempoMinutos = widget.tarea.tiempoEstimadoMinutos;
    _checklist = List<ChecklistItemModel>.from(widget.tarea.checklist);
    _comentarios = List<ComentarioTareaModel>.from(widget.tarea.comentarios);
    _recordatorios = List<RecordatorioTareaModel>.from(widget.tarea.recordatorios);
    _determinarOpcionFechaInicial();

    // Cargar recordatorios actualizados desde BD por si no venían en la tarea
    if (_recordatorios.isEmpty) {
      widget.controller.obtenerRecordatoriosTarea(widget.tarea.id).then((recs) {
        if (mounted && recs.isNotEmpty && _recordatorios.isEmpty) {
          setState(() => _recordatorios = recs);
        }
      });
    }
  }

  void _determinarOpcionFechaInicial() {
    final limite = widget.tarea.fechaLimite;
    if (limite == null) {
      _opcionFecha = _OpcionFecha.sinFecha;
      return;
    }

    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final manana = hoy.add(const Duration(days: 1));
    final fechaTarea = DateTime(limite.year, limite.month, limite.day);

    if (fechaTarea.isAtSameMomentAs(hoy)) {
      _opcionFecha = _OpcionFecha.hoy;
    } else if (fechaTarea.isAtSameMomentAs(manana)) {
      _opcionFecha = _OpcionFecha.manana;
    } else {
      _opcionFecha = _OpcionFecha.otra;
      _fechaPersonalizada = limite;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  DateTime? get _calcularNuevaFechaLimite {
    final now = DateTime.now();
    switch (_opcionFecha) {
      case _OpcionFecha.hoy:
        return DateTime(now.year, now.month, now.day, 12, 0);
      case _OpcionFecha.manana:
        final manana = now.add(const Duration(days: 1));
        return DateTime(manana.year, manana.month, manana.day, 12, 0);
      case _OpcionFecha.sinFecha:
        return null;
      case _OpcionFecha.otra:
        if (_fechaPersonalizada != null) {
          final d = _fechaPersonalizada!;
          return DateTime(d.year, d.month, d.day, 12, 0);
        }
        return null;
    }
  }

  Future<void> _guardarCambios() async {
    final nuevoTitulo = _tituloController.text.trim();
    if (nuevoTitulo.isEmpty) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final tareaActualizada = widget.tarea.copyWith(
        titulo: nuevoTitulo,
        descripcion: _etiquetaSeleccionada,
        clearDescripcion: _etiquetaSeleccionada == null,
        fechaLimite: _calcularNuevaFechaLimite,
        clearFechaLimite: _calcularNuevaFechaLimite == null,
        asignadoA: _asignadoAId,
        clearAsignadoA: _asignadoAId == null,
        tiempoEstimadoMinutos: _tiempoMinutos,
        checklist: _checklist,
        comentarios: _comentarios,
        recordatorios: _recordatorios,
        updatedAt: DateTime.now(),
      );

      await widget.controller.actualizarTarea(tareaActualizada);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarea actualizada correctamente'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: AppTheme.accentCoral,
          ),
        );
      }
    }
  }

  Future<void> _enviarComentario() async {
    final texto = _comentarioController.text.trim();
    if (texto.isEmpty || _isAddingComment) return;

    setState(() => _isAddingComment = true);
    HapticFeedback.lightImpact();

    final currentUserId = widget.usuarioActualId ??
        widget.controller.entornoId ??
        'usuario';

    String autorNombre = 'Yo';
    if (widget.miembros.isNotEmpty) {
      final miembro = widget.miembros.firstWhere(
        (m) => m.userId == widget.usuarioActualId,
        orElse: () => widget.miembros.first,
      );
      autorNombre = miembro.username;
    }

    try {
      await widget.controller.agregarComentario(
        tareaId: widget.tarea.id,
        texto: texto,
        autorId: currentUserId,
        autorNombre: autorNombre,
      );

      final nuevoComentario = ComentarioTareaModel(
        id: 'com_${DateTime.now().millisecondsSinceEpoch}',
        autorId: currentUserId,
        autorNombre: autorNombre,
        texto: texto,
        createdAt: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _comentarios.add(nuevoComentario);
          _comentarioController.clear();
          _isAddingComment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al añadir comentario: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _confirmarYEliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Eliminar tarea?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${widget.tarea.titulo}"? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _isDeleting = true);
    HapticFeedback.heavyImpact();

    try {
      await widget.controller.eliminarTarea(widget.tarea.id);
      if (mounted) {
        Navigator.pop(context); // Cierra bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tarea "${widget.tarea.titulo}" eliminada'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.surfaceDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: AppTheme.accentCoral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9,
      ),
      child: Container(
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
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tirador decorativo
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

          // Título y acciones rápidas superiores (Eliminar y Cerrar)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: AppTheme.primaryLiquid,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Editar Tarea',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                    color: AppTheme.accentCoral,
                    tooltip: 'Eliminar tarea',
                    onPressed: _isDeleting || _isSaving ? null : _confirmarYEliminar,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppTheme.textSecondary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Banner del Responsable con Logo y Nombre
          _buildResponsableBanner(),
          const SizedBox(height: 14),

          // Campo de texto para modificar nombre
          TextField(
            controller: _tituloController,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Nombre de la tarea',
              labelStyle: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppTheme.darkBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppTheme.primaryLiquid,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Selector de etiqueta / categoría
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

          // Selector de fecha
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
                icon: Icons.today_rounded,
                opcion: _OpcionFecha.hoy,
              ),
              const SizedBox(width: 8),
              _buildFechaChip(
                label: 'Mañana',
                icon: Icons.wb_sunny_outlined,
                opcion: _OpcionFecha.manana,
              ),
              const SizedBox(width: 8),
              _buildFechaChip(
                label: 'Sin fecha',
                icon: Icons.inbox_rounded,
                opcion: _OpcionFecha.sinFecha,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector de tiempo
          Text(
            'Tiempo',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildTiempoSelector(),
          const SizedBox(height: 14),

          // Selector de responsable
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

          // Selector y editor de subtareas
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
              fechaLimite: _calcularNuevaFechaLimite,
              onChanged: (recs) {
                setState(() => _recordatorios = List.from(recs));
              },
            ),
            const SizedBox(height: 18),

            // Sección de Comentarios
            _buildComentariosSection(),
            const SizedBox(height: 20),

            // Botón Guardar Cambios
            AppButton(
              text: _isSaving ? 'Guardando...' : 'Guardar Cambios',
              icon: Icons.check_circle_rounded,
              gradient: AppTheme.actionGradient,
              isLoading: _isSaving,
              onPressed: _guardarCambios,
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildResponsableBanner() {
    final EnvironmentMemberModel? responsable = widget.miembros
        .cast<EnvironmentMemberModel?>()
        .firstWhere((m) => m?.userId == _asignadoAId, orElse: () => null);

    final tieneAsignado = _asignadoAId != null;
    final esYo = _asignadoAId != null && _asignadoAId == widget.usuarioActualId;
    final nombre = tieneAsignado
        ? (responsable?.username ??
            'Usuario ${_asignadoAId!.length >= 4 ? _asignadoAId!.substring(0, 4) : _asignadoAId!}')
        : 'Sin asignar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tieneAsignado
              ? AppTheme.primaryLiquid.withValues(alpha: 0.45)
              : AppTheme.cardBorderColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: tieneAsignado
                    ? AppTheme.primaryLiquid
                    : AppTheme.textSecondary.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: tieneAsignado
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryLiquid.withValues(alpha: 0.2),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: tieneAsignado && responsable != null
                ? UserAvatar(
                    avatarData: responsable.avatarData,
                    username: responsable.username,
                    size: 34,
                  )
                : CircleAvatar(
                    radius: 17,
                    backgroundColor: AppTheme.surfaceDark,
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RESPONSABLE DE LA TAREA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tieneAsignado
                      ? (esYo ? '$nombre (Tú)' : nombre)
                      : 'Sin asignar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: tieneAsignado
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tieneAsignado
                  ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                  : AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tieneAsignado
                    ? AppTheme.accentEmerald.withValues(alpha: 0.4)
                    : AppTheme.cardBorderColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              tieneAsignado ? 'Asignada' : 'Pendiente',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: tieneAsignado
                    ? AppTheme.accentEmerald
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFechaChip({
    required String label,
    required IconData icon,
    required _OpcionFecha opcion,
  }) {
    final isSelected = _opcionFecha == opcion;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _opcionFecha = opcion);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryLiquid.withValues(alpha: 0.2)
                : AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryLiquid : AppTheme.cardBorderColor,
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
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
    final isSelected = _asignadoAId == userId;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _asignadoAId = userId);
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
          // Opción: Sin etiqueta
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
            width: isSelected ? 1.5 : 0.8,
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

  Widget _buildTiempoSelector() {
    final opciones = [
      (label: 'Sin tiempo', minutos: 0),
      (label: '15 min', minutos: 15),
      (label: '30 min', minutos: 30),
      (label: '45 min', minutos: 45),
      (label: '1 hora', minutos: 60),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: opciones.map((opcion) {
          final isSelected = _tiempoMinutos == opcion.minutos;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _tiempoMinutos = opcion.minutos);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryLiquid.withValues(alpha: 0.18)
                      : AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryLiquid
                        : AppTheme.cardBorderColor,
                    width: isSelected ? 1.4 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opcion.minutos == 0
                          ? Icons.timer_off_outlined
                          : Icons.access_time_rounded,
                      size: 13,
                      color: isSelected
                          ? AppTheme.primaryLiquid
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      opcion.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primaryLiquid
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComentariosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'COMENTARIOS (${_comentarios.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Lista de comentarios si los hay
        if (_comentarios.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.cardBorderColor.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comentarios.length,
              separatorBuilder: (_, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, color: Colors.white10),
              ),
              itemBuilder: (context, index) {
                final com = _comentarios[index];
                final esYo = com.autorId == widget.usuarioActualId;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: esYo
                          ? AppTheme.primaryLiquid.withValues(alpha: 0.25)
                          : AppTheme.secondaryAccent.withValues(alpha: 0.25),
                      child: Text(
                        com.autorNombre.isNotEmpty
                            ? com.autorNombre[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: esYo
                              ? AppTheme.primaryLiquid
                              : AppTheme.secondaryAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                esYo
                                    ? 'Tú (${com.autorNombre})'
                                    : com.autorNombre,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${com.createdAt.day}/${com.createdAt.month} ${com.createdAt.hour.toString().padLeft(2, '0')}:${com.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            com.texto,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Input para nuevo comentario
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _comentarioController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Escribe un comentario...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _enviarComentario(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isAddingComment ? null : _enviarComentario,
              icon: _isAddingComment
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              color: AppTheme.primaryLiquid,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
