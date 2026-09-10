/// Tipo discriminador del avatar de usuario
enum AvatarType {
  initials,
  icon,
  image;

  static AvatarType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'icon':
        return AvatarType.icon;
      case 'image':
        return AvatarType.image;
      case 'initials':
      default:
        return AvatarType.initials;
    }
  }

  String toDbString() {
    switch (this) {
      case AvatarType.icon:
        return 'icon';
      case AvatarType.image:
        return 'image';
      case AvatarType.initials:
        return 'initials';
    }
  }
}

/// Value Object inmutable que modela el estado exacto del avatar
class AvatarData {
  final AvatarType type;
  final String? imageUrl;
  final String? iconKey;
  final String? bgColorHex;

  const AvatarData({
    this.type = AvatarType.initials,
    this.imageUrl,
    this.iconKey,
    this.bgColorHex,
  });

  const AvatarData.initials()
      : type = AvatarType.initials,
        imageUrl = null,
        iconKey = null,
        bgColorHex = null;

  const AvatarData.icon({
    required String this.iconKey,
    required String this.bgColorHex,
  })  : type = AvatarType.icon,
        imageUrl = null;

  const AvatarData.image({
    required String this.imageUrl,
  })  : type = AvatarType.image,
        iconKey = null,
        bgColorHex = null;

  factory AvatarData.fromDb({
    String? typeStr,
    String? url,
    String? icon,
    String? bgColor,
  }) {
    final type = AvatarType.fromString(typeStr);
    switch (type) {
      case AvatarType.image:
        if (url != null && url.isNotEmpty) {
          return AvatarData.image(imageUrl: url);
        }
        return const AvatarData.initials();
      case AvatarType.icon:
        if (icon != null && icon.isNotEmpty && bgColor != null && bgColor.isNotEmpty) {
          return AvatarData.icon(iconKey: icon, bgColorHex: bgColor);
        }
        return const AvatarData.initials();
      case AvatarType.initials:
        return const AvatarData.initials();
    }
  }

  Map<String, dynamic> toDbMap() {
    switch (type) {
      case AvatarType.image:
        return {
          'avatar_type': 'image',
          'avatar_url': imageUrl,
          'avatar_icon': null,
          'avatar_bg_color': null,
        };
      case AvatarType.icon:
        return {
          'avatar_type': 'icon',
          'avatar_url': null,
          'avatar_icon': iconKey,
          'avatar_bg_color': bgColorHex,
        };
      case AvatarType.initials:
        return {
          'avatar_type': 'initials',
          'avatar_url': null,
          'avatar_icon': null,
          'avatar_bg_color': null,
        };
    }
  }

  AvatarData copyWith({
    AvatarType? type,
    String? imageUrl,
    String? iconKey,
    String? bgColorHex,
  }) {
    return AvatarData(
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      iconKey: iconKey ?? this.iconKey,
      bgColorHex: bgColorHex ?? this.bgColorHex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarData &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          imageUrl == other.imageUrl &&
          iconKey == other.iconKey &&
          bgColorHex == other.bgColorHex;

  @override
  int get hashCode =>
      type.hashCode ^
      (imageUrl?.hashCode ?? 0) ^
      (iconKey?.hashCode ?? 0) ^
      (bgColorHex?.hashCode ?? 0);
}
