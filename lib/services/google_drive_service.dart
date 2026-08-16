import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../core/utils/file_extensions.dart';
import '../models/media_item_model.dart';

class GoogleDriveService {
  static GoogleDriveService? _instance;
  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  GoogleSignInAccount? _currentUser;

  GoogleDriveService._();

  static GoogleDriveService get instance {
    _instance ??= GoogleDriveService._();
    return _instance!;
  }

  bool get isSignedIn => _currentUser != null;
  GoogleSignInAccount? get currentUser => _currentUser;

  GoogleSignIn get _signIn {
    _googleSignIn ??= GoogleSignIn(
      scopes: [drive.DriveApi.driveReadonlyScope],
    );
    return _googleSignIn!;
  }

  
  Future<bool> signIn() async {
    try {
      _currentUser = await _signIn.signIn();
      if (_currentUser != null) {
        final httpClient = (await _signIn.authenticatedClient())!;
        _driveApi = drive.DriveApi(httpClient);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return false;
    }
  }

 
  Future<bool> signInSilently() async {
    try {
      _currentUser = await _signIn.signInSilently();
      if (_currentUser != null) {
        final httpClient = (await _signIn.authenticatedClient())!;
        _driveApi = drive.DriveApi(httpClient);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Silent sign-in error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _signIn.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  Future<List<drive.File>> listFolders({String? parentId}) async {
    if (_driveApi == null) throw Exception('Not signed in');

    final parent = parentId ?? 'root';
    final query = "'$parent' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";

    final result = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id, name, modifiedTime)',
      orderBy: 'name',
      pageSize: 100,
    );

    return result.files ?? [];
  }

  Future<List<MediaItemModel>> listMediaFiles(String folderId) async {
    if (_driveApi == null) throw Exception('Not signed in');

    final items = <MediaItemModel>[];
    await _listFilesRecursive(folderId, '', items);
    return items;
  }

  Future<void> _listFilesRecursive(
    String folderId,
    String pathPrefix,
    List<MediaItemModel> items,
  ) async {
    if (_driveApi == null) return;

    String? pageToken;
    do {
      final result = await _driveApi!.files.list(
        q: "'$folderId' in parents and trashed=false",
        $fields: 'nextPageToken, files(id, name, mimeType, size, modifiedTime)',
        orderBy: 'name',
        pageSize: 200,
        pageToken: pageToken,
      );

      for (final file in result.files ?? []) {
        if (file.mimeType == 'application/vnd.google-apps.folder') {
       
          await _listFilesRecursive(
            file.id!,
            '$pathPrefix${file.name}/',
            items,
          );
        } else if (FileExtensions.isMedia(file.name ?? '')) {
          final isAudio = FileExtensions.isAudio(file.name ?? '');
          items.add(MediaItemModel.fromFileName(
            id: file.id!,
            fileName: file.name ?? 'Unknown',
            filePath: '$pathPrefix${file.name}',
            type: isAudio ? MediaType.audio : MediaType.video,
            source: MediaSource.googleDrive,
            sourceId: file.id!,
            fileSize: int.tryParse(file.size ?? ''),
            mimeType: file.mimeType,
          ));
        }
      }

      pageToken = result.nextPageToken;
    } while (pageToken != null);
  }

  
  Future<Map<String, String>> getStreamHeaders() async {
    if (_currentUser == null) throw Exception('Not signed in');
    final auth = await _currentUser!.authHeaders;
    return auth;
  }


  String getStreamUrl(String fileId) {
    return 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
  }
}
