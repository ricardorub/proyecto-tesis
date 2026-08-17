import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AutonomousActionDialog extends StatelessWidget {
  final bool isStopping; // true = Detener, false = Activar
  final VoidCallback onConfirm;

  const AutonomousActionDialog({
    super.key,
    required this.isStopping,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final title = isStopping ? '¿Detener Función Autónoma?' : '¿Activar Función Autónoma?';
    final description = isStopping
        ? '¿Estás seguro de que deseas detener la navegación autónoma? El robot parará su recorrido inmediatamente.'
        : '¿Estás seguro de que deseas activar nuevamente la navegación autónoma con el mapa cargado?';
    final btnText = isStopping ? 'SÍ, DETENER' : 'SÍ, ACTIVAR';
    final btnColor = isStopping ? AppTheme.crimsonRed : AppTheme.neonIndigo;
    final icon = isStopping ? Icons.front_hand_rounded : Icons.play_arrow_rounded;

    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: btnColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: btnColor.withOpacity(0.2),
                border: Border.all(color: btnColor, width: 2),
              ),
              child: Icon(
                icon,
                color: btnColor,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: AppTheme.borderDark),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('CANCELAR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      btnText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
