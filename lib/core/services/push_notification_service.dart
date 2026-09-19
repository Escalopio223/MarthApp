import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manejador de notificaciones en segundo plano (Background/Terminated).
/// Debe ser una función de nivel superior con la anotación @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Si ya está inicializado o en plataforma no soportada
  }
  debugPrint('[PushNotificationService] Push en segundo plano recibido: ${message.messageId} - ${message.notification?.title}');
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

  /// Asegura el registro explícito del canal nativo en Android (API 26+) con importancia máxima
  Future<void> _inicializarCanalAndroid() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('createNotificationChannel');
        debugPrint('[PushNotificationService] Canal Android "marthapp_notifications" registrado con prioridad máxima.');
      } catch (e) {
        debugPrint('[PushNotificationService] Advertencia al registrar canal Android: $e');
      }
    }
  }

  /// Inicializa el servicio de notificaciones push
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Inicializar canal nativo obligatorio en Android 8.0+ (API 26+)
      await _inicializarCanalAndroid();

      // 2. Registrar manejador de background
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

      debugPrint('[PushNotificationService] Estado de autorización: ${settings.authorizationStatus}');

      // 4. Configurar presentación en primer plano
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

      // Configurar listeners de primer plano
      FirebaseMessaging.onMessage.listen(_onForegroundMessageReceived);

      // Configurar listener cuando el usuario abre la notificación desde background
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);

      // Verificar si la app se abrió desde una notificación terminada
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _onNotificationOpenedApp(initialMessage);
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

  /// Maneja mensajes recibidos mientras la app está abierta en primer plano
  void _onForegroundMessageReceived(RemoteMessage message) {
    debugPrint('[PushNotificationService] Mensaje en primer plano: ${message.notification?.title} - ${message.notification?.body}');
    // Los datos adicionales pueden ser consumidos por controladores o notificadores locales
  }

  /// Maneja el clic en la notificación cuando el usuario abre la app
  void _onNotificationOpenedApp(RemoteMessage message) {
    debugPrint('[PushNotificationService] Notificación abierta por usuario: ${message.data}');
    final type = message.data['type'];
    if (type == 'friend_request') {
      // Redirigir o emitir evento para solicitudes de amistad
    } else if (type == 'environment_invitation') {
      // Redirigir o emitir evento para invitaciones
    } else if (type == 'task_reminder' ||
        type == 'reparto_sesion' ||
        type == 'task_comment') {
      // Redirigir a la pantalla del planificador / detalle de tarea
    }
  }

  /// Libera listeners
  void dispose() {
    _tokenRefreshSub?.cancel();
  }
}
