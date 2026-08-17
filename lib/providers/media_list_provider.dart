import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../models/media_item_model.dart';
import '../services/google_drive_service.dart';
import '../services/local_storage_service.dart';
import '../services/smb_service.dart';
import '../core/utils/flac_metadata_extractor.dart';
import '../core/utils/opus_metadata_extractor.dart';
import '../audio/audio_provider.dart';
import 'mode_provider.dart';


final mediaListProvider =
    StateNotifierProvider<MediaListNotifier, AsyncValue<List<MediaItemModel>>>(
  (ref) => MediaListNotifier(ref),
);

final audioListProvider = Provider<AsyncValue<List<MediaItemModel>>>((ref) {
  final all = ref.watch(mediaListProvider);
  return all.whenData(
    (items) => items.where((i) => i.type == MediaType.audio).toList(),
  );
});


final videoListProvider = Provider<AsyncValue<List<MediaItemModel>>>((ref) {
  final all = ref.watch(mediaListProvider);
  return all.whenData(
    (items) => items.where((i) => i.type == MediaType.video).toList(),
  );
});


final albumsProvider =
    Provider<AsyncValue<Map<String, List<MediaItemModel>>>>((ref) {
  final audio = ref.watch(audioListProvider);
  return audio.whenData((items) {
    final map = <String, List<MediaItemModel>>{};
    for (final item in items) {
      final album = item.album ?? 'Unknown Album';
      map.putIfAbsent(album, () => []).add(item);
    }
    return map;
  });
});


final artistsProvider =
    Provider<AsyncValue<Map<String, List<MediaItemModel>>>>((ref) {
  final audio = ref.watch(audioListProvider);
  return audio.whenData((items) {
    final map = <String, List<MediaItemModel>>{};
    for (final item in items) {
      final artist = item.artist ?? 'Unknown Artist';
      map.putIfAbsent(artist, () => []).add(item);
    }
    return map;
  });
});

class MediaListNotifier extends StateNotifier<AsyncValue<List<MediaItemModel>>> {
  final Ref _ref;

  MediaListNotifier(this._ref) : super(const AsyncValue.loading());


