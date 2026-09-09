import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si la clave ya está configurada, inicializamos Supabase al arrancar
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

/// Instancia global del cliente de Supabase recomendada por la documentación oficial
SupabaseClient get supabase => Supabase.instance.client;

/// Getter seguro para verificar si el cliente ya está inicializado
SupabaseClient? get supabaseClient {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

class MarthApp extends StatelessWidget {
  const MarthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MarthApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3ECF8E), // Verde insignia de Supabase
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3ECF8E),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const SupabaseStatusScreen(),
    );
  }
}

class SupabaseStatusScreen extends StatefulWidget {
  const SupabaseStatusScreen({super.key});

  @override
  State<SupabaseStatusScreen> createState() => _SupabaseStatusScreenState();
}

class _SupabaseStatusScreenState extends State<SupabaseStatusScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isConnecting = false;
  String? _statusMessage;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured && supabaseClient != null) {
      _testConnection();
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = null;
    });

    try {
      // Verificamos conexión consultando el estado de la sesión
      final client = supabaseClient;
      if (client == null) {
        throw Exception('El cliente de Supabase no está inicializado.');
      }

      // Hacemos una comprobación de conectividad al endpoint de Supabase
      final session = client.auth.currentSession;
      setState(() {
        _isConnected = true;
        _statusMessage = 'Conectado exitosamente con Supabase.\n'
            'Sesión activa: ${session != null ? "Sí" : "Sin sesión (anónimo)"}';
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Error al verificar conexión: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _manualConnect() async {
    final inputKey = _keyController.text.trim();
    if (inputKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa tu anon key')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = null;
    });

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: inputKey,
      );
      await _testConnection();
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Fallo en la conexión: $e';
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfigured = SupabaseConfig.isConfigured || supabaseClient != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MarthApp',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected
                          ? Icons.cloud_done_rounded
                          : (isConfigured
                              ? Icons.cloud_queue_rounded
                              : Icons.warning_amber_rounded),
                      size: 64,
                      color: _isConnected
                          ? const Color(0xFF3ECF8E)
                          : (isConfigured
                              ? theme.colorScheme.primary
                              : Colors.amber),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Estado de Supabase',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      SupabaseConfig.url,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 32),
                    if (_isConnecting) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Verificando conexión con Supabase...'),
                    ] else if (_isConnected) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3ECF8E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF3ECF8E),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _statusMessage ?? 'Conexión exitosa',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _testConnection,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Comprobar de nuevo'),
                      ),
                    ] else ...[
                      Text(
                        isConfigured
                            ? 'Listo para conectar'
                            : 'Falta configurar la anonKey',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isConfigured
                            ? 'El cliente está inicializado. Pulsa el botón para probar la conexión.'
                            : 'Para conectarse a Supabase necesitas la "anon key" pública de tu proyecto.\n'
                                'La encuentras en tu Dashboard de Supabase > Project Settings > API.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (!isConfigured) ...[
                        TextField(
                          controller: _keyController,
                          decoration: const InputDecoration(
                            labelText: 'Supabase anonKey',
                            hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.key),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _manualConnect,
                          icon: const Icon(Icons.link),
                          label: const Text('Conectar ahora'),
                        ),
                      ] else ...[
                        FilledButton.icon(
                          onPressed: _testConnection,
                          icon: const Icon(Icons.cloud_sync),
                          label: const Text('Probar conexión'),
                        ),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
