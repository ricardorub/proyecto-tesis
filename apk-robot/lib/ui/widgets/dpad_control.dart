import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DPadControl extends StatefulWidget {
  final bool isAutomatic;
  final ValueChanged<String> onCommandSent;

  const DPadControl({
    super.key,
    required this.isAutomatic,
    required this.onCommandSent,
  });

  @override
  State<DPadControl> createState() => _DPadControlState();
}

class _DPadControlState extends State<DPadControl> {
  String? _activeButton;

  void _handlePress(String cmd) {
    if (widget.isAutomatic && cmd != 'stop') return;
    setState(() => _activeButton = cmd);
    widget.onCommandSent(cmd);
  }

  void _handleRelease(String cmd) {
    if (widget.isAutomatic) return;
    setState(() => _activeButton = null);
    widget.onCommandSent('stop');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Contenedor principal de la cruceta D-Pad
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.cardDark,
            border: Border.all(
              color: widget.isAutomatic
                  ? AppTheme.borderDark.withOpacity(0.5)
                  : AppTheme.neonCyan.withOpacity(0.4),
              width: 2,
            ),
            boxShadow: widget.isAutomatic
                ? []
                : [
                    BoxShadow(
                      color: AppTheme.neonBlue.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // ARRIBA (UP)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildDPadButton(
                    cmd: 'up',
                    icon: Icons.keyboard_arrow_up_rounded,
                    label: 'ARRIBA',
                  ),
                ),
              ),

              // ABAJO (DOWN)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildDPadButton(
                    cmd: 'down',
                    icon: Icons.keyboard_arrow_down_rounded,
                    label: 'ABAJO',
                  ),
                ),
              ),

              // IZQUIERDA (LEFT)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _buildDPadButton(
                    cmd: 'left',
                    icon: Icons.keyboard_arrow_left_rounded,
                    label: 'IZQ',
                  ),
                ),
              ),

              // DERECHA (RIGHT)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildDPadButton(
                    cmd: 'right',
                    icon: Icons.keyboard_arrow_right_rounded,
                    label: 'DER',
                  ),
                ),
              ),

              // BOTÓN CENTRAL - STOP (PARADA DE EMERGENCIA)
              Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTapDown: (_) => _handlePress('stop'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.crimsonRed,
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.crimsonRed.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stop_rounded, color: Colors.white, size: 28),
                        Text(
                          'PARAR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // CAPA DE BLOQUEO CUANDO MODO AUTOMÁTICO ESTÁ ACTIVO
        if (widget.isAutomatic)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.65),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.neonIndigo.withOpacity(0.3),
                        border: Border.all(color: AppTheme.neonIndigo, width: 2),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: AppTheme.neonIndigo,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.neonIndigo.withOpacity(0.6)),
                      ),
                      child: const Text(
                        'MODO AUTÓNOMO ACTIVO\nFlechas Inhabilitadas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDPadButton({
    required String cmd,
    required IconData icon,
    required String label,
  }) {
    final isActive = _activeButton == cmd;
    final isDisabled = widget.isAutomatic;

    return GestureDetector(
      onTapDown: (_) => _handlePress(cmd),
      onTapUp: (_) => _handleRelease(cmd),
      onTapCancel: () => _handleRelease(cmd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.shade900.withOpacity(0.5)
              : (isActive ? AppTheme.neonCyan.withOpacity(0.4) : AppTheme.borderDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled
                ? Colors.transparent
                : (isActive ? AppTheme.neonCyan : AppTheme.borderDark),
            width: 2,
          ),
          boxShadow: (isActive && !isDisabled)
              ? [
                  BoxShadow(
                    color: AppTheme.neonCyan.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isDisabled
                  ? Colors.grey.shade600
                  : (isActive ? Colors.white : AppTheme.neonCyan),
              size: 32,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isDisabled
                    ? Colors.grey.shade600
                    : (isActive ? Colors.white : Colors.grey.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
