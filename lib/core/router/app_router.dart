import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/local_storage_service.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/player/audio_player_screen.dart';
import '../../features/video/video_player_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final onboarded = LocalStorageService.instance.isOnboardingComplete;
    final isOnboarding = state.matchedLocation == '/onboarding';

    if (!onboarded && !isOnboarding) return '/onboarding';
    if (onboarded && isOnboarding) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/player/audio',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const AudioPlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: '/player/video',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CustomTransitionPage(
          child: VideoPlayerScreen(
            url: extra?['url'] as String? ?? '',
            title: extra?['title'] as String? ?? '',
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
  ],
);
