import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/liquid_theme.dart';

/// Logotipo oficial de MarthApp dibujado vectorialmente con fondo 100% transparente.
/// Muta dinámicamente según la paleta cromática y gradientes del tema activo.
class MarthAppLogo extends StatelessWidget {
  /// Tamaño del logotipo (ancho y alto del lienzo)
  final double size;

  /// Color sólido opcional. Si no se especifica y [gradient] es nulo,
  /// utiliza [LiquidTheme.liquidPrimaryGradient] o [LiquidTheme.primaryLiquid].
  final Color? color;

  /// Gradiente opcional para pintar las líneas.
  /// Por defecto utiliza [LiquidTheme.liquidPrimaryGradient] para mutar según el tema.
  final Gradient? gradient;

  /// Grosor de trazo personalizado. Si es nulo, se calcula proporcionalmente al tamaño.
  final double? strokeWidth;

  /// Si es true, añade un sutil resplandor de luz (glow) con el color de acento del tema.
  final bool withGlow;

  const MarthAppLogo({
    super.key,
    this.size = 48.0,
    this.color,
    this.gradient,
    this.strokeWidth,
    this.withGlow = false,
  });

  /// Variante envuelta en un contenedor circular con efecto Neumórfico / Glassmórfico
  factory MarthAppLogo.badge({
    Key? key,
    double badgeSize = 56.0,
    double logoSize = 32.0,
    Color? color,
    Gradient? gradient,
    double? strokeWidth,
    bool withGlow = true,
  }) {
    return _MarthAppLogoBadge(
      key: key,
      badgeSize: badgeSize,
      logoSize: logoSize,
      color: color,
      gradient: gradient,
      strokeWidth: strokeWidth,
      withGlow: withGlow,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si no se especifica color ni gradiente, mutar dinámicamente con el tema activo
    final effectiveGradient = color == null
        ? (gradient ?? LiquidTheme.liquidPrimaryGradient)
        : null;
    final effectiveColor = effectiveGradient == null
        ? (color ?? LiquidTheme.primaryLiquid)
        : null;

    final logoPainter = CustomPaint(
      size: Size(size, size),
      painter: MarthAppLogoPainter(
        color: effectiveColor,
        gradient: effectiveGradient,
        strokeWidth: strokeWidth,
      ),
    );

    if (!withGlow) {
      return SizedBox(
        width: size,
        height: size,
        child: logoPainter,
      );
    }

    final glowColor =
        effectiveColor ?? LiquidTheme.primaryLiquid;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Capa de glow difuminado reactivo al tema
          Opacity(
            opacity: 0.35,
            child: ImageFiltered(
              imageFilter: ColorFilter.mode(
                glowColor.withValues(alpha: 0.6),
                BlendMode.srcIn,
              ),
              child: CustomPaint(
                size: Size(size, size),
                painter: MarthAppLogoPainter(
                  color: glowColor,
                  strokeWidth: (strokeWidth ?? (size * 0.09)) * 1.6,
                ),
              ),
            ),
          ),
          logoPainter,
        ],
      ),
    );
  }
}

class _MarthAppLogoBadge extends MarthAppLogo {
  final double badgeSize;
  final double logoSize;

  const _MarthAppLogoBadge({
    super.key,
    required this.badgeSize,
    required this.logoSize,
    super.color,
    super.gradient,
    super.strokeWidth,
    super.withGlow,
  }) : super(size: logoSize);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: LiquidTheme.surfaceDark.withValues(alpha: 0.8),
        border: Border.all(
          color: LiquidTheme.glassBorderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: LiquidTheme.neumorphicDarkShadow.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          if (withGlow)
            BoxShadow(
              color: LiquidTheme.primaryLiquid.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Center(
        child: MarthAppLogo(
          size: logoSize,
          color: color,
          gradient: gradient,
          strokeWidth: strokeWidth,
          withGlow: false,
        ),
      ),
    );
  }
}

/// Pintor vectorial de alta precisión para el logotipo oficial de MarthApp.
/// Trazo monoline continuo con puntas y uniones redondeadas.
class MarthAppLogoPainter extends CustomPainter {
  final Color? color;
  final Gradient? gradient;
  final double? strokeWidth;

  const MarthAppLogoPainter({
    this.color,
    this.gradient,
    this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Caja canónica del logotipo original: 62 de ancho x 57 de alto
    const double canonicalWidth = 62.0;
    const double canonicalHeight = 57.0;

    // Escalar manteniendo la proporción perfecta y centrar en el canvas
    final double scale = min(
      size.width / canonicalWidth,
      size.height / canonicalHeight,
    );

    final double ox = (size.width - canonicalWidth * scale) / 2.0;
    final double oy = (size.height - canonicalHeight * scale) / 2.0;

    // Configurar trazo con uniones y terminales redondeadas
    final double actualStrokeWidth = strokeWidth ?? (5.3 * scale);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = actualStrokeWidth;

    final bounds = Rect.fromLTWH(
      ox,
      oy,
      canonicalWidth * scale,
      canonicalHeight * scale,
    );

    if (gradient != null) {
      paint.shader = gradient!.createShader(bounds);
    } else {
      paint.color = color ?? const Color(0xFF7BB6FF);
    }

    // Trazado continuo del monograma M + Estructura de Casa
    final path = Path();

    // 1. Pata exterior izquierda: desde la base (53.5) hacia arriba (18.0)
    path.moveTo(ox + 3.0 * scale, oy + 53.5 * scale);
    path.lineTo(ox + 3.0 * scale, oy + 18.0 * scale);

    // 2. Arco superior izquierdo suave
    path.cubicTo(
      ox + 3.0 * scale,
      oy + 7.5 * scale,
      ox + 16.5 * scale,
      oy + 7.5 * scale,
      ox + 19.5 * scale,
      oy + 14.0 * scale,
    );

    // 3. Diagonal descendente izquierda hacia el cruce superior
    path.lineTo(ox + 30.5 * scale, oy + 24.5 * scale);

    // 4. Continúa diagonalmente hacia el alero derecho de la casa
    path.lineTo(ox + 44.5 * scale, oy + 36.0 * scale);

    // 5. Pared vertical derecha de la casa hacia la base
    path.lineTo(ox + 44.5 * scale, oy + 53.5 * scale);

    // 6. Base / suelo horizontal de la casa hacia la izquierda
    path.lineTo(ox + 17.5 * scale, oy + 53.5 * scale);

    // 7. Pared vertical izquierda de la casa hacia arriba
    path.lineTo(ox + 17.5 * scale, oy + 36.0 * scale);

    // 8. Diagonal ascendente izquierda hacia el cruce superior
    path.lineTo(ox + 30.5 * scale, oy + 24.5 * scale);

    // 9. Continúa diagonalmente hacia el arco superior derecho
    path.lineTo(ox + 41.5 * scale, oy + 14.0 * scale);

    // 10. Arco superior derecho suave
    path.cubicTo(
      ox + 44.5 * scale,
      oy + 7.5 * scale,
      ox + 58.5 * scale,
      oy + 7.5 * scale,
      ox + 58.5 * scale,
      oy + 18.0 * scale,
    );

    // 11. Pata exterior derecha hacia abajo hasta la base
    path.lineTo(ox + 58.5 * scale, oy + 53.5 * scale);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MarthAppLogoPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.gradient != gradient ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
