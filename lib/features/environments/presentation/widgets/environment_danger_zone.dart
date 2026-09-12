import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';

/// Componente presentacional puro para la zona de peligro (Eliminar o Abandonar entorno)
class EnvironmentDangerZone extends StatelessWidget {
  final bool isOwner;
  final bool isActionLoading;
  final VoidCallback onDeleteEnvironment;
  final VoidCallback onLeaveEnvironment;

  const EnvironmentDangerZone({
    super.key,
    required this.isOwner,
    this.isActionLoading = false,
    required this.onDeleteEnvironment,
    required this.onLeaveEnvironment,
  });

  @override
  Widget build(BuildContext context) {
    if (isOwner) {
      return AppButton(
        text: 'Eliminar Entorno',
        icon: Icons.delete_outline_rounded,
        isLoading: isActionLoading,
        gradient: LinearGradient(
          colors: [
            AppTheme.accentCoral,
            Colors.red.shade900,
          ],
        ),
        onPressed: onDeleteEnvironment,
      );
    }

    return AppButton(
      text: 'Abandonar Entorno',
      icon: Icons.exit_to_app_rounded,
      isLoading: isActionLoading,
      gradient: LinearGradient(
        colors: [
          AppTheme.accentCoral,
          Colors.red.shade900,
        ],
      ),
      onPressed: onLeaveEnvironment,
    );
  }
}
