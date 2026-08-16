import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';


enum AppMode { outdoor, indoor }


final modeProvider = StateNotifierProvider<ModeNotifier, AppMode>((ref) {
  return ModeNotifier(ref);
});

class ModeNotifier extends StateNotifier<AppMode> {
  final Ref _ref;

  ModeNotifier(this._ref) : super(AppMode.outdoor) {
    _loadDefault();
  }

  void _loadDefault() {
    final storage = LocalStorageService.instance;
    final defaultMode = storage.defaultMode;
    state = defaultMode == 'indoor' ? AppMode.indoor : AppMode.outdoor;
  }

  Future<bool> toggle() async {
    if (state == AppMode.outdoor) {
   
      final connectivity = _ref.read(connectivityServiceProvider);
      final wifi = await connectivity.isWifi;
      if (!wifi) return false;
      state = AppMode.indoor;
    } else {
      state = AppMode.outdoor;
    }
    await LocalStorageService.instance.setDefaultMode(
      state == AppMode.indoor ? 'indoor' : 'outdoor',
    );
    return true;
  }

  void setMode(AppMode mode) {
    state = mode;
  }
}
