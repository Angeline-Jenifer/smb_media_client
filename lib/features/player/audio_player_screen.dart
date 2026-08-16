import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../audio/audio_provider.dart';
import '../../extensions/duration_extension.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:android_intent_plus/android_intent.dart';

class _LyricLine {
  final Duration time;
  final String text;
  _LyricLine(this.time, this.text);
}

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  final ScrollController _lyricScrollController = ScrollController();
  List<_LyricLine>? _parsedLyrics;
  String? _lastRawLyrics;
  int _lastIndex = -1;

  bool _showLyrics = false;
  bool _isSyncedLyrics = true;
  bool _isFavorite = false;
  bool _isShuffle = false;
  bool _isRepeat = false;

  List<_LyricLine> _parseLyrics(String raw) {
    final lines = raw.split('\n');
    final result = <_LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final m = int.parse(match.group(1)!);
        final s = int.parse(match.group(2)!);
        final msStr = match.group(3)!;
        final ms = int.parse(msStr) * (msStr.length == 2 ? 10 : 1);
        final text = match.group(4)!.trim();
        if (text.isNotEmpty) {
          result.add(_LyricLine(Duration(minutes: m, seconds: s, milliseconds: ms), text));
        }
      }
    }
    return result;
  }

  void _scrollToLyric(int index) {
    if (index != _lastIndex && _lyricScrollController.hasClients) {
      _lastIndex = index;
      final target = (index * 52.0) - (250.0 / 2) + 26.0;
      _lyricScrollController.animateTo(
        target.clamp(0.0, _lyricScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _lyricScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final position = ref.watch(positionProvider);
    final duration = ref.watch(durationProvider);
    final handler = ref.watch(audioHandlerProvider);
    final audioParams = ref.watch(audioParamsProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: track.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('No track playing'));
          }

          final pos = position.value ?? Duration.zero;
          final dur = duration.value ?? item.duration ?? Duration.zero;

        
          final rawLyrics = item.extras?['lyrics'] as String?;
          if (rawLyrics != _lastRawLyrics) {
            _lastRawLyrics = rawLyrics;
            if (rawLyrics != null) {
              _parsedLyrics = _parseLyrics(rawLyrics);
              if (_parsedLyrics!.isEmpty) _parsedLyrics = null;
            } else {
              _parsedLyrics = null;
            }
            _lastIndex = -1;
          }

         
          int activeLyricIndex = -1;
          if (_parsedLyrics != null && _isSyncedLyrics) {
            for (int i = 0; i < _parsedLyrics!.length; i++) {
              if (pos >= _parsedLyrics![i].time) {
                activeLyricIndex = i;
              } else {
                break;
              }
            }
            if (activeLyricIndex >= 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToLyric(activeLyricIndex);
              });
            }
          }

          return Stack(
            children: [
             
              if (item.artUri != null)
                Positioned.fill(
                  child: Image(
                    image: item.artUri!.toString().startsWith('file://')
                        ? FileImage(File(item.artUri!.toString().replaceFirst('file://', ''))) as ImageProvider
                        : CachedNetworkImageProvider(item.artUri!.toString()),
                    fit: BoxFit.cover,
                  ),
                ),

         
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: Container(
                    color: isDark
                        ? AppColors.darkBackground.withValues(alpha: 0.85)
                        : AppColors.lightBackground.withValues(alpha: 0.90),
                  ),
                ),
              ),

            
              SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _showLyrics
                      ? _buildLyricsView(
                          context,
                          item,
                          rawLyrics,
                          activeLyricIndex,
                          pos,
                          dur,
                          isPlaying,
                          handler,
                          isDark,
                        )
                      : _buildPlayerView(
                          context,
                          item,
                          pos,
                          dur,
                          isPlaying,
                          handler,
                          isDark,
                          audioParams,
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

 
  Widget _buildPlayerView(
    BuildContext context,
    MediaItem item,
    Duration pos,
    Duration dur,
    bool isPlaying,
    AudioHandler handler,
    bool isDark,
    AudioParams? audioParams,
  ) {
    final primaryPillBg = isDark ? AppColors.neonGreen : AppColors.lightTextPrimary;
    final primaryPillIcon = isDark ? Colors.black : Colors.white;

    final secondaryPillBg = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final secondaryPillIcon = isDark ? Colors.white : AppColors.lightTextPrimary;

    final dockBg = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final dockBorder = isDark ? AppColors.glassBorder : AppColors.glassDarkBorder;

    return Column(
      key: const ValueKey('PlayerView'),
      children: [
      
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
            
              _buildCircleIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                isDark: isDark,
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Text(
                'Now Playing',
                style: googleSansFlex(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
             
              FutureBuilder<String>(
                future: _fetchActiveDevice(),
                builder: (context, snapshot) {
                  final deviceName = snapshot.data ?? 'Speaker';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.speaker_rounded,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          deviceName.length > 15 ? '${deviceName.substring(0, 15)}...' : deviceName,
                          style: googleSansFlex(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildCircleIconButton(
                icon: Icons.queue_music_rounded,
                isDark: isDark,
                iconSize: 20,
                onPressed: () {},
              ),
            ],
          ),
        ),

        const Spacer(flex: 1),

     
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Hero(
              tag: 'album_art_${item.id}',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  image: item.artUri != null
                      ? DecorationImage(
                          image: item.artUri!.toString().startsWith('file://')
                              ? FileImage(File(item.artUri!.toString().replaceFirst('file://', ''))) as ImageProvider
                              : CachedNetworkImageProvider(item.artUri!.toString()),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                ),
                child: item.artUri == null
                    ? Icon(
                        Icons.music_note_rounded,
                        size: 90,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      )
                    : null,
              ),
            ),
          ),
        ),

        const Spacer(flex: 1),


        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: googleSansFlex(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.artist ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: googleSansFlex(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

           
              _buildCircleIconButton(
                icon: Icons.lyrics_outlined,
                isDark: isDark,
                iconSize: 22,
                onPressed: () {
                  setState(() => _showLyrics = true);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

     
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: isDark ? AppColors.neonGreen : AppColors.lightTextPrimary,
                  inactiveTrackColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  thumbColor: isDark ? AppColors.neonGreen : AppColors.lightTextPrimary,
                ),
                child: Slider(
                  value: dur.inMilliseconds > 0
                      ? pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble())
                      : 0,
                  max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
                  onChanged: (val) {
                    handler.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pos.formatted,
                      style: googleSansFlex(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorder : AppColors.glassDarkBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        _getAudioQualityBadge(item, audioParams, dur),
                        style: googleSansFlex(
                          color: isDark ? AppColors.neonGreen : AppColors.lightTextPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      dur.formatted,
                      style: googleSansFlex(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

      
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
             
              _buildPillButton(
                icon: Icons.skip_previous_rounded,
                bgColor: secondaryPillBg,
                iconColor: secondaryPillIcon,
                onPressed: () => handler.skipToPrevious(),
              ),

       
              _buildPillButton(
                icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                bgColor: primaryPillBg,
                iconColor: primaryPillIcon,
                onPressed: () => isPlaying ? handler.pause() : handler.play(),
              ),

            
              _buildPillButton(
                icon: Icons.skip_next_rounded,
                bgColor: secondaryPillBg,
                iconColor: secondaryPillIcon,
                onPressed: () => handler.skipToNext(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

    
        Container(
          width: 280,
          height: 56,
          decoration: BoxDecoration(
            color: dockBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: dockBorder, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => setState(() => _isShuffle = !_isShuffle),
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: _isShuffle
                      ? (isDark ? AppColors.neonGreen : AppColors.lightTextPrimary)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  size: 22,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isRepeat = !_isRepeat),
                icon: Icon(
                  Icons.repeat_rounded,
                  color: _isRepeat
                      ? (isDark ? AppColors.neonGreen : AppColors.lightTextPrimary)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  size: 22,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isFavorite = !_isFavorite),
                icon: Icon(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isFavorite
                      ? AppColors.error
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  size: 22,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }


  Widget _buildLyricsView(
    BuildContext context,
    MediaItem item,
    String? rawLyrics,
    int activeLyricIndex,
    Duration pos,
    Duration dur,
    bool isPlaying,
    AudioHandler handler,
    bool isDark,
  ) {
    final pillBg = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final pillBorder = isDark ? AppColors.glassBorder : AppColors.glassDarkBorder;
    final playPillBg = isDark ? AppColors.neonGreen : AppColors.lightTextPrimary;
    final playPillIcon = isDark ? Colors.black : Colors.white;

    final syncedPillBg = isDark ? AppColors.neonGreen : AppColors.lightTextPrimary;
    final syncedPillText = isDark ? Colors.black : Colors.white;

    return Column(
      key: const ValueKey('LyricsView'),
      children: [
      
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: pillBorder, width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: item.artUri != null
                        ? DecorationImage(
                            image: item.artUri!.toString().startsWith('file://')
                                ? FileImage(File(item.artUri!.toString().replaceFirst('file://', ''))) as ImageProvider
                                : CachedNetworkImageProvider(item.artUri!.toString()),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  ),
                  child: item.artUri == null
                      ? Icon(
                          Icons.music_note_rounded,
                          size: 20,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: googleSansFlex(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.artist ?? 'Unknown Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: googleSansFlex(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.bar_chart_rounded,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  size: 24,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),


        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _parsedLyrics != null
                ? ListView.builder(
                    controller: _lyricScrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _parsedLyrics!.length,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    itemBuilder: (context, index) {
                      final isCurrent = index == activeLyricIndex;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.centerLeft,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: googleSansFlex(
                            color: isCurrent
                                ? (isDark ? AppColors.neonGreen : AppColors.lightTextPrimary)
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary.withValues(alpha: 0.6)),
                            fontSize: isCurrent ? 24 : 19,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                            height: 1.4,
                          ),
                          child: Text(
                            _parsedLyrics![index].text,
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        rawLyrics ?? 'No lyrics available.',
                        textAlign: TextAlign.center,
                        style: googleSansFlex(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontSize: 20,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
          ),
        ),

    
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
            
              Row(
                children: [
              
                  GestureDetector(
                    onTap: () => isPlaying ? handler.pause() : handler.play(),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: playPillBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: playPillIcon,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: pillBorder, width: 1.2),
                      ),
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          activeTrackColor: isDark ? AppColors.neonGreen : AppColors.lightTextPrimary,
                          inactiveTrackColor: isDark ? AppColors.darkCardHover : AppColors.lightSurfaceVariant,
                          thumbColor: isDark ? AppColors.neonGreen : AppColors.lightTextPrimary,
                        ),
                        child: Slider(
                          value: dur.inMilliseconds > 0
                              ? pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble())
                              : 0,
                          max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
                          onChanged: (val) {
                            handler.seek(Duration(milliseconds: val.toInt()));
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

          
              Row(
                children: [
                 
                  _buildCircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    isDark: isDark,
                    onPressed: () => setState(() => _showLyrics = false),
                  ),
                  const SizedBox(width: 12),

                 
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: pillBorder, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSyncedLyrics = true),
                              child: Container(
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: _isSyncedLyrics ? syncedPillBg : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Synced',
                                  style: googleSansFlex(
                                    color: _isSyncedLyrics
                                        ? syncedPillText
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSyncedLyrics = false),
                              child: Container(
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: !_isSyncedLyrics ? syncedPillBg : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Static',
                                  style: googleSansFlex(
                                    color: !_isSyncedLyrics
                                        ? syncedPillText
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                 
                  _buildCircleIconButton(
                    icon: Icons.more_vert_rounded,
                    isDark: isDark,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildCircleIconButton({
    required IconData icon,
    required bool isDark,
    double iconSize = 22,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? AppColors.glassBorder : AppColors.glassDarkBorder,
          width: 1.2,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: iconSize,
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  
  Widget _buildPillButton({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 96,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 32,
        ),
      ),
    );
  }

  String _getAudioQualityBadge(MediaItem item, AudioParams? params, Duration dur) {
    final fileName = (item.extras?['fileName'] as String?) ??
        (item.extras?['filePath'] as String?) ??
        item.title;

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final isFlac = ext == 'flac' || item.id.toLowerCase().contains('.flac');
    final isWav = ext == 'wav' || item.id.toLowerCase().contains('.wav');
    final isAac = ext == 'm4a' || ext == 'aac' || item.id.toLowerCase().contains('.m4a');
    final isMp3 = ext == 'mp3' || item.id.toLowerCase().contains('.mp3');

  
    String codec = 'AUDIO';
    if (isFlac) {
      codec = 'FLAC';
    } else if (isWav) {
      codec = 'WAV';
    } else if (isAac) {
      codec = 'AAC';
    } else if (isMp3) {
      codec = 'MP3';
    } else if (ext.isNotEmpty) {
      codec = ext.toUpperCase();
    }

    final sampleRateVal = params?.sampleRate;
    String sampleRateStr = '44.1 kHz';
    if (sampleRateVal != null && sampleRateVal > 0) {
      final khz = sampleRateVal / 1000.0;
      sampleRateStr = '${khz.toStringAsFixed(khz.truncateToDouble() == khz ? 0 : 1)} kHz';
    }

    final fileSize = item.extras?['fileSize'] as int?;
    String bitrateStr;
    if (fileSize != null && fileSize > 0 && dur.inSeconds > 0) {
      final kbps = ((fileSize * 8) / dur.inSeconds / 1000).round();
      bitrateStr = '$kbps kbps';
    } else if (isFlac || isWav) {
      bitrateStr = 'Lossless';
    } else if (isMp3) {
      bitrateStr = '320 kbps';
    } else {
      bitrateStr = 'Lossless';
    }

    return '$sampleRateStr • $bitrateStr • $codec';
  }

  Future<String> _fetchActiveDevice() async {
    try {
      final session = await audio_session.AudioSession.instance;
      final allDevices = await session.getDevices();
      final outputDevices = allDevices.where((d) => d.isOutput).toList();
      if (outputDevices.isEmpty) return 'Speaker';
      
      final a2dp = outputDevices.where((d) => d.type.name.toLowerCase().contains('bluetooth')).toList();
      if (a2dp.isNotEmpty) return a2dp.first.name;
      
      final usb = outputDevices.where((d) => d.type.name.toLowerCase().contains('usb')).toList();
      if (usb.isNotEmpty) return usb.first.name;
      
      final wired = outputDevices.where((d) => d.type.name.toLowerCase().contains('wired') || d.type.name.toLowerCase().contains('head')).toList();
      if (wired.isNotEmpty) return wired.first.name;

      final speaker = outputDevices.where((d) => d.type.name.toLowerCase().contains('speaker')).toList();
      if (speaker.isNotEmpty) return speaker.first.name;

      return outputDevices.first.name;
    } catch (_) {
      return 'Speaker';
    }
  }
}
