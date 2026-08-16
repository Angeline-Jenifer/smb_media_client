import 'package:flutter/material.dart';

class AppColors {
  AppColors._();


  static const darkBackground = Color(0xFF000000); 
  static const darkSurface = Color(0xFF0C0C0C);   
  static const darkSurfaceVariant = Color(0xFF141414); 
  static const darkCard = Color(0xFF121212);      
  static const darkCardHover = Color(0xFF1A1A1A);

  
  static const lightBackground = Color(0xFFF4F5F8); 
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFF0F1F8);
  static const lightCard = Color(0xFFFFFFFF);

  
  static const electricBlue = Color(0xFF1DB954); 
  static const neonGreen = Color(0xFF1DB954); 
  static const neonPurple = Color(0xFF10B981);
  static const accentGradientStart = Color(0xFF1DB954);
  static const accentGradientEnd = Color(0xFF121212);

  
  static const success = Color(0xFF1DB954);
  static const error = Color(0xFFFF5252);
  static const warning = Color(0xFFFFAB40);
  static const info = Color(0xFF40C4FF);

  
  static const darkTextPrimary = Color(0xFFFFFFFF); 
  static const darkTextSecondary = Color(0xFFB3B3B3); 
  static const darkTextTertiary = Color(0xFF737373);

  static const lightTextPrimary = Color(0xFF000000);
  static const lightTextSecondary = Color(0xFF666666);
  static const lightTextTertiary = Color(0xFF999999);

  
  static const outdoorMode = Color(0xFF1DB954);
  static const indoorMode = Color(0xFF1DB954);

  
  static const glassWhite = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x22FFFFFF);
  static const glassDarkBorder = Color(0x0F000000);

  
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1DB954), Color(0xFF0C0C0C)],
  );

  static const darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF000000),
      Color(0xFF000000),
    ],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF121212),
      Color(0xFF181818),
    ],
  );
}

