import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/leisure_shared_list_model.dart';
import '../controllers/leisure_controller.dart';

/// Hoja interactiva para gestionar y explorar las listas compartidas y matches del entorno
class LeisureSharedListsSheet extends StatefulWidget {
  final LeisureController controller;

  const LeisureSharedListsSheet({
    super.key,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required LeisureController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeisureSharedListsSheet(controller: controller),
    );
  }

  @override
  State<LeisureSharedListsSheet> createState() =>
      _LeisureSharedListsSheetState();
}

class _LeisureSharedListsSheetState extends State<LeisureSharedListsSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateList() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      await widget.controller.createSharedList(
        title,
        _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
      );
      _titleController.clear();
      _descController.clear();
      if (mounted) {
        Navigator.pop(context); // Cierra diálogo
        setState(() => _isCreating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear lista: $e')),
        );
      }
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Nueva lista compartida',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Título de la lista (ej. Películas del finde)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Descripción opcional',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLiquid,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isCreating ? null : _handleCreateList,
              child: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersonal = widget.controller.isPersonalEnvironment;
    final sharedLists = widget.controller.sharedLists;
    final matches = widget.controller.environmentMatches;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.cardBorderColor, width: 1),
          ),
          child: Column(
            children: [
              // Barra de arrastre
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Título y botón cerrar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Listas del Entorno',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: AppTheme.textSecondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Contenido
              Expanded(
                child: isPersonal
                    ? _buildPersonalNotice()
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // Botón para crear nueva lista
                          AppButton(
                            text: 'Crear nueva lista compartida',
                            icon: Icons.add_circle_outline_rounded,
                            onPressed: _showCreateDialog,
                          ),
                          const SizedBox(height: 20),

                          // Sección Matches de Gustos
                          if (matches.isNotEmpty) ...[
                            Text(
                              'Coincidencias (Watch Party)',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...matches.map((match) {
                              return AppCard(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.favorite_rounded,
                                        color: Color(0xFFFF4081)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            match.title,
                                            style: TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${match.matchedUserIds.length} miembros coinciden',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // Listas Compartidas
                          Text(
                            'Listas Temáticas (${sharedLists.length})',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          if (sharedLists.isEmpty)
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  'Aún no hay listas compartidas en este entorno.\n¡Crea una para planear qué ver o jugar juntos!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13),
                                ),
                              ),
                            )
                          else
                            ...sharedLists.map((list) => _buildListItem(list)),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalNotice() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.group_work_outlined,
                  size: 36,
                  color: AppTheme.primaryLiquid,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Entorno Personal Activo',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Las listas compartidas y las coincidencias de gustos (Watch Party) requieren un entorno colaborativo.\n\nCambia de espacio desde el selector superior de la pantalla principal para conectar con amigos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(LeisureSharedListModel list) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.playlist_play_rounded,
                color: AppTheme.primaryLiquid),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (list.description != null && list.description!.isNotEmpty)
                  Text(
                    list.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${list.itemsCount} elemento(s)',
                  style: TextStyle(
                    color: AppTheme.primaryLiquid,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
