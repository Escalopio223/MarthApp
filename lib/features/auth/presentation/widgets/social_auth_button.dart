import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración visual y de marca para cada proveedor OAuth
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
          borderColor: const Color(0xFFE5E7EB),
          iconWidget: _buildGoogleIcon(),
        );

      case OAuthProvider.azure:
        return SocialProviderConfig(
          name: 'Azure (Microsoft)',
          label: 'Continuar con Azure (Microsoft)',
          backgroundColor: const Color(0xFF1E293B),
          textColor: Colors.white,
          borderColor: const Color(0xFF334155),
          iconWidget: _buildMicrosoftIcon(),
        );

      case OAuthProvider.facebook:
        return SocialProviderConfig(
          name: 'Facebook',
          label: 'Continuar con Facebook',
          backgroundColor: const Color(0xFF1877F2),
          textColor: Colors.white,
          borderColor: const Color(0xFF166FE5),
          iconWidget: _buildFacebookIcon(),
        );

      case OAuthProvider.twitter:
        return SocialProviderConfig(
          name: 'Twitter (X)',
          label: 'Continuar con X',
          backgroundColor: const Color(0xFF000000),
          textColor: Colors.white,
          borderColor: const Color(0xFF27272A),
          iconWidget: _buildXIcon(),
        );

      case OAuthProvider.github:
        return SocialProviderConfig(
          name: 'GitHub',
          label: 'Continuar con GitHub',
          backgroundColor: const Color(0xFF1E2638),
          textColor: Colors.white,
          borderColor: const Color(0xFF334155),
          iconWidget: const Icon(Icons.code_rounded, size: 22, color: Colors.white),
        );

      case OAuthProvider.discord:
        return SocialProviderConfig(
          name: 'Discord',
          label: 'Continuar con Discord',
          backgroundColor: const Color(0xFF5865F2),
          textColor: Colors.white,
          borderColor: const Color(0xFF4752C4),
          iconWidget: const Icon(Icons.sports_esports_rounded, size: 22, color: Colors.white),
        );

      default:
        return SocialProviderConfig(
          name: provider.name,
          label: 'Continuar con ${provider.name}',
          backgroundColor: Colors.grey.shade900,
          textColor: Colors.white,
          borderColor: Colors.grey.shade700,
          iconWidget: const Icon(Icons.login, size: 22, color: Colors.white),
        );
    }
  }

  // Renderizadores de iconos vectoriales limpios oficiales

  static Widget _buildGoogleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }

  static Widget _buildMicrosoftIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _MicrosoftLogoPainter(),
      ),
    );
  }

  static Widget _buildFacebookIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'f',
        style: TextStyle(
          color: Color(0xFF1877F2),
          fontWeight: FontWeight.bold,
          fontSize: 17,
          fontFamily: 'sans-serif',
          height: 1.1,
        ),
      ),
    );
  }

  static Widget _buildXIcon() {
    return const Center(
      child: Text(
        '𝕏',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

/// CustomPainter para el isotipo de 4 cuadrantes oficial de Microsoft (Azure)
class _MicrosoftLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 2 - 1.2; // tamaño de cada bloque
    const gap = 2.4;

    // Rojo (superior izquierda)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()..color = const Color(0xFFF25022),
    );

    // Verde (superior derecha)
    canvas.drawRect(
      Rect.fromLTWH(s + gap, 0, s, s),
      Paint()..color = const Color(0xFF7FBA00),
    );

    // Azul (inferior izquierda)
    canvas.drawRect(
      Rect.fromLTWH(0, s + gap, s, s),
      Paint()..color = const Color(0xFF00A4EF),
    );

    // Amarillo (inferior derecha)
    canvas.drawRect(
      Rect.fromLTWH(s + gap, s + gap, s, s),
      Paint()..color = const Color(0xFFFFB900),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter para el isotipo de 4 colores oficial de Google
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final rect = Rect.fromCircle(center: center, radius: radius - 2);

    canvas.drawArc(rect, -0.6, 1.6, false, paintBlue);
    canvas.drawArc(rect, 1.0, 1.4, false, paintGreen);
    canvas.drawArc(rect, 2.4, 1.4, false, paintYellow);
    canvas.drawArc(rect, 3.8, 1.5, false, paintRed);

    final paintBar = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - 1.8, radius - 1, 3.6),
      paintBar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Botón accesible de autenticación social con feedback y estado de carga
class SocialAuthButton extends StatelessWidget {
  final OAuthProvider provider;
  final VoidCallback? onPressed;
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

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52.0,
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: config.borderColor,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onTap: isDisabled || isLoading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Center(
                child: isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                config.textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Conectando...',
                            style: TextStyle(
                              color: config.textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          config.iconWidget,
                          Expanded(
                            child: Text(
                              config.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: config.textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 22),
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
