import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/home_nav_provider.dart';
import '../music/music_home_view.dart';
import '../../audio/audio_provider.dart';
import '../music/widgets/mini_player.dart';

class OutdoorModeView extends ConsumerWidget {
  const OutdoorModeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(homeNavProvider);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      children: [
        const Expanded(
          child: MusicHomeView(),
        ),
      
        Consumer(builder: (context, ref, child) {
          final isPlaying = ref.watch(isPlayingProvider);
          if (isPlaying && !isKeyboardOpen) {
            return const MiniPlayer();
          }
          return const SizedBox.shrink();
        }),

        if (!isKeyboardOpen)
          NavigationBar(
            selectedIndex: navIndex,
            onDestinationSelected: (index) {
              ref.read(homeNavProvider.notifier).state = index;
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: AppColors.electricBlue),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.music_note_outlined),
                selectedIcon: Icon(Icons.music_note, color: AppColors.electricBlue),
                label: 'Songs',
              ),
              NavigationDestination(
                icon: Icon(Icons.album_outlined),
                selectedIcon: Icon(Icons.album, color: AppColors.electricBlue),
                label: 'Albums',
              ),
            ],
          ),
      ],
    );
  }
}
