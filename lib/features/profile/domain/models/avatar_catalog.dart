import 'package:flutter/material.dart';

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
