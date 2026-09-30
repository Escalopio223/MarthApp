import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/models/saved_weekly_menu_model.dart';
import '../controllers/weekly_menu_planner_controller.dart';
import 'load_menu_preset_modal.dart';
import 'saved_menu_editor_modal.dart';

/// Vista para listar, crear, previsualizar, renombrar y eliminar menús semanales guardados
class SavedMenusLibraryView extends StatefulWidget {
  final WeeklyMenuPlannerController controller;

  const SavedMenusLibraryView({
    super.key,
    required this.controller,
  });

  @override
  State<SavedMenusLibraryView> createState() => _SavedMenusLibraryViewState();
}

class _SavedMenusLibraryViewState extends State<SavedMenusLibraryView> {
  String? _expandedMenuId;

  final List<String> _dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  Future<void> _showRenameDialog(SavedWeeklyMenuModel menu) async {
    final nameController = TextEditingController(text: menu.name);
    final descController = TextEditingController(text: menu.description ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.cardBorderColor, width: 1),
        ),
        title: Text(
          'Renombrar Menú',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nombre del menú',
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 2,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Descripción u objetivo (opcional)',
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLiquid,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await widget.controller.renamePreset(
          menu.id,
          nameController.text.trim(),
          descController.text.trim().isNotEmpty ? descController.text.trim() : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentEmerald,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text('Menú renombrado con éxito.', style: TextStyle(color: Colors.white)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentCoral,
              content: Text('Error al renombrar: $e', style: const TextStyle(color: Colors.white)),
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteConfirmDialog(SavedWeeklyMenuModel menu) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.cardBorderColor, width: 1),
        ),
        title: Text(
          '¿Eliminar plantilla?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 17),
        ),
        content: Text(
          'Se eliminará "${menu.name}". El calendario activo de las semanas donde ya fue aplicado no se verá afectado.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.controller.deletePreset(menu.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentEmerald,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text('Menú eliminado de la biblioteca.', style: TextStyle(color: Colors.white)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentCoral,
              content: Text('Error al eliminar: $e', style: const TextStyle(color: Colors.white)),
            ),
          );
        }
      }
    }
  }

  Future<void> _showSaveActiveWeekDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.cardBorderColor, width: 1),
        ),
        title: Text(
          'Guardar Semana Activa como Plantilla',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Convierte las comidas de la semana que estás viendo en una plantilla reutilizable para el futuro.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nombre de la plantilla *',
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                hintText: 'Ej. Menú estándar de verano',
                hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              maxLines: 2,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Descripción u observaciones (opcional)',
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLiquid,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Crear Plantilla'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final created = await widget.controller.saveCurrentWeekAsPreset(
          name: nameController.text.trim(),
          description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentEmerald,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                'Plantilla "${created.name}" guardada con éxito.',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentCoral,
              content: Text('Error al guardar semana: $e', style: const TextStyle(color: Colors.white)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedMenus = widget.controller.savedMenus;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Banner Superior de Acciones Rápidas
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
            boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLiquid.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.bookmark_border_rounded, color: AppTheme.primaryLiquid, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plantillas Semanales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Reutiliza menús completos y cárgalos en cualquier semana activa',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLiquid,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Crear Menú',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => SavedMenuEditorModal.show(context, controller: widget.controller),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryLiquid,
                        side: BorderSide(color: AppTheme.primaryLiquid, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save_as_rounded, size: 18),
                      label: const Text(
                        'Guardar Semana',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showSaveActiveWeekDialog,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Título de sección
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Menús Guardados (${savedMenus.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Lista de presets
        if (savedMenus.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 44,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  'No tienes menús semanales en la biblioteca',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Crea una plantilla desde cero o guarda tu semana actual activa con el botón "Guardar Semana".',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Crear primer menú semanal',
                  icon: Icons.add_rounded,
                  height: 44,
                  onPressed: () => SavedMenuEditorModal.show(context, controller: widget.controller),
                ),
              ],
            ),
          )
        else
          ...savedMenus.map((menu) {
            final isExpanded = _expandedMenuId == menu.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
                boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    // Cabecera del Menú
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.restaurant_menu_rounded,
                              size: 22,
                              color: AppTheme.primaryLiquid,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  menu.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (menu.description != null && menu.description!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    menu.description!,
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${menu.slots.length} comidas planificadas (de 35)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
                            color: AppTheme.surfaceDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                            ),
                            onSelected: (val) {
                              if (val == 'rename') {
                                _showRenameDialog(menu);
                              } else if (val == 'delete') {
                                _showDeleteConfirmDialog(menu);
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_rounded, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Renombrar', style: TextStyle(color: AppTheme.textPrimary)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.accentCoral),
                                    const SizedBox(width: 8),
                                    const Text('Eliminar', style: TextStyle(color: AppTheme.accentCoral)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Barra de Acciones: Cargar, Editar, Ver desglose
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryLiquid,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.download_rounded, size: 15),
                              label: const Text(
                                'Cargar en semana',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => LoadMenuPresetModal.show(context, controller: widget.controller),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Editar', style: TextStyle(fontSize: 11)),
                            onPressed: () => SavedMenuEditorModal.show(
                              context,
                              controller: widget.controller,
                              initialMenu: menu,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: Icon(
                              isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                            tooltip: isExpanded ? 'Ocultar desglose' : 'Ver días',
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _expandedMenuId = isExpanded ? null : menu.id;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Desglose expandible de días
                    if (isExpanded) ...[
                      Divider(height: 1, color: AppTheme.cardBorderColor),
                      Container(
                        color: Colors.black.withValues(alpha: 0.18),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(7, (i) {
                            final dayNum = i + 1;
                            final daySlots = menu.slots.where((s) => s.dayOfWeek == dayNum).toList();
                            final dayName = _dayNames[i];

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      dayName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: daySlots.isEmpty
                                        ? Text(
                                            'Sin comidas asignadas',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                            ),
                                          )
                                        : Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: daySlots.map((s) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryLiquid.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: AppTheme.primaryLiquid.withValues(alpha: 0.3),
                                                    width: 0.6,
                                                  ),
                                                ),
                                                child: Text(
                                                  '${s.mealType.displayName}: ${s.displayTitle}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
