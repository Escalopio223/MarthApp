import 'package:supabase_flutter/supabase_flutter.dart';

/// Manejo y traducción amigable de excepciones de autenticación
class AppAuthException implements Exception {
  final String message;

  AppAuthException(this.message);

  factory AppAuthException.fromSupabase(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return AppAuthException('El correo o la contraseña no son correctos.');
    }
    if (msg.contains('user already registered') ||
        msg.contains('user_already_exists')) {
      return AppAuthException('Ya existe una cuenta registrada con este correo.');
    }
    if (msg.contains('email not confirmed')) {
      return AppAuthException('Por favor, confirma tu correo antes de iniciar sesión.');
    }
    if (msg.contains('password should be at least')) {
      return AppAuthException('La contraseña debe tener al menos 6 caracteres.');
    }
    if (msg.contains('rate limit')) {
      return AppAuthException('Demasiados intentos. Por favor, espera unos momentos.');
    }
    if (msg.contains('error sending confirmation email') ||
        msg.contains('unexpected_failure')) {
      return AppAuthException(
          'Error del servidor de correo. Desactiva "Confirm email" en Supabase o revisa la configuración.');
    }

    return AppAuthException(e.message);
  }

  @override
  String toString() => message;
}
