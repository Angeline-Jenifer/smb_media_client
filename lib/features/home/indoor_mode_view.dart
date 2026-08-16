import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/home_nav_provider.dart';
import '../music/music_home_view.dart';
import '../video/video_library_view.dart';
import '../../audio/audio_provider.dart';
import '../music/widgets/mini_player.dart';

class IndoorModeView extends ConsumerStatefulWidget {
  const IndoorModeView({super.key});

  @override
  ConsumerState<IndoorModeView> createState() => _IndoorModeViewState();
}

class _IndoorModeViewState extends ConsumerState<IndoorModeView> {
  int _selectedSegment = 0; 

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
       
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _buildSegment(0, 'Music', Icons.music_note),
                _buildSegment(1, 'Movies', Icons.movie_outlined),
              ],
            ),
          ),
        ),

       
        Expanded(
          child: _selectedSegment == 0
              ? const MusicHomeView()
              : const VideoLibraryView(),
        ),

        Consumer(builder: (context, ref, child) {
          final currentTrack = ref.watch(currentTrackProvider);
          if (currentTrack.value != null) {
            return const MiniPlayer();
          }
          return const SizedBox.shrink();
        }),

        if (_selectedSegment == 0)
          Consumer(builder: (context, ref, child) {
            final navIndex = ref.watch(homeNavProvider);
            return NavigationBar(
              selectedIndex: navIndex,
              onDestinationSelected: (index) {
                ref.read(homeNavProvider.notifier).state = index;
              },
              destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: AppColors.neonPurple),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.music_note_outlined),
                selectedIcon: Icon(Icons.music_note, color: AppColors.neonPurple),
                label: 'Songs',
              ),
              NavigationDestination(
                icon: Icon(Icons.album_outlined),
                selectedIcon: Icon(Icons.album, color: AppColors.neonPurple),
                label: 'Albums',
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildSegment(int index, String label, IconData icon) {
    final selected = _selectedSegment == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? (isDark ? AppColors.neonPurple : AppColors.electricBlue)
                : Colors.transparent,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: (isDark ? AppColors.neonPurple : AppColors.electricBlue)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
