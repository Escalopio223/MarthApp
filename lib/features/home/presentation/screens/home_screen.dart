import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/marth_app_logo.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../widgets/backend_status_card.dart';
import '../widgets/home_greeting_card.dart';
import '../widgets/home_quick_action_card.dart';

/// Pantalla principal modular de MarthApp con conexión en tiempo real a Supabase
class HomeScreen extends StatefulWidget {
  final AuthController authController;
  final FriendsController? friendsController;

  const HomeScreen({
    super.key,
    required this.authController,
    this.friendsController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FriendsController _friendsController;

  @override
  void initState() {
    super.initState();
    _friendsController = widget.friendsController ?? FriendsController();
    _friendsController.addListener(_onFriendsControllerUpdate);

    final user = widget.authController.user;
    if (user != null) {
      _friendsController.initialize(user.id, defaultEmail: user.email);
    }
  }

  void _onFriendsControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _friendsController.removeListener(_onFriendsControllerUpdate);
    if (widget.friendsController == null) {
      _friendsController.dispose();
    }
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          authController: widget.authController,
          themeController: LiquidThemeScope.of(context),
          friendsController: _friendsController,
        ),
      ),
    );
  }

  void _openFriends(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendsScreen(
          friendsController: _friendsController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.user;
    final email = user?.email ?? 'Explorador';
    final activeUsername =
        _friendsController.currentProfile?.username ?? email.split('@').first;
    final pendingCount = _friendsController.pendingCount;
    final friendsCount = _friendsController.friends.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _buildAppBarTitle(),
        actions: [
          _buildSettingsIconButton(context),
        ],
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta Hero de bienvenida con el username real
                  HomeGreetingCard(username: activeUsername),
                  const SizedBox(height: 24),

                  // Fila de accesos rápidos
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            HomeQuickActionCard(
                              icon: Icons.group_rounded,
                              iconColor: LiquidTheme.primaryLiquid,
                              title: 'Amigos',
                              subtitle: pendingCount > 0
                                  ? '$pendingCount solicitud(es) pendiente(s)'
                                  : (friendsCount > 0
                                      ? '$friendsCount amigo(s) conectado(s)'
                                      : 'Conecta con otros usuarios'),
                              onTap: () => _openFriends(context),
                            ),
                            if (pendingCount > 0)
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: LiquidTheme.accentCoral,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: LiquidTheme.accentCoral
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$pendingCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: HomeQuickActionCard(
                          icon: Icons.settings_suggest_rounded,
                          iconColor: LiquidTheme.secondaryLilac,
                          title: 'Ajustes',
                          subtitle: 'Gestiona tu cuenta y perfil',
                          onTap: () => _openSettings(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Diagnóstico de backend
                  BackendStatusCard(userEmail: email),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return Row(
      children: [
        MarthAppLogo.badge(
          badgeSize: 38,
          logoSize: 22,
          withGlow: true,
        ),
        const SizedBox(width: 10),
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: LiquidTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsIconButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: NeumorphicContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(4),
        baseColor: LiquidTheme.surfaceDark,
        onTap: () => _openSettings(context),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LiquidTheme.liquidPrimaryGradient,
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF0D1219),
            size: 22,
          ),
        ),
      ),
    );
  }
}
