import 'package:flutter/foundation.dart';

/// Controlador de cancelación (AbortController) para operaciones asíncronas en Ocio (Leisure).
/// Permite abortar peticiones HTTP en vuelo de APIs externas lentas (Open Library, IGDB, TMDB)
/// y descartar respuestas obsoletas cuando el usuario salta a otro tipo de medio, pestaña o pantalla.
class LeisureAbortController {
  bool _isAborted = false;
  final List<VoidCallback> _onAbortCallbacks = [];

  bool get isAborted => _isAborted;

  /// Registra un callback que se ejecutará en cuanto se invoque `abort()`.
  /// Si el controlador ya está abortado, la acción se ejecuta inmediatamente.
  void onAbort(VoidCallback callback) {
    if (_isAborted) {
      try {
        callback();
      } catch (_) {}
    } else {
      _onAbortCallbacks.add(callback);
    }
  }

  /// Cancela y aborta todas las operaciones asociadas a este controlador.
  void abort() {
    if (_isAborted) return;
    _isAborted = true;
    for (final callback in _onAbortCallbacks) {
      try {
        callback();
      } catch (_) {}
    }
    _onAbortCallbacks.clear();
  }
}
