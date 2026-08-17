import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SlamMapPainterWidget extends StatefulWidget {
  final bool isAutonomous;
  final bool isScanning;

  const SlamMapPainterWidget({
    super.key,
    required this.isAutonomous,
    required this.isScanning,
  });

  @override
  State<SlamMapPainterWidget> createState() => _SlamMapPainterWidgetState();
}

class _SlamMapPainterWidgetState extends State<SlamMapPainterWidget> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070C16), // Fondo oscuro de mapeo militar/robótico
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isAutonomous
              ? AppTheme.neonIndigo.withOpacity(0.6)
              : AppTheme.neonBlue.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Canvas interactivo con gestos de Zoom y Pan
            GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_scale * details.scale).clamp(0.5, 3.0);
                  _offset += details.focalPointDelta;
                });
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: SlamGridPainter(
                  scale: _scale,
                  offset: _offset,
                  isAutonomous: widget.isAutonomous,
                  isScanning: widget.isScanning,
                ),
              ),
            ),

            // SUPERPOSICIÓN DE ESTADO SUPERIOR EN MAPA
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isScanning
                          ? Icons.radar_rounded
                          : (widget.isAutonomous
                              ? Icons.smart_toy_rounded
                              : Icons.sports_esports_rounded),
                      size: 16,
                      color: widget.isScanning
                          ? AppTheme.amberWarning
                          : (widget.isAutonomous
                              ? AppTheme.neonIndigo
                              : AppTheme.neonCyan),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isScanning
                          ? 'ESCANEO SLAM EN VIVO'
                          : (widget.isAutonomous
                              ? 'AUTÓNOMO: MAPA CARGADO'
                              : 'MODO MANUAL'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // AVISO DE SEGURIDAD CUANDO MODO AUTÓNOMO ESTÁ ACTIVO
            if (widget.isAutonomous)
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.neonIndigo, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonIndigo.withOpacity(0.4),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, color: AppTheme.neonIndigo, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🔒 FUNCIÓN AUTÓNOMA ACTIVA\nFlechas direccionales e insumos manuales inhabilitados por seguridad.',
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
          ],
        ),
      ),
    );
  }
}

class SlamGridPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final bool isAutonomous;
  final bool isScanning;

  SlamGridPainter({
    required this.scale,
    required this.offset,
    required this.isAutonomous,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + offset;

    // 1. Dibujar rejilla de fondo estilo HUD
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Dibujar zona libre de mapa explorado, muros y láser (Solo en ESCANEO y AUTÓNOMO)
    if (isScanning || isAutonomous) {
      final floorPaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.fill;
      
      final mapRect = Rect.fromCenter(center: center, width: 320 * scale, height: 200 * scale);
      canvas.drawRRect(RRect.fromRectAndRadius(mapRect, const Radius.circular(8)), floorPaint);

      // 3. Dibujar muros y paredes del recinto
      final wallPaint = Paint()
        ..color = AppTheme.borderDark
        ..strokeWidth = 3.0 * scale
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(RRect.fromRectAndRadius(mapRect, const Radius.circular(8)), wallPaint);

      // Muros internos simulados del escaneo
      canvas.drawLine(
        Offset(mapRect.left + 60 * scale, mapRect.top),
        Offset(mapRect.left + 60 * scale, mapRect.top + 80 * scale),
        wallPaint,
      );
      canvas.drawLine(
        Offset(mapRect.right - 80 * scale, mapRect.bottom),
        Offset(mapRect.right - 80 * scale, mapRect.bottom - 70 * scale),
        wallPaint,
      );

      // 4. Dibujar puntos neón de escaneo LiDAR en vivo
      final laserPaint = Paint()
        ..color = isScanning ? AppTheme.neonCyan : AppTheme.emeraldGreen
        ..strokeWidth = 2.0 * scale
        ..strokeCap = StrokeCap.round;

      final laserPoints = [
        center + Offset(-40 * scale, -30 * scale),
        center + Offset(50 * scale, -50 * scale),
        center + Offset(80 * scale, 20 * scale),
        center + Offset(-60 * scale, 40 * scale),
        center + Offset(20 * scale, 60 * scale),
      ];
      for (var pt in laserPoints) {
        canvas.drawCircle(pt, 3.0 * scale, laserPaint);
      }
    }

    // 5. Dibujar posición y orientación del Robot Rover (Avatar)
    final robotPaint = Paint()
      ..color = isAutonomous
          ? AppTheme.neonIndigo
          : (isScanning ? AppTheme.amberWarning : AppTheme.neonCyan)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 10.0 * scale, robotPaint);

    // Vector de dirección
    final headingPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5 * scale;
    canvas.drawLine(center, center + Offset(0, -18 * scale), headingPaint);
  }

  @override
  bool shouldRepaint(covariant SlamGridPainter oldDelegate) => true;
}
