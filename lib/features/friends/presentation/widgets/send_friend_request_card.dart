import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';

/// Tarjeta para enviar solicitudes de amistad o canjear códigos temporales (MARTH-XXXX)
class SendFriendRequestCard extends StatefulWidget {
  final bool isLoading;
  final Future<void> Function(String codeOrTarget) onSendRequest;

  const SendFriendRequestCard({
    super.key,
    required this.isLoading,
    required this.onSendRequest,
  });

  @override
  State<SendFriendRequestCard> createState() => _SendFriendRequestCardState();
}

class _SendFriendRequestCardState extends State<SendFriendRequestCard> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    var raw = _searchController.text.trim().toUpperCase();
    if (raw.isEmpty) return;

    // Normalizar: si el usuario pegó el código completo MARTH-XXXX o solo XXXX, asegurar MARTH-XXXX
    final cleanSuffix = raw.startsWith('MARTH-') ? raw.substring(6) : raw;
    final fullCode = 'MARTH-$cleanSuffix';

    await widget.onSendRequest(fullCode);
    if (mounted) {
      _searchController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 18.0,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppTheme.primaryAccent,
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
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Introduce el código de invitación temporal de tu amigo (60s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _handleSubmit(),
            decoration: InputDecoration(
              hintText: '8K2A',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
                fontFamily: 'monospace',
                fontSize: 15,
                letterSpacing: 1.5,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MARTH-',
                      style: TextStyle(
                        color: AppTheme.primaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Enviar Solicitud',
            icon: Icons.send_rounded,
            height: 48,
            isLoading: widget.isLoading,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
