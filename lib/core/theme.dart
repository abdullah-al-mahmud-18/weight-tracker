import 'package:flutter/material.dart';

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

final ThemeData lightTheme = _buildTheme(Brightness.light);
final ThemeData darkTheme = _buildTheme(Brightness.dark);
