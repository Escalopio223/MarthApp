import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/planificador/domain/models/evento_model.dart';
import '../../features/planificador/domain/models/recordatorio_tarea_model.dart';
import '../../features/planificador/domain/models/tarea_model.dart';
import 'notification_id_registry.dart';

/// Servicio central de notificaciones y alarmas locales del sistema operativo.
/// Funciona de forma 100% offline (sin wifi ni datos), garantizando alertas
/// precisas con gestión real de zona horaria y cumplimiento con Google Play.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'marthapp_reminders';
  static const String channelName = 'Recordatorios de Tareas y Eventos';
  static const String channelDescription =
      'Canal de alta prioridad para alarmas y recordatorios programados del Planificador';

  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _syncDebounceTimer;

  bool get isInitialized => _isInitialized;

  /// Inicializa el plugin, zonas horarias y canales del sistema operativo
  Future<void> initialize({
    FlutterLocalNotificationsPlugin? customPlugin,
  }) async {
    if (_isInitialized && customPlugin == null) return;

    final plugin = customPlugin ?? _plugin;

    // 1. Inicializar registro persistente de IDs
    await NotificationIdRegistry.instance.initialize();

    // 2. Configurar zonas horarias de forma real (evitando desfases con UTC)
    try {
      tz.initializeTimeZones();
      if (!kIsWeb) {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        final String timeZoneName = timezoneInfo.identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('[LocalNotificationService] Zona horaria configurada: $timeZoneName');
      }
    } catch (e) {
      debugPrint('[LocalNotificationService] Advertencia en zona horaria: $e. Usando fallback.');
    }

    // 3. Configuración por plataforma
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 4. Crear canal de notificación prioritario en Android (API 26+)
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        await androidPlugin.createNotificationChannel(channel);
      }
    }

    _isInitialized = true;
  }

  /// Solicita permisos de notificación en tiempo de ejecución (Android 13+ y iOS)
  Future<bool> solicitarPermisos() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Comprueba si el dispositivo tiene concedido el permiso de alarmas exactas
  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('[LocalNotificationService] Error al verificar exact alarms: $e');
      return false;
    }
  }

  /// Callback cuando el usuario toca una notificación local en el dispositivo
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[LocalNotificationService] Notificación pulsada: payload=${response.payload}');
  }

  /// Cancela cualquier timer de sincronización pendiente
  void cancelDebounceTimer() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;
    _isSyncing = false;
  }

  /// Calcula la fecha y hora programada como `tz.TZDateTime` en la zona horaria local.
  /// Si la fecha ya expiró respecto al momento actual, retorna `null`.
  tz.TZDateTime? calcularFechaProgramada(
    DateTime fechaNotificacion,
    String? horaNotificacion,
  ) {
    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
    }

    int hour = 9;
    int minute = 0;
    if (horaNotificacion != null && horaNotificacion.contains(':')) {
      final parts = horaNotificacion.split(':');
      hour = int.tryParse(parts[0]) ?? 9;
      minute = int.tryParse(parts[1]) ?? 0;
    }

    final scheduled = tz.TZDateTime(
      tz.local,
      fechaNotificacion.year,
      fechaNotificacion.month,
      fechaNotificacion.day,
      hour,
      minute,
    );

    final now = tz.TZDateTime.now(tz.local);
    if (scheduled.isBefore(now)) {
      return null;
    }

    return scheduled;
  }

  /// Programa de forma quirúrgica un recordatorio para una tarea específica
  Future<void> programarRecordatorioTarea({
    required String tareaId,
    required String tituloTarea,
    required RecordatorioTareaModel recordatorio,
  }) async {
    if (!_isInitialized || kIsWeb) return;

    final scheduledDate = calcularFechaProgramada(
      recordatorio.fechaNotificacion,
      recordatorio.horaNotificacion,
    );

    if (scheduledDate == null) {
      return;
    }

    final notifId = await NotificationIdRegistry.instance.obtenerOCrearId(
      recordatorio.id,
      tareaId,
    );

    final bool exactAllowed = await canScheduleExactAlarms();
    final AndroidScheduleMode scheduleMode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final String horaTexto = recordatorio.horaNotificacion ?? '09:00';
    final String body = 'Tienes una tarea pendiente para hoy a las $horaTexto';

    try {
      await _plugin.zonedSchedule(
        id: notifId,
        title: '⏰ Tarea: $tituloTarea',
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
        payload: 'tarea:$tareaId',
      );
      debugPrint('[LocalNotificationService] Recordatorio programado: id=$notifId ($tituloTarea a las $scheduledDate)');
    } catch (e) {
      debugPrint('[LocalNotificationService] Error al programar recordatorio de tarea $tareaId: $e');
    }
  }

  /// Programa de forma quirúrgica un recordatorio para un evento específico
  Future<void> programarRecordatorioEvento({
    required String eventoId,
    required String tituloEvento,
    required RecordatorioTareaModel recordatorio,
  }) async {
    if (!_isInitialized || kIsWeb) return;

    final scheduledDate = calcularFechaProgramada(
      recordatorio.fechaNotificacion,
      recordatorio.horaNotificacion,
    );

    if (scheduledDate == null) {
      return;
    }

    final notifId = await NotificationIdRegistry.instance.obtenerOCrearId(
      recordatorio.id,
      eventoId,
    );

    final bool exactAllowed = await canScheduleExactAlarms();
    final AndroidScheduleMode scheduleMode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final String horaTexto = recordatorio.horaNotificacion ?? '09:00';
    final String body = 'Tienes un evento agendado para hoy a las $horaTexto';

    try {
      await _plugin.zonedSchedule(
        id: notifId,
        title: '📅 Evento: $tituloEvento',
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
        payload: 'evento:$eventoId',
      );
      debugPrint('[LocalNotificationService] Recordatorio de evento programado: id=$notifId ($tituloEvento)');
    } catch (e) {
      debugPrint('[LocalNotificationService] Error al programar recordatorio de evento $eventoId: $e');
    }
  }

  /// Cancela quirúrgicamente todos los recordatorios locales programados para una tarea
  Future<void> cancelarRecordatoriosDeTarea(String tareaId) async {
    if (!_isInitialized || kIsWeb) return;

    try {
      final notifIds = await NotificationIdRegistry.instance
          .obtenerYRemoverIdsPorEntidad(tareaId);

      for (final id in notifIds) {
        await _plugin.cancel(id: id);
        debugPrint('[LocalNotificationService] Cancelado recordatorio id=$id de tarea=$tareaId');
      }
    } catch (e) {
      debugPrint('[LocalNotificationService] Error al cancelar recordatorios de tarea $tareaId: $e');
    }
  }

  /// Cancela quirúrgicamente todos los recordatorios locales programados para un evento
  Future<void> cancelarRecordatoriosDeEvento(String eventoId) async {
    if (!_isInitialized || kIsWeb) return;

    try {
      final notifIds = await NotificationIdRegistry.instance
          .obtenerYRemoverIdsPorEntidad(eventoId);

      for (final id in notifIds) {
        await _plugin.cancel(id: id);
        debugPrint('[LocalNotificationService] Cancelado recordatorio id=$id de evento=$eventoId');
      }
    } catch (e) {
      debugPrint('[LocalNotificationService] Error al cancelar recordatorios de evento $eventoId: $e');
    }
  }

  /// Cancela un recordatorio individual
  Future<void> cancelarRecordatorioIndividual(String recordatorioId, {String? entityId}) async {
    if (!_isInitialized || kIsWeb) return;

    try {
      final notifId = await NotificationIdRegistry.instance.removerId(
        recordatorioId,
        entityId: entityId,
      );
      if (notifId != null) {
        await _plugin.cancel(id: notifId);
      }
    } catch (e) {
      debugPrint('[LocalNotificationService] Error al cancelar recordatorio $recordatorioId: $e');
    }
  }

  /// Sincronización global protegida por Mutex y Debounce.
  /// Se ejecuta únicamente en Cold Start tras resolver el entorno inicial.
  Future<void> sincronizarRecordatoriosLocalmente({
    required List<TareaModel> tareas,
    required List<EventoModel> eventos,
    required String? currentUserId,
  }) async {
    if (!_isInitialized || kIsWeb) return;

    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_isSyncing) return;
      _isSyncing = true;

      try {
        debugPrint('[LocalNotificationService] Iniciando sincronización global de recordatorios...');

        // 1. Procesar tareas
        for (final tarea in tareas) {
          if (tarea.estaCompletada) {
            await cancelarRecordatoriosDeTarea(tarea.id);
            continue;
          }

          // Solo programar recordatorios de tareas asignadas al usuario actual o sin asignar
          final bool perteneceAUsuario =
              tarea.asignadoA == null ||
              tarea.asignadoA!.isEmpty ||
              tarea.asignadoA == currentUserId;

          if (perteneceAUsuario && tarea.recordatorios.isNotEmpty) {
            for (final rec in tarea.recordatorios) {
              await programarRecordatorioTarea(
                tareaId: tarea.id,
                tituloTarea: tarea.titulo,
                recordatorio: rec,
              );
            }
          }
        }

        // 2. Procesar eventos
        for (final evento in eventos) {
          if (evento.recordatorios.isNotEmpty) {
            for (final rec in evento.recordatorios) {
              await programarRecordatorioEvento(
                eventoId: evento.id,
                tituloEvento: evento.titulo,
                recordatorio: rec,
              );
            }
          }
        }

        debugPrint('[LocalNotificationService] Sincronización global completada.');
      } catch (e) {
        debugPrint('[LocalNotificationService] Error en sincronización global: $e');
      } finally {
        _isSyncing = false;
      }
    });
  }
}
