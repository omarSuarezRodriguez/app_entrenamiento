import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bgDeep = Color(0xFF070709);
  static const Color bgCard = Color(0xFF12121A);
  static const Color accentRed = Color(0xFFFF3355);
  static const Color accentRedDim = Color(0xFFCC1F3D);
  static const Color textMuted = Color(0xFF9A9AA8);
  static const Color borderSubtle = Color(0xFF252532);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDeep,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentRed,
        brightness: Brightness.dark,
        primary: accentRed,
        surface: bgCard,
      ),
    );
    return base.copyWith(
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgCard.withValues(alpha: 0.94),
        indicatorColor: accentRed.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      textTheme: GoogleFonts.dmSansTextTheme(
        base.textTheme,
      ).apply(bodyColor: Colors.white, displayColor: Colors.white),
    );
  }
}
