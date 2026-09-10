import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_background.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../domain/models/friend_request_model.dart';
import '../../domain/models/profile_model.dart';
import '../controllers/friends_controller.dart';

/// Pantalla principal de Amistades en Tiempo Real (Supabase Realtime)
class FriendsScreen extends StatefulWidget {
  final FriendsController friendsController;

  const FriendsScreen({
    super.key,
    required this.friendsController,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchUsernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.friendsController.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.friendsController.removeListener(_onControllerChange);
    _searchUsernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSendRequest() async {
    final target = _searchUsernameController.text.trim();
    if (target.isEmpty) return;

    final success = await widget.friendsController.sendFriendRequest(target);
    if (success && mounted) {
      _searchUsernameController.clear();
      FocusScope.of(context).unfocus();
    }
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
          'Amigos y Conexiones',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: LiquidTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
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

                  // 2. Tarjeta: Enviar Solicitud por Username
                  _buildSendRequestCard(controller),
                  const SizedBox(height: 24),

                  // 3. Tarjeta: Bandeja de Solicitudes Recibidas (En tiempo real)
                  if (incomingRequests.isNotEmpty) ...[
                    _buildIncomingRequestsCard(incomingRequests, controller),
                    const SizedBox(height: 24),
                  ],

                  // 4. Tarjeta: Lista de Amigos en Tiempo Real
                  _buildFriendsListCard(friends, controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendRequestCard(FriendsController controller) {
    return GlassCard(
      blur: 20.0,
      borderRadius: 24.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LiquidTheme.primaryLiquid.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: LiquidTheme.primaryLiquid,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enviar Solicitud de Amistad',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: LiquidTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Busca a otro usuario por su nombre de usuario o código temporal (MARTH-XXXX)',
                      style: TextStyle(
                        fontSize: 12,
                        color: LiquidTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchUsernameController,
            style: TextStyle(color: LiquidTheme.textPrimary),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _handleSendRequest(),
            decoration: InputDecoration(
              hintText: 'Ej. arturo_dev o MARTH-8K2A',
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                color: LiquidTheme.primaryLiquid,
              ),
            ),
          ),
          const SizedBox(height: 16),
          LiquidButton(
            text: 'Enviar Solicitud',
            icon: Icons.send_rounded,
            height: 48,
            isLoading: controller.isSendingRequest,
            onPressed: _handleSendRequest,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsCard(
    List<FriendRequestModel> requests,
    FriendsController controller,
  ) {
    return GlassCard(
      blur: 20.0,
      borderRadius: 24.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LiquidTheme.accentCoral.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.mark_email_unread_rounded,
                  color: LiquidTheme.accentCoral,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Solicitudes Recibidas (${requests.length})',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: LiquidTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LiquidTheme.accentCoral.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: LiquidTheme.accentCoral.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'En tiempo real',
                  style: TextStyle(
                    color: LiquidTheme.accentCoral,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = requests[index];
              final senderName = req.senderProfile?.username ?? 'Usuario';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LiquidTheme.surfaceDark.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: LiquidTheme.glassBorderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LiquidTheme.liquidPrimaryGradient,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF0D1219),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderName,
                            style: TextStyle(
                              color: LiquidTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Quiere ser tu amigo',
                            style: TextStyle(
                              color: LiquidTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              LiquidTheme.accentEmerald.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: LiquidTheme.accentEmerald,
                          size: 18,
                        ),
                      ),
                      tooltip: 'Aceptar',
                      onPressed: () => controller.acceptRequest(req.id),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: LiquidTheme.accentCoral.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: LiquidTheme.accentCoral,
                          size: 18,
                        ),
                      ),
                      tooltip: 'Rechazar',
                      onPressed: () => controller.rejectRequest(req.id),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsListCard(
    List<ProfileModel> friends,
    FriendsController controller,
  ) {
    return GlassCard(
      blur: 20.0,
      borderRadius: 24.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LiquidTheme.primaryLiquid.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.group_rounded,
                  color: LiquidTheme.primaryLiquid,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis Amigos (${friends.length})',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: LiquidTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Los cambios de nombre se sincronizan al instante',
                      style: TextStyle(
                        fontSize: 12,
                        color: LiquidTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (friends.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 48,
                    color: LiquidTheme.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aún no tienes amigos agregados',
                    style: TextStyle(
                      color: LiquidTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Utiliza el buscador de arriba para enviar una solicitud.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LiquidTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: friends.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final friend = friends[index];

                return NeumorphicContainer(
                  borderRadius: 16,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  baseColor: LiquidTheme.surfaceDark,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              friend.username,
                              style: TextStyle(
                                color: LiquidTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Conectado en MarthApp',
                              style: TextStyle(
                                color: LiquidTheme.accentEmerald,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.person_remove_rounded,
                          size: 18,
                          color:
                              LiquidTheme.textSecondary.withValues(alpha: 0.6),
                        ),
                        tooltip: 'Eliminar amigo',
                        onPressed: () => _confirmRemoveFriend(friend),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _confirmRemoveFriend(ProfileModel friend) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LiquidTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: LiquidTheme.glassBorderColor),
        ),
        title: Text(
          'Eliminar Amigo',
          style: TextStyle(
            color: LiquidTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar a "${friend.username}" de tu lista de amigos?',
          style: TextStyle(color: LiquidTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: LiquidTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.friendsController.removeFriend(friend.id);
            },
            child: Text(
              'Eliminar',
              style: TextStyle(
                color: LiquidTheme.accentCoral,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
