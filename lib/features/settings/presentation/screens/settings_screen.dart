import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../domain/friend_code_manager.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../widgets/theme_selector_card.dart';
import '../widgets/user_profile_card.dart';

/// Pantalla de Ajustes: perfil con avatar en tiempo real, selector de temas, amigos y sesión
class SettingsScreen extends StatefulWidget {
  final AuthController authController;
  final FriendCodeManager? friendCodeManager;
  final ThemeController? themeController;
  final FriendsController? friendsController;
  final ProfileController? profileController;

  const SettingsScreen({
    super.key,
    required this.authController,
    this.friendCodeManager,
    this.themeController,
    this.friendsController,
    this.profileController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final FriendsController _friendsController;
  late final ProfileController _profileController;

  @override
  void initState() {
    super.initState();
    final user = widget.authController.user;

    _friendsController = widget.friendsController ?? FriendsController();
    _friendsController.addListener(_onControllerUpdate);

    _profileController = widget.profileController ?? ProfileController();
    _profileController.addListener(_onControllerUpdate);

    if (user != null) {
      if (widget.friendsController == null) {
        _friendsController.initialize(user.id, defaultEmail: user.email);
      }
      if (widget.profileController == null) {
        _profileController.initialize(user.id, defaultEmail: user.email);
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _friendsController.removeListener(_onControllerUpdate);
    _profileController.removeListener(_onControllerUpdate);
    if (widget.friendsController == null) {
      _friendsController.dispose();
    }
    if (widget.profileController == null) {
      _profileController.dispose();
    }
    super.dispose();
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
    _profileController.reset();
    _friendsController.reset();
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
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ajustes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Tarjeta de perfil con edición de username, avatar y contraseña
                  UserProfileCard(
                    email: email,
                    profileController: _profileController,
                    authController: widget.authController,
                    friendsController: _friendsController,
                  ),
                  const SizedBox(height: 24),

                  // 2. Acceso directo a Amigos y Conexiones en Tiempo Real
                  _buildRealtimeFriendsNavCard(),
                  const SizedBox(height: 24),

                  // 3. Selector dinámico de temas (6 temas en acordeón)
                  ThemeSelectorCard(
                    themeController: widget.themeController ??
                        AppThemeScope.of(context),
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

  Widget _buildRealtimeFriendsNavCard() {
    final pendingCount = _friendsController.pendingCount;
    final friendsCount = _friendsController.friends.length;

    return AppCard(
      borderRadius: 18.0,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openRealtimeFriends,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.people_alt_rounded,
                color: AppTheme.primaryLiquid,
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
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pendingCount > 0
                        ? '$pendingCount solicitud(es) pendiente(s)'
                        : '$friendsCount ${friendsCount == 1 ? 'amigo' : 'amigos'}',
                    style: TextStyle(
                      color: pendingCount > 0
                          ? AppTheme.accentCoral
                          : AppTheme.textSecondary,
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
              color: AppTheme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return AppContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(vertical: 6),
      baseColor: AppTheme.surfaceDark,
      child: TextButton.icon(
        onPressed: _logout,
        icon: Icon(Icons.logout_rounded, color: AppTheme.accentCoral),
        label: Text(
          'Cerrar Sesión',
          style: TextStyle(
            color: AppTheme.accentCoral,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
