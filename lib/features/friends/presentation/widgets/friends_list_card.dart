import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/profile_model.dart';

/// Tarjeta que muestra la lista de amigos aceptados con opción de eliminación
class FriendsListCard extends StatelessWidget {
  final List<ProfileModel> friends;
  final ValueChanged<ProfileModel> onRemoveFriend;

  const FriendsListCard({
    super.key,
    required this.friends,
    required this.onRemoveFriend,
  });

  void _showConfirmDeleteDialog(BuildContext context, ProfileModel friend) {
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
              onRemoveFriend(friend);
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
                      UserAvatar.fromProfile(
                        profile: friend,
                        size: 40,
                        showGlow: false,
                        showBorder: true,
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
                        onPressed: () =>
                            _showConfirmDeleteDialog(context, friend),
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
