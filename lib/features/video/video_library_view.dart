import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/file_extensions.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../models/media_item_model.dart';
import '../../providers/media_list_provider.dart';
import '../../services/smb_service.dart';
import '../../services/local_proxy_server.dart';


class VideoLibraryView extends ConsumerWidget {
  const VideoLibraryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoList = ref.watch(videoListProvider);

    return videoList.when(
      loading: () => ShimmerLoader.grid(crossAxisCount: 2, itemCount: 6),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (videos) {
        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.movie_outlined, size: 64, color: AppColors.darkTextTertiary),
                const SizedBox(height: 16),
                Text(
                  'No videos found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return _VideoCard(video: video);
          },
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  final MediaItemModel video;

  const _VideoCard({required this.video});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _playVideo(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isDark ? AppColors.cardGradient : null,
          color: isDark ? null : AppColors.lightCard,
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail placeholder
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.electricBlue.withValues(alpha: 0.2),
                      AppColors.neonPurple.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.movie, size: 48, color: AppColors.neonPurple),
                    // Format badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.black54,
                        ),
                        child: Text(
                          FileExtensions.getFormatBadge(video.fileName),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    video.formattedSize,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playVideo(BuildContext context) {
    final parts = video.sourceId.split('/');
    final share = parts.first;
    final path = parts.sublist(1).join('/');

    final url = LocalProxyServer.instance.getProxyUrl(share, path);

    context.push('/player/video', extra: {
      'url': url,
      'title': video.title,
    });
  }
}
