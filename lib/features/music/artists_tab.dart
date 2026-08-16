import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../providers/media_list_provider.dart';


class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider);

    return artists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (artistMap) {
        final artistNames = artistMap.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: artistNames.length,
          itemBuilder: (context, index) {
            final name = artistNames[index];
            final songs = artistMap[name]!;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.neonPurple.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: googleSansFlex(
                    color: AppColors.neonPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(name, style: googleSansFlex(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${songs.length} songs',
                style: googleSansFlex(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
             
              },
            );
          },
        );
      },
    );
  }
}
