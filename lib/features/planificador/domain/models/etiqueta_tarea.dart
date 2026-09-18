import 'package:flutter/material.dart';

/// Modelo de una Etiqueta o Categoría para clasificar y organizar las tareas del hogar.
@immutable
class EtiquetaTarea {
  final String id;
  final String nombre;
  final IconData icono;
  final Color color;

  const EtiquetaTarea({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.color,
  });

  /// Catálogo predeterminado de etiquetas del hogar armoniosas con el diseño de MarthApp
  static const List<EtiquetaTarea> etiquetasPredeterminadas = [
    EtiquetaTarea(
      id: 'Limpieza',
      nombre: 'Limpieza',
      icono: Icons.cleaning_services_rounded,
      color: Color(0xFF06B6D4), // Cyan
    ),
    EtiquetaTarea(
      id: 'Cocina',
      nombre: 'Cocina',
      icono: Icons.restaurant_rounded,
      color: Color(0xFFF59E0B), // Amber / Naranja cálido
    ),
    EtiquetaTarea(
      id: 'Compras',
      nombre: 'Compras',
      icono: Icons.shopping_bag_rounded,
      color: Color(0xFF10B981), // Emerald
    ),
    EtiquetaTarea(
      id: 'Mascotas',
      nombre: 'Mascotas',
      icono: Icons.pets_rounded,
      color: Color(0xFFA855F7), // Purple
    ),
    EtiquetaTarea(
      id: 'Hogar',
      nombre: 'Hogar',
      icono: Icons.home_rounded,
      color: Color(0xFF6366F1), // Indigo
    ),
    EtiquetaTarea(
      id: 'Mantenimiento',
      nombre: 'Mantenimiento',
      icono: Icons.build_rounded,
      color: Color(0xFF3B82F6), // Blue
    ),
    EtiquetaTarea(
      id: 'Personal',
      nombre: 'Personal',
      icono: Icons.person_rounded,
      color: Color(0xFFEC4899), // Pink
    ),
  ];

  /// Busca la etiqueta correspondiente por nombre ignorando mayúsculas/minúsculas
  static EtiquetaTarea? buscar(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) return null;
    final clean = nombre.trim().toLowerCase();

    // Normalizar alias habituales (singular a plural o equivalentes)
    if (clean == 'mascota') return buscar('Mascotas');
    if (clean == 'compra') return buscar('Compras');
    if (clean == 'ropa') return buscar('Limpieza');

    for (final e in etiquetasPredeterminadas) {
      if (e.nombre.toLowerCase() == clean || e.id.toLowerCase() == clean) {
        return e;
      }
    }
    // Si es una etiqueta personalizada que no está en el catálogo predeterminado
    return EtiquetaTarea(
      id: nombre,
      nombre: nombre,
      icono: Icons.label_rounded,
      color: const Color(0xFF8B5CF6),
    );
  }
}
