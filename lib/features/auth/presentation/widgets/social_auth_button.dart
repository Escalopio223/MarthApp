import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/liquid_theme.dart';

/// Configuración visual y de marca para proveedores OAuth activos
class SocialProviderConfig {
  final String name;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final Widget iconWidget;

  const SocialProviderConfig({
    required this.name,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.iconWidget,
  });

  static SocialProviderConfig fromProvider(OAuthProvider provider) {
    switch (provider) {
      case OAuthProvider.google:
        return SocialProviderConfig(
          name: 'Google',
          label: 'Continuar con Google',
          backgroundColor: const Color(0xFFFFFFFF),
          textColor: const Color(0xFF1F2937),
          borderColor: LiquidTheme.glassBorderColor,
          iconWidget: _buildGoogleIcon(),
        );

      case OAuthProvider.github:
        return SocialProviderConfig(
          name: 'GitHub',
          label: 'Continuar con GitHub',
          backgroundColor: LiquidTheme.surfaceDark, // #1A1F26
          textColor: LiquidTheme.textPrimary, // #E6EDF3
          borderColor: LiquidTheme.glassBorderColor, // rgba(139, 155, 180, 0.2)
          iconWidget: const Icon(
            Icons.code_rounded,
            size: 22,
            color: LiquidTheme.textPrimary,
          ),
        );

      default:
        return SocialProviderConfig(
          name: provider.name,
          label: 'Continuar con ${provider.name}',
          backgroundColor: LiquidTheme.surfaceDark,
          textColor: LiquidTheme.textPrimary,
          borderColor: LiquidTheme.glassBorderColor,
          iconWidget: const Icon(
            Icons.login_rounded,
            size: 20,
            color: LiquidTheme.textPrimary,
          ),
        );
    }
  }

  static Widget _buildGoogleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

/// Botón interactivo de autenticación social con estética Neumórfica 'Soft UI'
class SocialAuthButton extends StatelessWidget {
  final OAuthProvider provider;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isDisabled;

  const SocialAuthButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = SocialProviderConfig.fromProvider(provider);
    final isGoogle = provider == OAuthProvider.google;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      opacity: isDisabled ? 0.45 : 1.0,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: config.borderColor, width: 1.0),
          boxShadow: isGoogle
              ? [
                  BoxShadow(
                    color: LiquidTheme.neumorphicDarkShadow.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  // Sombra neumórfica exterior oscura
                  BoxShadow(
                    color: LiquidTheme.neumorphicDarkShadow.withValues(alpha: 0.8),
                    blurRadius: 8,
                    offset: const Offset(3, 3),
                  ),
                  // Realce neumórfico claro superior
                  BoxShadow(
                    color: LiquidTheme.neumorphicLightHighlight.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(-2, -2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: (isDisabled || isLoading) ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading) ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(config.textColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Conectando...',
                      style: TextStyle(
                        color: config.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    config.iconWidget,
                    const SizedBox(width: 12),
                    Text(
                      config.label,
                      style: TextStyle(
                        color: config.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pintor vectorial para el logotipo oficial de Google
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // Rojo (Google Red)
    paint.color = const Color(0xFFEA4335);
    final pathRed = Path()
      ..moveTo(w * 0.5, h * 0.2)
      ..cubicTo(w * 0.62, h * 0.2, w * 0.73, h * 0.25, w * 0.81, h * 0.32)
      ..lineTo(w * 0.95, h * 0.18)
      ..cubicTo(w * 0.83, h * 0.07, w * 0.67, 0, w * 0.5, 0)
      ..cubicTo(w * 0.3, 0, w * 0.13, h * 0.11, w * 0.05, h * 0.28)
      ..lineTo(w * 0.22, h * 0.41)
      ..cubicTo(w * 0.26, h * 0.29, w * 0.37, h * 0.2, w * 0.5, h * 0.2)
      ..close();
    canvas.drawPath(pathRed, paint);

    // Amarillo (Google Yellow)
    paint.color = const Color(0xFFFBBC05);
    final pathYellow = Path()
      ..moveTo(w * 0.05, h * 0.28)
      ..cubicTo(w * 0.02, h * 0.35, 0, h * 0.42, 0, h * 0.5)
      ..cubicTo(0, h * 0.58, w * 0.02, h * 0.65, w * 0.05, h * 0.72)
      ..lineTo(w * 0.22, h * 0.59)
      ..cubicTo(w * 0.21, h * 0.56, w * 0.2, h * 0.53, w * 0.2, h * 0.5)
      ..cubicTo(w * 0.2, h * 0.47, w * 0.21, h * 0.44, w * 0.22, h * 0.41)
      ..close();
    canvas.drawPath(pathYellow, paint);

    // Verde (Google Green)
    paint.color = const Color(0xFF34A853);
    final pathGreen = Path()
      ..moveTo(w * 0.5, h)
      ..cubicTo(w * 0.67, h, w * 0.81, h * 0.94, w * 0.92, h * 0.84)
      ..lineTo(w * 0.75, h * 0.71)
      ..cubicTo(w * 0.68, h * 0.76, w * 0.6, h * 0.8, w * 0.5, h * 0.8)
      ..cubicTo(w * 0.37, h * 0.8, w * 0.26, h * 0.71, w * 0.22, h * 0.59)
      ..lineTo(w * 0.05, h * 0.72)
      ..cubicTo(w * 0.13, h * 0.89, w * 0.3, h, w * 0.5, h)
      ..close();
    canvas.drawPath(pathGreen, paint);

    // Azul (Google Blue)
    paint.color = const Color(0xFF4285F4);
    final pathBlue = Path()
      ..moveTo(w, h * 0.5)
      ..cubicTo(w, h * 0.46, w * 0.99, h * 0.43, w * 0.98, h * 0.39)
      ..lineTo(w * 0.5, h * 0.39)
      ..lineTo(w * 0.5, h * 0.61)
      ..lineTo(w * 0.78, h * 0.61)
      ..cubicTo(w * 0.77, h * 0.68, w * 0.73, h * 0.73, w * 0.67, h * 0.77)
      ..lineTo(w * 0.84, h * 0.9)
      ..cubicTo(w * 0.94, h * 0.81, w, h * 0.67, w, h * 0.5)
      ..close();
    canvas.drawPath(pathBlue, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
