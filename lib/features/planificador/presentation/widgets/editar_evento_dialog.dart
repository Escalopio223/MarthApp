import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/evento_model.dart';
import '../controllers/planificador_controller.dart';
import 'checklist_editor_section.dart';

/// Modal bottom sheet para editar y eliminar eventos del Planificador:
/// - Permite editar título y fecha del evento
/// - Permite gestionar su lista de subtareas / checklist (ej. "Coger cartilla", "Preguntar síntomas")
/// - Permite eliminar el evento definitivamente con confirmación
class EditarEventoDialog extends StatefulWidget {
  final EventoModel evento;
  final PlanificadorController controller;

  const EditarEventoDialog({
    super.key,
    required this.evento,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required EventoModel evento,
    required PlanificadorController controller,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditarEventoDialog(
        evento: evento,
        controller: controller,
      ),
    );
  }

  @override
  State<EditarEventoDialog> createState() => _EditarEventoDialogState();
}

class _EditarEventoDialogState extends State<EditarEventoDialog> {
  late final TextEditingController _tituloController;
  late final TextEditingController _descController;
  late final TextEditingController _personaController;
  late final TextEditingController _ideasController;
  late String _tipo;
  late DateTime _fechaInicio;
  late List<ChecklistItemModel> _checklist;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.evento.titulo);
    _descController =
        TextEditingController(text: widget.evento.descripcion ?? '');
    _personaController =
        TextEditingController(text: widget.evento.personaCumpleanos ?? '');
    _ideasController =
        TextEditingController(text: widget.evento.ideasRegalo ?? '');
    _tipo = widget.evento.tipo;
    _fechaInicio = widget.evento.fechaInicio;
    _checklist = List<ChecklistItemModel>.from(widget.evento.checklist);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descController.dispose();
    _personaController.dispose();
    _ideasController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryLiquid,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _fechaInicio.hour,
          _fechaInicio.minute,
        );
      });
    }
  }

  Future<void> _guardarCambios() async {
    final nuevoTitulo = _tituloController.text.trim();
    if (nuevoTitulo.isEmpty) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final eventoActualizado = widget.evento.copyWith(
        titulo: nuevoTitulo,
        tipo: _tipo,
        fechaInicio: _fechaInicio,
        descripcion: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        personaCumpleanos: _tipo == 'cumpleanos'
            ? _personaController.text.trim()
            : null,
        ideasRegalo: _tipo == 'cumpleanos'
            ? _ideasController.text.trim()
            : null,
        checklist: _checklist,
      );

      await widget.controller.actualizarEvento(eventoActualizado);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento actualizado correctamente'),
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
            content: Text('Error al actualizar evento: $e'),
            backgroundColor: AppTheme.accentCoral,
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
          '¿Eliminar evento?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${widget.evento.titulo}"? Esta acción no se puede deshacer.',
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

    if (confirmar != true) return;

    setState(() => _isDeleting = true);
    HapticFeedback.heavyImpact();

    try {
      await widget.controller.eliminarEvento(widget.evento.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento eliminado'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar evento: $e'),
            backgroundColor: AppTheme.accentCoral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final esCumple = _tipo == 'cumpleanos';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: (esCumple ? AppTheme.accentCoral : AppTheme.secondaryAccent)
                .withValues(alpha: 0.4),
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
            // Tirador superior
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

            // Cabecera: Título y botón de papelera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (esCumple
                                ? AppTheme.accentCoral
                                : AppTheme.secondaryAccent)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        esCumple ? Icons.cake_rounded : Icons.event_note_rounded,
                        color: esCumple
                            ? AppTheme.accentCoral
                            : AppTheme.secondaryAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      esCumple ? 'Editar Cumpleaños' : 'Editar Evento',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 22),
                  color: AppTheme.accentCoral,
                  tooltip: 'Eliminar evento',
                  onPressed:
                      (_isSaving || _isDeleting) ? null : _confirmarYEliminar,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Campo de Título
            TextField(
              controller: _tituloController,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Título del evento',
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                filled: true,
                fillColor: AppTheme.darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Selector de fecha
            InkWell(
              onTap: _seleccionarFecha,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppTheme.secondaryAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Fecha: ${_fechaInicio.day}/${_fechaInicio.month}/${_fechaInicio.year}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Cambiar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryLiquid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (esCumple) ...[
              TextField(
                controller: _personaController,
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre de la persona homenajeada',
                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                controller: _ideasController,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Ideas de regalo',
                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              TextField(
                controller: _descController,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Descripción o notas...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // SECCIÓN CHECKLIST DEL EVENTO
            ChecklistEditorSection(
              items: _checklist,
              title: 'Subtareas',
              hintText: 'Añadir elemento (ej. Coger cartilla)...',
              onChanged: (nuevosItems) {
                setState(() => _checklist = nuevosItems);
              },
            ),
            const SizedBox(height: 20),

            // Botón Guardar Cambios
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (_isSaving || _isDeleting) ? null : _guardarCambios,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLiquid,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Guardar Cambios',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
