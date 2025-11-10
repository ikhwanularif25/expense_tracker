// lib/src/constants/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFBB86FC),
      secondary: Color(0xFF03DAC6),
      surface: Color(0xFF1E1E1E),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
  );

  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6200EE), 
      secondary: Color(0xFF03DAC6),
      surface: Color.fromARGB(239, 214, 210, 210),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
  );
}
