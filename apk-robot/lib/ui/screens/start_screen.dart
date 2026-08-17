import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../services/config_service.dart';
import '../../services/robot_network_service.dart';
import 'slam_control_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final _netService = RobotNetworkService();
  String _robotIp = ConfigService.defaultIp;

  bool _isAccessing = false;
  double _progress = 0.0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    // Forzar orientación Vertical para la pantalla de inicio
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final ip = await ConfigService.getRobotIp();
    if (mounted) {
      setState(() {
        _robotIp = ip;
      });
    }
  }

  Future<void> _startAccessSequence() async {
    if (_isAccessing) return;

    setState(() {
      _isAccessing = true;
      _progress = 0.05;
      _statusText = 'Activando Wi-Fi en la laptop de a bordo...';
    });

    // 1. Iniciar servicio de red
    await _netService.init();

    // 2. Simular y establecer conexión al Hotspot RoverNet (10.42.0.1) paso a paso
    const totalSteps = 20;
    for (int i = 1; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 110));
      if (!mounted) return;

      final p = i / totalSteps;
      String status = 'Accediendo...';
      if (p < 0.25) {
        status = 'Activando Wi-Fi en la laptop de a bordo...';
      } else if (p < 0.50) {
        status = 'Configurando Hotspot abierto RoverNet ($_robotIp)...';
      } else if (p < 0.75) {
        status = 'Estableciendo enlace HTTP en http://$_robotIp:5000...';
      } else if (p < 0.95) {
        status = 'Conectando canal ROSBridge (ws://$_robotIp:9090)...';
      } else {
        status = '¡Acceso concedido! Abriendo control SLAM...';
      }

      setState(() {
        _progress = p;
        _statusText = status;
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    
    // Cambiar a horizontal para la pantalla de control SLAM y navegar
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted || !context.mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SlamControlScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070C16),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // HEADER & LOGO PRINCIPAL (IMAGEN DEL ROBOT)
              Column(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.cardDark,
                      border: Border.all(color: AppTheme.neonCyan, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonCyan.withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/rover_logo.png',
                      color: Colors.white,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'ROVER SLAM CONTROL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sistema de Monitoreo y Navegación de A Bordo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              // SECCIÓN INFERIOR: BOTÓN INGRESAR / BARRA DE PROGRESO "ACCEDIENDO"
              Column(
                children: [
                  if (!_isAccessing) ...[
                    // BOTÓN INGRESAR (SIN CONTRASEÑA)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _startAccessSequence,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonCyan,
                          foregroundColor: Colors.black,
                          elevation: 8,
                          shadowColor: AppTheme.neonCyan.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 24),
                        label: const Text(
                          'INGRESAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // VISTA CUANDO SE PRESIONA INGRESAR: TEXTO ACCEDIENDO + BARRA DE PROGRESO
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.neonCyan,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'ACCEDIENDO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: AppTheme.neonCyan,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 10,
                            backgroundColor: AppTheme.cardDark,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _statusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
