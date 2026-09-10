import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../domain/friend_code_manager.dart';

class SettingsScreen extends StatefulWidget {
  final AuthController authController;
  final FriendCodeManager? friendCodeManager;

  const SettingsScreen({
    super.key,
    required this.authController,
    this.friendCodeManager,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final FriendCodeManager _friendCodeManager;
  final _friendCodeInputController = TextEditingController();
  String? _friendActionMessage;
  bool _isSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _friendCodeManager = widget.friendCodeManager ?? FriendCodeManager();
    _friendCodeManager.addListener(_onCodeManagerUpdate);
  }

  void _onCodeManagerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _friendCodeManager.removeListener(_onCodeManagerUpdate);
    if (widget.friendCodeManager == null) {
      _friendCodeManager.dispose();
    }
    _friendCodeInputController.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final code = _friendCodeInputController.text.trim();
    if (code.isEmpty) return;

    try {
      await _friendCodeManager.addFriend(code);
      _friendCodeInputController.clear();
      setState(() {
        _isSuccessMessage = true;
        _friendActionMessage = '¡Amigo ($code) añadido con éxito!';
      });
    } catch (e) {
      setState(() {
        _isSuccessMessage = false;
        _friendActionMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _logout() async {
    await widget.authController.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => AuthScreen(controller: widget.authController),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.user;
    final email = user?.email ?? 'usuario@marthapp.com';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: LiquidTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ajustes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: LiquidTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de Perfil de Usuario (Glassmorphism)
                GlassCard(
                  blur: 16.0,
                  borderRadius: 22.0,
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LiquidTheme.liquidPrimaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  LiquidTheme.primaryCyan.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cuenta Activa',
                              style: TextStyle(
                                color: LiquidTheme.primaryCyan,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(
                                color: LiquidTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sección Sistema de Código de Amigo (1 minuto)
                GlassCard(
                  blur: 18.0,
                  borderRadius: 24.0,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: LiquidTheme.primaryCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.group_add_rounded,
                              color: LiquidTheme.primaryCyan,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Mi Código de Amigo',
                              style: TextStyle(
                                color: LiquidTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Comparte tu código temporal. Es válido durante 1 minuto exacto y luego se elimina por seguridad.',
                        style: TextStyle(
                          color: LiquidTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Estado del Código
                      if (_friendCodeManager.hasActiveCode) ...[
                        // Caja Neumórfica para el código activo
                        NeumorphicContainer(
                          borderRadius: 18,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _friendCodeManager.currentCode!,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 3,
                                      color: LiquidTheme.primaryCyan,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded,
                                        color: LiquidTheme.textSecondary),
                                    tooltip: 'Copiar código',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                          text: _friendCodeManager.currentCode!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Código copiado al portapapeles'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Barra de Progreso del Tiempo (1 minuto)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _friendCodeManager.progress,
                                  minHeight: 8,
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _friendCodeManager.remainingSeconds <= 15
                                        ? LiquidTheme.accentCoral
                                        : LiquidTheme.accentEmerald,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '⏳ Expira en ${_friendCodeManager.remainingSeconds}s',
                                    style: TextStyle(
                                      color: _friendCodeManager.remainingSeconds <= 15
                                          ? LiquidTheme.accentCoral
                                          : LiquidTheme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Duración: 1 min',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else if (_friendCodeManager.isExpired) ...[
                        // Estado cuando expiró
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: LiquidTheme.accentCoral.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: LiquidTheme.accentCoral.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.timer_off_rounded,
                                  color: LiquidTheme.accentCoral, size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'El código ha expirado y ha sido eliminado automáticamente.',
                                  style: TextStyle(
                                    color: LiquidTheme.accentCoral,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Estado inicial antes de generar
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: LiquidTheme.primaryCyan, size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No tienes ningún código activo. Pulsa el botón para generar uno válido durante 1 minuto.',
                                  style: TextStyle(
                                    color: LiquidTheme.textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Botón para generar nuevo código
                      LiquidButton(
                        text: _friendCodeManager.hasActiveCode
                            ? 'Regenerar Código'
                            : 'Generar Código (1 min)',
                        icon: Icons.refresh_rounded,
                        height: 48,
                        gradient: LiquidTheme.liquidPrimaryGradient,
                        onPressed: () {
                          _friendCodeManager.generateNewCode();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sección Añadir Amigo con Código
                GlassCard(
                  blur: 18.0,
                  borderRadius: 24.0,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_add_rounded,
                              color: LiquidTheme.accentEmerald, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Añadir Amigo con Código',
                            style: TextStyle(
                              color: LiquidTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _friendCodeInputController,
                        style: const TextStyle(
                          color: LiquidTheme.textPrimary,
                          letterSpacing: 1.5,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Ej. MARTH-8K2A',
                          prefixIcon: Icon(Icons.key_rounded,
                              color: LiquidTheme.accentEmerald),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LiquidButton(
                        text: 'Añadir Amigo',
                        icon: Icons.check_rounded,
                        height: 48,
                        gradient: LiquidTheme.liquidEmeraldGradient,
                        onPressed: _addFriend,
                      ),
                      if (_friendActionMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _friendActionMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isSuccessMessage
                                ? LiquidTheme.accentEmerald
                                : LiquidTheme.accentCoral,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      // Lista de amigos añadidos
                      if (_friendCodeManager.addedFriends.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 12),
                        const Text(
                          'Amigos Añadidos:',
                          style: TextStyle(
                            color: LiquidTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _friendCodeManager.addedFriends.map((f) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: LiquidTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: LiquidTheme.accentEmerald
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person,
                                      size: 14,
                                      color: LiquidTheme.accentEmerald),
                                  const SizedBox(width: 6),
                                  Text(
                                    f,
                                    style: const TextStyle(
                                      color: LiquidTheme.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Botón Neumórfico de Cerrar Sesión
                NeumorphicContainer(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  baseColor: LiquidTheme.surfaceDark,
                  child: TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        color: LiquidTheme.accentCoral),
                    label: const Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        color: LiquidTheme.accentCoral,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
