import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _accent = Color(0xFF8B5CF6); // Vivid Violet
  static const _accentDark = Color(0xFF6D28D9); // Deep Violet
  static const _accentSoft = Color(0xFFC4B5FD); // Soft Violet
  static const _warningStart = Color(0xFFFFB45C);
  static const _warningEnd = Color(0xFFFF6B2C);
  static const _danger = Color(0xFFFF5252);
  static const _surface = Color(0xFF0F1219);
  static const _surfaceRaised = Color(0xFF141821);
  static const _surfaceAlt = Color(0xFF1B212D);
  static const _textPrimary = Color(0xFFF1F5F9); // Crisp Silver White
  static const _textSecondary = Color(0xFF94A3B8); // Slate Gray
  static const _textMuted = Color(0xFF64748B); // Muted Silver

  static const Color primary = _accent;
  static const Color primaryDeep = _accentDark;
  static const Color success = _accent; 
  static const Color danger = _danger;
  static const Color warning = _warningStart;
  static const Color info = Color(0xFFA78BFA);
  static const Color surface = _surface;
  static const Color surfaceRaised = _surfaceRaised;
  static const Color surfaceAlt = _surfaceAlt;
  static const Color surfaceLight = Color(0x0AFFFFFF);
  static const Color surfaceBorder = Color(0x1A94A3B8); // Silver Gray Border
  static const Color surfaceGlow = Color(0x268B5CF6); // Violet Glow
  static const Color textPrimary = _textPrimary;
  static const Color textSecondary = _textSecondary;
  static const Color textMuted = _textMuted;

  static const LinearGradient heroGradient = LinearGradient(
    colors: [_accentSoft, _accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [_accentSoft, _accent, _accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [_warningStart, _warningEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF0F1219), Color(0xFF05070A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: _accent,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accentDark,
        surface: _surface,
        onPrimary: Color(0xFF0B0D0F),
        onSecondary: Colors.white,
        onSurface: _textPrimary,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.manropeTextTheme(
        base.textTheme,
      ).apply(bodyColor: _textPrimary, displayColor: _textPrimary),
      primaryTextTheme:
          GoogleFonts.manropeTextTheme(base.primaryTextTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: _textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _accent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: const Color(0xFF0B0D0F),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          elevation: 0,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
      ),
      dividerColor: surfaceBorder,
    );
  }

  static TextStyle numericText({
    double size = 32,
    FontWeight weight = FontWeight.w600,
    Color color = textPrimary,
    double letterSpacing = -1.4,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: 1,
    );
  }

  static TextStyle arabicText({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textPrimary,
    double height = 2.0,
  }) {
    return GoogleFonts.amiri(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle glowingText({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = Colors.white,
    double letterSpacing = 0,
    Color glowColor = primary,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      shadows: [
        Shadow(color: glowColor.withValues(alpha: 0.30), blurRadius: 12),
        Shadow(color: glowColor.withValues(alpha: 0.12), blurRadius: 24),
      ],
    );
  }
}
