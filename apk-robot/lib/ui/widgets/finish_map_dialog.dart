import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FinishMapDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const FinishMapDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.emeraldGreen, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono reluciente de finalización
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.emeraldGreen.withOpacity(0.2),
                border: Border.all(color: AppTheme.emeraldGreen, width: 2),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppTheme.emeraldGreen,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),

            // Título
            const Text(
              '¿Aceptar y Finalizar Mapeo?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            // Descripción
            const Text(
              'Esta acción dará por concluido el escaneo SLAM actual y enviará la orden a la laptop ThinkPad T490 para guardar la matriz de mapa generada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Botones de acción
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
                      backgroundColor: AppTheme.emeraldGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ACEPTAR',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
