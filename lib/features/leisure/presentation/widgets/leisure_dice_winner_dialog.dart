import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/leisure_media_details.dart';
import '../controllers/leisure_controller.dart';
import 'leisure_detail_sheet.dart';

/// Diálogo modal con dado interactivo en 3D real y estética Neumórfica
/// que realiza la tirada al azar en 1.3 segundos y revela el ganador.
class LeisureDiceWinnerDialog extends StatefulWidget {
  final LeisureMediaDetails winner;
  final LeisureController controller;

  const LeisureDiceWinnerDialog({
    super.key,
    required this.winner,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required LeisureMediaDetails winner,
    required LeisureController controller,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LeisureDiceWinnerDialog(
        winner: winner,
        controller: controller,
      ),
    );
  }

  @override
  State<LeisureDiceWinnerDialog> createState() =>
      _LeisureDiceWinnerDialogState();
}

class _DiceFaceData {
  final int pips;
  final double nx, ny, nz; // Vector normal
  final double cx, cy, cz; // Vector de posición central
  final Matrix4 transform;

  _DiceFaceData({
    required this.pips,
    required this.nx,
    required this.ny,
    required this.nz,
    required this.cx,
    required this.cy,
    required this.cz,
    required this.transform,
  });
}

class _LeisureDiceWinnerDialogState extends State<LeisureDiceWinnerDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _rotX;
  late final Animation<double> _rotY;
  late final Animation<double> _rotZ;
  late final Animation<double> _diceBounce;
  bool _isRolling = true;

  static const double _half = 32.0;

  // Las 6 caras del dado canónico (caras opuestas suman 7: 1-6, 2-5, 3-4)
  static final List<_DiceFaceData> _cubeFaces = [
    // Cara 1: Frontal (+Z)
    _DiceFaceData(
      pips: 1,
      nx: 0, ny: 0, nz: 1,
      cx: 0, cy: 0, cz: _half,
      transform: Matrix4.translationValues(0, 0, _half),
    ),
    // Cara 6: Trasera (-Z)
    _DiceFaceData(
      pips: 6,
      nx: 0, ny: 0, nz: -1,
      cx: 0, cy: 0, cz: -_half,
      transform: Matrix4.translationValues(0, 0, -_half)..rotateY(math.pi),
    ),
    // Cara 2: Derecha (+X)
    _DiceFaceData(
      pips: 2,
      nx: 1, ny: 0, nz: 0,
      cx: _half, cy: 0, cz: 0,
      transform: Matrix4.translationValues(_half, 0, 0)..rotateY(math.pi / 2),
    ),
    // Cara 5: Izquierda (-X)
    _DiceFaceData(
      pips: 5,
      nx: -1, ny: 0, nz: 0,
      cx: -_half, cy: 0, cz: 0,
      transform: Matrix4.translationValues(-_half, 0, 0)..rotateY(-math.pi / 2),
    ),
    // Cara 3: Superior (-Y)
    _DiceFaceData(
      pips: 3,
      nx: 0, ny: -1, nz: 0,
      cx: 0, cy: -_half, cz: 0,
      transform: Matrix4.translationValues(0, -_half, 0)..rotateX(-math.pi / 2),
    ),
    // Cara 4: Inferior (+Y)
    _DiceFaceData(
      pips: 4,
      nx: 0, ny: 1, nz: 0,
      cx: 0, cy: _half, cz: 0,
      transform: Matrix4.translationValues(0, _half, 0)..rotateX(math.pi / 2),
    ),
  ];

  // Matriz 3x3 de pips para cada cara (1 al 6)
  static const Map<int, List<List<bool>>> _pipGrids = {
    1: [
      [false, false, false],
      [false, true,  false],
      [false, false, false],
    ],
    2: [
      [true,  false, false],
      [false, false, false],
      [false, false, true],
    ],
    3: [
      [true,  false, false],
      [false, true,  false],
      [false, false, true],
    ],
    4: [
      [true,  false, true],
      [false, false, false],
      [true,  false, true],
    ],
    5: [
      [true,  false, true],
      [false, true,  false],
      [true,  false, true],
    ],
    6: [
      [true,  false, true],
      [true,  false, true],
      [true,  false, true],
    ],
  };

  @override
  void initState() {
    super.initState();
    // Duración de 1.3 segundos (cumple estrictamente el límite de máx 1.5s)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // Rotaciones 3D que terminan en un ángulo isométrico para apreciar el volumen 3D
    _rotX = Tween<double>(begin: 0.0, end: 4 * math.pi + 0.38).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.78, curve: Curves.easeOutCubic),
      ),
    );

    _rotY = Tween<double>(begin: 0.0, end: 5 * math.pi - 0.45).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.78, curve: Curves.easeOutCubic),
      ),
    );

    _rotZ = Tween<double>(begin: 0.0, end: 3 * math.pi).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.78, curve: Curves.easeOutCubic),
      ),
    );

    // Rebote vertical con física de aterrizaje
    _diceBounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -34.0).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -34.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 32,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -14.0).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -14.0, end: 0.0).chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 28,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.78),
      ),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() {
            _isRolling = false;
          });
        }
      }
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutBack,
        child: _isRolling
            ? _buildRolling3DCard()
            : _buildWinnerCard(context),
      ),
    );
  }

  /// Tarjeta de animación con el dado volumétrico en 3D y sombras neumórficas
  Widget _buildRolling3DCard() {
    return AppCard(
      key: const ValueKey('rolling_3d_state'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 120,
            width: 120,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final rx = _rotX.value;
                final ry = _rotY.value;
                final rz = _rotZ.value;
                final bounce = _diceBounce.value;
                final shadowScale = (1.0 - (bounce.abs() / 65.0)).clamp(0.35, 1.0);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sombra de contacto reactiva al rebote del dado en el suelo
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 70 * shadowScale,
                        height: 12 * shadowScale,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55 * shadowScale),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.7 * shadowScale),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Dado en 3D Real con perspectiva y orden de profundidad
                    Transform.translate(
                      offset: Offset(0, bounce),
                      child: _build3DCube(rx, ry, rz),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '¡Tirada al azar!',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lanzando el dado en 3D...',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el Cubo 3D con caras sombreadas y ordenadas por profundidad Z (Painter's algorithm)
  Widget _build3DCube(double rx, double ry, double rz) {
    final cubeRotation = Matrix4.identity()
      ..setEntry(3, 2, 0.0018) // Cámara con perspectiva 3D
      ..rotateX(rx)
      ..rotateY(ry)
      ..rotateZ(rz);

    final s = cubeRotation.storage;

    // Calculamos la dirección de la luz (luz cenital-izquierda: (-0.35, -0.55, 0.75))
    const lx = -0.35;
    const ly = -0.55;
    const lz = 0.75;

    // Evaluamos qué caras apuntan hacia la cámara (backface culling)
    final List<Map<String, dynamic>> visibleFaces = [];

    for (final face in _cubeFaces) {
      // Normal transformada en coordenadas de pantalla
      final nxPrime = s[0] * face.nx + s[4] * face.ny + s[8] * face.nz;
      final nyPrime = s[1] * face.nx + s[5] * face.ny + s[9] * face.nz;
      final nzPrime = s[2] * face.nx + s[6] * face.ny + s[10] * face.nz;

      // Si nzPrime > 0, la cara apunta al frente (hacia el usuario)
      if (nzPrime > 0.0) {
        // Centro Z transformado para ordenar las caras por profundidad
        final czPrime = s[2] * face.cx + s[6] * face.cy + s[10] * face.cz + s[14];

        // Factor de iluminación difusa (entre 0.35 y 1.0)
        final diffuse = (nxPrime * lx + nyPrime * ly + nzPrime * lz).clamp(-0.2, 1.0);
        final lightFactor = (0.45 + 0.55 * (diffuse + 0.2) / 1.2).clamp(0.35, 1.0);

        visibleFaces.add({
          'face': face,
          'depth': czPrime,
          'light': lightFactor,
        });
      }
    }

    // Ordenamos las caras visibles por profundidad (las más lejanas se pintan primero)
    visibleFaces.sort((a, b) => (a['depth'] as double).compareTo(b['depth'] as double));

    return Stack(
      alignment: Alignment.center,
      children: [
        for (final item in visibleFaces) ...[
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.copy(cubeRotation)..multiply((item['face'] as _DiceFaceData).transform),
            child: _buildDiceFace(
              (item['face'] as _DiceFaceData).pips,
              item['light'] as double,
            ),
          ),
        ],
      ],
    );
  }

  /// Renderiza una cara individual del dado en 3D con relieve neumórfico y pips de color coral
  Widget _buildDiceFace(int pips, double lightFactor) {
    // Tonalidad neumórfica modulada por la iluminación 3D
    final baseColor = Color.lerp(
      const Color(0xFF13141F),
      const Color(0xFF2E3044),
      lightFactor,
    )!;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppTheme.accentCoral.withValues(alpha: 0.35 + 0.45 * lightFactor),
          width: 1.5,
        ),
        boxShadow: [
          // Sombra de volumen de la cara
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 4,
          ),
          // Resplandor neumórfico coral
          BoxShadow(
            color: AppTheme.accentCoral.withValues(alpha: 0.15 * lightFactor),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.all(9),
      child: _buildPipsLayout(pips),
    );
  }

  /// Dibuja los puntos (pips) del dado en una cuadrícula proporcional 3x3
  Widget _buildPipsLayout(int pips) {
    final grid = _pipGrids[pips] ?? _pipGrids[1]!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int r = 0; r < 3; r++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int c = 0; c < 3; c++)
                _buildPip(grid[r][c]),
            ],
          ),
      ],
    );
  }

  /// Punto individual (pip) con iluminación Neumórfica
  Widget _buildPip(bool active) {
    if (!active) return const SizedBox(width: 8, height: 8);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppTheme.accentCoral,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentCoral.withValues(alpha: 0.85),
            blurRadius: 3,
            spreadRadius: 0.6,
          ),
          const BoxShadow(
            color: Colors.black45,
            offset: Offset(0.5, 0.5),
            blurRadius: 1,
          ),
        ],
      ),
    );
  }

  /// Tarjeta de revelado con el título ganador
  Widget _buildWinnerCard(BuildContext context) {
    final winner = widget.winner;
    return AppCard(
      key: const ValueKey('winner_state'),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabecera de celebración
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentCoral.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.casino_rounded,
                  color: AppTheme.accentCoral,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Tirada al azar completada!',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ganador seleccionado al azar',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Tarjeta del Ítem Ganador
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentCoral.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carátula / Póster
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 80,
                    height: 116,
                    child: winner.posterUrl != null
                        ? Image.network(
                            winner.posterUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildFallbackPoster(),
                          )
                        : _buildFallbackPoster(),
                  ),
                ),
                const SizedBox(width: 14),

                // Información del Ítem
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Etiqueta de Tipo de Medio
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLiquid.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          winner.mediaType.label.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryLiquid,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Título
                      Text(
                        winner.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Año y Puntuación
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (winner.year != null && winner.year!.isNotEmpty) ...[
                            Text(
                              winner.year!,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (winner.rating != null && winner.rating! > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              winner.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Sinopsis resumida
                      if (winner.overview != null &&
                          winner.overview!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          winner.overview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Notificación de Limpieza Automática
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 14,
                  color: AppTheme.accentEmerald,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tirada al azar limpiada automáticamente',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Acciones: Ver detalles y Cerrar
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(
                  text: 'Ver ficha',
                  icon: Icons.open_in_new_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    LeisureDetailSheet.show(
                      context,
                      media: winner,
                      controller: widget.controller,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackPoster() {
    return Container(
      color: AppTheme.surfaceDark,
      child: Center(
        child: Icon(
          Icons.movie_rounded,
          color: AppTheme.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}
