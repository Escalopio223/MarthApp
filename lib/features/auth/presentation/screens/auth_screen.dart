import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../controllers/auth_controller.dart';
import '../widgets/reset_password_dialog.dart';
import '../widgets/social_auth_button.dart';

enum AuthMode { login, register }

/// Pantalla híbrida de autenticación para MarthApp:
/// Credenciales directas (Email + Contraseña) y OAuth Social (Google, Microsoft, GitHub)
class AuthScreen extends StatefulWidget {
  final AuthController? controller;

  const AuthScreen({super.key, this.controller});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final AuthController _authController;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  AuthMode _mode = AuthMode.login;

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitDirectAuth() async {
    if (!_formKey.currentState!.validate()) return;
    _authController.clearMessages();

    if (_mode == AuthMode.login) {
      await _authController.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      // Regla estricta: Registro directo sin confirmación previa de correo
      await _authController.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnyLoading = _authController.isLoading;

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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logotipo / Icono Liquid
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LiquidTheme.liquidPrimaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: LiquidTheme.primaryCyan.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.bubble_chart_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Título
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            LiquidTheme.liquidPrimaryGradient.createShader(bounds),
                        child: const Text(
                          'MarthApp',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Selector de Modo: Iniciar Sesión / Registrarme
                      _buildModeSelector(),
                      const SizedBox(height: 24),

                      // Mensaje de Error
                      if (_authController.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: LiquidTheme.accentCoral.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: LiquidTheme.accentCoral.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: LiquidTheme.accentCoral,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _authController.errorMessage!,
                                  style: const TextStyle(
                                    color: LiquidTheme.accentCoral,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Campo Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: LiquidTheme.textPrimary),
                        decoration: const InputDecoration(
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
                      const SizedBox(height: 16),

                      // Campo Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: LiquidTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Introduce tu contraseña';
                          }
                          if (value.length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),

                      // Enlace "¿Has olvidado tu contraseña?" (Solo en Login)
                      if (_mode == AuthMode.login) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ResetPasswordDialog.show(
                                context,
                                authController: _authController,
                              );
                            },
                            child: const Text(
                              '¿Has olvidado tu contraseña?',
                              style: TextStyle(
                                color: LiquidTheme.primaryCyan,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        const SizedBox(height: 24),
                      ],

                      // Botón Principal (Email + Password)
                      LiquidButton(
                        text: _mode == AuthMode.login
                            ? 'Iniciar Sesión'
                            : 'Crear Cuenta',
                        icon: _mode == AuthMode.login
                            ? Icons.login_rounded
                            : Icons.person_add_alt_1_rounded,
                        isLoading: _authController.isEmailLoading,
                        onPressed: _submitDirectAuth,
                      ),
                      const SizedBox(height: 24),

                      // Divisor "o continúa con"
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Colors.white12)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'o continúa con',
                              style: TextStyle(
                                color: LiquidTheme.textSecondary.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Colors.white12)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Botón Social 1: Google
                      SocialAuthButton(
                        provider: OAuthProvider.google,
                        isLoading: _authController
                            .isProviderLoading(OAuthProvider.google),
                        isDisabled: isAnyLoading &&
                            !_authController
                                .isProviderLoading(OAuthProvider.google),
                        onPressed: () => _authController.signInWithGoogle(),
                      ),
                      const SizedBox(height: 12),

                      // Botón Social 2: Microsoft (Azure)
                      SocialAuthButton(
                        provider: OAuthProvider.azure,
                        isLoading: _authController
                            .isProviderLoading(OAuthProvider.azure),
                        isDisabled: isAnyLoading &&
                            !_authController
                                .isProviderLoading(OAuthProvider.azure),
                        onPressed: () => _authController.signInWithMicrosoft(),
                      ),
                      const SizedBox(height: 12),

                      // Botón Social 3: GitHub
                      SocialAuthButton(
                        provider: OAuthProvider.github,
                        isLoading: _authController
                            .isProviderLoading(OAuthProvider.github),
                        isDisabled: isAnyLoading &&
                            !_authController
                                .isProviderLoading(OAuthProvider.github),
                        onPressed: () => _authController.signInWithGithub(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Selector de Modo estilo Liquid UI (Iniciar Sesión vs Crear Cuenta)
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = AuthMode.login;
                  _authController.clearMessages();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _mode == AuthMode.login
                      ? LiquidTheme.liquidPrimaryGradient
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Iniciar Sesión',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mode == AuthMode.login
                        ? Colors.white
                        : LiquidTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = AuthMode.register;
                  _authController.clearMessages();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _mode == AuthMode.register
                      ? LiquidTheme.liquidPrimaryGradient
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Crear Cuenta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mode == AuthMode.register
                        ? Colors.white
                        : LiquidTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
