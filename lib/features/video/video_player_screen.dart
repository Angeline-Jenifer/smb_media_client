import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/constants/app_colors.dart';
import '../../extensions/duration_extension.dart';

/// Full-screen video player with controls for MKV/MP4 streaming.
class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    // Enter fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    _player.open(Media(widget.url));
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            Video(controller: _controller),

            // Controls overlay
            if (_showControls) ...[
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0, 0.2, 0.7, 1],
                  ),
                ),
              ),

              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Center play/pause
              Center(
                child: StreamBuilder<bool>(
                  stream: _player.stream.playing,
                  builder: (context, snap) {
                    final playing = snap.data ?? false;
                    return IconButton(
                      onPressed: () {
                        playing ? _player.pause() : _player.play();
                        _startHideTimer();
                      },
                      icon: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Seek bar
                        StreamBuilder<Duration>(
                          stream: _player.stream.position,
                          builder: (context, posSnap) {
                            return StreamBuilder<Duration>(
                              stream: _player.stream.duration,
                              builder: (context, durSnap) {
                                final pos = posSnap.data ?? Duration.zero;
                                final dur = durSnap.data ?? Duration.zero;

                                return Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 5),
                                        activeTrackColor: AppColors.electricBlue,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: AppColors.electricBlue,
                                      ),
                                      child: Slider(
                                        value: dur.inMilliseconds > 0
                                            ? pos.inMilliseconds
                                                .toDouble()
                                                .clamp(0, dur.inMilliseconds.toDouble())
                                            : 0,
                                        max: dur.inMilliseconds > 0
                                            ? dur.inMilliseconds.toDouble()
                                            : 1,
                                        onChanged: (v) {
                                          _player.seek(
                                              Duration(milliseconds: v.toInt()));
                                          _startHideTimer();
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(pos.formatted,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                          Text(dur.formatted,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),

                        // Bottom action row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Audio track
                            _buildTrackButton(
                              icon: Icons.audiotrack,
                              label: 'Audio',
                              onTap: () => _showAudioTrackPicker(),
                            ),
                            // Subtitles
                            _buildTrackButton(
                              icon: Icons.subtitles,
                              label: 'Subtitles',
                              onTap: () => _showSubtitlePicker(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.white70),
      label: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }

  void _showAudioTrackPicker() {
    final tracks = _player.state.tracks.audio;
    if (tracks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return ListTile(
            leading: const Icon(Icons.audiotrack, color: AppColors.electricBlue),
            title: Text(
              track.title ?? track.language ?? 'Track ${index + 1}',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              _player.setAudioTrack(track);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _showSubtitlePicker() {
    final tracks = _player.state.tracks.subtitle;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.subtitles_off, color: AppColors.error),
            title: const Text('Off', style: TextStyle(color: Colors.white)),
            onTap: () {
              _player.setSubtitleTrack(SubtitleTrack.no());
              Navigator.pop(context);
            },
          ),
          ...tracks.map((track) => ListTile(
                leading: const Icon(Icons.subtitles, color: AppColors.electricBlue),
                title: Text(
                  track.title ?? track.language ?? 'Unknown',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _player.setSubtitleTrack(track);
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }
}
