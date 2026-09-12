import 'package:flutter/material.dart';
import '../../../../core/widgets/app_background.dart';
import '../controllers/auth_controller.dart';
import '../widgets/update_password_card.dart';

/// Pantalla dedicada para actualizar la contraseña tras capturar el evento de recuperación
class UpdatePasswordScreen extends StatefulWidget {
  final AuthController? controller;
  final VoidCallback onPasswordUpdated;

  const UpdatePasswordScreen({
    super.key,
    this.controller,
    required this.onPasswordUpdated,
  });

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = widget.controller ?? AuthController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: UpdatePasswordCard(
                authController: _authController,
                centeredHeader: true,
                submitButtonText: 'Guardar Nueva Contraseña',
                subtitle: 'Introduce tu nueva contraseña segura para tu cuenta de MarthApp.',
                onSuccess: widget.onPasswordUpdated,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
