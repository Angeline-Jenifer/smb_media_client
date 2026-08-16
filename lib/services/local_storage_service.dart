import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_info.dart';
import '../models/media_item_model.dart';


class LocalStorageService {
  static LocalStorageService? _instance;
  late final SharedPreferences _prefs;

  LocalStorageService._(this._prefs);

  static Future<LocalStorageService> init() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = LocalStorageService._(prefs);
    return _instance!;
  }

  static LocalStorageService get instance => _instance!;


  static const _onboardingComplete = 'onboarding_complete';

  bool get isOnboardingComplete => _prefs.getBool(_onboardingComplete) ?? false;

  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(_onboardingComplete, value);

  static const _driveFolderId = 'drive_folder_id';
  static const _driveFolderName = 'drive_folder_name';
  static const _isDriveConnected = 'is_drive_connected';

  String? get driveFolderId => _prefs.getString(_driveFolderId);
  String? get driveFolderName => _prefs.getString(_driveFolderName);
  bool get isDriveConnected => _prefs.getBool(_isDriveConnected) ?? false;

  Future<void> saveDriveFolder(String folderId, String folderName) async {
    await _prefs.setString(_driveFolderId, folderId);
    await _prefs.setString(_driveFolderName, folderName);
    await _prefs.setBool(_isDriveConnected, true);
  }

  Future<void> clearDriveFolder() async {
    await _prefs.remove(_driveFolderId);
    await _prefs.remove(_driveFolderName);
    await _prefs.setBool(_isDriveConnected, false);
  }


  static const _smbServer = 'smb_server';
  static const _smbShare = 'smb_share';

  ServerInfo? get smbServer {
    final json = _prefs.getString(_smbServer);
    if (json == null) return null;
    return ServerInfo.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveSmbServer(ServerInfo info) =>
      _prefs.setString(_smbServer, jsonEncode(info.toJson()));

  Future<void> clearSmbServer() => _prefs.remove(_smbServer);

  String? get smbShare => _prefs.getString(_smbShare);
  Future<void> saveSmbShare(String share) =>
      _prefs.setString(_smbShare, share);

 
  static const _defaultMode = 'default_mode';

  String get defaultMode => _prefs.getString(_defaultMode) ?? 'outdoor';

  Future<void> setDefaultMode(String mode) =>
      _prefs.setString(_defaultMode, mode);

  
  static const _recentlyPlayedIndoorKey = 'recently_played_indoor';
  static const _recentlyPlayedOutdoorKey = 'recently_played_outdoor';
  static const _recentlyPlayedLegacy = 'recently_played';
  static const _maxRecent = 25;

  List<String> get recentlyPlayedIds {
    return _prefs.getStringList(_recentlyPlayedLegacy) ?? [];
  }

  List<MediaItemModel> getRecentlyPlayedForMode(String mode) {
    final key = mode == 'indoor' ? _recentlyPlayedIndoorKey : _recentlyPlayedOutdoorKey;
    final jsonList = _prefs.getStringList(key) ?? [];
    final items = <MediaItemModel>[];
    for (final str in jsonList) {
      try {
        items.add(MediaItemModel.fromJson(jsonDecode(str) as Map<String, dynamic>));
      } catch (_) {}
    }
    return items;
  }


  Future<void> addToRecentlyPlayedForMode(MediaItemModel song, String mode) async {
    final key = mode == 'indoor' ? _recentlyPlayedIndoorKey : _recentlyPlayedOutdoorKey;
    final jsonList = _prefs.getStringList(key) ?? [];

    final items = <MediaItemModel>[];
    for (final str in jsonList) {
      try {
        items.add(MediaItemModel.fromJson(jsonDecode(str) as Map<String, dynamic>));
      } catch (_) {}
    }

    
    items.removeWhere((item) => item.id == song.id || item.sourceId == song.sourceId);
    items.insert(0, song);

    if (items.length > _maxRecent) {
      items.removeRange(_maxRecent, items.length);
    }

    final updatedJsonList = items.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(key, updatedJsonList);

    await addToRecentlyPlayed(song.id);
  }

  Future<void> addToRecentlyPlayed(String mediaId) async {
    final list = recentlyPlayedIds;
    list.remove(mediaId);
    list.insert(0, mediaId);
    if (list.length > _maxRecent) {
      list.removeRange(_maxRecent, list.length);
    }
    await _prefs.setStringList(_recentlyPlayedLegacy, list);
  }

  static const _metadataCachePrefix = 'meta_';

  Map<String, dynamic>? getCachedMetadata(String filePath) {
    final jsonStr = _prefs.getString('$_metadataCachePrefix$filePath');
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedMetadata(String filePath, Map<String, dynamic> metadata) async {
    await _prefs.setString('$_metadataCachePrefix$filePath', jsonEncode(metadata));
  }


  static const _themeMode = 'theme_mode';

  String get themeMode => _prefs.getString(_themeMode) ?? 'dark';

  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_themeMode, mode);
}
