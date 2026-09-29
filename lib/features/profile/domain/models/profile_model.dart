import 'avatar_data.dart';

/// Modelo de dominio que representa el perfil de un usuario en MarthApp
class ProfileModel {
  final String id;
  final String username;
  final AvatarData avatarData;
  final DateTime? birthDate;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.username,
    this.avatarData = const AvatarData.initials(),
    this.birthDate,
    required this.updatedAt,
  });

  AvatarType get avatarType => avatarData.type;
  String? get avatarUrl => avatarData.imageUrl;
  String? get avatarIcon => avatarData.iconKey;
  String? get avatarBgColor => avatarData.bgColorHex;

  /// Getters deprecados para compatibilidad transicional hacia la única fuente de verdad (birthDate)
  @Deprecated('Usar birthDate como único campo canónico')
  DateTime? get birthday => birthDate;

  @Deprecated('Usar birthDate como único campo canónico')
  DateTime? get fechaNacimiento => birthDate;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // Lectura canónica con fallback tolerante a campos deprecados
    final rawDate = json['birth_date'] ??
        json['birthday'] ??
        json['fecha_nacimiento'] ??
        json['cumpleanos'];
    final parsedBirthDate =
        rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;

    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Usuario',
      avatarData: AvatarData.fromDb(
        typeStr: json['avatar_type'] as String?,
        url: json['avatar_url'] as String?,
        icon: json['avatar_icon'] as String?,
        bgColor: json['avatar_bg_color'] as String?,
      ),
      birthDate: parsedBirthDate,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      ...avatarData.toDbMap(),
      if (birthDate != null)
        'birth_date': birthDate!.toIso8601String().split('T').first,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? username,
    AvatarData? avatarData,
    DateTime? birthDate,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarData: avatarData ?? this.avatarData,
      birthDate: birthDate ?? this.birthDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          avatarData == other.avatarData &&
          birthDate == other.birthDate;

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      avatarData.hashCode ^
      (birthDate?.hashCode ?? 0);
}
