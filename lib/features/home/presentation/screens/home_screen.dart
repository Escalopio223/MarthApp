import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_container.dart';
import '../../../../core/widgets/marth_app_logo.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../environments/presentation/controllers/environment_controller.dart';
import '../../../environments/presentation/widgets/environment_selector_chip.dart';
import '../widgets/backend_status_card.dart';
import '../widgets/home_greeting_card.dart';
import '../widgets/home_quick_action_card.dart';

/// Pantalla principal modular de MarthApp con conexión en tiempo real a Supabase
class HomeScreen extends StatefulWidget {
  final AuthController authController;
  final FriendsController? friendsController;
  final ProfileController? profileController;
  final EnvironmentController? environmentController;

  const HomeScreen({
    super.key,
    required this.authController,
    this.friendsController,
    this.profileController,
    this.environmentController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FriendsController _friendsController;
  late final ProfileController _profileController;
  late final EnvironmentController _environmentController;

  @override
  void initState() {
    super.initState();
    _friendsController = widget.friendsController ?? FriendsController();
    _friendsController.addListener(_onControllerUpdate);

    _profileController = widget.profileController ?? ProfileController();
    _profileController.addListener(_onControllerUpdate);

    _environmentController =
        widget.environmentController ?? EnvironmentController();
    _environmentController.addListener(_onControllerUpdate);

    final user = widget.authController.user;
    if (user != null) {
      if (widget.friendsController == null) {
        _friendsController.initialize(user.id, defaultEmail: user.email);
      }
      if (widget.profileController == null) {
        _profileController.initialize(user.id, defaultEmail: user.email);
      }
      if (widget.environmentController == null) {
        _environmentController.initialize(user.id);
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
    _environmentController.removeListener(_onControllerUpdate);
    if (widget.friendsController == null) {
      _friendsController.dispose();
    }
    if (widget.profileController == null) {
      _profileController.dispose();
    }
    if (widget.environmentController == null) {
      _environmentController.dispose();
    }
    super.dispose();
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          authController: widget.authController,
          themeController: AppThemeScope.of(context),
          friendsController: _friendsController,
          profileController: _profileController,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openFriends(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendsScreen(
          friendsController: _friendsController,
          environmentController: _environmentController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.user;
    final email = user?.email ?? 'Explorador';
    final currentProfile = _profileController.currentProfile ??
        _friendsController.currentProfile;
    final activeUsername =
        currentProfile?.username ?? email.split('@').first;
    final pendingFriendsCount = _friendsController.pendingCount;
    final pendingEnvCount = _environmentController.pendingInvitationsCount;
    final totalPendingCount = pendingFriendsCount + pendingEnvCount;
    final friendsCount = _friendsController.friends.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _buildAppBarTitle(),
        actions: [
          EnvironmentSelectorChip(
            environmentController: _environmentController,
            friendsController: _friendsController,
            onEnvironmentChanged: () {
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 8),
          _buildSettingsIconButton(context),
        ],
      ),
      body: AppBackground(
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
                              iconColor: AppTheme.primaryLiquid,
                              title: 'Amigos',
                              subtitle: totalPendingCount > 0
                                  ? '$totalPendingCount solicitud(es)'
                                  : (friendsCount > 0
                                      ? '$friendsCount amigo(s) conectado(s)'
                                      : 'Conecta con otros usuarios'),
                              onTap: () => _openFriends(context),
                            ),
                            if (totalPendingCount > 0)
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentCoral,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentCoral
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$totalPendingCount',
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
                          iconColor: AppTheme.secondaryLilac,
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
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsIconButton(BuildContext context) {
    final currentProfile = _profileController.currentProfile ??
        _friendsController.currentProfile;
    final email = widget.authController.user?.email;

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: AppContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(2),
        baseColor: AppTheme.surfaceDark,
        onTap: () => _openSettings(context),
        child: currentProfile != null
            ? UserAvatar.fromProfile(
                profile: currentProfile,
                size: 38,
                showGlow: true,
              )
            : UserAvatar(
                avatarData: const AvatarData.initials(),
                username: email?.split('@').first ?? 'Usuario',
                size: 38,
                showGlow: true,
              ),
      ),
    );
  }
}
