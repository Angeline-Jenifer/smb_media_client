import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../services/smb_service.dart';

class FlacMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final String? lyrics;
  final String? albumArtUrl;

  FlacMetadata({
    this.title,
    this.artist,
    this.album,
    this.lyrics,
    this.albumArtUrl,
  });
}


class FlacMetadataExtractor {
  static Future<FlacMetadata?> extractFromSmb(String share, String filePath) async {
    if (!filePath.toLowerCase().endsWith('.flac')) {
      return null;
    }

    RandomAccessFile? raf;
    try {
      raf = await SmbService.instance.openMetadataFile(share, filePath) as RandomAccessFile;

      final headBytes = await raf.read(4);
      if (headBytes.length < 4 || ascii.decode(headBytes) != 'fLaC') {
        return null; 
      }

      String? title;
      String? artist;
      String? album;
      String? lyrics;
      String? albumArtPath;
      bool isLast = false;
      int blockCount = 0;

      while (!isLast && blockCount < 10) { 
        final headerBytes = await raf.read(4);
        if (headerBytes.length < 4) break;

        final flags = headerBytes[0];
        isLast = (flags & 0x80) != 0;
        final type = flags & 0x7F;
        final length = (headerBytes[1] << 16) | (headerBytes[2] << 8) | headerBytes[3];

        if (type == 4) { 
          final dataBytes = await raf.read(length);

          if (dataBytes.length == length) {
            final tags = await compute(_parseVorbisBlock, dataBytes);
            if (tags != null) {
              if (tags.containsKey('TITLE')) title = tags['TITLE'];
              if (tags.containsKey('ARTIST')) artist = tags['ARTIST'];
              if (tags.containsKey('ALBUM')) album = tags['ALBUM'];
              if (tags.containsKey('LYRICS')) lyrics = tags['LYRICS'];
            }
          }
        } else if (type == 6) { 
          final dataBytes = await raf.read(length);

          if (dataBytes.length == length) {
            final tempDir = await getTemporaryDirectory();
            final safeName = filePath.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
            final outPath = '${tempDir.path}/art_$safeName.jpg';
            
            final successPath = await compute(_parsePictureBlock, {
              'data': dataBytes,
              'outPath': outPath,
            });
            
            if (successPath != null) {
              albumArtPath = 'file://$successPath';
            }
          }
        } else {
    
          await raf.read(length);
        }

        blockCount++;
      }

      if (title != null || artist != null || album != null || lyrics != null || albumArtPath != null) {
        return FlacMetadata(
          title: title,
          artist: artist,
          album: album,
          lyrics: lyrics,
          albumArtUrl: albumArtPath,
        );
      }
      return null;
    } catch (e) {
      return null;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  static Future<FlacMetadata?> extractFromDrive(String fileId, String fileName, Map<String, String> authHeaders) async {
    if (!fileName.toLowerCase().endsWith('.flac')) {
      return null;
    }

    try {
      final url = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media');
      final response = await http.get(url, headers: {
        ...authHeaders,
        'Range': 'bytes=0-4000000', 
      });

      if (response.statusCode != 200 && response.statusCode != 206) {
        return null;
      }

      final bytes = response.bodyBytes;
      int offset = 0;

      if (bytes.length < 4) return null;
      final headBytes = bytes.sublist(0, 4);
      if (ascii.decode(headBytes) != 'fLaC') return null;
      offset += 4;

      String? title;
      String? artist;
      String? album;
      String? lyrics;
      String? albumArtPath;
      bool isLast = false;
      int blockCount = 0;

      while (!isLast && blockCount < 10 && offset + 4 <= bytes.length) {
        final headerBytes = bytes.sublist(offset, offset + 4);
        offset += 4;

        final flags = headerBytes[0];
        isLast = (flags & 0x80) != 0;
        final type = flags & 0x7F;
        final length = (headerBytes[1] << 16) | (headerBytes[2] << 8) | headerBytes[3];

        if (offset + length > bytes.length) {
          break; 
        }

        if (type == 4) { 
          final dataBytes = bytes.sublist(offset, offset + length);
          final tags = await compute(_parseVorbisBlock, dataBytes);
          if (tags != null) {
            if (tags.containsKey('TITLE')) title = tags['TITLE'];
            if (tags.containsKey('ARTIST')) artist = tags['ARTIST'];
            if (tags.containsKey('ALBUM')) album = tags['ALBUM'];
            if (tags.containsKey('LYRICS')) lyrics = tags['LYRICS'];
          }
        } else if (type == 6) { 
          final dataBytes = bytes.sublist(offset, offset + length);
          final tempDir = await getTemporaryDirectory();
          final safeName = fileId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          final outPath = '${tempDir.path}/art_$safeName.jpg';

          final successPath = await compute(_parsePictureBlock, {
            'data': dataBytes,
            'outPath': outPath,
          });

          if (successPath != null) {
            albumArtPath = 'file://$successPath';
          }
        }

        offset += length;
        blockCount++;
      }

      if (title != null || artist != null || album != null || lyrics != null || albumArtPath != null) {
        return FlacMetadata(
          title: title,
          artist: artist,
          album: album,
          lyrics: lyrics,
          albumArtUrl: albumArtPath,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Map<String, String>? _parseVorbisBlock(Uint8List dataBytes) {
    try {
      final length = dataBytes.length;
      int pos = 0;
      if (pos + 4 <= length) {
        int vendorLen = dataBytes[pos] |
            (dataBytes[pos + 1] << 8) |
            (dataBytes[pos + 2] << 16) |
            (dataBytes[pos + 3] << 24);
        pos += 4 + vendorLen;

        if (pos + 4 <= length) {
          int commentListLen = dataBytes[pos] |
              (dataBytes[pos + 1] << 8) |
              (dataBytes[pos + 2] << 16) |
              (dataBytes[pos + 3] << 24);
          pos += 4;

          final tags = <String, String>{};
          for (int i = 0; i < commentListLen; i++) {
            if (pos + 4 > length) break;
            int commentLen = dataBytes[pos] |
                (dataBytes[pos + 1] << 8) |
                (dataBytes[pos + 2] << 16) |
                (dataBytes[pos + 3] << 24);
            pos += 4;
            if (pos + commentLen > length) break;
            
            final comment = utf8.decode(
              dataBytes.sublist(pos, pos + commentLen),
              allowMalformed: true,
            );
            pos += commentLen;

            final eqIdx = comment.indexOf('=');
            if (eqIdx != -1) {
              final key = comment.substring(0, eqIdx).toUpperCase();
              final val = comment.substring(eqIdx + 1);
              tags[key] = val;
            }
          }
          return tags;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _parsePictureBlock(Map<String, dynamic> args) async {
    try {
      final Uint8List dataBytes = args['data'];
      final String outPath = args['outPath'];
      final length = dataBytes.length;

      int pos = 0;
      pos += 4; 

      if (pos + 4 <= length) {
        int mimeLen = (dataBytes[pos] << 24) |
            (dataBytes[pos + 1] << 16) |
            (dataBytes[pos + 2] << 8) |
            dataBytes[pos + 3];
        pos += 4 + mimeLen;

        if (pos + 4 <= length) {
          int descLen = (dataBytes[pos] << 24) |
              (dataBytes[pos + 1] << 16) |
              (dataBytes[pos + 2] << 8) |
              dataBytes[pos + 3];
          pos += 4 + descLen;

          pos += 16; 

          if (pos + 4 <= length) {
            int picLen = (dataBytes[pos] << 24) |
                (dataBytes[pos + 1] << 16) |
                (dataBytes[pos + 2] << 8) |
                dataBytes[pos + 3];
            pos += 4;

            if (pos + picLen <= length) {
              final imgBytes = dataBytes.sublist(pos, pos + picLen);
              final file = File(outPath);
              await file.writeAsBytes(imgBytes);
              return outPath;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
