import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../domain/models/avatar_data.dart';
import '../../domain/models/profile_model.dart';

/// Catálogo centralizado de iconos disponibles para personalización de avatares
class AvatarIconCatalog {
  AvatarIconCatalog._();

  static const Map<String, IconData> icons = {
    'person': Icons.person_rounded,
    'gamepad': Icons.sports_esports_rounded,
    'bolt': Icons.bolt_rounded,
    'rocket': Icons.rocket_launch_rounded,
    'shield': Icons.shield_rounded,
    'star': Icons.star_rounded,
    'heart': Icons.favorite_rounded,
    'fire': Icons.local_fire_department_rounded,
    'code': Icons.code_rounded,
    'palette': Icons.palette_rounded,
    'robot': Icons.smart_toy_rounded,
    'music': Icons.headphones_rounded,
    'pets': Icons.pets_rounded,
    'crown': Icons.workspace_premium_rounded,
    'diamond': Icons.diamond_rounded,
    'auto_awesome': Icons.auto_awesome_rounded,
  };

  static IconData getIcon(String? key) {
    if (key == null) return Icons.person_rounded;
    return icons[key] ?? Icons.person_rounded;
  }
}

/// Paleta cromática líquida para colores de fondo de avatar
class AvatarColorPalette {
  AvatarColorPalette._();

  static const List<String> presetColors = [
    '#00E5FF', // Cyan Eléctrico
    '#00E676', // Esmeralda Neón
    '#FF3366', // Coral Líquido
    '#BD00FF', // Amatista Púrpura
    '#FFB300', // Ámbar Solar
    '#00B0FF', // Glaciar Azul
    '#FF6E40', // Naranja Atardecer
    '#E040FB', // Magenta Intenso
    '#64FFDA', // Menta Helada
    '#7C4DFF', // Índigo Profundo
  ];

  static Color parseHex(String? hex, {Color fallback = const Color(0xFF00E5FF)}) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }
}

/// Widget unificado de alta fidelidad visual para renderizar avatares de usuario
class UserAvatar extends StatelessWidget {
  final AvatarData avatarData;
  final String username;
  final double size;
  final bool isEditable;
  final VoidCallback? onTap;
  final bool showGlow;
  final bool showBorder;

  const UserAvatar({
    super.key,
    required this.avatarData,
    required this.username,
    this.size = 50.0,
    this.isEditable = false,
    this.onTap,
    this.showGlow = false,
    this.showBorder = true,
  });

  /// Constructor conveniente a partir de un [ProfileModel]
  factory UserAvatar.fromProfile({
    Key? key,
    required ProfileModel profile,
    double size = 50.0,
    bool isEditable = false,
    VoidCallback? onTap,
    bool showGlow = false,
    bool showBorder = true,
  }) {
    return UserAvatar(
      key: key,
      avatarData: profile.avatarData,
      username: profile.username,
      size: size,
      isEditable: isEditable,
      onTap: onTap,
      showGlow: showGlow,
      showBorder: showBorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarContent;

    switch (avatarData.type) {
      case AvatarType.image:
        avatarContent = _buildImageAvatar();
        break;
      case AvatarType.icon:
        avatarContent = _buildIconAvatar();
        break;
      case AvatarType.initials:
        avatarContent = _buildInitialsAvatar();
        break;
    }

    Widget coreWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: LiquidTheme.glassBorderColor.withValues(alpha: 0.8),
                width: size > 60 ? 2.0 : 1.2,
              )
            : null,
        boxShadow: [
          if (showGlow)
            BoxShadow(
              color: _resolveGlowColor().withValues(alpha: 0.35),
              blurRadius: size * 0.3,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipOval(child: avatarContent),
    );

    if (isEditable) {
      coreWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          coreWidget,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LiquidTheme.liquidPrimaryGradient,
                border: Border.all(
                  color: LiquidTheme.surfaceDark,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.edit_rounded,
                size: size * 0.18,
                color: const Color(0xFF0D1219),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: coreWidget,
      );
    }

    return coreWidget;
  }

  Widget _buildImageAvatar() {
    final url = avatarData.imageUrl;
    if (url == null || url.isEmpty) {
      return _buildInitialsAvatar();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: size,
      height: size,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: LiquidTheme.surfaceDark,
          child: Center(
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(),
    );
  }

  Widget _buildIconAvatar() {
    final iconData = AvatarIconCatalog.getIcon(avatarData.iconKey);
    final bgColor = AvatarColorPalette.parseHex(
      avatarData.bgColorHex,
      fallback: LiquidTheme.primaryCyan,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor,
            bgColor.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: const Color(0xFF0D1219),
          size: size * 0.52,
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    final initial = username.isNotEmpty
        ? username.substring(0, 1).toUpperCase()
        : 'M';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LiquidTheme.liquidPrimaryGradient,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: const Color(0xFF0D1219),
            fontWeight: FontWeight.bold,
            fontSize: size * 0.44,
          ),
        ),
      ),
    );
  }

  Color _resolveGlowColor() {
    if (avatarData.type == AvatarType.icon) {
      return AvatarColorPalette.parseHex(avatarData.bgColorHex);
    }
    return LiquidTheme.primaryLiquid;
  }
}
