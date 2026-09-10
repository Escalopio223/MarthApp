import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final AuthController authController;

  const HomeScreen({
    super.key,
    required this.authController,
  });

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
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LiquidTheme.liquidPrimaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: LiquidTheme.primaryCyan.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.bubble_chart_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'MarthApp',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: LiquidTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // Icono de usuario arriba a la derecha que abre Ajustes
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: NeumorphicContainer(
              borderRadius: 24,
              padding: const EdgeInsets.all(4),
              baseColor: LiquidTheme.surfaceDark.withValues(alpha: 0.8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(authController: authController),
                  ),
                );
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LiquidTheme.liquidPrimaryGradient,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
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
                  // Tarjeta Hero con estilo Liquid Glassmorphism
                  GlassCard(
                    blur: 24.0,
                    borderRadius: 28.0,
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: LiquidTheme.primaryCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: LiquidTheme.primaryCyan.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  color: LiquidTheme.primaryCyan, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Sesión Activa con Supabase',
                                style: TextStyle(
                                  color: LiquidTheme.primaryCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '¡Hola, $username!',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: LiquidTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bienvenido a tu panel principal en MarthApp. Tu aplicación móvil conectada a Supabase con estilo Liquid UI.',
                          style: TextStyle(
                            color: LiquidTheme.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Accesos Rápidos
                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          blur: 16.0,
                          borderRadius: 20.0,
                          padding: const EdgeInsets.all(20.0),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SettingsScreen(
                                      authController: authController),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: LiquidTheme.primaryCyan
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.group_add_rounded,
                                      color: LiquidTheme.primaryCyan, size: 24),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Añadir Amigo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: LiquidTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Código con expiración de 1 min',
                                  style: TextStyle(
                                    color: LiquidTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GlassCard(
                          blur: 16.0,
                          borderRadius: 20.0,
                          padding: const EdgeInsets.all(20.0),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SettingsScreen(
                                      authController: authController),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: LiquidTheme.accentEmerald
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.settings_suggest_rounded,
                                      color: LiquidTheme.accentEmerald, size: 24),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Ajustes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: LiquidTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Gestiona tu cuenta y perfil',
                                  style: TextStyle(
                                    color: LiquidTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Estado del Sistema Neumórfico
                  NeumorphicContainer(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cloud_done_rounded,
                                color: LiquidTheme.accentEmerald, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Backend Supabase Conectado',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: LiquidTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Proyecto: cntspvnxrmqchvtcdiwv\n'
                          'SDK: supabase_flutter v2.17.2\n'
                          'Usuario: $email',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: LiquidTheme.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
