import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../../core/widgets/liquid_button.dart';
import 'added_friends_list.dart';

/// Tarjeta para ingresar y canjear códigos de amigo
class AddFriendCard extends StatelessWidget {
  final TextEditingController inputController;
  final VoidCallback onAddFriend;
  final String? feedbackMessage;
  final bool isSuccessMessage;
  final List<String> addedFriends;

  const AddFriendCard({
    super.key,
    required this.inputController,
    required this.onAddFriend,
    required this.addedFriends,
    this.feedbackMessage,
    this.isSuccessMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 18.0,
      borderRadius: 24.0,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.person_add_rounded,
                  color: LiquidTheme.primaryLiquid, size: 22),
              SizedBox(width: 10),
              Text(
                'Añadir Amigo con Código',
                style: TextStyle(
                  color: LiquidTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: inputController,
            style: const TextStyle(
              color: LiquidTheme.textPrimary,
              letterSpacing: 1.5,
            ),
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Ej. MARTH-8K2A',
              prefixIcon: Icon(Icons.key_rounded,
                  color: LiquidTheme.primaryLiquid),
            ),
          ),
          const SizedBox(height: 14),
          LiquidButton(
            text: 'Añadir Amigo',
            icon: Icons.check_rounded,
            height: 48,
            gradient: LiquidTheme.liquidPrimaryGradient,
            onPressed: onAddFriend,
          ),
          if (feedbackMessage != null) ...[
            const SizedBox(height: 14),
            LiquidBanner(
              message: feedbackMessage!,
              type: isSuccessMessage ? BannerType.success : BannerType.error,
            ),
          ],
          AddedFriendsList(friends: addedFriends),
        ],
      ),
    );
  }
}
