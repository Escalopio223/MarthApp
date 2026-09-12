import 'package:flutter/foundation.dart';
import '../../../../core/config/leisure_config.dart';

/// DTO para plataformas de streaming (VOD / suscripción)
@immutable
class StreamingProviderDto {
  final int providerId;
  final String providerName;
  final String logoPath;
  final int displayPriority;

  const StreamingProviderDto({
    required this.providerId,
    required this.providerName,
    required this.logoPath,
    this.displayPriority = 0,
  });

  /// URL canónica completa del logo de la plataforma
  String get logoUrl => logoPath.startsWith('http')
      ? logoPath
      : '${LeisureConfig.tmdbImageBaseUrl}/original$logoPath';

  factory StreamingProviderDto.fromJson(Map<String, dynamic> json) {
    return StreamingProviderDto(
      providerId: (json['provider_id'] as num?)?.toInt() ?? 0,
      providerName: json['provider_name'] as String? ?? 'Plataforma',
      logoPath: json['logo_path'] as String? ?? '',
      displayPriority: (json['display_priority'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider_id': providerId,
      'provider_name': providerName,
      'logo_path': logoPath,
      'display_priority': displayPriority,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamingProviderDto &&
          runtimeType == other.runtimeType &&
          providerId == other.providerId;

  @override
  int get hashCode => providerId.hashCode;

  @override
  String toString() => 'StreamingProviderDto($providerName, id: $providerId)';
}
