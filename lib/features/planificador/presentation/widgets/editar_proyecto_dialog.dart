import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/models/proyecto_model.dart';
import '../controllers/planificador_controller.dart';

/// Modal bottom sheet para editar y eliminar proyectos del Planificador.
class EditarProyectoDialog extends StatefulWidget {
  final ProyectoModel proyecto;
  final PlanificadorController controller;

  const EditarProyectoDialog({
    super.key,
    required this.proyecto,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required ProyectoModel proyecto,
    required PlanificadorController controller,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditarProyectoDialog(
        proyecto: proyecto,
        controller: controller,
      ),
    );
  }

  @override
  State<EditarProyectoDialog> createState() => _EditarProyectoDialogState();
}

class _EditarProyectoDialogState extends State<EditarProyectoDialog> {
  late final TextEditingController _nombreController;
  late final TextEditingController _descController;
  late String _colorHexSeleccionado;
  late String _iconoSeleccionado;
  bool _isSaving = false;
  bool _isDeleting = false;

  static const List<String> _coloresDisponibles = [
    '#6366F1', // Indigo
    '#10B981', // Esmeralda
    '#F59E0B', // Ambar
    '#EF4444', // Coral / Rojo
    '#8B5CF6', // Violeta
    '#EC4899', // Rosa
    '#06B6D4', // Cian
    '#3B82F6', // Azul
  ];

  static const List<Map<String, dynamic>> _iconosDisponibles = [
    {'id': 'folder', 'icon': Icons.folder_rounded, 'nombre': 'Carpeta'},
    {'id': 'home', 'icon': Icons.home_rounded, 'nombre': 'Hogar'},
    {'id': 'work', 'icon': Icons.work_rounded, 'nombre': 'Trabajo'},
    {'id': 'shopping', 'icon': Icons.shopping_bag_rounded, 'nombre': 'Compras'},
    {'id': 'star', 'icon': Icons.star_rounded, 'nombre': 'Destacado'},
    {'id': 'build', 'icon': Icons.build_rounded, 'nombre': 'Reformas'},
    {'id': 'favorite', 'icon': Icons.favorite_rounded, 'nombre': 'Personal'},
    {'id': 'fitness', 'icon': Icons.fitness_center_rounded, 'nombre': 'Salud'},
    {'id': 'flight', 'icon': Icons.flight_rounded, 'nombre': 'Viajes'},
  ];

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.proyecto.nombre);
    _descController =
        TextEditingController(text: widget.proyecto.descripcion ?? '');
    _colorHexSeleccionado = widget.proyecto.colorHex;
    _iconoSeleccionado = widget.proyecto.icono;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryLiquid;
    }
  }

  IconData _getIconData(String iconoKey) {
    final item = _iconosDisponibles.firstWhere(
      (e) => e['id'] == iconoKey,
      orElse: () => {'icon': Icons.folder_rounded},
    );
    return item['icon'] as IconData;
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre del proyecto no puede estar vacío'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final actualizado = widget.proyecto.copyWith(
        nombre: nombre,
        descripcion:
            _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        colorHex: _colorHexSeleccionado,
        icono: _iconoSeleccionado,
        updatedAt: DateTime.now(),
      );

      await widget.controller.actualizarProyecto(actualizado);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Proyecto "${actualizado.nombre}" actualizado'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
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
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¿Eliminar proyecto?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${widget.proyecto.nombre}"?\n\n'
          'Las tareas asociadas NO se eliminarán; se moverán a la sección de "Tareas sueltas".',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isDeleting = true);
    HapticFeedback.heavyImpact();

    try {
      await widget.controller.eliminarProyecto(widget.proyecto.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proyecto "${widget.proyecto.nombre}" eliminado'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar proyecto: $e'),
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
    final colorActual = _parseColor(_colorHexSeleccionado);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: colorActual.withValues(alpha: 0.4),
            width: 1.5,
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

            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorActual.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getIconData(_iconoSeleccionado),
                        color: colorActual,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Editar Proyecto',
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
            const SizedBox(height: 16),

            // Nombre del proyecto
            TextField(
              controller: _nombreController,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Nombre del proyecto',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
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
                    color: colorActual,
                    width: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Descripción
            TextField(
              controller: _descController,
              maxLines: 2,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Descripción u objetivo (opcional)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.darkBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                    color: colorActual,
                    width: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selector de Color
            Text(
              'Color del Proyecto',
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
                children: _coloresDisponibles.map((hex) {
                  final c = _parseColor(hex);
                  final isSelected =
                      _colorHexSeleccionado.toUpperCase() == hex.toUpperCase();
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _colorHexSeleccionado = hex);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.4,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Selector de Icono
            Text(
              'Icono del Proyecto',
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
                children: _iconosDisponibles.map((item) {
                  final id = item['id'] as String;
                  final icon = item['icon'] as IconData;
                  final isSelected = _iconoSeleccionado == id;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _iconoSeleccionado = id);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorActual.withValues(alpha: 0.22)
                            : AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? colorActual
                              : AppTheme.cardBorderColor,
                          width: isSelected ? 1.4 : 0.8,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? colorActual : AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 22),

            // Botón Guardar
            AppButton(
              text: _isSaving ? 'Guardando...' : 'Guardar Cambios',
              icon: Icons.check_circle_rounded,
              gradient: AppTheme.actionGradient,
              isLoading: _isSaving,
              onPressed: _isSaving || _isDeleting ? null : _guardar,
            ),
            const SizedBox(height: 12),

            // Botón Eliminar
            OutlinedButton.icon(
              onPressed: _isSaving || _isDeleting ? null : _confirmarYEliminar,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                  width: 1,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                _isDeleting ? 'Eliminando...' : 'Eliminar Proyecto',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
