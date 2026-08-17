import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/media_item_model.dart';
import '../../providers/media_list_provider.dart';
import '../../providers/mode_provider.dart';
import '../../audio/audio_provider.dart';
import '../../services/google_drive_service.dart';
import '../../services/local_proxy_server.dart';
import '../../providers/search_provider.dart';

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumsProvider);
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();

    return albums.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (albumMap) {
        final albumNames = albumMap.keys.where((name) {
          if (query.isEmpty) return true;
          final songs = albumMap[name]!;
          final artist = (songs.first.artist ?? '').toLowerCase();
          return name.toLowerCase().contains(query) || artist.contains(query);
        }).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: albumNames.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final albumName = albumNames[index];
            final songs = albumMap[albumName]!;
            final artist = songs.first.artist ?? 'Unknown Artist';

            return _AlbumCard(
              albumName: albumName,
              artist: artist,
              songs: songs,
            );
          },
        );
      },
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  final String albumName;
  final String artist;
  final List<MediaItemModel> songs;

  const _AlbumCard({
    required this.albumName,
    required this.artist,
    required this.songs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

   
    MediaItemModel? songWithArt;
    for (final s in songs) {
      if (s.albumArtUrl != null && s.albumArtUrl!.isNotEmpty) {
        songWithArt = s;
        break;
      }
    }

    final albumArtUrl = songWithArt?.albumArtUrl;

  
    if (albumArtUrl == null) {
      for (final s in songs) {
        if (s.albumArtUrl == null && s.fileName.toLowerCase().endsWith('.flac')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(mediaListProvider.notifier).extractMetadata(s);
          });
          break;
        }
      }
    }

    return GestureDetector(
      onTap: () async {
        if (songs.isEmpty) return;
        final handler = ref.read(audioHandlerProvider);
        final mode = ref.read(modeProvider);

        final playlistItems = songs.map((s) {
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
            },
          );
        }).toList();

        await handler.playMedia(playlistItems.first, playlist: playlistItems, index: 0);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isDark ? AppColors.cardGradient : null,
          color: isDark ? null : AppColors.lightCard,
          border: Border.all(
            color: isDark ? AppColors.glassBorder : AppColors.glassDarkBorder,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: albumArtUrl == null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.neonPurple.withValues(alpha: 0.3),
                            AppColors.electricBlue.withValues(alpha: 0.3),
                          ],
                        )
                      : null,
                  image: albumArtUrl != null
                      ? DecorationImage(
                          image: ResizeImage(
                            albumArtUrl.startsWith('file://')
                                ? FileImage(File(albumArtUrl.replaceFirst('file://', ''))) as ImageProvider
                                : CachedNetworkImageProvider(albumArtUrl),
                            width: 350,
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: albumArtUrl == null
                    ? const Icon(Icons.album, size: 48, color: AppColors.electricBlue)
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    albumName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: googleSansFlex(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$artist • ${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: googleSansFlex(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }
}
