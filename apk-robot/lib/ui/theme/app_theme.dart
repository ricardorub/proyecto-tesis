import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de colores para interfaz robótica premium
  static const Color bgDark = Color(0xFF0F172A);       // Slate 900
  static const Color cardDark = Color(0xFF1E293B);     // Slate 800
  static const Color borderDark = Color(0xFF334155);   // Slate 700
  
  static const Color neonCyan = Color(0xFF00F2FE);     // Acento secundario neón
  static const Color neonBlue = Color(0xFF4FACFE);     // Acento primario
  static const Color neonIndigo = Color(0xFF6366F1);   // Modo Automático
  static const Color emeraldGreen = Color(0xFF10B981); // Conectado / Aceptar
  static const Color crimsonRed = Color(0xFFEF4444);   // Stop / Parada de emergencia
  static const Color amberWarning = Color(0xFFF59E0B); // Reintentando

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: neonBlue,
      colorScheme: const ColorScheme.dark(
        primary: neonBlue,
        secondary: neonCyan,
        surface: cardDark,
        error: crimsonRed,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardTheme(
        color: cardDark,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Estilo de texto tipo consola terminal
  static TextStyle get monoTextStyle {
    return GoogleFonts.jetBrainsMono(
      fontSize: 12,
      color: const Color(0xFF94A3B8),
    );
  }
}
