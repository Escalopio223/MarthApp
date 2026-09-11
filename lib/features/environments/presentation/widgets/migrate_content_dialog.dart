import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_button.dart';

/// Modal de salvaguarda obligatorio previo a eliminar, abandonar o expulsar de un entorno
/// Ofrece la opción de migrar el contenido propio al espacio personal antes de proceder.
class MigrateContentDialog extends StatefulWidget {
  final String environmentName;
  final String actionTitle;
  final Future<bool> Function() onMigrateAndProceed;
  final Future<bool> Function() onProceedWithoutMigrating;

  const MigrateContentDialog({
    super.key,
    required this.environmentName,
    this.actionTitle = 'Continuar',
    required this.onMigrateAndProceed,
    required this.onProceedWithoutMigrating,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String environmentName,
    String actionTitle = 'Continuar',
    required Future<bool> Function() onMigrateAndProceed,
    required Future<bool> Function() onProceedWithoutMigrating,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MigrateContentDialog(
        environmentName: environmentName,
        actionTitle: actionTitle,
        onMigrateAndProceed: onMigrateAndProceed,
        onProceedWithoutMigrating: onProceedWithoutMigrating,
      ),
    );
  }

  @override
  State<MigrateContentDialog> createState() => _MigrateContentDialogState();
}

class _MigrateContentDialogState extends State<MigrateContentDialog> {
  bool _isMigrating = false;
  bool _isProceeding = false;
  String? _errorMessage;

  Future<void> _handleMigrate() async {
    setState(() {
      _isMigrating = true;
      _errorMessage = null;
    });

    try {
      final ok = await widget.onMigrateAndProceed();
      if (ok && mounted) {
        Navigator.of(context, rootNavigator: true).pop(true);
      } else if (mounted) {
        setState(() => _errorMessage = 'No se pudo completar la migración');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  Future<void> _handleProceedWithoutMigrating() async {
    setState(() {
      _isProceeding = true;
      _errorMessage = null;
    });

    try {
      final ok = await widget.onProceedWithoutMigrating();
      if (ok && mounted) {
        Navigator.of(context, rootNavigator: true).pop(false);
      } else if (mounted) {
        setState(() => _errorMessage = 'No se pudo completar la acción');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isProceeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isMigrating || _isProceeding;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassCard(
              blur: 24.0,
              borderRadius: 24.0,
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                        border: Border.all(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        size: 34,
                        color: Color(0xFFFFB300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    '¿Deseas migrar tu contenido?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: LiquidTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'Antes de realizar esta acción en "${widget.environmentName}", puedes reasignar atómicamente todas tus listas y elementos creados a tu entorno personal "Mi Espacio" para no perderlos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LiquidTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: LiquidTheme.accentCoral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: LiquidTheme.accentCoral,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Botón 1: Migrar y continuar
                  LiquidButton(
                    text: 'Migrar a "Mi Espacio" y Continuar',
                    icon: Icons.drive_file_move_rounded,
                    isLoading: _isMigrating,
                    onPressed: isBusy ? null : _handleMigrate,
                  ),
                  const SizedBox(height: 12),

                  // Botón 2: Continuar sin migrar
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LiquidTheme.accentCoral,
                      side: BorderSide(
                        color: LiquidTheme.accentCoral.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isBusy ? null : _handleProceedWithoutMigrating,
                    child: _isProceeding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.actionTitle),
                  ),
                  const SizedBox(height: 8),

                  // Botón 3: Cancelar
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () => Navigator.of(context, rootNavigator: true).pop(null),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: LiquidTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
