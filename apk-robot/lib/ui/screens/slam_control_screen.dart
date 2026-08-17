import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../services/robot_network_service.dart';
import '../widgets/top_app_bar_trio.dart';
import '../widgets/dpad_overlay_left.dart';
import '../widgets/slam_map_painter.dart';
import '../widgets/finish_map_dialog.dart';
import 'settings_dialog.dart';
import 'start_screen.dart';

class SlamControlScreen extends StatefulWidget {
  const SlamControlScreen({super.key});

  @override
  State<SlamControlScreen> createState() => _SlamControlScreenState();
}

class _SlamControlScreenState extends State<SlamControlScreen> {
  final _netService = RobotNetworkService();
  bool _isConnected = false;

  // Iniciar por defecto en Modo MANUAL
  SlamMode _currentMode = SlamMode.manual;
  bool _useJoystick = false;

  // Estado interno de la función de ESCANEO (false = INICIAR, true = CONCLUIDO)
  bool _isScanStarted = false;

  // Estado interno de la navegación autónoma
  bool _isAutonomousRunning = false;

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
    setState(() => _isScanStarted = true);
    _netService.setMode(SlamMode.scan);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚀 Mapeo SLAM iniciado. Guía el robot con el Joystick o las flechas.'),
        backgroundColor: AppTheme.amberWarning,
      ),
    );
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

  void _onExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: AppTheme.crimsonRed),
            SizedBox(width: 10),
            Text(
              'Desconectar Hotspot',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          '¿Deseas salir del control y desactivar el Hotspot RoverNet para que la laptop de a bordo se reconecte a la red principal?',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📡 Desactivando Hotspot RoverNet y reconectando la laptop...'),
                  backgroundColor: AppTheme.crimsonRed,
                  duration: Duration(seconds: 3),
                ),
              );

              await _netService.disconnectHotspotAndReconnectMainNetwork();

              await SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]);

              if (!mounted || !context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const StartScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimsonRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('SALIR Y RECONECTAR'),
          ),
        ],
      ),
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
                  onExit: _onExit,
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
