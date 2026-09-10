import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../domain/friend_code_manager.dart';
import '../widgets/add_friend_card.dart';
import '../widgets/friend_code_card.dart';
import '../widgets/theme_selector_card.dart';
import '../widgets/user_profile_card.dart';

/// Pantalla de Ajustes: perfil con username en tiempo real, selector de temas, amigos y sesión
class SettingsScreen extends StatefulWidget {
  final AuthController authController;
  final FriendCodeManager? friendCodeManager;
  final ThemeController? themeController;
  final FriendsController? friendsController;

  const SettingsScreen({
    super.key,
    required this.authController,
    this.friendCodeManager,
    this.themeController,
    this.friendsController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final FriendCodeManager _friendCodeManager;
  late final FriendsController _friendsController;
  final _friendCodeInputController = TextEditingController();
  String? _friendActionMessage;
  bool _isSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    final user = widget.authController.user;

    _friendsController = widget.friendsController ?? FriendsController();
    _friendsController.addListener(_onFriendsControllerUpdate);

    _friendCodeManager = widget.friendCodeManager ??
        FriendCodeManager(
          friendsService: _friendsController.friendsService,
          userId: user?.id,
        );
    _friendCodeManager.setUserId(user?.id);
    _friendCodeManager.addListener(_onCodeManagerUpdate);

    if (user != null && widget.friendsController == null) {
      _friendsController.initialize(user.id, defaultEmail: user.email);
    }
  }

  void _onCodeManagerUpdate() {
    if (mounted) setState(() {});
  }

  void _onFriendsControllerUpdate() {
    if (mounted) {
      if (_friendsController.friends.isNotEmpty) {
        _friendCodeManager.syncFriends(
          _friendsController.friends.map((f) => f.username).toList(),
        );
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _friendCodeManager.removeListener(_onCodeManagerUpdate);
    if (widget.friendCodeManager == null) {
      _friendCodeManager.dispose();
    }
    _friendsController.removeListener(_onFriendsControllerUpdate);
    if (widget.friendsController == null) {
      _friendsController.dispose();
    }
    _friendCodeInputController.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final code = _friendCodeInputController.text.trim();
    if (code.isEmpty) return;

    try {
      final user = widget.authController.user;
      await _friendCodeManager.addFriend(
        code,
        currentUserId: user?.id,
        service: _friendsController.friendsService,
      );
      _friendCodeInputController.clear();
      final lastAdded = _friendCodeManager.addedFriends.isNotEmpty
          ? _friendCodeManager.addedFriends.last
          : code;
      setState(() {
        _isSuccessMessage = true;
        _friendActionMessage = '¡Invitación enviada con éxito a @$lastAdded!';
      });
      if (user != null) {
        _friendsController.refresh();
      }
    } catch (e) {
      setState(() {
        _isSuccessMessage = false;
        _friendActionMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _openRealtimeFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendsScreen(friendsController: _friendsController),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.authController.signOut();
    if (mounted) {
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
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: LiquidTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
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
                  // 1. Tarjeta de perfil con edición de username y detección de colisiones
                  UserProfileCard(
                    email: email,
                    friendsController: _friendsController,
                  ),
                  const SizedBox(height: 24),

                  // 2. Acceso directo a Amigos y Conexiones en Tiempo Real
                  _buildRealtimeFriendsNavCard(),
                  const SizedBox(height: 24),

                  // 3. Selector dinámico de temas (10 temas en acordeón)
                  ThemeSelectorCard(
                    themeController: widget.themeController ??
                        LiquidThemeScope.of(context),
                  ),
                  const SizedBox(height: 24),

                  // 4. Tarjeta del código de amigo temporal (1 min)
                  FriendCodeCard(
                    friendCodeManager: _friendCodeManager,
                    onGenerateCode: () {
                      final u = widget.authController.user;
                      _friendCodeManager.generateNewCode(
                        userId: u?.id,
                        service: _friendsController.friendsService,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 5. Tarjeta para añadir amigo con código temporal
                  AddFriendCard(
                    inputController: _friendCodeInputController,
                    onAddFriend: _addFriend,
                    addedFriends: _friendCodeManager.addedFriends,
                    feedbackMessage: _friendActionMessage,
                    isSuccessMessage: _isSuccessMessage,
                  ),
                  const SizedBox(height: 28),

                  // 6. Botón de cierre de sesión
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeFriendsNavCard() {
    final pendingCount = _friendsController.pendingCount;
    final friendsCount = _friendsController.friends.length;

    return GlassCard(
      blur: 16.0,
      borderRadius: 22.0,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openRealtimeFriends,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LiquidTheme.primaryLiquid.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.people_alt_rounded,
                color: LiquidTheme.primaryLiquid,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amigos y Solicitudes',
                    style: TextStyle(
                      color: LiquidTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pendingCount > 0
                        ? '$pendingCount solicitud(es) pendiente(s)'
                        : '$friendsCount amigo(s) en tiempo real',
                    style: TextStyle(
                      color: pendingCount > 0
                          ? LiquidTheme.accentCoral
                          : LiquidTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: pendingCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: LiquidTheme.textSecondary,
              size: 16,
            ),
          ],
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
        icon: Icon(Icons.logout_rounded, color: LiquidTheme.accentCoral),
        label: Text(
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
