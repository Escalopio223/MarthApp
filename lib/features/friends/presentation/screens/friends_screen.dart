import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../domain/friend_code_manager.dart';
import '../../../environments/presentation/controllers/environment_controller.dart';
import '../../../environments/presentation/widgets/environment_invitation_tile.dart';
import '../controllers/friends_controller.dart';
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
