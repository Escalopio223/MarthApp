import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_card.dart';
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
import '../../../leisure/presentation/controllers/leisure_controller.dart';
import '../../../leisure/presentation/screens/leisure_screen.dart';
import '../widgets/backend_status_card.dart';
import '../widgets/home_greeting_card.dart';
import '../widgets/home_quick_action_card.dart';

/// Pantalla principal modular de MarthApp con conexión en tiempo real a Supabase
class HomeScreen extends StatefulWidget {
  final AuthController authController;
  final FriendsController? friendsController;
  final ProfileController? profileController;
  final EnvironmentController? environmentController;
  final LeisureController? leisureController;

  const HomeScreen({
    super.key,
    required this.authController,
    this.friendsController,
    this.profileController,
    this.environmentController,
    this.leisureController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FriendsController _friendsController;
  late final ProfileController _profileController;
  late final EnvironmentController _environmentController;
  late final LeisureController _leisureController;

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

    _leisureController = widget.leisureController ?? LeisureController();
    _leisureController.addListener(_onControllerUpdate);

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
      if (widget.leisureController == null) {
        final activeEnv = _environmentController.activeEnvironment;
        _leisureController.initialize(
          user.id,
          environmentId: activeEnv?.id,
          isPersonal: activeEnv?.isPersonal ?? true,
        );
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
    _leisureController.removeListener(_onControllerUpdate);
    if (widget.friendsController == null) {
      _friendsController.dispose();
    }
    if (widget.profileController == null) {
      _profileController.dispose();
    }
    if (widget.environmentController == null) {
      _environmentController.dispose();
    }
    if (widget.leisureController == null) {
      _leisureController.dispose();
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

  void _openLeisure(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeisureScreen(
          controller: _leisureController,
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
                  const SizedBox(height: 20),

                  // Tarjeta destacada de Ocio & Cultura
                  _buildLeisureCard(context),
                  const SizedBox(height: 20),

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

  Widget _buildLeisureCard(BuildContext context) {
    final rouletteCount = _leisureController.rouletteCount;

    return AppCard(
      borderRadius: 22.0,
      padding: const EdgeInsets.all(18.0),
      onTap: () => _openLeisure(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.movie_filter_rounded,
                  color: AppTheme.primaryLiquid,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Ocio & Cultura',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (rouletteCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCoral,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$rouletteCount en ruleta',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Películas, Series, Libros y Videojuegos',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildLeisurePill('🎬 Cine'),
              const SizedBox(width: 6),
              _buildLeisurePill('📺 Series'),
              const SizedBox(width: 6),
              _buildLeisurePill('📚 Libros'),
              const SizedBox(width: 6),
              _buildLeisurePill('🎮 Juegos'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeisurePill(String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.textSecondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
