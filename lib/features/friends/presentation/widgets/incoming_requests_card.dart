import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/friend_request_model.dart';

/// Tarjeta que muestra la bandeja de solicitudes de amistad entrantes
class IncomingRequestsCard extends StatelessWidget {
  final List<FriendRequestModel> requests;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;

  const IncomingRequestsCard({
    super.key,
    required this.requests,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
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
                      onPressed: () => onAccept(req.id),
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
                      onPressed: () => onReject(req.id),
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
}
