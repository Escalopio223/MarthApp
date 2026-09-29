import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/friends/presentation/controllers/friends_controller.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';

/// Modelo normalizado e inmutable para metadatos de notificaciones
/// provenientes tanto de FCM Push como de alarmas locales.
class NotificationPayload {
  final String? type;
  final String? title;
  final String? body;
  final String? targetId;
  final String? tareaId;
  final String? eventoId;
  final String? entornoId;
  final String? sesionId;
  final String? requestId;
  final Map<String, dynamic> rawData;

  const NotificationPayload({
    this.type,
    this.title,
    this.body,
    this.targetId,
    this.tareaId,
    this.eventoId,
    this.entornoId,
    this.sesionId,
    this.requestId,
    this.rawData = const {},
  });

  bool get isPlanner =>
      type == 'task_reminder' ||
      type == 'tarea' ||
      type == 'evento' ||
      type == 'reparto_sesion' ||
      type == 'task_comment';

  bool get isFriends => type == 'friend_request';

  bool get isEnvironment => type == 'environment_invitation';

  /// Constructor a partir de RemoteMessage (FCM)
  factory NotificationPayload.fromData({
    required Map<String, dynamic> data,
    String? notificationTitle,
    String? notificationBody,
  }) {
    final type = data['type']?.toString();
    final tareaId = data['tarea_id']?.toString() ?? data['tareaId']?.toString();
    final eventoId = data['evento_id']?.toString() ?? data['eventoId']?.toString();
    final entornoId = data['entorno_id']?.toString() ?? data['entornoId']?.toString();
    final sesionId = data['sesion_id']?.toString() ?? data['sesionId']?.toString();
    final requestId = data['request_id']?.toString() ?? data['requestId']?.toString();
    final targetId = tareaId ?? eventoId ?? sesionId ?? requestId ?? data['id']?.toString();

    final title = notificationTitle ?? data['title']?.toString();
    final body = notificationBody ?? data['body']?.toString();

    return NotificationPayload(
      type: type,
      title: title,
      body: body,
      targetId: targetId,
      tareaId: tareaId,
      eventoId: eventoId,
      entornoId: entornoId,
      sesionId: sesionId,
      requestId: requestId,
      rawData: Map<String, dynamic>.unmodifiable(data),
    );
  }

  /// Constructor a partir del payload de notificaciones locales (string o JSON)
  factory NotificationPayload.fromLocalPayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const NotificationPayload();
    }

    final trimmed = raw.trim();

    // 1. Si es formato JSON estructurado
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
        return NotificationPayload.fromData(
          data: decoded,
          notificationTitle: decoded['title']?.toString(),
          notificationBody: decoded['body']?.toString(),
        );
      } catch (_) {
        // En caso de error, intentar como string simple
      }
    }

    // 2. Si es formato clave:valor (ej. "tarea:uuid" o "evento:uuid")
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      final prefix = parts[0].trim();
      final id = parts.sublist(1).join(':').trim();

      if (prefix == 'tarea') {
        return NotificationPayload(
          type: 'tarea',
          tareaId: id,
          targetId: id,
          rawData: {'type': 'tarea', 'tarea_id': id},
        );
      } else if (prefix == 'evento') {
        return NotificationPayload(
          type: 'evento',
          eventoId: id,
          targetId: id,
          rawData: {'type': 'evento', 'evento_id': id},
        );
      } else {
        return NotificationPayload(
          type: prefix,
          targetId: id,
          rawData: {'type': prefix, 'id': id},
        );
      }
    }

    return NotificationPayload(
      type: trimmed,
      targetId: trimmed,
      rawData: {'raw': trimmed},
    );
  }

  @override
  String toString() {
    return 'NotificationPayload(type: $type, targetId: $targetId, tareaId: $tareaId, eventoId: $eventoId, entornoId: $entornoId)';
  }
}

/// Coordinador singleton para la captura, encolamiento y navegación determinista
/// de notificaciones (push y locales) evitando pantallas en blanco o carreras
/// de hidratación de sesión de usuario.
class NotificationNavigationService {
  NotificationNavigationService._();
  static final NotificationNavigationService instance =
      NotificationNavigationService._();

  /// GlobalKey del MaterialApp para acceso al Navigator en cualquier estado
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final StreamController<NotificationPayload> _streamController =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get onNotificationTapped =>
      _streamController.stream;

  NotificationPayload? _pendingPayload;
  NotificationPayload? get pendingPayload => _pendingPayload;

  /// Registra un payload pendiente para cuando la UI esté completamente hidratada (Killed state)
  void setPendingPayload(NotificationPayload payload) {
    debugPrint('[NotificationNavigationService] Payload pendiente encolado: $payload');
    _pendingPayload = payload;
    _streamController.add(payload);
  }

  /// Consume y limpia el payload pendiente acumulado en el arranque en frío
  NotificationPayload? consumePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    if (payload != null) {
      debugPrint('[NotificationNavigationService] Payload pendiente consumido: $payload');
    }
    return payload;
  }

  /// Emite evento de notificación pulsada (Background o Foreground)
  void emitNotificationTapped(NotificationPayload payload) {
    debugPrint('[NotificationNavigationService] Emisión de pulsación: $payload');
    _pendingPayload = payload;
    _streamController.add(payload);
  }

  /// Ejecuta la navegación segura a la pantalla correspondiente según el payload
  Future<bool> executeNavigation(
    NotificationPayload payload, {
    BuildContext? context,
    void Function(int tabIndex)? onSelectTab,
  }) async {
    final navContext = context ?? navigatorKey.currentContext;
    if (navContext == null) {
      debugPrint('[NotificationNavigationService] Imposible navegar: Contexto no montado aún.');
      return false;
    }

    // Verificar si hay sesión activa antes de redirigir a vistas protegidas
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint('[NotificationNavigationService] Sesión no autenticada. Conservando payload para post-login.');
        return false;
      }
    } catch (_) {
      return false;
    }

    debugPrint('[NotificationNavigationService] Despachando navegación para: ${payload.type}');

    // 1. Solicitudes de amistad -> Abrir FriendsScreen
    if (payload.isFriends) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final friendsController = FriendsController();
        friendsController.initialize(user.id, defaultEmail: user.email);
        await Navigator.of(navContext).push(
          MaterialPageRoute(
            builder: (_) => FriendsScreen(friendsController: friendsController),
          ),
        );
        return true;
      }
    }

    // 2. Invitación a entorno -> Cambiar a pestaña 0 (Entornos) o abrir FriendsScreen
    if (payload.isEnvironment) {
      if (onSelectTab != null) {
        onSelectTab(0);
        return true;
      }
    }

    // 3. Recordatorio de tarea, evento o reparto de sesión -> Cambiar a pestaña 2 (Planificador)
    if (payload.isPlanner) {
      if (onSelectTab != null) {
        onSelectTab(2);
        return true;
      }
    }

    return false;
  }

  void dispose() {
    _streamController.close();
  }
}
