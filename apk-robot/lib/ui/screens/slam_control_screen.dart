import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../services/robot_network_service.dart';
import '../widgets/top_app_bar_trio.dart';
import '../widgets/dpad_overlay_left.dart';
import '../widgets/slam_map_painter.dart';
import '../widgets/finish_map_dialog.dart';
import '../widgets/autonomous_action_dialog.dart';
import 'settings_dialog.dart';

class SlamControlScreen extends StatefulWidget {
  const SlamControlScreen({super.key});

  @override
  State<SlamControlScreen> createState() => _SlamControlScreenState();
}

class _SlamControlScreenState extends State<SlamControlScreen> {
  final _netService = RobotNetworkService();
  bool _isConnected = false;

  // Iniciar por defecto en la FUNCIÓN AUTÓNOMO
  SlamMode _currentMode = SlamMode.autonomous;
  bool _useJoystick = false;

  // Estado interno de la función de ESCANEO (false = INICIAR, true = CONCLUIDO)
  bool _isScanStarted = false;

  // Estado interno de la navegación autónoma (Inicia activa por defecto)
  bool _isAutonomousRunning = true;

  @override
  void initState() {
    super.initState();
    _netService.init();

    _netService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });

    _netService.modeStream.listen((mode) {
      if (mounted) {
        setState(() {
          _currentMode = mode;
        });
      }
    });
  }

  void _onModeSelected(SlamMode newMode) {
    // REGLA: Si el modo AUTÓNOMO está en ejecución, primero se debe presionar DETENER para cambiar de función
    if (_isAutonomousRunning && newMode != SlamMode.autonomous) {
      _confirmAutonomousAction(
        isStopping: true,
        onConfirmed: () {
          // Si intenta ir a MANUAL y el escaneo aún sigue abierto
          if (newMode == SlamMode.manual && _isScanStarted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Para usar el Modo MANUAL primero debes presionar CONCLUIDO y finalizar el escaneo de mapa.'),
                backgroundColor: AppTheme.crimsonRed,
                duration: Duration(seconds: 3),
              ),
            );
            setState(() => _isAutonomousRunning = false);
            return;
          }

          setState(() {
            _currentMode = newMode;
            _isAutonomousRunning = false;
          });
          _netService.setMode(newMode);
          _netService.sendDirectionCommand('stop');
        },
      );
      return;
    }

    // REGLA: Para usar el Modo MANUAL debe estar desactivado tanto AUTÓNOMO como ESCANEO
    if (newMode == SlamMode.manual && _isScanStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Para usar el Modo MANUAL primero debes presionar CONCLUIDO y finalizar el escaneo de mapa.'),
          backgroundColor: AppTheme.crimsonRed,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _currentMode = newMode;
    });
    _netService.setMode(newMode);
  }

  void _startScan() {
    // REGLA: No iniciar escaneo si AUTÓNOMO está activo
    if (_isAutonomousRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No se puede iniciar el escaneo de mapa. Primero debes presionar DETENER en la Función AUTÓNOMA.'),
          backgroundColor: AppTheme.crimsonRed,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isScanStarted = true);
    _netService.setMode(SlamMode.scan);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚀 Mapeo SLAM iniciado. Guía el robot con el Joystick o las flechas.'),
        backgroundColor: AppTheme.amberWarning,
      ),
    );
  }

  void _confirmAutonomousAction({
    required bool isStopping,
    required VoidCallback onConfirmed,
  }) {
    showDialog(
      context: context,
      builder: (context) => AutonomousActionDialog(
        isStopping: isStopping,
        onConfirm: onConfirmed,
      ),
    );
  }

  void _toggleAutonomousAction() {
    if (_isAutonomousRunning) {
      // Confirmación para DETENER
      _confirmAutonomousAction(
        isStopping: true,
        onConfirmed: () {
          setState(() => _isAutonomousRunning = false);
          _netService.sendDirectionCommand('stop');
        },
      );
    } else {
      // REGLA: No activar autónomo si el escaneo está activo
      if (_isScanStarted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No se puede activar la Función AUTÓNOMA mientras el escaneo de mapa está en curso. Presiona CONCLUIDO primero.'),
            backgroundColor: AppTheme.crimsonRed,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Confirmación para ACTIVAR
      _confirmAutonomousAction(
        isStopping: false,
        onConfirmed: () {
          setState(() => _isAutonomousRunning = true);
          _netService.setMode(SlamMode.autonomous);
        },
      );
    }
  }

  void _onCommandSent(String cmd) {
    // REGLA: En modo MANUAL solo se puede mover si AUTÓNOMO y ESCANEO están desactivados
    if (_isAutonomousRunning || _isScanStarted && _currentMode == SlamMode.manual) {
      return;
    }
    _netService.sendDirectionCommand(cmd);
  }

  void _openFinishDialog() {
    showDialog(
      context: context,
      builder: (context) => FinishMapDialog(
        onConfirm: () async {
          final messenger = ScaffoldMessenger.of(context);
          final success = await _netService.finishAndSaveMap();
          if (success) {
            setState(() => _isScanStarted = false);
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? '🎉 ¡Mapa guardado y cargado en el programa del robot!'
                    : '❌ Error al comunicarse con la ThinkPad T490.',
              ),
              backgroundColor: success ? AppTheme.emeraldGreen : AppTheme.crimsonRed,
            ),
          );
        },
      ),
    );
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAutonomous = _currentMode == SlamMode.autonomous;
    final isScanning = _currentMode == SlamMode.scan;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (KeyEvent event) {
        if (isAutonomous || _isAutonomousRunning) return;
        if (event is KeyDownEvent) {
          if (!_useJoystick) {
            setState(() => _useJoystick = true);
          }
          final key = event.logicalKey.keyLabel.toLowerCase();
          if (key.contains('up') || key == 'w') _onCommandSent('up');
          if (key.contains('down') || key == 's') _onCommandSent('down');
          if (key.contains('left') || key == 'a') _onCommandSent('left');
          if (key.contains('right') || key == 'd') _onCommandSent('right');
        } else if (event is KeyUpEvent) {
          _onCommandSent('stop');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF070C16),
        body: SafeArea(
          child: Stack(
            children: [
              // 1. FONDO PRINCIPAL: MAPA SLAM EN PANTALLA COMPLETA
              Positioned.fill(
                child: SlamMapPainterWidget(
                  isAutonomous: isAutonomous,
                  isScanning: isScanning,
                ),
              ),

              // 2. PARTE SUPERIOR: BARRA UNIFICADA DE MODOS (MANUAL | ESCANEO | AUTÓNOMO)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: TopAppBarTrio(
                  isConnected: _isConnected,
                  robotIp: _netService.ip,
                  currentMode: _currentMode,
                  onModeChanged: _onModeSelected,
                  onOpenSettings: _openSettings,
                  isScanStarted: _isScanStarted,
                  onStartScan: _startScan,
                  onOpenFinishDialog: _openFinishDialog,
                  useJoystick: _useJoystick,
                  onToggleJoystick: (val) {
                    setState(() => _useJoystick = val);
                  },
                ),
              ),

              // 3. LADO IZQUIERDO: FLECHAS DIRECCIONALES (HOLD & RELEASE)
              Positioned(
                left: 16,
                bottom: 20,
                child: DPadOverlayLeft(
                  isAutonomous: isAutonomous || _isAutonomousRunning,
                  useJoystick: _useJoystick,
                  onCommandSent: _onCommandSent,
                ),
              ),

              // 4. MODO AUTÓNOMO: BOTÓN DETENER / ACTIVAR CON CONFIRMACIÓN
              if (isAutonomous)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: ElevatedButton.icon(
                    onPressed: _toggleAutonomousAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAutonomousRunning
                          ? AppTheme.crimsonRed
                          : AppTheme.neonIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.white, width: 2),
                      ),
                      elevation: 8,
                    ),
                    icon: Icon(
                      _isAutonomousRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 26,
                    ),
                    label: Text(
                      _isAutonomousRunning ? 'DETENER' : 'ACTIVAR',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

              // 5. BADGE DE JOYSTICK ACTIVO
              if (_useJoystick && !isAutonomous && !_isAutonomousRunning)
                Positioned(
                  left: 16,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emeraldGreen),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.videogame_asset_rounded, color: AppTheme.emeraldGreen, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '🕹️ Joystick Físico Activo (Flechas Ocultas)',
                          style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
