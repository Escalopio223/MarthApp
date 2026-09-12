import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_container.dart';
import '../../domain/friend_code_manager.dart';

/// Tarjeta del código de amigo autogenerado con cuenta regresiva de 1 minuto
class FriendCodeCard extends StatelessWidget {
  final FriendCodeManager friendCodeManager;
  final VoidCallback onGenerateCode;

  const FriendCodeCard({
    super.key,
    required this.friendCodeManager,
    required this.onGenerateCode,
  });

  void _copyToClipboard(BuildContext context, String code) {
    // Si el código empieza por MARTH-, copiar únicamente el sufijo (ej: "TVU7" en lugar de "MARTH-TVU7")
    final suffix = code.startsWith('MARTH-') ? code.substring(6) : code;
    Clipboard.setData(ClipboardData(text: suffix));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código "$suffix" copiado al portapapeles'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 18.0,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          Text(
            'Comparte tu código temporal. Es válido durante 1 minuto exacto y luego se elimina por seguridad.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Estado actual del código
          if (friendCodeManager.hasActiveCode)
            _buildActiveCodeBox(context)
          else if (friendCodeManager.isExpired)
            _buildExpiredNotice()
          else
            _buildInitialNotice(),

          const SizedBox(height: 18),

          // Botón de generación / regeneración
          AppButton(
            text: friendCodeManager.hasActiveCode
                ? 'Regenerar Código'
                : 'Generar Código (1 min)',
            icon: Icons.refresh_rounded,
            height: 48,
            gradient: AppTheme.actionGradient,
            onPressed: onGenerateCode,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.group_add_rounded,
            color: AppTheme.primaryAccent,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Mi Código de Amigo',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCodeBox(BuildContext context) {
    final code = friendCodeManager.currentCode!;

    return AppContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: AppTheme.primaryAccent,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.copy_rounded,
                    color: AppTheme.textSecondary),
                tooltip: 'Copiar código',
                onPressed: () => _copyToClipboard(context, code),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra de progreso de 1 minuto
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: friendCodeManager.progress,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceDark,
              valueColor: AlwaysStoppedAnimation<Color>(
                friendCodeManager.remainingSeconds <= 15
                    ? AppTheme.accentCoral
                    : AppTheme.primaryAccent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⏳ Expira en ${friendCodeManager.remainingSeconds}s',
                style: TextStyle(
                  color: friendCodeManager.remainingSeconds <= 15
                      ? AppTheme.accentCoral
                      : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Duración: 1 min',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentCoral.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_off_rounded,
              color: AppTheme.accentCoral, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'El código ha expirado y ha sido eliminado automáticamente.',
              style: TextStyle(
                color: AppTheme.accentCoral,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cardBorderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppTheme.primaryAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No tienes ningún código activo. Pulsa el botón para generar uno válido durante 1 minuto.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
