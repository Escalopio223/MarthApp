import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../controllers/auth_controller.dart';

/// Modal bloqueante de barrera para introducir y confirmar la nueva contraseña tras el enlace de recuperación
class UpdatePasswordModal extends StatefulWidget {
  final AuthController authController;
  final VoidCallback onPasswordUpdated;
  final bool isDismissible;

  const UpdatePasswordModal({
    super.key,
    required this.authController,
    required this.onPasswordUpdated,
    this.isDismissible = true,
  });

  static Future<void> show(
    BuildContext context, {
    required AuthController authController,
    required VoidCallback onPasswordUpdated,
    bool isDismissible = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (_) => UpdatePasswordModal(
        authController: authController,
        onPasswordUpdated: onPasswordUpdated,
        isDismissible: isDismissible,
      ),
    );
  }

  @override
  State<UpdatePasswordModal> createState() => _UpdatePasswordModalState();
}

class _UpdatePasswordModalState extends State<UpdatePasswordModal> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSuccess = false;
  String? _localError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _localError = null);
    final ok = await widget.authController.updatePassword(_passwordController.text);

    if (ok && mounted) {
      setState(() => _isSuccess = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          widget.onPasswordUpdated();
        }
      });
    } else if (mounted) {
      setState(() {
        _localError = widget.authController.errorMessage ??
            'Error al actualizar la contraseña. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.authController.isLoading;

    return PopScope(
      canPop: widget.isDismissible,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GlassCard(
                blur: 24.0,
                borderRadius: 24.0,
                padding: const EdgeInsets.all(28.0),
                child: _isSuccess ? _buildSuccessView() : _buildFormView(isLoading),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LiquidTheme.accentEmerald.withValues(alpha: 0.2),
            border: Border.all(color: LiquidTheme.accentEmerald, width: 2),
          ),
          child: Icon(
            Icons.check_rounded,
            color: LiquidTheme.accentEmerald,
            size: 38,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '¡Contraseña Actualizada!',
          style: TextStyle(
            color: LiquidTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tu contraseña ha sido modificada con éxito. Ya puedes seguir usando MarthApp.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LiquidTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        if (widget.isDismissible) ...[
          const SizedBox(height: 20),
          LiquidButton(
            text: 'Continuar',
            gradient: LiquidTheme.liquidEmeraldGradient,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              widget.onPasswordUpdated();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFormView(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiquidTheme.primaryLiquid.withValues(alpha: 0.18),
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  color: LiquidTheme.primaryLiquid,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actualizar Contraseña',
                      style: TextStyle(
                        color: LiquidTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Establece tu nueva contraseña segura',
                      style: TextStyle(
                        color: LiquidTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isDismissible)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: LiquidTheme.textSecondary,
                    size: 22,
                  ),
                  tooltip: 'Cerrar',
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                ),
            ],
          ),
          const SizedBox(height: 22),

          // Campo Nueva Contraseña
          Text(
            'Nueva Contraseña',
            style: TextStyle(
              color: LiquidTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: LiquidTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Mínimo 6 caracteres',
              prefixIcon: Icon(Icons.lock_outline_rounded, color: LiquidTheme.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: LiquidTheme.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Introduce la nueva contraseña';
              }
              if (value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Campo Confirmar Contraseña
          Text(
            'Confirmar Nueva Contraseña',
            style: TextStyle(
              color: LiquidTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: TextStyle(color: LiquidTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Repite la nueva contraseña',
              prefixIcon: Icon(Icons.lock_outline_rounded, color: LiquidTheme.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: LiquidTheme.textSecondary,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirma tu nueva contraseña';
              }
              if (value != _passwordController.text) {
                return 'Las contraseñas no coinciden';
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

          LiquidButton(
            text: 'Confirmar y Guardar',
            isLoading: isLoading,
            icon: Icons.check_rounded,
            onPressed: isLoading ? null : _handleUpdate,
          ),
        ],
      ),
    );
  }
}
