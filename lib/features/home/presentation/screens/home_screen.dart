import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../widgets/backend_status_card.dart';
import '../widgets/home_greeting_card.dart';
import '../widgets/home_quick_action_card.dart';

/// Pantalla principal modular de MarthApp
class HomeScreen extends StatelessWidget {
  final AuthController authController;

  const HomeScreen({
    super.key,
    required this.authController,
  });

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          authController: authController,
          themeController: LiquidThemeScope.of(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = authController.user;
    final email = user?.email ?? 'Explorador';
    final username = email.split('@').first;

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
                  // Tarjeta Hero de bienvenida
                  HomeGreetingCard(username: username),
                  const SizedBox(height: 24),

                  // Fila de accesos rápidos
                  Row(
                    children: [
                      Expanded(
                        child: HomeQuickActionCard(
                          icon: Icons.group_add_rounded,
                          iconColor: LiquidTheme.primaryLiquid,
                          title: 'Añadir Amigo',
                          subtitle: 'Código con expiración de 1 min',
                          onTap: () => _openSettings(context),
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LiquidTheme.liquidPrimaryGradient,
            boxShadow: [
              BoxShadow(
                color: LiquidTheme.primaryLiquid.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Icon(Icons.bubble_chart_rounded,
              color: Color(0xFF0D1219), size: 22),
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
