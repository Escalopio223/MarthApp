import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/utils/subtask_utils.dart';

/// Componente interactivo para la gestión y reordenamiento Drag & Drop de subtareas.
/// Permite añadir (con Enter o botón), editar, eliminar, marcar completadas y arrastrar
/// para reordenar deterministamente.
class SubtaskList extends StatefulWidget {
  final List<ChecklistItemModel> items;
  final ValueChanged<List<ChecklistItemModel>> onChanged;
  final bool isEditable;
  final String? emptyMessage;

  const SubtaskList({
    super.key,
    required this.items,
    required this.onChanged,
    this.isEditable = true,
    this.emptyMessage,
  });

  @override
  State<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends State<SubtaskList> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _handleAddSubtask() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    final updated = addSubtask(widget.items, text);
    widget.onChanged(updated);
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  void _handleRemoveSubtask(int index) {
    HapticFeedback.selectionClick();
    final updated = removeSubtaskAt(widget.items, index);
    widget.onChanged(updated);
  }

  void _handleToggleCompletion(int index) {
    HapticFeedback.selectionClick();
    final updated = toggleSubtaskCompletion(widget.items, index);
    widget.onChanged(updated);
  }

  void _handleReorder(int oldIndex, int newIndex) {
    HapticFeedback.mediumImpact();
    final updated = reorderSubtasks(widget.items, oldIndex, newIndex);
    widget.onChanged(updated);
  }

  Future<void> _handleEditSubtask(int index, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Editar subtarea',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Título de la subtarea',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: AppTheme.darkBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primaryLiquid, width: 1.2),
            ),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLiquid,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && result.trim() != currentTitle) {
      HapticFeedback.lightImpact();
      final updated = editSubtaskTitle(widget.items, index, result.trim());
      widget.onChanged(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = widget.items.where((i) => i.completado).length;
    final totalCount = widget.items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con contador y progreso
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 14,
                  color: AppTheme.primaryLiquid,
                ),
                const SizedBox(width: 6),
                Text(
                  'Subtareas / Checklist',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            if (totalCount > 0)
              Text(
                '$completedCount/$totalCount completadas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: completedCount == totalCount && totalCount > 0
                      ? AppTheme.accentEmerald
                      : AppTheme.secondaryLilac,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // 1. Input rápido para añadir nuevas subtareas
        _buildInputRow(),
        const SizedBox(height: 10),

        // 2. Estado de la lista (Vacía vs Reorderable Drag & Drop)
        if (widget.items.isEmpty)
          _buildEmptyState()
        else
          _buildReorderableList(),
      ],
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            focusNode: _inputFocusNode,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Añadir un paso o subtarea...',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                fontSize: 12.5,
              ),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.cardBorderColor,
                  width: 0.8,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryLiquid,
                  width: 1.4,
                ),
              ),
            ),
            onSubmitted: (_) => _handleAddSubtask(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_rounded, size: 28),
          color: AppTheme.primaryLiquid,
          tooltip: 'Añadir subtarea',
          onPressed: _handleAddSubtask,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final message = widget.emptyMessage ??
        'No hay subtareas añadidas. Divide esta tarea en pasos más sencillos para mayor claridad.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 22,
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: widget.items.length,
      // ignore: deprecated_member_use
      onReorder: _handleReorder,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return _buildSubtaskItemTile(item, index);
      },
    );
  }

  Widget _buildSubtaskItemTile(ChecklistItemModel item, int index) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.completado
              ? AppTheme.accentEmerald.withValues(alpha: 0.3)
              : AppTheme.cardBorderColor,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // 1. Drag Handle táctil claro
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 2. Checkbox visual e interactivo
          GestureDetector(
            onTap: () => _handleToggleCompletion(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: item.completado
                    ? AppTheme.accentEmerald
                    : Colors.transparent,
                border: Border.all(
                  color: item.completado
                      ? AppTheme.accentEmerald
                      : AppTheme.textSecondary.withValues(alpha: 0.6),
                  width: 1.4,
                ),
              ),
              child: item.completado
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // 3. Título de la subtarea con estilo tachado si está completada (clic para editar)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.isEditable ? () => _handleEditSubtask(index, item.titulo) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  item.titulo,
                  style: TextStyle(
                    fontSize: 13,
                    color: item.completado
                        ? AppTheme.textSecondary.withValues(alpha: 0.6)
                        : AppTheme.textPrimary,
                    decoration: item.completado
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),

          // 4. Botón de edición rápida
          if (widget.isEditable)
            GestureDetector(
              onTap: () => _handleEditSubtask(index, item.titulo),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),

          // 5. Botón de eliminación
          GestureDetector(
            onTap: () => _handleRemoveSubtask(index),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
