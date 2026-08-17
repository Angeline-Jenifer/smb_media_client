import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/constants/app_colors.dart';
import '../../extensions/duration_extension.dart';
import '../../services/local_storage_service.dart';

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
  

  BoxFit _currentFit = BoxFit.contain;
  bool _isLocked = true;
  static const MethodChannel _pipChannel = MethodChannel('com.rexon.homeclient/pip');
  static const EventChannel _pipEventChannel = EventChannel('com.rexon.homeclient/pip_events');
  bool _isPipMode = false;
  StreamSubscription? _pipSubscription;
  StreamSubscription? _positionSubscription;
  bool _hasAutoResumed = false;

  @override
  void initState() {
    super.initState();

    _player = Player();
    _controller = VideoController(_player);

    _player.stream.log.listen((event) {
      debugPrint('libmpv: ${event.level} ${event.prefix}: ${event.text}');
    });

    try {
      final nativePlayer = _player.platform;
      if (nativePlayer != null) {
        dynamic p = nativePlayer;
        p.setProperty('demuxer-readahead-secs', '120');
        p.setProperty('demuxer-max-bytes', '150MiB');
        p.setProperty('demuxer-max-back-bytes', '50MiB');
        p.setProperty('cache', 'yes');
        p.setProperty('cache-secs', '120');
        p.setProperty('network-timeout', '30');
      }
    } catch (e) {
      debugPrint('Error setting mpv properties: $e');
    }

    _applyOrientation();

    debugPrint('Opening media URL: ${widget.url}');
    _player.open(Media(widget.url));
    _startHideTimer();

   
    final savedPosition = LocalStorageService.instance.getVideoPosition(widget.url);
    if (savedPosition.inMilliseconds > 0) {
      _positionSubscription = _player.stream.duration.listen((duration) {
        if (!_hasAutoResumed && duration.inMilliseconds > 0) {
          _hasAutoResumed = true;
          if (savedPosition < duration) {
            _player.seek(savedPosition);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Resumed from ${savedPosition.formatted}'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: AppColors.darkSurface,
                ),
              );
            }
          }
        }
      });
    }

   
    _pipSubscription = _pipEventChannel.receiveBroadcastStream().listen((event) {
      if (event is bool && mounted) {
        setState(() {
          _isPipMode = event;
          if (_isPipMode) _showControls = false;
        });
      }
    });
  }

  void _applyOrientation() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (_isLocked) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pipSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isPipMode) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_isPipMode) return; 
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _toggleFit() {
    setState(() {
      if (_currentFit == BoxFit.contain) {
        _currentFit = BoxFit.cover;
      } else if (_currentFit == BoxFit.cover) {
        _currentFit = BoxFit.fill;
      } else {
        _currentFit = BoxFit.contain;
      }
    });
    _startHideTimer();
  }

  void _toggleLock() {
    setState(() => _isLocked = !_isLocked);
    _applyOrientation();
    _startHideTimer();
  }

  Future<void> _enterPipMode() async {
    try {
      await _pipChannel.invokeMethod('enterPip');
    } catch (e) {
      debugPrint('PiP Error: $e');
    }
  }

  Future<void> _handleExit() async {
    _player.pause();
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Exit Video', style: TextStyle(color: Colors.white)),
        content: const Text('Do you want to stop watching and save your position?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.electricBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      final currentPos = _player.state.position;
      await LocalStorageService.instance.saveVideoPosition(widget.url, currentPos);
      if (mounted) Navigator.pop(context);
    } else {
      _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video
              Center(
                child: Video(
                  controller: _controller,
                  controls: NoVideoControls,
                  fit: _currentFit,
                ),
              ),

             
              if (_showControls && !_isPipMode) ...[
                
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0, 0.2, 0.7, 1],
                    ),
                  ),
                ),

                
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
                            onPressed: _handleExit,
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
                          IconButton(
                            onPressed: _enterPipMode,
                            icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

               
                Center(
                  child: StreamBuilder<bool>(
                    stream: _player.stream.buffering,
                    builder: (context, snapshot) {
                      final buffering = snapshot.data ?? false;
                      if (buffering) {
                        return const CircularProgressIndicator(
                          color: AppColors.electricBlue,
                        );
                      }
                      return StreamBuilder<bool>(
                        stream: _player.stream.playing,
                        builder: (context, snapshot) {
                          final playing = snapshot.data ?? false;
                          return IconButton(
                            onPressed: () {
                              _player.playOrPause();
                              _startHideTimer();
                            },
                            icon: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 64,
                              color: Colors.white,
                            ),
                          );
                        },
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
                              final pos = posSnap.data ?? Duration.zero;
                              final dur = _player.state.duration;

                              return Column(
                                children: [
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6),
                                      activeTrackColor: AppColors.electricBlue,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: AppColors.electricBlue,
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          ),
                          const SizedBox(height: 8),
                          // Bottom action row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton(
                                icon: _isLocked ? Icons.lock : Icons.lock_open,
                                label: 'Lock',
                                onTap: _toggleLock,
                              ),
                              _buildActionButton(
                                icon: Icons.aspect_ratio,
                                label: 'Fit',
                                onTap: _toggleFit,
                              ),
                              _buildActionButton(
                                icon: Icons.audiotrack,
                                label: 'Audio',
                                onTap: () => _showAudioTrackPicker(),
                              ),
                              _buildActionButton(
                                icon: Icons.subtitles,
                                label: 'Subs',
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
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showAudioTrackPicker() {
    final tracks = _player.state.tracks.audio;
    if (tracks.isEmpty || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: tracks.map((track) {
          return ListTile(
            leading: const Icon(Icons.audiotrack, color: AppColors.electricBlue),
            title: Text(
              track.title ?? track.language ?? track.id,
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              _player.setAudioTrack(track);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showSubtitlePicker() {
    final tracks = _player.state.tracks.subtitle;
    if (!mounted) return;

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
                  track.title ?? track.language ?? track.id,
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
