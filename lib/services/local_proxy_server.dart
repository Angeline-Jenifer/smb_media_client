import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'smb_service.dart';


class LocalProxyServer {
  static LocalProxyServer? _instance;
  HttpServer? _server;
  int _port = 0;
  final Map<String, int> _fileSizeCache = {};

  LocalProxyServer._();

  static LocalProxyServer get instance {
    _instance ??= LocalProxyServer._();
    return _instance!;
  }

  int get port => _port;
  bool get isRunning => _server != null;
  String get baseUrl => 'http://127.0.0.1:$_port';

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    debugPrint('Proxy started on port $_port');
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }

  String getProxyUrl(String share, String filePath) {
    final s = Uri.encodeComponent(share);
    final p = Uri.encodeComponent(filePath);
    return '$baseUrl/stream?share=$s&path=$p';
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      if (req.uri.path == '/stream') {
        await _handleStream(req);
      } else {
        req.response..statusCode = 404..write('Not Found');
        await req.response.close();
      }
    } catch (e) {
      debugPrint('Proxy error: $e');
      try {
        req.response..statusCode = 500..write('Error: $e');
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleStream(HttpRequest req) async {
    final share = req.uri.queryParameters['share'];
    final path = req.uri.queryParameters['path'];
    if (share == null || path == null) {
      req.response..statusCode = 400..write('Missing params');
      await req.response.close();
      return;
    }

    final smb = SmbService.instance;
    if (!smb.isConnected) {
      req.response..statusCode = 503..write('SMB not connected');
      await req.response.close();
      return;
    }

    final cacheKey = '$share/$path';
    if (!_fileSizeCache.containsKey(cacheKey)) {
      _fileSizeCache[cacheKey] = await smb.getFileSize(share, path);
    }
    final fileSize = _fileSizeCache[cacheKey]!;
    final rangeHeader = req.headers.value('range');
    int? start;
    int? end;

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final parts = rangeHeader.substring(6).split('-');
      start = int.tryParse(parts[0]);
      if (parts.length > 1 && parts[1].isNotEmpty) end = int.tryParse(parts[1]);
    }

    final mime = _mime(path);

    if (start != null) {
      final e = end ?? (fileSize - 1);
      final len = e - start + 1;
      req.response
        ..statusCode = 206
        ..headers.set('Content-Range', 'bytes $start-$e/$fileSize')
        ..headers.set('Content-Length', len.toString())
        ..headers.set('Accept-Ranges', 'bytes')
        ..headers.set('Content-Type', mime);
      final stream = await smb.readFileStream(share, path, offset: start, length: len);
      await req.response.addStream(stream);
    } else {
      req.response
        ..statusCode = 200
        ..headers.set('Content-Length', fileSize.toString())
        ..headers.set('Accept-Ranges', 'bytes')
        ..headers.set('Content-Type', mime);
      final stream = await smb.readFileStream(share, path);
      await req.response.addStream(stream);
    }
    await req.response.close();
  }

  String _mime(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'flac' => 'audio/flac',
      'mp3' => 'audio/mpeg',
      'aac' || 'm4a' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'mkv' => 'video/x-matroska',
      'mp4' => 'video/mp4',
      'avi' => 'video/x-msvideo',
      'webm' => 'video/webm',
      _ => 'application/octet-stream',
    };
  }
}
