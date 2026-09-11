import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../controllers/environment_controller.dart';
import 'environment_selection_list.dart';

/// Hoja modal para invitar a un amigo a un entorno colaborativo propio
class InviteToEnvironmentSheet extends StatelessWidget {
  final ProfileModel friend;
  final EnvironmentController environmentController;

  const InviteToEnvironmentSheet({
    super.key,
    required this.friend,
    required this.environmentController,
  });

  static Future<void> show(
    BuildContext context, {
    required ProfileModel friend,
    required EnvironmentController environmentController,
  }) async {
    // Solo entornos colaborativos donde el usuario es propietario
    final myCollaborativeEnvs = environmentController.environments
        .where((e) => !e.isPersonal && e.isOwner)
        .toList();

    if (myCollaborativeEnvs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No tienes entornos colaborativos propios creados. Crea uno primero desde el selector de entornos.',
          ),
          backgroundColor: LiquidTheme.surfaceDark,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => InviteToEnvironmentSheet(
        friend: friend,
        environmentController: environmentController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myCollaborativeEnvs = environmentController.environments
        .where((e) => !e.isPersonal && e.isOwner)
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: LiquidTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: LiquidTheme.glassBorderColor.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: LiquidTheme.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.group_add_rounded,
                  color: LiquidTheme.accentEmerald, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Invitar a "${friend.username}"',
                  style: TextStyle(
                    color: LiquidTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: LiquidTheme.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona el entorno colaborativo al que deseas invitarlo:',
            style: TextStyle(color: LiquidTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: EnvironmentSelectionList(
              environments: myCollaborativeEnvs,
              onSelect: (env) => _handleInvite(context, env.id, env.name),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInvite(
    BuildContext context,
    String environmentId,
    String environmentName,
  ) async {
    Navigator.pop(context);
    final ok = await environmentController.inviteFriend(
      environmentId: environmentId,
      friendId: friend.id,
    );

    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invitación enviada a ${friend.username} para "$environmentName"',
          ),
          backgroundColor: LiquidTheme.accentEmerald,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            environmentController.errorMessage ??
                'No se pudo enviar la invitación',
          ),
          backgroundColor: LiquidTheme.accentCoral,
        ),
      );
    }
  }
}
