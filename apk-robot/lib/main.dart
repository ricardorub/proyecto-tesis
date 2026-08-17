import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/slam_control_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Fijar orientación a modo Horizontal (Landscape) para aprovechar todo el ancho de pantalla
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Barra de estado inmersiva para pantalla panorámica
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const RoverControlApp());
}

class RoverControlApp extends StatelessWidget {
  const RoverControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rover SLAM & Navigation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SlamControlScreen(),
    );
  }
}
