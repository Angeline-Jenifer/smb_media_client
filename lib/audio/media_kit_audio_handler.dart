import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/foundation.dart';
import '../services/google_drive_service.dart';


class MediaKitAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final Player _player = Player();
  final List<MediaItem> _queue = [];
  int _currentIndex = -1;

  MediaKitAudioHandler() {
    _initStreams();
  }

  Player get player => _player;
  int get currentIndex => _currentIndex;

  void _initStreams() {
   
    _player.stream.playing.listen((playing) {
      _updatePlaybackState();
    });


    _player.stream.position.listen((pos) {
      _updatePlaybackState();
    });


    _player.stream.duration.listen((dur) {
      final current = mediaItem.value;
      if (current != null && dur > Duration.zero) {
        mediaItem.add(current.copyWith(duration: dur));
      }
    });

  
    _player.stream.completed.listen((completed) {
      if (completed) skipToNext();
    });


    _player.stream.error.listen((error) {
      debugPrint('media_kit error: $error');
    });
  }

  void _updatePlaybackState() {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.state.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: _player.state.playing,
      updatePosition: _player.state.position,
      bufferedPosition: _player.state.buffer,
      queueIndex: _currentIndex,
    ));
  }

 
  Future<void> playMedia(MediaItem item, {List<MediaItem>? playlist, int? index}) async {
    if (playlist != null) {
      _queue.clear();
      _queue.addAll(playlist);
      queue.add(List.from(_queue));
    } else if (!_queue.contains(item)) {
      _queue.add(item);
      queue.add(List.from(_queue));
    }

    _currentIndex = index ?? _queue.indexOf(item);
    mediaItem.add(item);

    await _openMediaItem(item);
    _updatePlaybackState();
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      final item = _queue[_currentIndex];
      mediaItem.add(item);
      await _openMediaItem(item);
    }
  }

  @override
  Future<void> skipToPrevious() async {
 
    if (_player.state.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      final item = _queue[_currentIndex];
      mediaItem.add(item);
      await _openMediaItem(item);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      final item = _queue[_currentIndex];
      mediaItem.add(item);
      await _openMediaItem(item);
    }
  }

  Future<void> _openMediaItem(MediaItem item) async {
    Map<String, String>? headers;
    if (item.id.startsWith('https://www.googleapis.com')) {
      headers = await GoogleDriveService.instance.getStreamHeaders();
    }
    await _player.open(Media(item.id, httpHeaders: headers));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
