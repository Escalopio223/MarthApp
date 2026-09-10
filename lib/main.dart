import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/liquid_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/auth_screen.dart';
import 'features/auth/presentation/screens/update_password_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización del SDK oficial de Supabase
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
    } catch (e) {
      debugPrint('Error al inicializar Supabase: $e');
    }
  }

  runApp(const MarthApp());
}

/// Instancia global del cliente de Supabase
SupabaseClient get supabase => Supabase.instance.client;

/// Getter seguro para verificar si el cliente ya está inicializado
SupabaseClient? get supabaseClient {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

class MarthApp extends StatefulWidget {
  final AuthController? authController;
  final ThemeController? themeController;

  const MarthApp({super.key, this.authController, this.themeController});

  @override
  State<MarthApp> createState() => _MarthAppState();
}

class _MarthAppState extends State<MarthApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = widget.themeController ?? ThemeController();
  }

  @override
  Widget build(BuildContext context) {
    return LiquidThemeScope(
      controller: _themeController,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: _themeController.currentTheme.themeData,
            home: AuthGate(
              authController: widget.authController,
              themeController: _themeController,
            ),
          );
        },
      ),
    );
  }
}

/// Enrutador raíz con precedencia estricta de eventos de autenticación
class AuthGate extends StatefulWidget {
  final AuthController? authController;
  final ThemeController? themeController;

  const AuthGate({super.key, this.authController, this.themeController});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthController _authController;
  bool _isPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? AuthController();
    _authController.addListener(_onAuthControllerChanged);

    // Escucha activa de eventos del ciclo de autenticación de Supabase
    try {
      supabaseClient?.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        debugPrint('[AuthGate] Evento recibido de Supabase: $event');

        if (event == AuthChangeEvent.passwordRecovery) {
          if (mounted) {
            setState(() {
              _isPasswordRecovery = true;
            });
          }
        } else if (event == AuthChangeEvent.signedOut) {
          if (mounted) {
            setState(() {
              _isPasswordRecovery = false;
            });
          }
        } else if (event == AuthChangeEvent.userUpdated) {
          if (mounted) {
            setState(() {
              _isPasswordRecovery = false;
            });
          }
        } else {
          if (mounted && !_authController.isRegistering) setState(() {});
        }
      });
    } catch (e) {
      debugPrint('[AuthGate] Listener onAuthStateChange no disponible: $e');
    }
  }

  void _onAuthControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authController.removeListener(_onAuthControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // =========================================================================
    // 1. REGLA ESTRICTA: PRECEDENCIA DE passwordRecovery SOBRE session != null
    // =========================================================================
    // Al pulsar el enlace de recuperación del correo, Supabase establece una
    // sesión temporal. Si evaluáramos 'session != null' antes, el usuario
    // entraría por error a HomeScreen. Por tanto, passwordRecovery tiene
    // máxima prioridad para forzar la actualización de contraseña.
    if (_isPasswordRecovery) {
      return UpdatePasswordScreen(
        controller: _authController,
        onPasswordUpdated: () {
          setState(() {
            _isPasswordRecovery = false;
          });
        },
      );
    }

    // 2. Sesión activa -> Pantalla Principal
    final session = supabaseClient?.auth.currentSession;
    if (!_authController.isRegistering &&
        (session != null || _authController.isAuthenticated)) {
      return HomeScreen(authController: _authController);
    }

    // 3. Sin sesión -> Pantalla de Autenticación Híbrida (Email + OAuth)
    return AuthScreen(controller: _authController);
  }
}
