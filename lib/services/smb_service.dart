import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:smb_connect/smb_connect.dart';
import '../core/utils/file_extensions.dart';
import '../models/media_item_model.dart';
import '../models/server_info.dart';


class SmbService {
  static SmbService? _instance;
  SmbConnect? _client;
  SmbConnect? _metadataClient;
  ServerInfo? _serverInfo;
  bool _isConnected = false;

  SmbService._();

  static SmbService get instance {
    _instance ??= SmbService._();
    return _instance!;
  }

  bool get isConnected => _isConnected;
  ServerInfo? get serverInfo => _serverInfo;


  Future<bool> connect(ServerInfo server) async {
    try {
      _client = await SmbConnect.connectAuth(
        host: server.host,
        domain: 'WORKGROUP',
        username: 'guest',
        password: '',
      );

      await _client!.listShares();
      _serverInfo = server;
      _isConnected = true;
      debugPrint('SMB connected to ${server.host}');
      return true;
    } catch (e) {
      debugPrint('SMB connection error: $e');
      _isConnected = false;
      return false;
    }
  }


  Future<void> disconnect() async {
    try {
      await _client?.close();
    } catch (_) {}
    try {
      await _metadataClient?.close();
    } catch (_) {}
    _client = null;
    _metadataClient = null;
    _isConnected = false;
    _serverInfo = null;
  }

  Future<List<String>> listShares() async {
    if (_client == null) throw Exception('Not connected');
    try {
      final shares = await _client!.listShares();
      return shares
          .map((s) => s.name)
          .where((name) => !name.endsWith('\$'))
          .toList();
    } catch (e) {
      debugPrint('Error listing shares: $e');
      return [];
    }
  }


  Future<List<MediaItemModel>> listMediaFiles(
    String share, {
    String path = '',
    bool recursive = true,
  }) async {
    if (_client == null) throw Exception('Not connected');

    final items = <MediaItemModel>[];
    await _listRecursive(share, path, items, recursive);
    return items;
  }

  Future<void> _listRecursive(
    String share,
    String path,
    List<MediaItemModel> items,
    bool recursive,
  ) async {
    try {
      final folderPath = path.isEmpty ? '/$share' : '/$share/$path';
      final folder = await _client!.file(folderPath);
      final entries = await _client!.listFiles(folder);

      for (final entry in entries) {
        final entryName = entry.name;
        final fullPath = path.isEmpty ? entryName : '$path/$entryName';

        if (entry.isDirectory() && recursive) {
          await _listRecursive(share, fullPath, items, recursive);
        } else if (entry.isFile() && FileExtensions.isMedia(entryName)) {
          final isAudio = FileExtensions.isAudio(entryName);
          items.add(MediaItemModel.fromFileName(
            id: '${share}_$fullPath',
            fileName: entryName,
            filePath: fullPath,
            type: isAudio ? MediaType.audio : MediaType.video,
            source: MediaSource.smb,
            sourceId: '$share/$fullPath',
            fileSize: entry.size,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error listing $path: $e');
    }
  }

  Future<Stream<Uint8List>> readFileStream(
    String share,
    String filePath, {
    int? offset,
    int? length,
  }) async {
    if (_client == null) throw Exception('Not connected');

    final smbFile = await _client!.file('/$share/$filePath');
    return await _client!.openRead(smbFile, offset, length != null && offset != null ? offset + length : null);
  }

 
  Future<int> getFileSize(String share, String filePath) async {
    if (_client == null) throw Exception('Not connected');
    final smbFile = await _client!.file('/$share/$filePath');
    return smbFile.size;
  }

  Future<dynamic> openFile(String share, String filePath) async {
    if (_client == null) throw Exception('Not connected');
    final smbFile = await _client!.file('/$share/$filePath');
    return await _client!.open(smbFile);
  }

 
  Future<dynamic> openMetadataFile(String share, String filePath) async {
    if (_serverInfo == null) throw Exception('No server info');
    
    if (_metadataClient == null) {
      _metadataClient = await SmbConnect.connectAuth(
        host: _serverInfo!.host,
        domain: 'WORKGROUP',
        username: 'guest',
        password: '',
      );
    }
    
    final smbFile = await _metadataClient!.file('/$share/$filePath');
    return await _metadataClient!.open(smbFile);
  }
}
