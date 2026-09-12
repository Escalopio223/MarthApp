import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../controllers/environment_controller.dart';

/// Modal interactivo para crear un nuevo entorno compartido de trabajo
class CreateEnvironmentModal extends StatefulWidget {
  final EnvironmentController environmentController;

  const CreateEnvironmentModal({
    super.key,
    required this.environmentController,
  });

  static Future<void> show(
    BuildContext context, {
    required EnvironmentController environmentController,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CreateEnvironmentModal(
        environmentController: environmentController,
      ),
    );
  }

  @override
  State<CreateEnvironmentModal> createState() => _CreateEnvironmentModalState();
}

class _CreateEnvironmentModalState extends State<CreateEnvironmentModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _localError = null);

    final success = await widget.environmentController.createEnvironment(
      _nameController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    } else if (mounted) {
      setState(() {
        _localError = widget.environmentController.errorMessage ??
            'Error al crear el entorno';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.environmentController.isActionLoading;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AppCard(
              borderRadius: 20.0,
              padding: const EdgeInsets.all(28.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryCyan.withValues(alpha: 0.18),
                          ),
                          child: Icon(
                            Icons.groups_rounded,
                            color: AppTheme.primaryCyan,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nuevo Entorno',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Crea un espacio para colaborar con amigos',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppTheme.textSecondary,
                            size: 22,
                          ),
                          tooltip: 'Cerrar',
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Campo: Nombre del Entorno
                    Text(
                      'Nombre del Entorno',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ej. Piso Compartido, Viaje Verano...',
                        prefixIcon: Icon(Icons.drive_file_rename_outline_rounded,
                            color: AppTheme.textSecondary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Introduce un nombre para el entorno';
                        }
                        if (value.trim().length < 3) {
                          return 'El nombre debe tener al menos 3 caracteres';
                        }
                        return null;
                      },
                    ),

                    if (_localError != null) ...[
                      const SizedBox(height: 14),
                      LiquidBanner(
                        message: _localError!,
                        type: BannerType.error,
                        onClose: () => setState(() => _localError = null),
                      ),
                    ],

                    const SizedBox(height: 24),

                    AppButton(
                      text: 'Crear Entorno',
                      isLoading: isLoading,
                      icon: Icons.check_rounded,
                      onPressed: isLoading ? null : _handleCreate,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
