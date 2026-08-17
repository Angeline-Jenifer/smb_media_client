import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../providers/media_list_provider.dart';
import '../../providers/home_nav_provider.dart';
import '../../providers/mode_provider.dart';
import '../../audio/audio_provider.dart';
import '../../models/media_item_model.dart';
import '../../services/google_drive_service.dart';
import '../../services/local_proxy_server.dart';
import '../../providers/search_provider.dart';
import '../../providers/recently_played_provider.dart';
import 'songs_tab.dart';
import 'albums_tab.dart';

import 'widgets/song_tile.dart';
import 'package:flutter_animate/flutter_animate.dart';
class MusicHomeView extends ConsumerStatefulWidget {
  const MusicHomeView({super.key});

  @override
  ConsumerState<MusicHomeView> createState() => _MusicHomeViewState();
}

class _MusicHomeViewState extends ConsumerState<MusicHomeView> {
  @override
  Widget build(BuildContext context) {
    final audioList = ref.watch(audioListProvider);
    final initialTab = ref.watch(homeNavProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final recentSongs = ref.watch(recentlyPlayedProvider);

    return audioList.when(
      loading: () => ShimmerLoader.list(),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 8),
            Text('Error loading media', style: TextStyle(color: AppColors.darkTextSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(mediaListProvider.notifier).fetchMedia(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (allSongs) {
        if (allSongs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_off, size: 64, color: AppColors.darkTextTertiary),
                const SizedBox(height: 16),
                Text(
                  'No music found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add music to your selected folder',
                  style: TextStyle(color: AppColors.darkTextTertiary),
                ),
              ],
            ),
          );
        }

        if (initialTab == 1) return SongsTab(songs: allSongs);
        if (initialTab == 2) return const AlbumsTab();

        final query = searchQuery.trim().toLowerCase();
        final songs = query.isEmpty 
            ? allSongs 
            : allSongs.where((s) {
                final titleMatch = s.title.toLowerCase().contains(query);
                final artistMatch = (s.artist ?? '').toLowerCase().contains(query);
                final albumMatch = (s.album ?? '').toLowerCase().contains(query);
                return titleMatch || artistMatch || albumMatch;
              }).toList();

     
        final displayRecent = recentSongs.isNotEmpty
            ? recentSongs
            : (songs.length > 3 ? songs.take(10).toList() : <MediaItemModel>[]);

       
        final halfIndex = (songs.length / 2).ceil();
        final mix1Songs = songs.take(halfIndex).toList();
        final mix2Songs = songs.skip(halfIndex).toList();
        final flacSongs = songs.where((s) => s.fileName.toLowerCase().endsWith('.flac') || s.fileName.toLowerCase().endsWith('.wav')).toList();
        final losslessSongs = flacSongs.isNotEmpty ? flacSongs : songs;

        final dailyMixes = <_DailyMixData>[
          _DailyMixData(
            title: 'Daily Mix 1',
            subtitle: mix1Songs.take(3).map((e) => e.artist ?? e.title).join(', '),
            colors: const [Color(0xFF1DB954), Color(0xFF0B331A)],
            icon: Icons.auto_awesome_rounded,
            playlist: mix1Songs,
          ),
          _DailyMixData(
            title: 'Daily Mix 2',
            subtitle: mix2Songs.take(3).map((e) => e.artist ?? e.title).join(', '),
            colors: const [Color(0xFF8E2DE2), Color(0xFF3B007A)],
            icon: Icons.headphones_rounded,
            playlist: mix2Songs.isNotEmpty ? mix2Songs : songs,
          ),
          _DailyMixData(
            title: 'Lossless Hi-Res',
            subtitle: '${losslessSongs.length} Master FLAC/WAV tracks',
            colors: const [Color(0xFF00C6FF), Color(0xFF00458E)],
            icon: Icons.high_quality_rounded,
            playlist: losslessSongs,
          ),
          _DailyMixData(
            title: 'Discover Weekly',
            subtitle: 'Fresh rotation based on your library',
            colors: const [Color(0xFFFF512F), Color(0xFFDD2476)],
            icon: Icons.explore_rounded,
            playlist: songs.reversed.toList(),
          ),
        ];

      
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 8),
            ),

            
            if (displayRecent.isNotEmpty && query.isEmpty) ...[
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Recently Played'),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayRecent.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final song = displayRecent[index];
                      return _RecentCard(song: song, allSongs: songs);
                    },
                  ),
                ),
              ),
            ],

          
            if (songs.isNotEmpty && query.isEmpty) ...[
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Made For You'),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 175,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dailyMixes.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final mix = dailyMixes[index];
                      return _DailyMixCard(mix: mix);
                    },
                  ),
                ),
              ),
            ],

       
            if (songs.isNotEmpty && query.isEmpty) ...[
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Quick Play'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickPlayPill(
                          label: 'Shuffle All',
                          icon: Icons.shuffle_rounded,
                          color: AppColors.neonGreen,
                          onTap: () {
                            final shuffled = List<MediaItemModel>.from(songs)..shuffle();
                            _playMix(ref, shuffled);
                          },
                        ),
                        const SizedBox(width: 10),
                        _QuickPlayPill(
                          label: 'Lossless Only',
                          icon: Icons.graphic_eq_rounded,
                          color: const Color(0xFF00C6FF),
                          onTap: () => _playMix(ref, losslessSongs),
                        ),
                        const SizedBox(width: 10),
                        _QuickPlayPill(
                          label: 'Recently Added',
                          icon: Icons.new_releases_rounded,
                          color: const Color(0xFFFFAB40),
                          onTap: () => _playMix(ref, songs),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

           
            SliverToBoxAdapter(
              child: _SectionHeader(title: query.isEmpty ? 'Songs' : 'Search Results', count: songs.length),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => SongTile(
                  song: songs[index],
                  playlist: songs,
                  index: index,
                ),
                childCount: query.isEmpty ? songs.length.clamp(0, 20) : songs.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),

         
            if (songs.length > 20 && query.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextButton(
                    onPressed: () {
                      ref.read(homeNavProvider.notifier).state = 1;
                    },
                    child: const Text('View all songs →'),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: googleSansFlex(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.electricBlue.withValues(alpha: 0.15),
              ),
              child: Text(
                '$count',
                style: googleSansFlex(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.electricBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0, curve: Curves.easeOutQuad);
  }
}

class _RecentCard extends ConsumerWidget {
  final MediaItemModel song;
  final List<MediaItemModel> allSongs;

  const _RecentCard({required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (song.albumArtUrl == null && song.fileName.toLowerCase().endsWith('.flac')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mediaListProvider.notifier).extractMetadata(song);
      });
    }

    return GestureDetector(
      onTap: () async {
        final handler = ref.read(audioHandlerProvider);
        final mode = ref.read(modeProvider);
        final index = allSongs.indexOf(song);

        String url;
        if (mode == AppMode.outdoor) {
          url = GoogleDriveService.instance.getStreamUrl(song.sourceId);
        } else {
          final parts = song.sourceId.split('/');
          url = LocalProxyServer.instance.getProxyUrl(parts.first, parts.sublist(1).join('/'));
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

        final playlistItems = allSongs.map((s) {
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
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: AppColors.cardGradient,
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
                image: song.albumArtUrl != null
                    ? DecorationImage(
                        image: ResizeImage(
                          song.albumArtUrl!.startsWith('file://')
                              ? FileImage(File(song.albumArtUrl!.replaceFirst('file://', ''))) as ImageProvider
                              : CachedNetworkImageProvider(song.albumArtUrl!),
                          width: 300, 
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: song.albumArtUrl == null
                  ? const Icon(Icons.music_note, size: 40, color: AppColors.electricBlue)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: googleSansFlex(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            Text(
              song.artist ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: googleSansFlex(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }
}

Future<void> _playMix(WidgetRef ref, List<MediaItemModel> mixSongs, {BuildContext? context}) async {
  if (mixSongs.isEmpty) return;
  final handler = ref.read(audioHandlerProvider);
  final mode = ref.read(modeProvider);

  final playlistItems = mixSongs.map((s) {
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

  await handler.playMedia(playlistItems.first, playlist: playlistItems, index: 0);
  await ref.read(recentlyPlayedProvider.notifier).addTrack(mixSongs.first);

  if (context != null && context.mounted) {
    context.push('/player/audio');
  }
}

class _DailyMixData {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;
  final List<MediaItemModel> playlist;

  const _DailyMixData({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.playlist,
  });
}

class _DailyMixCard extends ConsumerWidget {
  final _DailyMixData mix;

  const _DailyMixCard({required this.mix});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _playMix(ref, mix.playlist, context: context),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: mix.colors,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: mix.colors.first.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(mix.icon, color: Colors.white, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: AppColors.neonGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mix.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: googleSansFlex(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mix.subtitle.isEmpty ? 'Curated Playlist' : mix.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: googleSansFlex(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPlayPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickPlayPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: googleSansFlex(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
