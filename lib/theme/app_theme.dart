import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData theme = ThemeData(
    primaryColor: Color(0xff2F3E46),

    scaffoldBackgroundColor: Color(0xffF5F7FA),

    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),

    cardTheme: CardThemeData(elevation: 4, margin: const EdgeInsets.all(8)),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
