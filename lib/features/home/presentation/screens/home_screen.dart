import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_container.dart';
import '../../../../core/widgets/marth_app_logo.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../environments/presentation/controllers/environment_controller.dart';
import '../../../environments/presentation/widgets/environment_selector_chip.dart';
import '../../../environments/presentation/widgets/environments_home_view.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../leisure/presentation/controllers/leisure_controller.dart';
import '../../../leisure/presentation/screens/leisure_screen.dart';
import '../../../planificador/presentation/controllers/planificador_controller.dart';
import '../../../planificador/presentation/screens/planificador_screen.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../widgets/marth_bottom_nav_bar.dart';

/// Pantalla principal y shell de navegacion de MarthApp:
/// - AppBar superior: Logo MarthApp ampliado a la izquierda, Selector de Entorno interactivo y Avatar de ajustes
/// - Barra inferior Claymorfica de 3 pestanas: Entornos, Ocio y Planificador
/// - Renderizado diferido (lazy loading) para Ocio y Planificador (cero llamadas innecesarias en el arranque)
/// - Sincronizacion reactiva inmediata entre EnvironmentController, LeisureController y PlanificadorController
class HomeScreen extends StatefulWidget {
  final AuthController authController;
  final FriendsController? friendsController;
  final ProfileController? profileController;
  final EnvironmentController? environmentController;
  final LeisureController? leisureController;
  final PlanificadorController? planificadorController;
  final int initialIndex;

  const HomeScreen({
    super.key,
    required this.authController,
    this.friendsController,
    this.profileController,
    this.environmentController,
    this.leisureController,
    this.planificadorController,
    this.initialIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FriendsController _friendsController;
  late final ProfileController _profileController;
  late final EnvironmentController _environmentController;
  late final LeisureController _leisureController;
  late final PlanificadorController _planificadorController;

  late int _currentTabIndex;
  late final Set<int> _loadedIndices;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialIndex;
    _loadedIndices = {_currentTabIndex};

    _friendsController = widget.friendsController ?? FriendsController();
    _friendsController.addListener(_onControllerUpdate);

    _profileController = widget.profileController ?? ProfileController();
    _profileController.addListener(_onControllerUpdate);

    _environmentController =
        widget.environmentController ?? EnvironmentController();
    _environmentController.addListener(_onEnvironmentChanged);

    _leisureController = widget.leisureController ?? LeisureController();
    _leisureController.addListener(_onControllerUpdate);

    _planificadorController =
        widget.planificadorController ?? PlanificadorController();
    _planificadorController.addListener(_onControllerUpdate);

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
      final activeEnv = _environmentController.activeEnvironment;
      if (widget.leisureController == null) {
        _leisureController.initialize(
          user.id,
          environmentId: activeEnv?.id,
          isPersonal: activeEnv?.isPersonal ?? true,
        );
      }
      if (widget.planificadorController == null && activeEnv != null) {
        _planificadorController.setEntorno(activeEnv.id);
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onEnvironmentChanged() {
    final activeEnv = _environmentController.activeEnvironment;
    _leisureController.setEnvironment(
      activeEnv?.id,
      isPersonal: activeEnv?.isPersonal ?? true,
    );
    if (activeEnv != null) {
      _planificadorController.setEntorno(activeEnv.id);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _friendsController.removeListener(_onControllerUpdate);
    _profileController.removeListener(_onControllerUpdate);
    _environmentController.removeListener(_onEnvironmentChanged);
    _leisureController.removeListener(_onControllerUpdate);
    _planificadorController.removeListener(_onControllerUpdate);

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
    if (widget.planificadorController == null) {
      _planificadorController.dispose();
    }
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentTabIndex == index) return;
    setState(() {
      _currentTabIndex = index;
      _loadedIndices.add(index);
    });
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

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.user;
    final email = user?.email ?? 'Explorador';
    final pendingEnvCount = _environmentController.pendingInvitationsCount;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _buildAppBarTitle(),
        actions: [
          // Selector de entorno colocado en la barra superior
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
        child: IndexedStack(
          index: _currentTabIndex,
          children: [
            // Pestana 0: Vista redisenada y minimalista de entornos
            EnvironmentsHomeView(
              environmentController: _environmentController,
              friendsController: _friendsController,
              profileController: _profileController,
              userEmail: email,
              onNavigateToLeisure: () => _onTabSelected(1),
              onNavigateToPlanificador: () => _onTabSelected(2),
              onOpenSettings: () => _openSettings(context),
            ),

            // Pestana 1: Carga diferida de LeisureScreen
            _loadedIndices.contains(1)
                ? LeisureScreen(
                    controller: _leisureController,
                    environmentController: _environmentController,
                    asTab: true,
                  )
                : const SizedBox.shrink(),

            // Pestana 2: Carga diferida de PlanificadorScreen
            _loadedIndices.contains(2)
                ? PlanificadorScreen(
                    controller: _planificadorController,
                    environmentController: _environmentController,
                    currentUserId: user?.id,
                    asTab: true,
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: MarthBottomNavBar(
        currentIndex: _currentTabIndex,
        onTabSelected: _onTabSelected,
        pendingInvitesCount: pendingEnvCount,
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: MarthAppLogo.badge(
        badgeSize: 44,
        logoSize: 26,
        color: AppTheme.primaryLiquid,
      ),
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
              ),
      ),
    );
  }
}
