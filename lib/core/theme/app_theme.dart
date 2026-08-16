import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';


class AppTheme {
  AppTheme._();


  static ThemeData get dark => ThemeData(
        fontFamily: 'GoogleSansFlex',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        typography: Typography.material2021().copyWith(
          black: Typography.material2021().black.apply(fontFamily: 'GoogleSansFlex'),
          white: Typography.material2021().white.apply(fontFamily: 'GoogleSansFlex'),
          englishLike: Typography.material2021().englishLike.apply(fontFamily: 'GoogleSansFlex'),
          dense: Typography.material2021().dense.apply(fontFamily: 'GoogleSansFlex'),
          tall: Typography.material2021().tall.apply(fontFamily: 'GoogleSansFlex'),
        ),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonGreen,
          secondary: AppColors.neonGreen,
          surface: AppColors.darkSurface,
          error: AppColors.error,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: AppColors.darkTextPrimary,
          onError: Colors.white,
        ),
        textTheme: AppTypography.textTheme.apply(
          fontFamily: 'GoogleSansFlex',
          bodyColor: AppColors.darkTextPrimary,
          displayColor: AppColors.darkTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
          titleTextStyle: TextStyle(
            fontFamily: 'GoogleSansFlex',
            color: AppColors.darkTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide.none,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.neonGreen,
          unselectedItemColor: AppColors.darkTextTertiary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          indicatorColor: AppColors.neonGreen.withValues(alpha: 0.20),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontFamily: 'GoogleSansFlex',
                color: AppColors.neonGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              );
            }
            return const TextStyle(
              fontFamily: 'GoogleSansFlex',
              color: AppColors.darkTextTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.neonGreen);
            }
            return const IconThemeData(color: AppColors.darkTextTertiary);
          }),
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextSecondary),
        dividerColor: AppColors.glassBorder,
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.darkTextPrimary,
          inactiveTrackColor: AppColors.darkSurfaceVariant,
          thumbColor: AppColors.darkTextPrimary,
          overlayColor: AppColors.darkTextPrimary.withValues(alpha: 0.12),
          trackHeight: 8,
          trackShape: const RoundedRectSliderTrackShape(),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(fontFamily: 'GoogleSansFlex', color: AppColors.darkTextTertiary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkTextPrimary,
            foregroundColor: AppColors.darkBackground,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkTextPrimary,
            side: const BorderSide(color: AppColors.darkTextPrimary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const StadiumBorder(),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.darkSurfaceVariant,
          selectedColor: AppColors.darkTextPrimary.withValues(alpha: 0.2),
          labelStyle: const TextStyle(fontFamily: 'GoogleSansFlex', color: AppColors.darkTextPrimary),
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.darkSurfaceVariant,
          contentTextStyle: const TextStyle(fontFamily: 'GoogleSansFlex', color: AppColors.darkTextPrimary),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        useMaterial3: true,
      );

  static ThemeData get light => ThemeData(
        fontFamily: 'GoogleSansFlex',
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        typography: Typography.material2021().copyWith(
          black: Typography.material2021().black.apply(fontFamily: 'GoogleSansFlex'),
          white: Typography.material2021().white.apply(fontFamily: 'GoogleSansFlex'),
          englishLike: Typography.material2021().englishLike.apply(fontFamily: 'GoogleSansFlex'),
          dense: Typography.material2021().dense.apply(fontFamily: 'GoogleSansFlex'),
          tall: Typography.material2021().tall.apply(fontFamily: 'GoogleSansFlex'),
        ),
        colorScheme: const ColorScheme.light(
          primary: AppColors.electricBlue,
          secondary: AppColors.neonPurple,
          surface: AppColors.lightSurface,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.lightTextPrimary,
          onError: Colors.white,
        ),
        textTheme: AppTypography.textTheme.apply(
          fontFamily: 'GoogleSansFlex',
          bodyColor: AppColors.lightTextPrimary,
          displayColor: AppColors.lightTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
          titleTextStyle: TextStyle(
            fontFamily: 'GoogleSansFlex',
            color: AppColors.lightTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightCard,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide.none,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.lightSurface,
          selectedItemColor: AppColors.electricBlue,
          unselectedItemColor: AppColors.lightTextTertiary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.lightSurface,
          indicatorColor: AppColors.electricBlue.withValues(alpha: 0.1),
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextSecondary),
        dividerColor: AppColors.glassDarkBorder,
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.lightTextPrimary,
          inactiveTrackColor: AppColors.lightSurfaceVariant,
          thumbColor: AppColors.lightTextPrimary,
          overlayColor: AppColors.lightTextPrimary.withValues(alpha: 0.12),
          trackHeight: 8,
          trackShape: const RoundedRectSliderTrackShape(),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightSurfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(fontFamily: 'GoogleSansFlex', color: AppColors.lightTextTertiary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lightTextPrimary,
            foregroundColor: AppColors.lightSurface,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.lightSurfaceVariant,
          selectedColor: AppColors.electricBlue.withValues(alpha: 0.15),
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        useMaterial3: true,
      );
}
