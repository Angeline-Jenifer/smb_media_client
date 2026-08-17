import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/file_extensions.dart';
import '../../../models/media_item_model.dart';
import '../../../audio/audio_provider.dart';
import '../../../providers/mode_provider.dart';
import '../../../services/google_drive_service.dart';
import '../../../services/local_proxy_server.dart';
import '../../../providers/media_list_provider.dart';
import '../../../providers/recently_played_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/widgets/animated_equalizer.dart';

class SongTile extends ConsumerWidget {
  final MediaItemModel song;
  final List<MediaItemModel> playlist;
  final int index;

  const SongTile({
    super.key,
    required this.song,
    required this.playlist,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTrack = ref.watch(currentTrackProvider);
    final playbackState = ref.watch(playbackStateProvider);

    final isCurrentTrack = currentTrack.when(
      data: (item) => item?.extras?['mediaId'] == song.id,
      loading: () => false,
      error: (_, __) => false,
    );
    final isPlaying = playbackState.when(
      data: (state) => state.playing,
      loading: () => false,
      error: (_, __) => false,
    );

    final lowerName = song.fileName.toLowerCase();
    final needsExtraction = song.albumArtUrl == null &&
        (lowerName.endsWith('.flac') || lowerName.endsWith('.opus') || lowerName.endsWith('.ogg'));
    if (needsExtraction) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mediaListProvider.notifier).extractMetadata(song);
      });
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: isCurrentTrack ? AppColors.primaryGradient : AppColors.cardGradient,
          border: Border.all(
            color: isCurrentTrack ? AppColors.electricBlue : AppColors.glassBorder,
            width: 0.5,
          ),
          image: song.albumArtUrl != null
              ? DecorationImage(
                  image: ResizeImage(
                    song.albumArtUrl!.startsWith('file://')
                        ? FileImage(File(song.albumArtUrl!.replaceFirst('file://', ''))) as ImageProvider
                        : CachedNetworkImageProvider(song.albumArtUrl!),
                    width: 150,
                  ),
                  fit: BoxFit.cover,
                  colorFilter: isCurrentTrack
                      ? ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken)
                      : null,
                )
              : null,
        ),
        child: isCurrentTrack
            ? Center(
                child: AnimatedEqualizer(
                  color: AppColors.neonGreen,
                  size: 18,
                  isPlaying: isPlaying,
                ),
              )
            : (song.albumArtUrl == null
                ? Icon(
                    Icons.music_note,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    size: 20,
                  )
                : null),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: googleSansFlex(
          fontWeight: isCurrentTrack ? FontWeight.w700 : FontWeight.w600,
          fontSize: 15,
          color: isCurrentTrack
              ? AppColors.neonGreen
              : (isDark ? Colors.white : AppColors.lightTextPrimary),
        ),
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              song.artist ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: googleSansFlex(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: AppColors.neonGreen.withValues(alpha: 0.18),
            ),
            child: Text(
              FileExtensions.getFormatBadge(song.fileName),
              style: googleSansFlex(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.neonGreen,
              ),
            ),
          ),
        ],
      ),
      trailing: Text(
        song.formattedSize,
        style: googleSansFlex(
          fontSize: 12,
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
      ),
      onTap: () => _playSong(ref, context),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  Future<void> _playSong(WidgetRef ref, BuildContext context) async {
    final handler = ref.read(audioHandlerProvider);
    final mode = ref.read(modeProvider);

    String url;
    if (mode == AppMode.outdoor) {
   
      url = GoogleDriveService.instance.getStreamUrl(song.sourceId);
    } else {
      
      final parts = song.sourceId.split('/');
      final share = parts.first;
      final path = parts.sublist(1).join('/');
      url = LocalProxyServer.instance.getProxyUrl(share, path);
    }

    
    final mediaItem = MediaItem(
      id: url,
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      album: song.album ?? 'Unknown Album',
      artUri: song.albumArtUrl != null ? Uri.parse(song.albumArtUrl!) : null,
      extras: {
        'mediaId': song.id,
        'lyrics': song.lyrics,
        'fileName': song.fileName,
        'fileSize': song.fileSize,
        'mimeType': song.mimeType,
        'filePath': song.filePath,
      },
    );

    final playlistItems = playlist.map((s) {
      String itemUrl;
      if (mode == AppMode.outdoor) {
        itemUrl = GoogleDriveService.instance.getStreamUrl(s.sourceId);
      } else {
        final p = s.sourceId.split('/');
        itemUrl = LocalProxyServer.instance.getProxyUrl(p.first, p.sublist(1).join('/'));
      }
      return MediaItem(
        id: itemUrl,
        title: s.title,
        artist: s.artist ?? 'Unknown Artist',
        album: s.album ?? 'Unknown Album',
        artUri: s.albumArtUrl != null ? Uri.parse(s.albumArtUrl!) : null,
        extras: {
          'mediaId': s.id,
          'lyrics': s.lyrics,
          'fileName': s.fileName,
          'fileSize': s.fileSize,
          'mimeType': s.mimeType,
          'filePath': s.filePath,
        },
      );
    }).toList();

    await handler.playMedia(mediaItem, playlist: playlistItems, index: index);
    await ref.read(recentlyPlayedProvider.notifier).addTrack(song);

    if (context.mounted) context.push('/player/audio');
  }
}
