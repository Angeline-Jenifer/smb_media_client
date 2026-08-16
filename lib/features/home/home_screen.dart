import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_typography.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/mode_provider.dart';
import '../../providers/media_list_provider.dart';
import '../../providers/search_provider.dart';
import 'outdoor_mode_view.dart';
import 'indoor_mode_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mediaListProvider.notifier).fetchMedia();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(modeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, mode),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: mode == AppMode.outdoor
                    ? const OutdoorModeView(key: ValueKey('outdoor'))
                    : const IndoorModeView(key: ValueKey('indoor')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppMode mode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOutdoor = mode == AppMode.outdoor;

    final title = isOutdoor ? 'Outdoor' : 'Indoor';
    final subtitle = isOutdoor ? 'Google Drive' : 'Samba Network';
    final searchQuery = ref.watch(searchQueryProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Actions Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: googleSansFlex(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: googleSansFlex(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () {
                  ref.read(mediaListProvider.notifier).fetchMedia();
                },
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  size: 24,
                ),
                tooltip: 'Refresh library',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              ),

            
              _buildThemeToggle(),
              const SizedBox(width: 6),

             
              _buildModePill(isOutdoor),
            ],
          ),

          const SizedBox(height: 16),

         
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppColors.glassBorder : AppColors.glassDarkBorder,
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      ref.read(searchQueryProvider.notifier).state = value;
                    },
                    style: googleSansFlex(
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search songs, artists, albums...',
                      hintStyle: googleSansFlex(
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill(bool isOutdoor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final success = await ref.read(modeProvider.notifier).toggle();
        if (!success && mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text(AppStrings.errorNoWifi)),
          );
        } else {
          ref.read(mediaListProvider.notifier).fetchMedia();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.glassBorder : AppColors.glassDarkBorder,
            width: 1.2,
          ),
        ),
        child: Icon(
          isOutdoor ? Icons.cloud_rounded : Icons.wifi_rounded,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return IconButton(
      onPressed: () => ref.read(themeProvider.notifier).toggle(),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) =>
            RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(anim), child: child),
        child: Icon(
          isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
          key: ValueKey(isDark),
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
          size: 22,
        ),
      ),
      tooltip: 'Toggle theme',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
    );
  }
}
