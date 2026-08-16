import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../audio/audio_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';


class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final handler = ref.watch(audioHandlerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return track.when(
      data: (item) {
        if (item == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => context.push('/player/audio'),
          child: Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isDark ? AppColors.cardGradient : null,
              color: isDark ? null : AppColors.lightCard,
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.electricBlue.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 8),
                 
                      Hero(
                        tag: 'album_art_${item.id}',
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: AppColors.primaryGradient,
                            image: item.artUri != null
                                ? DecorationImage(
                                    image: item.artUri!.toString().startsWith('file://')
                                        ? FileImage(File(item.artUri!.toString().replaceFirst('file://', ''))) as ImageProvider
                                        : NetworkImage(item.artUri!.toString()),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: item.artUri == null
                              ? const Icon(Icons.music_note, color: Colors.white, size: 22)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                    
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: googleSansFlex(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              item.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: googleSansFlex(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                
                      IconButton(
                        onPressed: () => handler.skipToPrevious(),
                        icon: const Icon(Icons.skip_previous_rounded, size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                      ),
                      IconButton(
                        onPressed: () => isPlaying ? handler.pause() : handler.play(),
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 28,
                          color: AppColors.neonGreen,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                      ),
                      IconButton(
                        onPressed: () => handler.skipToNext(),
                        icon: const Icon(Icons.skip_next_rounded, size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Consumer(
                      builder: (context, ref, child) {
                        final positionAsync = ref.watch(positionProvider);
                        final durationAsync = ref.watch(durationProvider);
                        
                        final pos = positionAsync.value ?? Duration.zero;
                        final dur = durationAsync.value ?? Duration.zero;
                        
                        final progress = dur.inMilliseconds > 0 
                            ? pos.inMilliseconds / dur.inMilliseconds 
                            : 0.0;
                            
                        return LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.transparent,
                          color: AppColors.neonGreen.withValues(alpha: 0.8),
                          minHeight: 2.5,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().slideY(begin: 1.0, end: 0, duration: 400.ms, curve: Curves.easeOutCubic).fadeIn();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
