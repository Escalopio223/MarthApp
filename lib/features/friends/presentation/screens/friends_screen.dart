import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../domain/friend_code_manager.dart';
import '../../../environments/presentation/controllers/environment_controller.dart';
import '../../../environments/presentation/widgets/environment_invitation_tile.dart';
import '../controllers/friends_controller.dart';
import '../../domain/models/profile_model.dart';
import '../widgets/friend_code_card.dart';
import '../widgets/friends_list_card.dart';
import '../widgets/incoming_requests_card.dart';
import '../widgets/send_friend_request_card.dart';

/// Pantalla principal modular de Amigos y Solicitudes
class FriendsScreen extends StatefulWidget {
  final FriendsController friendsController;
  final EnvironmentController? environmentController;

  const FriendsScreen({
    super.key,
    required this.friendsController,
    this.environmentController,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendCodeManager _friendCodeManager;

  @override
  void initState() {
    super.initState();
    _friendCodeManager = FriendCodeManager(
      friendsService: widget.friendsController.friendsService,
      userId: widget.friendsController.currentUserId,
    );
    _friendCodeManager.addListener(_onControllerChange);
    widget.friendsController.addListener(_onControllerChange);
    widget.environmentController?.addListener(_onControllerChange);

    // Cargar datos en vivo al abrir la vista
    widget.friendsController.refresh();
    widget.environmentController?.refresh();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.friendsController.removeListener(_onControllerChange);
    widget.environmentController?.removeListener(_onControllerChange);
    _friendCodeManager.removeListener(_onControllerChange);
    _friendCodeManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.friendsController;
    final incomingRequests = controller.incomingRequests;
    final friends = controller.friends;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: LiquidTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Amigos y Solicitudes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: LiquidTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: LiquidTheme.textPrimary),
            tooltip: 'Actualizar en vivo',
            onPressed: () => controller.refresh(),
          ),
        ],
      ),
      body: LiquidBackground(
        child: RefreshIndicator(
          color: LiquidTheme.primaryLiquid,
          backgroundColor: LiquidTheme.surfaceDark,
          onRefresh: () => controller.refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Mensajes de éxito y error
                    if (controller.errorMessage != null) ...[
                      LiquidBanner(
                        message: controller.errorMessage!,
                        type: BannerType.error,
                        onClose: () => controller.clearMessages(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (controller.successMessage != null) ...[
                      LiquidBanner(
                        message: controller.successMessage!,
                        type: BannerType.success,
                        onClose: () => controller.clearMessages(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 2. Mi Código de Amigo temporal (1 min)
                    FriendCodeCard(
                      friendCodeManager: _friendCodeManager,
                      onGenerateCode: () {
                        final u = controller.currentUserId;
                        _friendCodeManager.generateNewCode(
                          userId: u,
                          service: controller.friendsService,
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 3. Tarjeta: Enviar Solicitud o Canjear Código
                    SendFriendRequestCard(
                      isLoading: controller.isSendingRequest,
                      onSendRequest: (code) =>
                          controller.sendFriendRequest(code),
                    ),
                    const SizedBox(height: 24),

                    // 4. Sección: Invitaciones a Entornos de Trabajo (Workspaces)
                    if (widget.environmentController != null &&
                        widget.environmentController!.pendingInvitations.isNotEmpty) ...[
                      _buildEnvironmentInvitationsSection(
                          widget.environmentController!),
                      const SizedBox(height: 24),
                    ],

                    // 5. Tarjeta: Bandeja de Solicitudes Recibidas de Amistad
                    if (incomingRequests.isNotEmpty) ...[
                      IncomingRequestsCard(
                        requests: incomingRequests,
                        onAccept: (reqId) => controller.acceptRequest(reqId),
                        onReject: (reqId) => controller.rejectRequest(reqId),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 6. Tarjeta: Lista de Amigos Aceptados
                    FriendsListCard(
                      friends: friends,
                      onRemoveFriend: (friend) =>
                          controller.removeFriend(friend.id),
                      onInviteToEnvironment: widget.environmentController != null
                          ? (friend) =>
                              _showInviteToEnvironmentSheet(context, friend)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInviteToEnvironmentSheet(BuildContext context, ProfileModel friend) {
    final envController = widget.environmentController;
    if (envController == null) return;

    // Solo entornos colaborativos donde el usuario es propietario
    final myCollaborativeEnvs = envController.environments
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: LiquidTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: LiquidTheme.glassBorderColor),
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
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona el entorno colaborativo al que deseas invitarlo:',
              style: TextStyle(color: LiquidTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              itemCount: myCollaborativeEnvs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final env = myCollaborativeEnvs[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: LiquidTheme.glassBorderColor
                            .withValues(alpha: 0.4)),
                  ),
                  tileColor: LiquidTheme.surfaceDark.withValues(alpha: 0.6),
                  leading: Icon(Icons.groups_rounded,
                      color: LiquidTheme.accentEmerald),
                  title: Text(env.name,
                      style: TextStyle(
                          color: LiquidTheme.textPrimary,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text('Propietario',
                      style: TextStyle(
                          color: LiquidTheme.textSecondary, fontSize: 12)),
                  trailing: Icon(Icons.send_rounded,
                      size: 18, color: LiquidTheme.primaryCyan),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await envController.inviteFriend(
                      environmentId: env.id,
                      friendId: friend.id,
                    );
                    if (context.mounted) {
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Invitación enviada a ${friend.username} para "${env.name}"'),
                            backgroundColor: LiquidTheme.accentEmerald,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(envController.errorMessage ??
                                'No se pudo enviar la invitación'),
                            backgroundColor: LiquidTheme.accentCoral,
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentInvitationsSection(EnvironmentController envController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.mark_email_unread_rounded,
                color: LiquidTheme.accentEmerald, size: 20),
            const SizedBox(width: 8),
            Text(
              'Invitaciones a Entornos (${envController.pendingInvitationsCount})',
              style: TextStyle(
                color: LiquidTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: envController.pendingInvitations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final inv = envController.pendingInvitations[index];
            return EnvironmentInvitationTile(
              invitation: inv,
              isLoading: envController.isActionLoading,
              onAccept: () =>
                  envController.respondInvitation(invitationId: inv.id, accept: true),
              onDecline: () =>
                  envController.respondInvitation(invitationId: inv.id, accept: false),
            );
          },
        ),
      ],
    );
  }
}
