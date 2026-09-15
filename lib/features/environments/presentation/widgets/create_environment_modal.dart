import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../domain/models/environment_model.dart';
import '../controllers/environment_controller.dart';

/// Modal interactivo para crear un nuevo entorno compartido de trabajo
/// Permite seleccionar un icono temático y una paleta de color para diferenciarlo fácilmente
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
      builder: (_) =>
          CreateEnvironmentModal(environmentController: environmentController),
    );
  }

  @override
  State<CreateEnvironmentModal> createState() => _CreateEnvironmentModalState();
}

class _CreateEnvironmentModalState extends State<CreateEnvironmentModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _localError;

  String _selectedIcon = 'groups';
  String _selectedColor = '#06B6D4';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _localError = null);

    final success = await widget.environmentController.createEnvironment(
      _nameController.text.trim(),
      icon: _selectedIcon,
      color: _selectedColor,
    );

    if (success && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    } else if (mounted) {
      setState(() {
        _localError =
            widget.environmentController.errorMessage ??
            'Error al crear el entorno';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.environmentController.isActionLoading;
    final activeColor = EnvironmentThemeHelper.resolveColor(_selectedColor);
    final activeIconData = EnvironmentThemeHelper.resolveIcon(_selectedIcon);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AppCard(
              borderRadius: 20.0,
              padding: const EdgeInsets.all(18.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header con botón de cerrar
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeColor.withValues(alpha: 0.18),
                            border: Border.all(
                              color: activeColor.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            activeIconData,
                            color: activeColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nuevo entorno',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Personaliza tu espacio colaborativo',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          tooltip: 'Cerrar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Previsualización en vivo del entorno
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: activeColor.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activeColor.withValues(alpha: 0.22),
                            ),
                            child: Icon(
                              activeIconData,
                              color: activeColor,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameController.text.trim().isEmpty
                                      ? 'Nombre de tu entorno'
                                      : _nameController.text.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _nameController.text.trim().isEmpty
                                        ? AppTheme.textSecondary
                                        : AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Propietario • Espacio compartido',
                                  style: TextStyle(
                                    color: activeColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Campo: Nombre del Entorno
                    Text(
                      'Nombre del Entorno',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        hintText: 'Ej. Piso Compartido, Cineclub, Gaming...',
                        prefixIcon: Icon(
                          Icons.drive_file_rename_outline_rounded,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
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
                    const SizedBox(height: 10),

                    // Selector de Color
                    Row(
                      children: [
                        Text(
                          'Color del Entorno',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: activeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: EnvironmentThemeHelper.availableColors.map((
                        hex,
                      ) {
                        final color = EnvironmentThemeHelper.resolveColor(hex);
                        final isSelected =
                            _selectedColor.toUpperCase() == hex.toUpperCase();
                        return GestureDetector(
                          key: ValueKey('color_option_$hex'),
                          onTap: () => setState(() => _selectedColor = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: isSelected ? 2.0 : 0,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Selector de Icono
                    Text(
                      'Icono del Entorno',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: EnvironmentThemeHelper.availableIcons.entries
                          .map((entry) {
                            final key = entry.key;
                            final icon = entry.value;
                            final isSelected = _selectedIcon == key;

                            return InkWell(
                              key: ValueKey('icon_option_$key'),
                              onTap: () => setState(() => _selectedIcon = key),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? activeColor.withValues(alpha: 0.22)
                                      : AppTheme.surfaceDark.withValues(
                                          alpha: 0.6,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? activeColor
                                        : AppTheme.glassBorderColor.withValues(
                                            alpha: 0.35,
                                          ),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    icon,
                                    size: 18,
                                    color: isSelected
                                        ? activeColor
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),

                    if (_localError != null) ...[
                      const SizedBox(height: 10),
                      LiquidBanner(
                        message: _localError!,
                        type: BannerType.error,
                        onClose: () => setState(() => _localError = null),
                      ),
                    ],

                    const SizedBox(height: 14),

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
