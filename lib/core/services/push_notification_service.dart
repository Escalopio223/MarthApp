import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_notification_service.dart';
import 'notification_navigation_service.dart';

/// Manejador de notificaciones en segundo plano (Background/Terminated).
/// Debe ser una función de nivel superior con la anotación @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Si ya está inicializado o en plataforma no soportada
  }
  debugPrint('[PushNotificationService] Push en segundo plano recibido: ${message.messageId} - ${message.notification?.title} - data: ${message.data}');

  // Si se trata de un mensaje data-only con contenido visible que despierta el proceso en background
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title']?.toString();
    final body = message.data['body']?.toString() ?? '';
    if (title != null && title.isNotEmpty) {
      try {
        await LocalNotificationService.instance.mostrarNotificacionInmediata(
          title: title,
          body: body,
          payload: jsonEncode(message.data),
        );
      } catch (e) {
        debugPrint('[PushNotificationService] Error al mostrar alerta background: $e');
      }
    }
  }
}

/// Servicio singleton para la gestión global de notificaciones push vía FCM y Supabase.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.marth_app/notifications');

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _isInitialized = false;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;

  String? get currentToken => _currentToken;
  bool get isInitialized => _isInitialized;

  /// Asegura el registro explícito de canales nativos en Android (API 26+) con importancia máxima
  Future<void> _inicializarCanalesAndroid() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('createNotificationChannels');
        debugPrint('[PushNotificationService] Canales Android registrados con prioridad máxima.');
      } catch (e) {
        try {
          await _nativeChannel.invokeMethod('createNotificationChannel');
        } catch (_) {}
        debugPrint('[PushNotificationService] Registro de canal completado con fallback: $e');
      }
    }
  }

  /// Inicializa el servicio de notificaciones push
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Inicializar canales nativos obligatorios en Android 8.0+ (API 26+)
      await _inicializarCanalesAndroid();

      // 2. Registrar manejador de background de nivel superior
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Solicitar permisos de notificación (Android 13+ y iOS)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[PushNotificationService] Estado de autorización FCM: ${settings.authorizationStatus}');

      // 4. Configurar presentación en primer plano (iOS)
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Obtener token FCM inicial
      _currentToken = await _fcm.getToken();
      debugPrint('[PushNotificationService] Token FCM obtenido: ${_currentToken != null ? "${_currentToken!.substring(0, 10)}..." : "null"}');

      // Escuchar actualización o refresco de token
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        debugPrint('[PushNotificationService] Token FCM refrescado.');
        sincronizarTokenConSupabase(token: newToken);
      });

      // 6. Configurar listeners de primer plano
      FirebaseMessaging.onMessage.listen(_onForegroundMessageReceived);

      // 7. Configurar listener cuando el usuario abre la notificación desde background
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);

      // 8. Verificar si la app se abrió desde una notificación en estado terminado (Killed state)
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[PushNotificationService] App abierta desde estado TERMINADO con FCM: ${initialMessage.data}');
        final payload = NotificationPayload.fromData(
          data: initialMessage.data,
          notificationTitle: initialMessage.notification?.title,
          notificationBody: initialMessage.notification?.body,
        );
        NotificationNavigationService.instance.setPendingPayload(payload);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[PushNotificationService] Inicialización parcial o plataforma no configurada para FCM: $e');
    }
  }

  /// Sincroniza el token del dispositivo con la tabla `usuario_fcm_tokens` en Supabase
  Future<void> sincronizarTokenConSupabase({
    String? token,
    String? entornoId,
    SupabaseClient? client,
  }) async {
    final tokenToSync = token ?? _currentToken;
    if (tokenToSync == null || tokenToSync.trim().isEmpty) return;

    final supabaseClient = client ?? Supabase.instance.client;
    final user = supabaseClient.auth.currentUser;
    if (user == null) {
      debugPrint('[PushNotificationService] No hay usuario autenticado para vincular el token FCM.');
      return;
    }

    try {
      String infoDispositivo = 'Flutter App';
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          infoDispositivo = 'Android Device';
        } else if (Platform.isIOS) {
          infoDispositivo = 'iOS Device';
        }
      } else {
        infoDispositivo = 'Web Browser';
      }

      final payload = <String, dynamic>{
        'user_id': user.id,
        'fcm_token': tokenToSync,
        'dispositivo_info': infoDispositivo,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (entornoId != null && entornoId.isNotEmpty) {
        payload['entorno_id'] = entornoId;
      }

      await supabaseClient
          .from('usuario_fcm_tokens')
          .upsert(payload, onConflict: 'fcm_token');

      debugPrint('[PushNotificationService] Token FCM sincronizado con Supabase para usuario ${user.id}.');
    } catch (e) {
      debugPrint('[PushNotificationService] Error al sincronizar token FCM con Supabase: $e');
    }
  }

  /// Maneja mensajes recibidos mientras la app está abierta en primer plano.
  /// En Android, FCM no renderiza heads-up banners en primer plano automáticamente,
  /// por lo que invocamos explícitamente LocalNotificationService para garantizar la alerta.
  void _onForegroundMessageReceived(RemoteMessage message) {
    debugPrint('[PushNotificationService] Mensaje en primer plano: ${message.notification?.title} - ${message.notification?.body}');

    if (!kIsWeb && Platform.isAndroid) {
      final title = message.notification?.title ?? message.data['title']?.toString();
      final body = message.notification?.body ?? message.data['body']?.toString() ?? '';

      if (title != null && title.isNotEmpty) {
        LocalNotificationService.instance.mostrarNotificacionInmediata(
          title: title,
          body: body,
          payload: jsonEncode(message.data),
          channelId: 'marthapp_notifications',
          channelName: 'Notificaciones MarthApp',
        );
      }
    }
  }

  /// Maneja el clic en la notificación cuando el usuario abre la app desde background
  void _onNotificationOpenedApp(RemoteMessage message) {
    debugPrint('[PushNotificationService] Notificación abierta desde background: ${message.data}');
    final payload = NotificationPayload.fromData(
      data: message.data,
      notificationTitle: message.notification?.title,
      notificationBody: message.notification?.body,
    );
    NotificationNavigationService.instance.emitNotificationTapped(payload);
  }

  /// Libera listeners
  void dispose() {
    _tokenRefreshSub?.cancel();
  }
}

