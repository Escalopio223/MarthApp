import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';

/// Tarjeta de perfil del usuario en la pantalla de Ajustes con edición de username en tiempo real
class UserProfileCard extends StatefulWidget {
  final String email;
  final FriendsController? friendsController;

  const UserProfileCard({
    super.key,
    required this.email,
    this.friendsController,
  });

  @override
  State<UserProfileCard> createState() => _UserProfileCardState();
}

class _UserProfileCardState extends State<UserProfileCard> {
  bool _isEditing = false;
  late final TextEditingController _usernameController;
  String? _localValidationError;

  @override
  void initState() {
    super.initState();
    final initialUsername = widget.friendsController?.currentProfile?.username ??
        widget.email.split('@').first;
    _usernameController = TextEditingController(text: initialUsername);
    widget.friendsController?.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.friendsController?.removeListener(_onControllerUpdate);
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveUsername() async {
    final newName = _usernameController.text.trim();
    if (newName.isEmpty) {
      setState(() => _localValidationError = 'El nombre no puede estar vacío');
      return;
    }
    if (newName.length < 3) {
      setState(() => _localValidationError = 'Mínimo 3 caracteres');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(newName)) {
      setState(() => _localValidationError = 'Solo letras, números y guión bajo');
      return;
    }

    setState(() => _localValidationError = null);

    if (widget.friendsController != null) {
      final success = await widget.friendsController!.updateUsername(newName);
      if (success && mounted) {
        setState(() => _isEditing = false);
      }
    } else {
      // Si no hay controlador inyectado (ej. en tests específicos)
      setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.friendsController;
    final currentUsername = controller?.currentProfile?.username ??
        widget.email.split('@').first;
    final isUpdating = controller?.isUpdatingUsername ?? false;
    final errorMessage = _localValidationError ?? controller?.errorMessage;
    final successMessage = controller?.successMessage;

    return GlassCard(
      blur: 16.0,
      borderRadius: 22.0,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LiquidTheme.liquidPrimaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: LiquidTheme.primaryCyan.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF0D1219),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Cuenta Activa',
                          style: TextStyle(
                            color: LiquidTheme.primaryCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        if (!_isEditing)
                          IconButton(
                            icon: Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: LiquidTheme.primaryLiquid,
                            ),
                            tooltip: 'Editar nombre de usuario',
                            onPressed: () {
                              _usernameController.text = currentUsername;
                              setState(() {
                                _isEditing = true;
                                _localValidationError = null;
                                controller?.clearMessages();
                              });
                            },
                          ),
                      ],
                    ),
                    if (!_isEditing) ...[
                      Text(
                        '@$currentUsername',
                        style: TextStyle(
                          color: LiquidTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.email,
                        style: TextStyle(
                          color: LiquidTheme.textSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usernameController,
                              style: TextStyle(
                                color: LiquidTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              autofocus: true,
                              decoration: InputDecoration(
                                prefixText: '@',
                                prefixStyle: TextStyle(
                                  color: LiquidTheme.primaryLiquid,
                                  fontWeight: FontWeight.bold,
                                ),
                                hintText: 'nuevo_usuario',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (_) => _handleSaveUsername(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isUpdating)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          else ...[
                            IconButton(
                              icon: Icon(
                                Icons.check_circle_rounded,
                                color: LiquidTheme.accentEmerald,
                                size: 24,
                              ),
                              tooltip: 'Guardar',
                              onPressed: _handleSaveUsername,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.cancel_rounded,
                                color: LiquidTheme.textSecondary,
                                size: 24,
                              ),
                              tooltip: 'Cancelar',
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _localValidationError = null;
                                  controller?.clearMessages();
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            LiquidBanner(
              message: errorMessage,
              type: BannerType.error,
              onClose: () {
                setState(() => _localValidationError = null);
                controller?.clearMessages();
              },
            ),
          ],
          if (successMessage != null && !_isEditing) ...[
            const SizedBox(height: 12),
            LiquidBanner(
              message: successMessage,
              type: BannerType.success,
              onClose: () => controller?.clearMessages(),
            ),
          ],
        ],
      ),
    );
  }
}
