import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'media_kit_audio_handler.dart';


late final MediaKitAudioHandler globalAudioHandler;

final audioHandlerProvider = Provider<MediaKitAudioHandler>((ref) {
  return globalAudioHandler;
});


final currentTrackProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem;
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState;
});


final isPlayingProvider = Provider<bool>((ref) {
  final state = ref.watch(playbackStateProvider);
  return state.when(
    data: (s) => s.playing,
    loading: () => false,
    error: (_, __) => false,
  );
});

final queueProvider = StreamProvider<List<MediaItem>>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.queue;
});


final positionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.stream.position;
});


final durationProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.stream.duration;
});

final bufferProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.stream.buffer;
});

final audioParamsProvider = StreamProvider<AudioParams>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.stream.audioParams;
});
