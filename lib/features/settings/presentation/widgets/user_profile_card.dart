import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/update_password_modal.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/widgets/avatar_picker_modal.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';

/// Tarjeta de perfil del usuario en la pantalla de Ajustes
/// Incluye personalización de avatar, edición de username y solicitud de cambio de contraseña
class UserProfileCard extends StatefulWidget {
  final String email;
  final ProfileController? profileController;
  final AuthController? authController;
  final FriendsController? friendsController;

  const UserProfileCard({
    super.key,
    required this.email,
    this.profileController,
    this.authController,
    this.friendsController,
  });

  @override
  State<UserProfileCard> createState() => _UserProfileCardState();
}

class _UserProfileCardState extends State<UserProfileCard> {
  bool _isEditing = false;
  late final TextEditingController _usernameController;
  String? _localValidationError;
  String? _passwordUpdateFeedback;

  @override
  void initState() {
    super.initState();
    final initialUsername = widget.profileController?.currentProfile?.username ??
        widget.friendsController?.currentProfile?.username ??
        widget.email.split('@').first;
    _usernameController = TextEditingController(text: initialUsername);

    widget.profileController?.addListener(_onControllerUpdate);
    widget.friendsController?.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.profileController?.removeListener(_onControllerUpdate);
    widget.friendsController?.removeListener(_onControllerUpdate);
    _usernameController.dispose();
    super.dispose();
  }

  ProfileModel _resolveProfile(String fallbackUsername) {
    if (widget.profileController?.currentProfile != null) {
      return widget.profileController!.currentProfile!;
    }
    if (widget.friendsController?.currentProfile != null) {
      return widget.friendsController!.currentProfile!;
    }
    return ProfileModel(
      id: 'me',
      username: fallbackUsername,
      updatedAt: DateTime.now(),
    );
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

    bool ok = false;
    if (widget.profileController != null) {
      ok = await widget.profileController!.updateUsername(newName);
    } else if (widget.friendsController != null) {
      ok = await widget.friendsController!.updateUsername(newName);
    } else {
      ok = true;
    }

    if (ok && mounted) {
      setState(() => _isEditing = false);
    }
  }

  void _openAvatarPicker() {
    if (widget.profileController != null) {
      AvatarPickerModal.show(
        context,
        profileController: widget.profileController!,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Controlador de perfil no disponible')),
      );
    }
  }

  void _openChangePasswordModal() {
    final authCtrl = widget.authController;
    if (authCtrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio de autenticación no disponible')),
      );
      return;
    }

    UpdatePasswordModal.show(
      context,
      authController: authCtrl,
      isDismissible: true,
      onPasswordUpdated: () {
        setState(() {
          _passwordUpdateFeedback = '¡Contraseña actualizada con éxito!';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileCtrl = widget.profileController;
    final friendsCtrl = widget.friendsController;

    final currentUsername = profileCtrl?.currentProfile?.username ??
        friendsCtrl?.currentProfile?.username ??
        widget.email.split('@').first;

    final profile = _resolveProfile(currentUsername);

    final isUpdating = (profileCtrl?.isUpdatingUsername ?? false) ||
        (friendsCtrl?.isUpdatingUsername ?? false);

    final errorMessage = _localValidationError ??
        profileCtrl?.errorMessage ??
        friendsCtrl?.errorMessage;

    final successMessage = profileCtrl?.successMessage ?? friendsCtrl?.successMessage;

    return GlassCard(
      blur: 16.0,
      borderRadius: 22.0,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Avatar con badge editable interactivo
              UserAvatar.fromProfile(
                profile: profile,
                size: 62,
                isEditable: true,
                showGlow: true,
                onTap: _openAvatarPicker,
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
                                profileCtrl?.clearMessages();
                                friendsCtrl?.clearMessages();
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
                                  profileCtrl?.clearMessages();
                                  friendsCtrl?.clearMessages();
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

          const SizedBox(height: 16),

          // Botón Cambiar Contraseña / Seguridad
          NeumorphicContainer(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            baseColor: LiquidTheme.surfaceDark.withValues(alpha: 0.6),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _openChangePasswordModal,
              child: Row(
                children: [
                  Icon(
                    Icons.lock_reset_rounded,
                    color: LiquidTheme.primaryLiquid,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cambiar Contraseña',
                      style: TextStyle(
                        color: LiquidTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: LiquidTheme.textSecondary,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            LiquidBanner(
              message: errorMessage,
              type: BannerType.error,
              onClose: () {
                setState(() => _localValidationError = null);
                profileCtrl?.clearMessages();
                friendsCtrl?.clearMessages();
              },
            ),
          ],

          if (successMessage != null && !_isEditing) ...[
            const SizedBox(height: 12),
            LiquidBanner(
              message: successMessage,
              type: BannerType.success,
              onClose: () {
                profileCtrl?.clearMessages();
                friendsCtrl?.clearMessages();
              },
            ),
          ],

          if (_passwordUpdateFeedback != null) ...[
            const SizedBox(height: 12),
            LiquidBanner(
              message: _passwordUpdateFeedback!,
              type: _passwordUpdateFeedback!.contains('éxito')
                  ? BannerType.success
                  : BannerType.error,
              onClose: () => setState(() => _passwordUpdateFeedback = null),
            ),
          ],
        ],
      ),
    );
  }
}
