import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/media_item_model.dart';
import '../../providers/search_provider.dart';
import 'widgets/song_tile.dart';


class SongsTab extends ConsumerWidget {
  final List<MediaItemModel> songs;

  const SongsTab({super.key, required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    final filteredSongs = query.isEmpty
        ? songs
        : songs.where((s) {
            final titleMatch = s.title.toLowerCase().contains(query);
            final artistMatch = (s.artist ?? '').toLowerCase().contains(query);
            final albumMatch = (s.album ?? '').toLowerCase().contains(query);
            return titleMatch || artistMatch || albumMatch;
          }).toList();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredSongs.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) => SongTile(
        song: filteredSongs[index],
        playlist: filteredSongs,
        index: index,
      ),
    );
  }
}
