import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/checklist_item_model.dart';

/// Widget reutilizable y ágil para crear y editar listas de comprobación (subtareas)
/// tanto en Eventos como en Tareas.
class ChecklistEditorSection extends StatefulWidget {
  final List<ChecklistItemModel> items;
  final ValueChanged<List<ChecklistItemModel>> onChanged;
  final String hintText;
  final String title;

  const ChecklistEditorSection({
    super.key,
    required this.items,
    required this.onChanged,
    this.hintText = 'Añadir elemento (ej: Coger cartilla)...',
    this.title = 'Subtareas',
  });

  @override
  State<ChecklistEditorSection> createState() => _ChecklistEditorSectionState();
}

class _ChecklistEditorSectionState extends State<ChecklistEditorSection> {
  final TextEditingController _itemController = TextEditingController();
  final FocusNode _itemFocusNode = FocusNode();

  @override
  void dispose() {
    _itemController.dispose();
    _itemFocusNode.dispose();
    super.dispose();
  }

  void _agregarItem() {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    final newItem = ChecklistItemModel(
      id: 'chk_${DateTime.now().millisecondsSinceEpoch}_${widget.items.length}',
      titulo: text,
      completado: false,
    );

    final updated = List<ChecklistItemModel>.from(widget.items)..add(newItem);
    widget.onChanged(updated);
    _itemController.clear();
    // Mantener el foco para permitir escribir varios ítems rápidamente
    _itemFocusNode.requestFocus();
  }

  void _eliminarItem(int index) {
    HapticFeedback.selectionClick();
    final updated = List<ChecklistItemModel>.from(widget.items)..removeAt(index);
    widget.onChanged(updated);
  }

  void _toggleItem(int index) {
    HapticFeedback.selectionClick();
    final item = widget.items[index];
    final updated = List<ChecklistItemModel>.from(widget.items);
    updated[index] = item.copyWith(completado: !item.completado);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final completados = widget.items.where((i) => i.completado).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con título y contador
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppTheme.textSecondary,
              ),
            ),
            if (widget.items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$completados/${widget.items.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryLiquid,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Campo de entrada rápido para añadir items con Enter o botón '+'
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _itemController,
                  focusNode: _itemFocusNode,
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _agregarItem(),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _agregarItem,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.actionGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryLiquid.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Lista de elementos existentes
        if (widget.items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.cardBorderColor.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: AppTheme.cardBorderColor.withValues(alpha: 0.2),
                indent: 40,
              ),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      // Checkbox para marcar/desmarcar
                      GestureDetector(
                        onTap: () => _toggleItem(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: item.completado
                                ? AppTheme.accentEmerald
                                : Colors.transparent,
                            border: Border.all(
                              color: item.completado
                                  ? AppTheme.accentEmerald
                                  : AppTheme.textSecondary.withValues(alpha: 0.6),
                              width: 1.5,
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

                      // Texto del elemento
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _toggleItem(index),
                          child: Text(
                            item.titulo,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: item.completado
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                              color: item.completado
                                  ? AppTheme.textSecondary.withValues(alpha: 0.5)
                                  : AppTheme.textPrimary,
                              decoration: item.completado
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),

                      // Botón eliminar elemento
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: AppTheme.textSecondary.withValues(alpha: 0.6),
                        splashRadius: 16,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        onPressed: () => _eliminarItem(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
