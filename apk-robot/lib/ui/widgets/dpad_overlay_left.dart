import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DPadOverlayLeft extends StatefulWidget {
  final bool isAutonomous;
  final bool useJoystick;
  final ValueChanged<String> onCommandSent;

  const DPadOverlayLeft({
    super.key,
    required this.isAutonomous,
    required this.useJoystick,
    required this.onCommandSent,
  });

  @override
  State<DPadOverlayLeft> createState() => _DPadOverlayLeftState();
}

class _DPadOverlayLeftState extends State<DPadOverlayLeft> {
  String? _activeButton;

  void _handlePress(String cmd) {
    if (widget.isAutonomous) return;
    setState(() => _activeButton = cmd);
    widget.onCommandSent(cmd);
  }

  void _handleRelease(String cmd) {
    if (widget.isAutonomous) return;
    setState(() => _activeButton = null);
    widget.onCommandSent('stop');
  }

  @override
  Widget build(BuildContext context) {
    // Si se está usando el Joystick Físico o el modo es AUTÓNOMO, se ocultan por completo las flechas de la izquierda
    if (widget.useJoystick || widget.isAutonomous) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 170,
      height: 170,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withOpacity(0.85),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.neonCyan.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
          )
        ],
      ),
      child: Stack(
        children: [
          // ARRIBA
          Align(
            alignment: Alignment.topCenter,
            child: _buildArrowBtn('up', Icons.keyboard_arrow_up_rounded),
          ),
          // ABAJO
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildArrowBtn('down', Icons.keyboard_arrow_down_rounded),
          ),
          // IZQUIERDA
          Align(
            alignment: Alignment.centerLeft,
            child: _buildArrowBtn('left', Icons.keyboard_arrow_left_rounded),
          ),
          // DERECHA
          Align(
            alignment: Alignment.centerRight,
            child: _buildArrowBtn('right', Icons.keyboard_arrow_right_rounded),
          ),
          // PARAR (CENTRO)
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTapDown: (_) => _handlePress('stop'),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.crimsonRed,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowBtn(String cmd, IconData icon) {
    final isActive = _activeButton == cmd;

    return GestureDetector(
      onTapDown: (_) => _handlePress(cmd),
      onTapUp: (_) => _handleRelease(cmd),
      onTapCancel: () => _handleRelease(cmd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.neonCyan.withOpacity(0.4) : AppTheme.bgDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppTheme.neonCyan : AppTheme.borderDark,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : AppTheme.neonCyan,
          size: 26,
        ),
      ),
    );
  }
}
