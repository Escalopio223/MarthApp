import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../domain/models/avatar_catalog.dart';
import '../../domain/models/avatar_data.dart';
import '../../domain/models/profile_model.dart';

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
    final rawUrl = avatarData.imageUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      return _buildInitialsAvatar();
    }

    final separator = rawUrl.contains('?') ? '&' : '?';
    final url = rawUrl.contains('v=')
        ? rawUrl
        : '$rawUrl${separator}v=${DateTime.now().millisecondsSinceEpoch}';

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
