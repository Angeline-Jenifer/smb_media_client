import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item_model.dart';
import '../services/local_storage_service.dart';
import 'mode_provider.dart';

final recentlyPlayedProvider =
    StateNotifierProvider<RecentlyPlayedNotifier, List<MediaItemModel>>((ref) {
  final mode = ref.watch(modeProvider);
  return RecentlyPlayedNotifier(mode);
});

class RecentlyPlayedNotifier extends StateNotifier<List<MediaItemModel>> {
  final AppMode _mode;

  RecentlyPlayedNotifier(this._mode) : super([]) {
    load();
  }

  void load() {
    final modeStr = _mode == AppMode.indoor ? 'indoor' : 'outdoor';
    final items = LocalStorageService.instance.getRecentlyPlayedForMode(modeStr);
    state = items;
  }

  Future<void> addTrack(MediaItemModel track) async {
    final modeStr = _mode == AppMode.indoor ? 'indoor' : 'outdoor';
    await LocalStorageService.instance.addToRecentlyPlayedForMode(track, modeStr);
    load();
  }
}
