import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/friend_code_manager.dart';
import '../widgets/add_friend_card.dart';
import '../widgets/friend_code_card.dart';
import '../widgets/user_profile_card.dart';

/// Pantalla de Ajustes modularizada: perfil, códigos de amigo de 1 minuto y sesión
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
    await widget.authController.signOut();
    if (mounted) {
      // Regresa a la ruta raíz donde AuthGate gestiona declarativamente la pantalla de Auth
      Navigator.of(context).popUntil((route) => route.isFirst);
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Tarjeta de perfil
                  UserProfileCard(email: email),
                  const SizedBox(height: 24),

                  // 2. Tarjeta del código de amigo (1 min)
                  FriendCodeCard(
                    friendCodeManager: _friendCodeManager,
                    onGenerateCode: () => _friendCodeManager.generateNewCode(),
                  ),
                  const SizedBox(height: 24),

                  // 3. Tarjeta para añadir amigo con código
                  AddFriendCard(
                    inputController: _friendCodeInputController,
                    onAddFriend: _addFriend,
                    addedFriends: _friendCodeManager.addedFriends,
                    feedbackMessage: _friendActionMessage,
                    isSuccessMessage: _isSuccessMessage,
                  ),
                  const SizedBox(height: 28),

                  // 4. Botón de cierre de sesión
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return NeumorphicContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(vertical: 6),
      baseColor: LiquidTheme.surfaceDark,
      child: TextButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, color: LiquidTheme.accentCoral),
        label: const Text(
          'Cerrar Sesión',
          style: TextStyle(
            color: LiquidTheme.accentCoral,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
