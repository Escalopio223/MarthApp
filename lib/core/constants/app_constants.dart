/// Constantes globales de la aplicación MarthApp
class AppConstants {
  AppConstants._();

  static const String appName = 'MarthApp';

  // Esquema de Deep Linking para aplicaciones móviles (Android e iOS)
  static const String mobileDeepLinkScheme = 'io.supabase.marthapp';
  static const String loginCallbackPath = 'login-callback';
  static const String resetCallbackPath = 'reset-callback';

  // Configuración de expiración de códigos temporales de amigo
  static const int friendCodeDurationSeconds = 60;

  // Formato del código de amigo
  static const String friendCodePrefix = 'MARTH-';

  // Timeouts y límites de reintento
  static const int defaultRateLimitSeconds = 60;
}
