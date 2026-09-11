import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../controllers/auth_controller.dart';

/// Componente modular y reutilizable para el cambio y confirmación de contraseña.
/// Gestiona de manera estricta el ciclo de vida de sus controladores y FocusNodes.
class UpdatePasswordCard extends StatefulWidget {
  final AuthController authController;
  final VoidCallback? onSuccess;
  final VoidCallback? onClose;
  final bool isDismissible;
  final String title;
  final String subtitle;
  final String submitButtonText;
  final bool centeredHeader;

  const UpdatePasswordCard({
    super.key,
    required this.authController,
    this.onSuccess,
    this.onClose,
    this.isDismissible = false,
    this.title = 'Actualizar Contraseña',
    this.subtitle = 'Establece tu nueva contraseña segura',
    this.submitButtonText = 'Confirmar y Guardar',
    this.centeredHeader = false,
  });

  @override
  State<UpdatePasswordCard> createState() => _UpdatePasswordCardState();
}

class _UpdatePasswordCardState extends State<UpdatePasswordCard> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final FocusNode _passwordFocusNode;
  late final FocusNode _confirmPasswordFocusNode;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSuccess = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _passwordFocusNode = FocusNode();
    _confirmPasswordFocusNode = FocusNode();

    widget.authController.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant UpdatePasswordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authController != widget.authController) {
      oldWidget.authController.removeListener(_onAuthChanged);
      widget.authController.addListener(_onAuthChanged);
    }
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
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
          widget.onSuccess?.call();
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

    return GlassCard(
      blur: 24.0,
      borderRadius: 24.0,
      padding: const EdgeInsets.all(28.0),
      child: _isSuccess ? _buildSuccessView() : _buildFormView(isLoading),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LiquidTheme.accentEmerald.withValues(alpha: 0.2),
            border: Border.all(color: LiquidTheme.accentEmerald, width: 2),
            boxShadow: [
              BoxShadow(
                color: LiquidTheme.accentEmerald.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: LiquidTheme.accentEmerald,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '¡Contraseña Actualizada!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LiquidTheme.textPrimary,
            fontSize: 22,
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
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        LiquidButton(
          text: 'Continuar',
          gradient: LiquidTheme.liquidEmeraldGradient,
          onPressed: () => widget.onSuccess?.call(),
        ),
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
          _buildHeader(),
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
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            style: TextStyle(color: LiquidTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Mínimo 8 caracteres',
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
              if (value.length < 8) {
                return 'La contraseña debe tener al menos 8 caracteres';
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
            focusNode: _confirmPasswordFocusNode,
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
            text: widget.submitButtonText,
            isLoading: isLoading,
            icon: Icons.check_rounded,
            onPressed: isLoading ? null : _handleUpdate,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    if (widget.centeredHeader) {
      return Column(
        children: [
          Container(
            width: 64,
            height: 64,
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
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: LiquidTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return Row(
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
                widget.title,
                style: TextStyle(
                  color: LiquidTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: LiquidTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (widget.isDismissible && widget.onClose != null)
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: LiquidTheme.textSecondary,
              size: 22,
            ),
            tooltip: 'Cerrar',
            onPressed: widget.onClose,
          ),
      ],
    );
  }
}
