import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/environment_member_model.dart';
import '../../domain/models/environment_model.dart';
import '../controllers/environment_controller.dart';
import 'environment_selection_list.dart';

/// Hoja modal para invitar a un amigo a un entorno colaborativo propio
/// Incluye previsualización detallada: anfitrión, entorno y todos los integrantes con foto y nombre
class InviteToEnvironmentSheet extends StatefulWidget {
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
    final myCollaborativeEnvs = environmentController.environments
        .where((e) => !e.isPersonal && e.isOwner)
        .toList();

    if (myCollaborativeEnvs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No tienes entornos colaborativos propios creados. Crea uno primero desde el selector de entornos.',
          ),
          backgroundColor: AppTheme.surfaceDark,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => InviteToEnvironmentSheet(
        friend: friend,
        environmentController: environmentController,
      ),
    );
  }

  @override
  State<InviteToEnvironmentSheet> createState() =>
      _InviteToEnvironmentSheetState();
}

class _InviteToEnvironmentSheetState extends State<InviteToEnvironmentSheet> {
  EnvironmentModel? _selectedEnv;
  List<EnvironmentMemberModel> _envMembers = [];
  bool _isLoadingMembers = false;
  bool _isSending = false;

  Future<void> _onSelectEnvironment(EnvironmentModel env) async {
    setState(() {
      _selectedEnv = env;
      _isLoadingMembers = true;
      _envMembers = [];
    });

    try {
      final members =
          await widget.environmentController.getMembers(env.id);
      if (mounted) {
        setState(() {
          _envMembers = members;
          _isLoadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
        });
      }
    }
  }

  void _backToSelection() {
    setState(() {
      _selectedEnv = null;
      _envMembers = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final myCollaborativeEnvs = widget.environmentController.environments
        .where((e) => !e.isPersonal && e.isOwner)
        .toList();

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: AppTheme.glassBorderColor.withValues(alpha: 0.8),
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
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_selectedEnv == null)
            _buildSelectionView(myCollaborativeEnvs)
          else
            _buildConfirmationPreviewView(),
        ],
      ),
    );
  }

  Widget _buildSelectionView(List<EnvironmentModel> myCollaborativeEnvs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            UserAvatar(
              avatarData: widget.friend.avatarData,
              username: widget.friend.username,
              size: 38,
              showBorder: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invitar a "${widget.friend.username}"',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Selecciona el entorno colaborativo:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: EnvironmentSelectionList(
            environments: myCollaborativeEnvs,
            onSelect: _onSelectEnvironment,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationPreviewView() {
    final env = _selectedEnv!;
    final otherMembers = _envMembers
        .where((m) => m.userId != widget.environmentController.currentUserId)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera con botón de retroceso
        Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: _backToSelection,
            ),
            Expanded(
              child: Text(
                'Confirmar invitación',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tarjeta resumen del entorno seleccionado
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.accentEmerald.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.liquidEmeraldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  env.iconData,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      env.name,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invitando a @${widget.friend.username}',
                      style: TextStyle(
                        color: AppTheme.accentEmerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              UserAvatar(
                avatarData: widget.friend.avatarData,
                username: widget.friend.username,
                size: 34,
                showBorder: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Lista de los demás integrantes del entorno
        if (_isLoadingMembers) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ),
          ),
        ] else if (otherMembers.isNotEmpty) ...[
          Text(
            'Otros integrantes del entorno (${otherMembers.length}):',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 130),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: otherMembers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final m = otherMembers[index];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.glassBorderColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        avatarData: m.avatarData,
                        username: m.username,
                        size: 26,
                        showBorder: false,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.username,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (m.isOwner)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Propietario',
                            style: TextStyle(
                              color: Colors.amber.shade300,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No hay otros miembros aún. Seréis los dos primeros colaboradores.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // Botón de confirmación y envío
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(
                    color: AppTheme.glassBorderColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _backToSelection,
                child: const Text('Cambiar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppButton(
                text: 'Enviar invitación',
                isLoading: _isSending,
                icon: Icons.send_rounded,
                gradient: AppTheme.liquidEmeraldGradient,
                onPressed: _isSending
                    ? null
                    : () => _handleInvite(env.id, env.name),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleInvite(
    String environmentId,
    String environmentName,
  ) async {
    setState(() => _isSending = true);

    final ok = await widget.environmentController.inviteFriend(
      environmentId: environmentId,
      friendId: widget.friend.id,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    Navigator.pop(context);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invitación enviada a ${widget.friend.username} para "$environmentName"',
          ),
          backgroundColor: AppTheme.accentEmerald,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.environmentController.errorMessage ??
                'No se pudo enviar la invitación',
          ),
          backgroundColor: AppTheme.accentCoral,
        ),
      );
    }
  }
}

