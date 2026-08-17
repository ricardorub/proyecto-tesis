import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../services/robot_network_service.dart';

class TopAppBarTrio extends StatelessWidget {
  final bool isConnected;
  final String robotIp;
  final SlamMode currentMode;
  final ValueChanged<SlamMode> onModeChanged;
  final VoidCallback onOpenSettings;
  final bool isScanStarted;
  final VoidCallback onStartScan;
  final VoidCallback onOpenFinishDialog;
  final bool useJoystick;
  final ValueChanged<bool> onToggleJoystick;
  final VoidCallback? onExit;

  const TopAppBarTrio({
    super.key,
    required this.isConnected,
    required this.robotIp,
    required this.currentMode,
    required this.onModeChanged,
    required this.onOpenSettings,
    required this.isScanStarted,
    required this.onStartScan,
    required this.onOpenFinishDialog,
    required this.useJoystick,
    required this.onToggleJoystick,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final isScanning = currentMode == SlamMode.scan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Estado de Conexión ThinkPad T490
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? AppTheme.emeraldGreen : AppTheme.crimsonRed,
              boxShadow: [
                BoxShadow(
                  color: isConnected
                      ? AppTheme.emeraldGreen.withOpacity(0.8)
                      : AppTheme.crimsonRed.withOpacity(0.8),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ROVER SLAM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                isConnected ? 'T490 ($robotIp)' : 'Offline',
                style: TextStyle(
                  fontSize: 9,
                  color: isConnected ? AppTheme.emeraldGreen : Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // 2. BOTONES DE MODO PRINCIPALES (MANUAL | ESCANEO | SALIR)
          Expanded(
            child: Row(
              children: [
                _buildModeBtn(
                  mode: SlamMode.manual,
                  label: 'MANUAL',
                  icon: Icons.sports_esports_rounded,
                  activeColor: AppTheme.neonCyan,
                ),
                const SizedBox(width: 6),
                _buildModeBtn(
                  mode: SlamMode.scan,
                  label: 'ESCANEO',
                  icon: Icons.map_rounded,
                  activeColor: AppTheme.amberWarning,
                ),
                const SizedBox(width: 6),
                // Botón SALIR (Desactivar Hotspot y Reconectar Laptop)
                Expanded(
                  child: GestureDetector(
                    onTap: onExit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.crimsonRed.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.crimsonRed,
                          width: 1.5,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, size: 16, color: AppTheme.crimsonRed),
                          SizedBox(width: 6),
                          Text(
                            'SALIR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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

          const SizedBox(width: 10),

          // 3. Conmutador de Joystick / Ocultar flechas
          IconButton(
            tooltip: useJoystick ? 'Joystick Activo (Flechas Ocultas)' : 'Usar Joystick Físico',
            icon: Icon(
              Icons.videogame_asset_rounded,
              color: useJoystick ? AppTheme.emeraldGreen : Colors.grey,
              size: 22,
            ),
            onPressed: () => onToggleJoystick(!useJoystick),
          ),

          // 4. Botón de Ajustes (⚙️)
          IconButton(
            tooltip: 'Ajustes IP',
            icon: const Icon(Icons.settings_rounded, color: AppTheme.neonCyan, size: 22),
            onPressed: onOpenSettings,
          ),

          // 5. Botón INICIAR / CONCLUIDO (Visible en modo ESCANEO)
          if (isScanning) ...[
            const SizedBox(width: 6),
            if (!isScanStarted)
              ElevatedButton.icon(
                onPressed: onStartScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.amberWarning,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text(
                  'INICIAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: onOpenFinishDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'CONCLUIDO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeBtn({
    required SlamMode mode,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isActive = currentMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => onModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.25) : AppTheme.bgDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? activeColor : AppTheme.borderDark,
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.4),
                      blurRadius: 8,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? activeColor : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
