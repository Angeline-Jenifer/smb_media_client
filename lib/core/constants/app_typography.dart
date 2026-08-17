import 'package:flutter/material.dart';

TextStyle googleSansFlex({
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
  Color? color,
  TextOverflow? overflow,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: 'GoogleSansFlex',
    fontFamilyFallback: const ['sans-serif'],
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
    overflow: overflow,
    decoration: decoration,
  );
}

class AppTypography {
  AppTypography._();

  static TextStyle _fontStyle({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    return googleSansFlex(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme get textTheme => TextTheme(
        displayLarge: _fontStyle(
          fontSize: 57,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        displayMedium: _fontStyle(
          fontSize: 45,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        displaySmall: _fontStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineLarge: _fontStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
        headlineMedium: _fontStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
        headlineSmall: _fontStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
        titleLarge: _fontStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
        titleMedium: _fontStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        titleSmall: _fontStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        bodyLarge: _fontStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        bodyMedium: _fontStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
        ),
        bodySmall: _fontStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
        ),
        labelLarge: _fontStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: _fontStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelSmall: _fontStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
}
