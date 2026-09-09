/// Configuración centralizada de Supabase para MarthApp.
///
/// Como buena práctica en producción, la URL base no debe incluir '/rest/v1/'
/// debido a que el SDK oficial (`supabase_flutter`) concatena automáticamente
/// las rutas correspondientes para Auth (/auth/v1), REST (/rest/v1), Storage (/storage/v1)
/// y Realtime.
class SupabaseConfig {
  SupabaseConfig._();

  /// URL base del proyecto Supabase
  static const String url = 'https://cntspvnxrmqchvtcdiwv.supabase.co';

  /// Publishable Key oficial requerida por el API Gateway de Supabase.
  /// Puede pasarse en tiempo de compilación con:
  /// `--dart-define=SUPABASE_PUBLISHABLE_KEY=tu_clave` o configurarse aquí.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_s7GVGzdUiHuyw0jgf-ICEA_f_OvHlHb',
  );

  /// Alias de conveniencia retrocompatible
  static String get anonKey => publishableKey;

  /// Validador para determinar si la clave pública ha sido configurada
  static bool get isConfigured =>
      publishableKey.isNotEmpty &&
      publishableKey != 'YOUR_SUPABASE_PUBLISHABLE_KEY';
}
