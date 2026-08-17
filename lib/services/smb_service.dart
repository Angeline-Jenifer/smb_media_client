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
  SmbConnect? _streamClient;
  ServerInfo? _serverInfo;
  bool _isConnected = false;

  /// Size of aggregated output chunks for buffered streaming.
  /// Incoming 4KB SMB reads are collected into this size before yielding.
  static const int _streamBufferSize = 512 * 1024; // 512KB

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
    try {
      await _streamClient?.close();
    } catch (_) {}
    _client = null;
    _metadataClient = null;
    _streamClient = null;
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

  /// Opens a buffered read stream on a **dedicated streaming connection**.
  ///
  /// The tiny ~4KB chunks emitted by `smb_connect` are aggregated into
  /// [_streamBufferSize] (512KB) blocks before being yielded downstream,
  /// dramatically reducing I/O overhead for large file streaming.
  ///
  /// Uses a separate SMB connection ([_streamClient]) so video playback
  /// never competes with directory listings or metadata operations on [_client].
  Future<Stream<Uint8List>> readFileStreamBuffered(
    String share,
    String filePath, {
    int? offset,
    int? length,
  }) async {
    final client = await _getOrCreateStreamClient();
    final smbFile = await client.file('/$share/$filePath');
    final rawStream = await client.openRead(
      smbFile,
      offset,
      length != null && offset != null ? offset + length : null,
    );

    // Aggregate small SMB chunks into large output blocks.
    return _bufferStream(rawStream);
  }

  /// Aggregates a stream of small [Uint8List] chunks into larger blocks.
  Stream<Uint8List> _bufferStream(Stream<Uint8List> source) async* {
    final buffer = BytesBuilder(copy: false);

    await for (final chunk in source) {
      buffer.add(chunk);

      while (buffer.length >= _streamBufferSize) {
        final accumulated = buffer.takeBytes();
        // If exactly _streamBufferSize, yield directly.
        // If larger, split: yield the first _streamBufferSize and re-add rest.
        if (accumulated.length <= _streamBufferSize) {
          yield accumulated;
        } else {
          yield Uint8List.sublistView(accumulated, 0, _streamBufferSize);
          buffer.add(Uint8List.sublistView(accumulated, _streamBufferSize));
        }
      }
    }

    // Flush any remaining data.
    if (buffer.length > 0) {
      yield buffer.takeBytes();
    }
  }

  /// Returns the dedicated streaming client, creating it if necessary.
  /// Auto-reconnects if the previous connection was lost.
  Future<SmbConnect> _getOrCreateStreamClient() async {
    if (_serverInfo == null) throw Exception('No server info');

    if (_streamClient == null) {
      _streamClient = await SmbConnect.connectAuth(
        host: _serverInfo!.host,
        domain: 'WORKGROUP',
        username: 'guest',
        password: '',
      );
      debugPrint('SMB stream client connected to ${_serverInfo!.host}');
    }

    return _streamClient!;
  }

  /// Closes and resets the dedicated streaming client.
  /// Called by the proxy when a seek or disconnect invalidates the current stream.
  Future<void> resetStreamClient() async {
    try {
      await _streamClient?.close();
    } catch (_) {}
    _streamClient = null;
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
