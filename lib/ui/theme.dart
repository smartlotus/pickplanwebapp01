import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Colors.white;
  static const Color accent = Colors.white70;
  static const Color background = Colors.black;
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color textColor = Colors.white;
  static const Color errorColor = Color(0xFFCF6679);

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: cardColor,
        error: errorColor,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textColor,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: Colors.white38,
        showUnselectedLabels: true,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF424242), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white38),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent, width: 0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.black),
        side: const BorderSide(color: Colors.white54, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
