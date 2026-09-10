import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../../../../core/widgets/neumorphic_container.dart';
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
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 18.0,
      borderRadius: 24.0,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          const Text(
            'Comparte tu código temporal. Es válido durante 1 minuto exacto y luego se elimina por seguridad.',
            style: TextStyle(
              color: LiquidTheme.textSecondary,
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
          LiquidButton(
            text: friendCodeManager.hasActiveCode
                ? 'Regenerar Código'
                : 'Generar Código (1 min)',
            icon: Icons.refresh_rounded,
            height: 48,
            gradient: LiquidTheme.liquidPrimaryGradient,
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
            color: LiquidTheme.primaryCyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.group_add_rounded,
            color: LiquidTheme.primaryCyan,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Mi Código de Amigo',
            style: TextStyle(
              color: LiquidTheme.textPrimary,
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

    return NeumorphicContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: LiquidTheme.primaryCyan,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    color: LiquidTheme.textSecondary),
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
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                friendCodeManager.remainingSeconds <= 15
                    ? LiquidTheme.accentCoral
                    : LiquidTheme.accentEmerald,
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
                      ? LiquidTheme.accentCoral
                      : LiquidTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Duración: 1 min',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LiquidTheme.accentCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LiquidTheme.accentCoral.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.timer_off_rounded,
              color: LiquidTheme.accentCoral, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'El código ha expirado y ha sido eliminado automáticamente.',
              style: TextStyle(
                color: LiquidTheme.accentCoral,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: LiquidTheme.primaryCyan, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No tienes ningún código activo. Pulsa el botón para generar uno válido durante 1 minuto.',
              style: TextStyle(
                color: LiquidTheme.textSecondary,
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
