import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registro determinista y persistente para la correlación entre identificadores
/// UUID de la lógica de negocio (recordatorios de tareas y eventos) y los IDs enteros
/// de 32 bits requeridos por los sistemas de notificaciones locales de Android e iOS.
class NotificationIdRegistry {
  NotificationIdRegistry._();
  static final NotificationIdRegistry instance = NotificationIdRegistry._();

  static const String _keySeqId = 'notif_seq_id';
  static const String _keyRemToId = 'notif_rem_to_id';
  static const String _keyEntityToRems = 'notif_entity_to_rems';

  /// Límite máximo de enteros nativos en Android (Integer.MAX_VALUE = 2^31 - 1)
  static const int maxSafeInt32 = 2147483647;

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Caché en memoria para operaciones O(1)
  int _currentSeq = 0;
  final Map<String, int> _remToIdMap = {};
  final Map<String, List<String>> _entityToRemsMap = {};

  /// Inicializa el registro cargando el estado persistido desde SharedPreferences
  Future<void> initialize({SharedPreferences? customPrefs}) async {
    if (_isInitialized && customPrefs == null) return;

    _prefs = customPrefs ?? await SharedPreferences.getInstance();
    _currentSeq = _prefs!.getInt(_keySeqId) ?? 0;

    // Cargar mapa recordatorio_uuid -> notification_int_id
    final rawRemToId = _prefs!.getString(_keyRemToId);
    if (rawRemToId != null && rawRemToId.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawRemToId) as Map<String, dynamic>;
        _remToIdMap.clear();
        decoded.forEach((key, val) {
          if (val is int) {
            _remToIdMap[key] = val;
          } else if (val is num) {
            _remToIdMap[key] = val.toInt();
          }
        });
      } catch (e) {
        debugPrint('[NotificationIdRegistry] Error al decodificar remToId: $e');
      }
    }

    // Cargar índice entity_uuid -> [recordatorio_uuid...]
    final rawEntityToRems = _prefs!.getString(_keyEntityToRems);
    if (rawEntityToRems != null && rawEntityToRems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawEntityToRems) as Map<String, dynamic>;
        _entityToRemsMap.clear();
        decoded.forEach((key, val) {
          if (val is List) {
            _entityToRemsMap[key] = val.map((e) => e.toString()).toList();
          }
        });
      } catch (e) {
        debugPrint('[NotificationIdRegistry] Error al decodificar entityToRems: $e');
      }
    }

    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Genera el siguiente ID entero de 32 bits garantizando ciclo seguro y no-colisión
  int _generarSiguienteIdSeguro() {
    final activeIds = _remToIdMap.values.toSet();

    int candidate = _currentSeq;
    for (int attempts = 0; attempts < maxSafeInt32; attempts++) {
      candidate = (candidate + 1) % maxSafeInt32;
      if (candidate == 0) candidate = 1;

      // Si el ID generado no está ocupado actualmente por ningún recordatorio activo
      if (!activeIds.contains(candidate)) {
        _currentSeq = candidate;
        return candidate;
      }
    }

    // En caso extremo teórico de saturación total, reiniciar en 1
    _currentSeq = 1;
    return 1;
  }

  /// Obtiene el notification ID entero existente para el recordatorio dado,
  /// o genera y persiste un nuevo ID secuencial de 32 bits asociándolo a la entidad.
  Future<int> obtenerOCrearId(String recordatorioId, String entityId) async {
    await _ensureInitialized();

    final existing = _remToIdMap[recordatorioId];
    if (existing != null) {
      // Asegurar que esté indexado en la entidad correspondiente
      final remList = _entityToRemsMap[entityId] ??= [];
      if (!remList.contains(recordatorioId)) {
        remList.add(recordatorioId);
        await _guardarEntityToRems();
      }
      return existing;
    }

    final newId = _generarSiguienteIdSeguro();
    _remToIdMap[recordatorioId] = newId;

    final remList = _entityToRemsMap[entityId] ??= [];
    if (!remList.contains(recordatorioId)) {
      remList.add(recordatorioId);
    }

    await _guardarTodo();
    return newId;
  }

  /// Retorna el ID entero asignado a un recordatorio, o null si no existe
  Future<int?> obtenerId(String recordatorioId) async {
    await _ensureInitialized();
    return _remToIdMap[recordatorioId];
  }

  /// Retorna y remueve de forma atómica todos los IDs enteros asociados a una entidad
  /// (tarea o evento), limpiando el índice y el mapa para que puedan ser cancelados en el SO.
  Future<List<int>> obtenerYRemoverIdsPorEntidad(String entityId) async {
    await _ensureInitialized();

    final remIds = _entityToRemsMap.remove(entityId);
    if (remIds == null || remIds.isEmpty) {
      return const [];
    }

    final List<int> removedNotificationIds = [];
    for (final remId in remIds) {
      final notifId = _remToIdMap.remove(remId);
      if (notifId != null) {
        removedNotificationIds.add(notifId);
      }
    }

    await _guardarTodo();
    return removedNotificationIds;
  }

  /// Remueve un recordatorio individual y retorna su ID entero para cancelación
  Future<int?> removerId(String recordatorioId, {String? entityId}) async {
    await _ensureInitialized();

    final notifId = _remToIdMap.remove(recordatorioId);
    if (notifId == null) return null;

    if (entityId != null) {
      final rems = _entityToRemsMap[entityId];
      if (rems != null) {
        rems.remove(recordatorioId);
        if (rems.isEmpty) {
          _entityToRemsMap.remove(entityId);
        }
      }
    } else {
      // Buscar en todas las entidades si no se especificó entityId
      for (final entry in _entityToRemsMap.entries) {
        if (entry.value.contains(recordatorioId)) {
          entry.value.remove(recordatorioId);
          break;
        }
      }
    }

    await _guardarTodo();
    return notifId;
  }

  /// Retorna una copia de los IDs enteros actualmente registrados
  Future<List<int>> obtenerTodosLosIds() async {
    await _ensureInitialized();
    return _remToIdMap.values.toList();
  }

  /// Limpia todo el registro (útil para pruebas o reseteo)
  Future<void> clearAll() async {
    await _ensureInitialized();
    _currentSeq = 0;
    _remToIdMap.clear();
    _entityToRemsMap.clear();
    await _prefs?.remove(_keySeqId);
    await _prefs?.remove(_keyRemToId);
    await _prefs?.remove(_keyEntityToRems);
  }

  Future<void> _guardarTodo() async {
    if (_prefs == null) return;
    await _prefs!.setInt(_keySeqId, _currentSeq);
    await _prefs!.setString(_keyRemToId, jsonEncode(_remToIdMap));
    await _prefs!.setString(_keyEntityToRems, jsonEncode(_entityToRemsMap));
  }

  Future<void> _guardarEntityToRems() async {
    if (_prefs == null) return;
    await _prefs!.setString(_keyEntityToRems, jsonEncode(_entityToRemsMap));
  }
}
