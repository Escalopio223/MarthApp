import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../controllers/auth_controller.dart';

/// Modal interactivo para restablecer la contraseña mediante código OTP numérico de 6 dígitos.
/// Elimina cualquier dependencia de enlaces web y redirecciones externas,
/// permitiendo al usuario completar todo el proceso 100% dentro de la aplicación.
class ResetPasswordDialog extends StatefulWidget {
  final AuthController authController;
  final String? initialEmail;

  const ResetPasswordDialog({
    super.key,
    required this.authController,
    this.initialEmail,
  });

  static Future<void> show(
    BuildContext context, {
    required AuthController authController,
    String? initialEmail,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ResetPasswordDialog(
        authController: authController,
        initialEmail: initialEmail,
      ),
    );
  }

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // 0: Solicitar código (Email)
  // 1: Introducir OTP de 6 dígitos y Nueva Contraseña
  // 2: Confirmación de éxito
  int _step = 0;

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  Timer? _cooldownTimer;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _handleSendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    final success = await widget.authController.sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    if (success && mounted) {
      _startCooldown(60);
      setState(() => _step = 1);
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCooldown > 0) return;
    HapticFeedback.selectionClick();

    final success = await widget.authController.sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    if (success && mounted) {
      _startCooldown(60);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nuevo código de 6 dígitos enviado a tu correo.'),
          backgroundColor: AppTheme.accentEmerald,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleCompleteReset() async {
    if (!_resetFormKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final success = await widget.authController.completePasswordReset(
      email: _emailController.text.trim(),
      token: _otpController.text.trim(),
      newPassword: _newPasswordController.text,
    );

    if (success && mounted) {
      setState(() => _step = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AppCard(
          borderRadius: 22,
          padding: const EdgeInsets.all(26),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildCurrentStepContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_step) {
      case 1:
        return _buildOtpAndNewPasswordStep();
      case 2:
        return _buildSuccessStep();
      case 0:
      default:
        return _buildEmailStep();
    }
  }

  // ===========================================================================
  // Paso 0: Solicitar Código OTP al Correo
  // ===========================================================================

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('step_email'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  color: AppTheme.primaryCyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recuperar Contraseña',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Introduce el correo asociado a tu cuenta. Te enviaremos un código de seguridad de 6 dígitos.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          _buildErrorMessageBox(),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Correo Electrónico',
              prefixIcon: Icon(Icons.mail_outline_rounded,
                  color: AppTheme.primaryCyan),
              hintText: 'ejemplo@marthapp.com',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Introduce tu correo';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Introduce un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),

          AppButton(
            text: 'Enviar Código de 6 Dígitos',
            icon: Icons.send_rounded,
            isLoading: widget.authController.isResetLoading,
            onPressed: _handleSendOtp,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Paso 1: Introducir Código OTP y Nueva Contraseña
  // ===========================================================================

  Widget _buildOtpAndNewPasswordStep() {
    return Form(
      key: _resetFormKey,
      child: Column(
        key: const ValueKey('step_otp_password'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  color: AppTheme.accentEmerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Código de Seguridad',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hemos enviado un código a ${_emailController.text}. Escríbelo junto con tu nueva clave:',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          _buildErrorMessageBox(),

          // Campo Código OTP de 6 dígitos
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              labelText: 'Código de 6 Dígitos',
              prefixIcon: Icon(Icons.pin_rounded, color: AppTheme.accentEmerald),
              hintText: '123456',
              hintStyle: TextStyle(
                letterSpacing: 6,
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Introduce el código de 6 dígitos';
              }
              if (value.trim().length != 6) {
                return 'El código debe tener exactamente 6 dígitos';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Campo Nueva Contraseña
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Nueva Contraseña',
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  color: AppTheme.primaryCyan),
              hintText: 'Mínimo 6 caracteres',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () => setState(
                    () => _obscureNewPassword = !_obscureNewPassword),
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
          const SizedBox(height: 14),

          // Campo Confirmar Nueva Contraseña
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Confirmar Nueva Contraseña',
              prefixIcon: Icon(Icons.lock_reset_rounded,
                  color: AppTheme.primaryCyan),
              hintText: 'Repite tu contraseña',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () => setState(() =>
                    _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirma tu nueva contraseña';
              }
              if (value != _newPasswordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Botón de reenvío con temporizador cooldown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _step = 0),
                child: Text(
                  'Cambiar correo',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _resendCooldown == 0 ? _handleResendOtp : null,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: _resendCooldown == 0
                      ? AppTheme.primaryLiquid
                      : AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                label: Text(
                  _resendCooldown > 0
                      ? 'Reenviar en ${_resendCooldown}s'
                      : 'Reenviar código',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _resendCooldown == 0
                        ? AppTheme.primaryLiquid
                        : AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          AppButton(
            text: 'Restablecer Contraseña',
            icon: Icons.check_circle_outline_rounded,
            isLoading: widget.authController.isUpdateLoading,
            onPressed: _handleCompleteReset,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Paso 2: Confirmación de Éxito
  // ===========================================================================

  Widget _buildSuccessStep() {
    return Column(
      key: const ValueKey('step_success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.liquidEmeraldGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentEmerald.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '¡Contraseña Actualizada!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tu contraseña ha sido restablecida con éxito.\nYa puedes iniciar sesión en MarthApp con tus nuevas credenciales.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        AppButton(
          text: 'Iniciar Sesión',
          gradient: AppTheme.liquidEmeraldGradient,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildErrorMessageBox() {
    final error = widget.authController.errorMessage;
    if (error == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.accentCoral.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.accentCoral.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppTheme.accentCoral, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: AppTheme.accentCoral,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
