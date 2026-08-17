import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../services/robot_network_service.dart';

class ModeSelectorTrio extends StatelessWidget {
  final SlamMode currentMode;
  final ValueChanged<SlamMode> onModeChanged;

  const ModeSelectorTrio({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark, width: 1),
      ),
      child: Column(
        children: [
          // 1. Botón FUNCIÓN ESCANEO
          _buildButton(
            mode: SlamMode.scan,
            title: 'ESCANEO',
            icon: Icons.map_rounded,
            activeColor: AppTheme.amberWarning,
          ),
          const SizedBox(height: 6),

          // 2. Botón FUNCIÓN MANUAL
          _buildButton(
            mode: SlamMode.manual,
            title: 'MANUAL',
            icon: Icons.sports_esports_rounded,
            activeColor: AppTheme.neonCyan,
          ),

        ],
      ),
    );
  }

  Widget _buildButton({
    required SlamMode mode,
    required String title,
    required IconData icon,
    required Color activeColor,
  }) {
    final isActive = currentMode == mode;

    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (isActive)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
