import 'package:flutter/foundation.dart';

/// DTO representativo de una tienda oficial o plataforma donde se distribuye un videojuego.
@immutable
class GameStoreDto {
  final String storeName;
  final String url;

  const GameStoreDto({
    required this.storeName,
    required this.url,
  });

  factory GameStoreDto.fromJson(Map<String, dynamic> json) {
    return GameStoreDto(
      storeName: json['store_name'] as String? ?? 'Tienda oficial',
      url: json['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'store_name': storeName,
      'url': url,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameStoreDto &&
          runtimeType == other.runtimeType &&
          storeName == other.storeName &&
          url == other.url;

  @override
  int get hashCode => storeName.hashCode ^ url.hashCode;

  @override
  String toString() => 'GameStoreDto($storeName, url: $url)';
}
