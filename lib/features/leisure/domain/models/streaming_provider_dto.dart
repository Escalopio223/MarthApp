import 'package:flutter/foundation.dart';
import '../../../../core/config/leisure_config.dart';

/// DTO para plataformas de streaming (VOD / suscripción / compra / alquiler)
@immutable
class StreamingProviderDto {
  final int providerId;
  final String providerName;
  final String logoPath;
  final int displayPriority;
  final String type; // 'flatrate', 'free', 'ads', 'rent', 'buy'
  final String? watchLink;

  const StreamingProviderDto({
    required this.providerId,
    required this.providerName,
    required this.logoPath,
    this.displayPriority = 0,
    this.type = 'flatrate',
    this.watchLink,
  });

  /// URL canónica completa del logo de la plataforma
  String get logoUrl => logoPath.startsWith('http')
      ? logoPath
      : '${LeisureConfig.tmdbImageBaseUrl}/original$logoPath';

  /// Etiqueta amigable según el tipo de disponibilidad
  String get typeLabel {
    switch (type) {
      case 'flatrate':
        return 'Suscripción';
      case 'free':
        return 'Gratuito';
      case 'ads':
        return 'Con anuncios';
      case 'rent':
        return 'Alquiler';
      case 'buy':
        return 'Compra';
      default:
        return 'Streaming';
    }
  }

  factory StreamingProviderDto.fromJson(
    Map<String, dynamic> json, {
    String? type,
    String? watchLink,
  }) {
    return StreamingProviderDto(
      providerId: (json['provider_id'] as num?)?.toInt() ?? 0,
      providerName: json['provider_name'] as String? ?? 'Plataforma',
      logoPath: json['logo_path'] as String? ?? '',
      displayPriority: (json['display_priority'] as num?)?.toInt() ?? 0,
      type: (json['type'] as String?) ?? type ?? 'flatrate',
      watchLink: (json['watch_link'] as String?) ??
          (json['link'] as String?) ??
          watchLink,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider_id': providerId,
      'provider_name': providerName,
      'logo_path': logoPath,
      'display_priority': displayPriority,
      'type': type,
      if (watchLink != null) 'watch_link': watchLink,
    };
  }

  StreamingProviderDto copyWith({
    int? providerId,
    String? providerName,
    String? logoPath,
    int? displayPriority,
    String? type,
    String? watchLink,
  }) {
    return StreamingProviderDto(
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      logoPath: logoPath ?? this.logoPath,
      displayPriority: displayPriority ?? this.displayPriority,
      type: type ?? this.type,
      watchLink: watchLink ?? this.watchLink,
    );
  }

  /// Catálogo de plataformas principales para filtros rápidos
  static const List<StreamingProviderDto> popularProviders = [
    StreamingProviderDto(
      providerId: 8,
      providerName: 'Netflix',
      logoPath: '/t2yyOv40HZeVlLjYsCsPHnWLk4W.jpg',
      displayPriority: 1,
    ),
    StreamingProviderDto(
      providerId: 337,
      providerName: 'Disney+',
      logoPath: '/7rwgEs55tOXyYDu8WuNX1Y9qJAc.jpg',
      displayPriority: 2,
    ),
    StreamingProviderDto(
      providerId: 119,
      providerName: 'Prime Video',
      logoPath: '/emthp39XA2zhcoYL323Vio0DYGW.jpg',
      displayPriority: 3,
    ),
    StreamingProviderDto(
      providerId: 384,
      providerName: 'Max (HBO)',
      logoPath: '/Ajqyt5GhGFOXny19RAAvnT4wnas.jpg',
      displayPriority: 4,
    ),
    StreamingProviderDto(
      providerId: 350,
      providerName: 'Apple TV+',
      logoPath: '/6uhKBfmt2FsQwe93nHua8f9455y.jpg',
      displayPriority: 5,
    ),
    StreamingProviderDto(
      providerId: 15,
      providerName: 'Hulu',
      logoPath: '/zxrVdFjIjLqkfnwyghn2WZhGD3d.jpg',
      displayPriority: 6,
    ),
    StreamingProviderDto(
      providerId: 149,
      providerName: 'Movistar+',
      logoPath: '/f17XFp6U5F8N4U5Nq7a6E5i3o.jpg',
      displayPriority: 7,
    ),
    StreamingProviderDto(
      providerId: 1773,
      providerName: 'SkyShowtime',
      logoPath: '/j7y0vK6f1sX6R5z1Y9gK4M2n9p.jpg',
      displayPriority: 8,
    ),
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamingProviderDto &&
          runtimeType == other.runtimeType &&
          providerId == other.providerId;

  @override
  int get hashCode => providerId.hashCode;

  @override
  String toString() => 'StreamingProviderDto($providerName, id: $providerId, type: $type)';
}
