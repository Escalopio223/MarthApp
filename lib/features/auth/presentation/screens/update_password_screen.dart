import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../controllers/auth_controller.dart';

/// Pantalla dedicada para actualizar la contraseña tras capturar el evento de recuperación
class UpdatePasswordScreen extends StatefulWidget {
  final AuthController? controller;
  final VoidCallback onPasswordUpdated;

  const UpdatePasswordScreen({
    super.key,
    this.controller,
    required this.onPasswordUpdated,
  });

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  late final AuthController _authController;
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _authController = widget.controller ?? AuthController();
    _authController.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authController.removeListener(_onAuthChanged);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _authController.updatePassword(
      _passwordController.text,
    );

    if (success && mounted) {
      setState(() {
        _success = true;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          widget.onPasswordUpdated();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GlassCard(
                blur: 24.0,
                borderRadius: 28.0,
                padding: const EdgeInsets.all(32.0),
                child: _success ? _buildSuccessView() : _buildFormView(),
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LiquidTheme.liquidEmeraldGradient,
            boxShadow: [
              BoxShadow(
                color: LiquidTheme.accentEmerald.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          '¡Contraseña Actualizada!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: LiquidTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tu clave de acceso ha sido cambiada correctamente. Entrando a MarthApp...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LiquidTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(LiquidTheme.accentEmerald),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LiquidTheme.liquidPrimaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: LiquidTheme.primaryCyan.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.password_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Actualizar Contraseña',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: LiquidTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Introduce tu nueva contraseña segura para tu cuenta de MarthApp.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),

          if (_authController.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LiquidTheme.accentCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LiquidTheme.accentCoral.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _authController.errorMessage!,
                style: const TextStyle(
                  color: LiquidTheme.accentCoral,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: LiquidTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Nueva Contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: LiquidTheme.primaryCyan),
              hintText: 'Mínimo 6 caracteres',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: LiquidTheme.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Introduce una contraseña';
              if (val.length < 6) return 'Debe tener al menos 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 18),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(color: LiquidTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Confirmar Nueva Contraseña',
              prefixIcon: const Icon(Icons.lock_reset_rounded,
                  color: LiquidTheme.primaryCyan),
              hintText: 'Repite la contraseña',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: LiquidTheme.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Confirma la contraseña';
              if (val != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: 26),

          LiquidButton(
            text: 'Guardar Nueva Contraseña',
            icon: Icons.check_circle_outline_rounded,
            isLoading: _authController.isUpdateLoading,
            onPressed: _handleUpdatePassword,
          ),
        ],
      ),
    );
  }
}
