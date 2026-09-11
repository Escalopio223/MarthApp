import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import 'update_password_card.dart';

/// Modal para introducir y confirmar la nueva contraseña tras el enlace de recuperación o desde Ajustes
class UpdatePasswordModal extends StatelessWidget {
  final AuthController authController;
  final VoidCallback onPasswordUpdated;
  final bool isDismissible;

  const UpdatePasswordModal({
    super.key,
    required this.authController,
    required this.onPasswordUpdated,
    this.isDismissible = true,
  });

  static Future<void> show(
    BuildContext context, {
    required AuthController authController,
    required VoidCallback onPasswordUpdated,
    bool isDismissible = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (_) => UpdatePasswordModal(
        authController: authController,
        onPasswordUpdated: onPasswordUpdated,
        isDismissible: isDismissible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: isDismissible,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: UpdatePasswordCard(
                authController: authController,
                isDismissible: isDismissible,
                submitButtonText: 'Confirmar y Guardar',
                onClose: () => Navigator.of(context, rootNavigator: true).pop(),
                onSuccess: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  onPasswordUpdated();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
