package com.example.marth_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.marth_app/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registrar e inicializar inmediatamente los canales prioritarios para Android 8.0+ (API 26+)
        createNotificationChannels()

        // Exponer método por si la capa Flutter invoca explícitamente la creación del canal
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "createNotificationChannel" || call.method == "createNotificationChannels") {
                createNotificationChannels()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            // 1. Canal prioritario para notificaciones push (FCM)
            val pushChannel = NotificationChannel(
                "marthapp_notifications",
                "Notificaciones MarthApp",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Canal de alta prioridad para avisos push y eventos de MarthApp"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
                enableLights(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(soundUri, audioAttributes)
            }

            // 2. Canal prioritario para recordatorios y alarmas locales programadas
            val reminderChannel = NotificationChannel(
                "marthapp_reminders",
                "Recordatorios de Tareas y Eventos",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Canal de alta prioridad para alarmas y recordatorios programados del Planificador"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                enableLights(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(soundUri, audioAttributes)
            }

            notificationManager.createNotificationChannels(listOf(pushChannel, reminderChannel))
        }
    }
}

