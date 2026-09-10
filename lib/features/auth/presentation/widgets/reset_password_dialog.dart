import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../controllers/auth_controller.dart';

/// Modal interactivo para solicitar el correo y enviar el enlace de recuperación de contraseña
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendReset() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await widget.authController.sendPasswordResetEmail(
      _emailController.text,
    );

    if (success && mounted) {
      setState(() {
        _sent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassCard(
          blur: 24,
          borderRadius: 24,
          padding: const EdgeInsets.all(28),
          child: _sent ? _buildSentContent() : _buildFormContent(),
        ),
      ),
    );
  }

  Widget _buildSentContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LiquidTheme.liquidEmeraldGradient,
            boxShadow: [
              BoxShadow(
                color: LiquidTheme.accentEmerald.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '¡Correo Enviado!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: LiquidTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Hemos enviado un enlace de recuperación a:\n${_emailController.text}\n\nAbre tu correo y pulsa en el enlace para actualizar tu contraseña en MarthApp.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: LiquidTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        LiquidButton(
          text: 'Entendido',
          gradient: LiquidTheme.liquidEmeraldGradient,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LiquidTheme.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  color: LiquidTheme.primaryCyan,
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
                    color: LiquidTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: LiquidTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Introduce el correo asociado a tu cuenta. Te enviaremos un enlace seguro para restablecer tu clave.',
            style: TextStyle(
              fontSize: 13,
              color: LiquidTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          if (widget.authController.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LiquidTheme.accentCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: LiquidTheme.accentCoral.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                widget.authController.errorMessage!,
                style: TextStyle(
                  color: LiquidTheme.accentCoral,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: LiquidTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Correo Electrónico',
              prefixIcon: Icon(Icons.mail_outline_rounded,
                  color: LiquidTheme.primaryCyan),
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

          LiquidButton(
            text: 'Enviar Enlace',
            icon: Icons.send_rounded,
            isLoading: widget.authController.isResetLoading,
            onPressed: _handleSendReset,
          ),
        ],
      ),
    );
  }
}