  Future<void> fetchMedia() async {
    state = const AsyncValue.loading();

    try {
      final mode = _ref.read(modeProvider);
      List<MediaItemModel> items;

      if (mode == AppMode.outdoor) {
        items = await _fetchFromDrive();
      } else {
        items = await _fetchFromSmb();
      }

      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<MediaItemModel>> _fetchFromDrive() async {
    final driveService = GoogleDriveService.instance;
    final storage = LocalStorageService.instance;
    final folderId = storage.driveFolderId;

    if (folderId == null || !driveService.isSignedIn) {
      return [];
    }

    final items = await driveService.listMediaFiles(folderId);

    for (int i = 0; i < items.length; i++) {
      
      final cached = LocalStorageService.instance.getCachedMetadata(items[i].sourceId);
      if (cached != null) {
        items[i] = items[i].copyWith(
          title: cached['title'] as String?,
          artist: cached['artist'] as String?,
          album: cached['album'] as String?,
          lyrics: cached['lyrics'] as String?,
          albumArtUrl: cached['albumArtUrl'] as String?,
        );
      }
    }

    return items;
  }

  Future<List<MediaItemModel>> _fetchFromSmb() async {
    final smbService = SmbService.instance;
    final storage = LocalStorageService.instance;

    if (!smbService.isConnected) {
      final server = storage.smbServer;
      if (server != null) {
        await smbService.connect(server);
      }
    }

    if (!smbService.isConnected) {
      return [];
    }

 
    final shares = await smbService.listShares();
    final allItems = <MediaItemModel>[];

    for (final share in shares) {
      final items = await smbService.listMediaFiles(share);
      

      for (int i = 0; i < items.length; i++) {
        final cached = LocalStorageService.instance.getCachedMetadata(items[i].filePath);
        if (cached != null) {
          items[i] = items[i].copyWith(
            title: cached['title'] as String?,
            artist: cached['artist'] as String?,
            album: cached['album'] as String?,
            lyrics: cached['lyrics'] as String?,
            albumArtUrl: cached['albumArtUrl'] as String?,
          );
        }
      }
      
      allItems.addAll(items);
    }

    return allItems;
  }

  final Set<String> _extractingIds = {};

  static const _extractableExtensions = ['.flac', '.opus', '.ogg'];

  static bool _isExtractable(String fileName) {
    final lower = fileName.toLowerCase();
    return _extractableExtensions.any((ext) => lower.endsWith(ext));
  }

  Future<void> extractMetadata(MediaItemModel item) async {
    if (!_isExtractable(item.fileName)) return;
    if (item.albumArtUrl != null) return; 
    if (_extractingIds.contains(item.id)) return; 

    _extractingIds.add(item.id);
    
    try {
      final lowerName = item.fileName.toLowerCase();
      final isFlac = lowerName.endsWith('.flac');
      final isOpus = lowerName.endsWith('.opus') || lowerName.endsWith('.ogg');

      debugPrint('[MediaList] extractMetadata: ${item.fileName} isFlac=$isFlac isOpus=$isOpus source=${item.source}');

      String? title;
      String? artist;
      String? album;
      String? lyrics;
      String? albumArtUrl;
      String cacheKey;

      if (item.source == MediaSource.smb) {
        final share = item.sourceId.split('/')[0];
        cacheKey = item.filePath;

        if (isFlac) {
          final m = await FlacMetadataExtractor.extractFromSmb(share, item.filePath);
          if (m != null) {
            title = m.title; artist = m.artist; album = m.album;
            lyrics = m.lyrics; albumArtUrl = m.albumArtUrl;
          }
        } else if (isOpus) {
          final m = await OpusMetadataExtractor.extractFromSmb(share, item.filePath);
          if (m != null) {
            title = m.title; artist = m.artist; album = m.album;
            lyrics = m.lyrics; albumArtUrl = m.albumArtUrl;
          }
        }
      } else if (item.source == MediaSource.googleDrive) {
        final headers = await GoogleDriveService.instance.getStreamHeaders();
        cacheKey = item.sourceId;

        if (isFlac) {
          final m = await FlacMetadataExtractor.extractFromDrive(item.sourceId, item.fileName, headers);
          if (m != null) {
            title = m.title; artist = m.artist; album = m.album;
            lyrics = m.lyrics; albumArtUrl = m.albumArtUrl;
          }
        } else if (isOpus) {
          final m = await OpusMetadataExtractor.extractFromDrive(item.sourceId, item.fileName, headers);
          if (m != null) {
            title = m.title; artist = m.artist; album = m.album;
            lyrics = m.lyrics; albumArtUrl = m.albumArtUrl;
          }
        }
      } else {
        return;
      }
      
      if (title != null || artist != null || album != null || lyrics != null || albumArtUrl != null) {
        LocalStorageService.instance.saveCachedMetadata(cacheKey, {
          'title': title,
          'artist': artist,
          'album': album,
          'lyrics': lyrics,
          'albumArtUrl': albumArtUrl,
        });

        state.whenData((currentItems) {
          final index = currentItems.indexWhere((e) => e.id == item.id);
          if (index != -1) {
            final newItems = List<MediaItemModel>.from(currentItems);
            newItems[index] = newItems[index].copyWith(
              title: title,
              artist: artist,
              album: album,
              lyrics: lyrics,
              albumArtUrl: albumArtUrl,
            );
            state = AsyncValue.data(newItems);
          }
        });

        // Dynamically update the active track in the Audio Service if it's currently playing
        try {
          final audioHandler = _ref.read(audioHandlerProvider);
          final currentItem = audioHandler.mediaItem.value;
          
          MediaItem? updatedItem;
          
          if (currentItem != null && currentItem.extras?['mediaId'] == item.id) {
            updatedItem = currentItem.copyWith(
              title: title ?? currentItem.title,
              artist: artist ?? currentItem.artist,
              album: album ?? currentItem.album,
              artUri: albumArtUrl != null ? Uri.parse(albumArtUrl) : currentItem.artUri,
              extras: {
                ...?currentItem.extras,
                'lyrics': lyrics ?? currentItem.extras?['lyrics'],
              },
            );
          } else {
            // Check if it's in the queue at least
            final queue = audioHandler.queue.value;
            final queueIndex = queue.indexWhere((e) => e.extras?['mediaId'] == item.id);
            if (queueIndex != -1) {
              final qItem = queue[queueIndex];
              updatedItem = qItem.copyWith(
                title: title ?? qItem.title,
                artist: artist ?? qItem.artist,
                album: album ?? qItem.album,
                artUri: albumArtUrl != null ? Uri.parse(albumArtUrl) : qItem.artUri,
                extras: {
                  ...?qItem.extras,
                  'lyrics': lyrics ?? qItem.extras?['lyrics'],
                },
              );
            }
          }
          
          if (updatedItem != null) {
            audioHandler.updateTrackMetadata(updatedItem);
          }
        } catch (e) {
          debugPrint('[MediaList] Error updating audio handler metadata: $e');
        }
      }
    } catch (_) {} finally {
      _extractingIds.remove(item.id);
    }
  }
}
