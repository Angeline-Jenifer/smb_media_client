import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../services/smb_service.dart';

class OpusMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final String? lyrics;
  final String? albumArtUrl;

  OpusMetadata({
    this.title,
    this.artist,
    this.album,
    this.lyrics,
    this.albumArtUrl,
  });
}

/// Extracts metadata (tags + cover art) from Ogg Opus files.
///
/// Ogg Opus stores metadata in an "OpusTags" page (the second Ogg page),
/// which contains Vorbis Comments. Cover art is base64-encoded inside a
/// METADATA_BLOCK_PICTURE vorbis comment field.
class OpusMetadataExtractor {
  static const _opusExtensions = ['.opus', '.ogg'];

  static bool _isOpusFile(String fileName) {
    final lower = fileName.toLowerCase();
    return _opusExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Extract metadata from an Opus file on an SMB share.
  static Future<OpusMetadata?> extractFromSmb(String share, String filePath) async {
    if (!_isOpusFile(filePath)) return null;

    debugPrint('[OpusExtractor] extractFromSmb: share=$share path=$filePath');

    RandomAccessFile? raf;
    try {
      raf = await SmbService.instance.openMetadataFile(share, filePath) as RandomAccessFile;
      debugPrint('[OpusExtractor] SMB file opened successfully');

      // Read in chunks to handle SMB network I/O limitations.
      // First read a small header to verify it's an Ogg file,
      // then read more for metadata.
      final headerCheck = await raf.read(4);
      if (headerCheck.length < 4 ||
          headerCheck[0] != 0x4F || // O
          headerCheck[1] != 0x67 || // g
          headerCheck[2] != 0x67 || // g
          headerCheck[3] != 0x53) { // S
        debugPrint('[OpusExtractor] Not an OGG file (bad magic: ${headerCheck.length >= 4 ? headerCheck.sublist(0, 4) : headerCheck})');
        return null;
      }

      // Seek back to start and read a larger chunk for full metadata
      await raf.setPosition(0);

      // Read in 512KB chunks, up to 4MB total
      final chunks = <Uint8List>[];
      int totalRead = 0;
      const maxBytes = 4 * 1024 * 1024;
      const chunkSize = 512 * 1024;

      while (totalRead < maxBytes) {
        final chunk = await raf.read(chunkSize);
        if (chunk.isEmpty) break;
        chunks.add(chunk);
        totalRead += chunk.length;
        if (chunk.length < chunkSize) break; // EOF
      }

      debugPrint('[OpusExtractor] Read $totalRead bytes in ${chunks.length} chunks');

      if (totalRead < 47) {
        debugPrint('[OpusExtractor] File too small');
        return null;
      }

      // Concatenate chunks
      final bytes = Uint8List(totalRead);
      int offset = 0;
      for (final chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Get temp dir on main isolate (platform channels don't work in compute)
      final tempDir = await getTemporaryDirectory();
      final safeName = filePath.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final artOutPath = '${tempDir.path}/art_opus_$safeName.jpg';

      debugPrint('[OpusExtractor] Parsing ${bytes.length} bytes, artOutPath=$artOutPath');

      final result = await compute(_parseOggOpus, {
        'data': bytes,
        'artOutPath': artOutPath,
      });

      debugPrint('[OpusExtractor] Result: title=${result?.title}, artist=${result?.artist}, hasArt=${result?.albumArtUrl != null}');
      return result;
    } catch (e, st) {
      debugPrint('[OpusExtractor] extractFromSmb ERROR: $e');
      debugPrint('[OpusExtractor] Stack: $st');
      return null;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  /// Extract metadata from an Opus file on Google Drive.
  static Future<OpusMetadata?> extractFromDrive(
    String fileId,
    String fileName,
    Map<String, String> authHeaders,
  ) async {
    if (!_isOpusFile(fileName)) return null;

    debugPrint('[OpusExtractor] extractFromDrive: fileId=$fileId name=$fileName');

    try {
      final url = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media');
      final response = await http.get(url, headers: {
        ...authHeaders,
        'Range': 'bytes=0-4000000',
      });

      debugPrint('[OpusExtractor] Drive response: ${response.statusCode}, ${response.bodyBytes.length} bytes');

      if (response.statusCode != 200 && response.statusCode != 206) {
        return null;
      }

      // Get temp dir on main isolate
      final tempDir = await getTemporaryDirectory();
      final safeName = fileId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final artOutPath = '${tempDir.path}/art_opus_$safeName.jpg';

      final result = await compute(_parseOggOpus, {
        'data': response.bodyBytes,
        'artOutPath': artOutPath,
      });

      debugPrint('[OpusExtractor] Drive result: title=${result?.title}, artist=${result?.artist}, hasArt=${result?.albumArtUrl != null}');
      return result;
    } catch (e, st) {
      debugPrint('[OpusExtractor] extractFromDrive ERROR: $e');
      debugPrint('[OpusExtractor] Stack: $st');
      return null;
    }
  }

  /// Top-level isolate function that parses Ogg pages to find OpusTags,
  /// then extracts Vorbis Comments and cover art.
  ///
  /// IMPORTANT: No platform channel calls (like getTemporaryDirectory)
  /// are allowed here — all paths must be passed in via args.
  static OpusMetadata? _parseOggOpus(Map<String, dynamic> args) {
    final Uint8List data = args['data'];
    final String artOutPath = args['artOutPath'];

    try {
      // Collect all segment data from OpusTags pages.
      final tagsPayload = _extractOpusTagsPayload(data);
      if (tagsPayload == null || tagsPayload.isEmpty) {
        // ignore: avoid_print
        print('[OpusExtractor:isolate] No OpusTags payload found');
        return null;
      }
      // ignore: avoid_print
      print('[OpusExtractor:isolate] OpusTags payload: ${tagsPayload.length} bytes');

      final tags = _parseVorbisComments(tagsPayload);
      if (tags == null) {
        // ignore: avoid_print
        print('[OpusExtractor:isolate] Failed to parse Vorbis comments');
        return null;
      }

      // ignore: avoid_print
      print('[OpusExtractor:isolate] Found ${tags.length} tags: ${tags.keys.toList()}');

      String? albumArtPath;

      // Check for METADATA_BLOCK_PICTURE (base64-encoded FLAC picture block)
      final pictureB64 = tags['METADATA_BLOCK_PICTURE'];
      if (pictureB64 != null && pictureB64.isNotEmpty) {
        // ignore: avoid_print
        print('[OpusExtractor:isolate] METADATA_BLOCK_PICTURE found, b64 length: ${pictureB64.length}');
        try {
          final pictureBytes = base64.decode(pictureB64);
          // ignore: avoid_print
          print('[OpusExtractor:isolate] Decoded picture bytes: ${pictureBytes.length}');
          final savedPath = _extractPictureData(pictureBytes, artOutPath);
          if (savedPath != null) {
            albumArtPath = 'file://$savedPath';
            // ignore: avoid_print
            print('[OpusExtractor:isolate] Cover art saved to: $savedPath');
          } else {
            // ignore: avoid_print
            print('[OpusExtractor:isolate] _extractPictureData returned null');
          }
        } catch (e) {
          // ignore: avoid_print
          print('[OpusExtractor:isolate] METADATA_BLOCK_PICTURE decode error: $e');
        }
      }

      // Also check for the non-standard COVERART tag (raw base64 image)
      if (albumArtPath == null) {
        final coverArt = tags['COVERART'];
        if (coverArt != null && coverArt.isNotEmpty) {
          // ignore: avoid_print
          print('[OpusExtractor:isolate] COVERART tag found, b64 length: ${coverArt.length}');
          try {
            final imgBytes = base64.decode(coverArt);
            final file = File(artOutPath);
            file.writeAsBytesSync(imgBytes);
            albumArtPath = 'file://$artOutPath';
          } catch (e) {
            // ignore: avoid_print
            print('[OpusExtractor:isolate] COVERART decode error: $e');
          }
        }
      }

      final title = tags['TITLE'];
      final artist = tags['ARTIST'];
      final album = tags['ALBUM'];
      final lyrics = tags['LYRICS'] ?? tags['UNSYNCEDLYRICS'];

      if (title != null || artist != null || album != null || lyrics != null || albumArtPath != null) {
        return OpusMetadata(
          title: title,
          artist: artist,
          album: album,
          lyrics: lyrics,
          albumArtUrl: albumArtPath,
        );
      }
      // ignore: avoid_print
      print('[OpusExtractor:isolate] No useful metadata found in tags');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[OpusExtractor:isolate] _parseOggOpus ERROR: $e');
      return null;
    }
  }

  /// Walks Ogg pages to collect the payload of the OpusTags header.
  /// Returns the concatenated segment data from all OpusTags pages,
  /// or null if not found.
  static Uint8List? _extractOpusTagsPayload(Uint8List data) {
    int offset = 0;
    bool foundOpusTags = false;
    final segments = <Uint8List>[];
    int pageCount = 0;

    while (offset + 27 <= data.length) {
      // Each Ogg page starts with "OggS"
      if (data[offset] != 0x4F || // O
          data[offset + 1] != 0x67 || // g
          data[offset + 2] != 0x67 || // g
          data[offset + 3] != 0x53) { // S
        // ignore: avoid_print
        print('[OpusExtractor:isolate] Page $pageCount: bad OggS magic at offset $offset');
        break;
      }

      // Byte 5 = header type flag
      final headerType = data[offset + 5];
      // Byte 26 = number of page segments
      final numSegments = data[offset + 26];

      if (offset + 27 + numSegments > data.length) break;

      // Read the segment table to compute total payload size
      int payloadSize = 0;
      for (int i = 0; i < numSegments; i++) {
        payloadSize += data[offset + 27 + i];
      }

      final payloadStart = offset + 27 + numSegments;
      if (payloadStart + payloadSize > data.length) break;

      // ignore: avoid_print
      print('[OpusExtractor:isolate] Page $pageCount: headerType=0x${headerType.toRadixString(16)}, '
          'segments=$numSegments, payloadSize=$payloadSize, payloadStart=$payloadStart');

      if (!foundOpusTags) {
        // Check if this page's payload starts with "OpusTags"
        if (payloadSize >= 8) {
          final magic = String.fromCharCodes(data.sublist(payloadStart, payloadStart + 8));
          // ignore: avoid_print
          print('[OpusExtractor:isolate] Page $pageCount magic: "$magic"');

          if (magic == 'OpusTags') {
            foundOpusTags = true;
            segments.add(Uint8List.sublistView(data, payloadStart + 8, payloadStart + payloadSize));
            // ignore: avoid_print
            print('[OpusExtractor:isolate] Found OpusTags! payload=${payloadSize - 8} bytes');

            // Check if this page's segments indicate continuation
            // (last segment value == 255 means packet continues on next page)
            final lastSegmentVal = data[offset + 27 + numSegments - 1];
            if (lastSegmentVal != 255) {
              // Packet is complete, no continuation needed
              // ignore: avoid_print
              print('[OpusExtractor:isolate] OpusTags complete in single page');
              break;
            }
          }
        }
      } else {
        // Continuation page for OpusTags
        if ((headerType & 0x01) != 0) {
          segments.add(Uint8List.sublistView(data, payloadStart, payloadStart + payloadSize));
          // ignore: avoid_print
          print('[OpusExtractor:isolate] Continuation page: +$payloadSize bytes');

          // Check if this is the last continuation page
          final lastSegmentVal = data[offset + 27 + numSegments - 1];
          if (lastSegmentVal != 255) {
            // ignore: avoid_print
            print('[OpusExtractor:isolate] OpusTags continuation complete');
            break;
          }
        } else {
          break;
        }
      }

      offset = payloadStart + payloadSize;
      pageCount++;

      // Safety: don't iterate more than 100 pages
      if (pageCount > 100) break;
    }

    if (segments.isEmpty) return null;

    if (segments.length == 1) return segments.first;
    final totalLen = segments.fold<int>(0, (sum, s) => sum + s.length);
    final result = Uint8List(totalLen);
    int pos = 0;
    for (final seg in segments) {
      result.setRange(pos, pos + seg.length, seg);
      pos += seg.length;
    }
    return result;
  }

  /// Parses Vorbis Comments from the raw payload (after "OpusTags" prefix).
  /// Format: vendor_length(4 LE) + vendor_string + comment_count(4 LE) + comments
  static Map<String, String>? _parseVorbisComments(Uint8List data) {
    try {
      final length = data.length;
      int pos = 0;

      // Vendor string length (little-endian 32-bit)
      if (pos + 4 > length) return null;
      int vendorLen = data[pos] |
          (data[pos + 1] << 8) |
          (data[pos + 2] << 16) |
          (data[pos + 3] << 24);
      pos += 4;
      if (vendorLen < 0 || pos + vendorLen > length) return null;
      
      final vendorString = utf8.decode(data.sublist(pos, pos + vendorLen), allowMalformed: true);
      // ignore: avoid_print
      print('[OpusExtractor:isolate] Vendor: "$vendorString"');
      pos += vendorLen;

      // Comment count (little-endian 32-bit)
      if (pos + 4 > length) return null;
      int commentCount = data[pos] |
          (data[pos + 1] << 8) |
          (data[pos + 2] << 16) |
          (data[pos + 3] << 24);
      pos += 4;

      // ignore: avoid_print
      print('[OpusExtractor:isolate] Comment count: $commentCount');

      if (commentCount < 0 || commentCount > 10000) return null;

      final tags = <String, String>{};
      for (int i = 0; i < commentCount; i++) {
        if (pos + 4 > length) break;
        int commentLen = data[pos] |
            (data[pos + 1] << 8) |
            (data[pos + 2] << 16) |
            (data[pos + 3] << 24);
        pos += 4;
        if (commentLen < 0 || pos + commentLen > length) break;

        final comment = utf8.decode(
          data.sublist(pos, pos + commentLen),
          allowMalformed: true,
        );
        pos += commentLen;

        final eqIdx = comment.indexOf('=');
        if (eqIdx != -1) {
          final key = comment.substring(0, eqIdx).toUpperCase();
          final val = comment.substring(eqIdx + 1);
          // Don't print base64 values (too large)
          final displayVal = val.length > 100 ? '${val.substring(0, 50)}... (${val.length} chars)' : val;
          // ignore: avoid_print
          print('[OpusExtractor:isolate] Tag[$i]: $key = $displayVal');
          tags[key] = val;
        }
      }
      return tags.isNotEmpty ? tags : null;
    } catch (e) {
      // ignore: avoid_print
      print('[OpusExtractor:isolate] _parseVorbisComments ERROR: $e');
      return null;
    }
  }

  /// Extracts the raw image bytes from a METADATA_BLOCK_PICTURE binary payload.
  /// Same structure as FLAC PICTURE block (big-endian integers).
  static String? _extractPictureData(Uint8List data, String outPath) {
    try {
      final length = data.length;
      int pos = 0;

      // Picture type (4 bytes, big-endian) — skip
      if (pos + 4 > length) return null;
      pos += 4;

      // MIME type length + string
      if (pos + 4 > length) return null;
      int mimeLen = (data[pos] << 24) |
          (data[pos + 1] << 16) |
          (data[pos + 2] << 8) |
          data[pos + 3];
      pos += 4;
      if (mimeLen < 0 || pos + mimeLen > length) return null;

      final mimeType = utf8.decode(data.sublist(pos, pos + mimeLen), allowMalformed: true);
      // ignore: avoid_print
      print('[OpusExtractor:isolate] Picture MIME: $mimeType');
      pos += mimeLen;

      // Description length + string
      if (pos + 4 > length) return null;
      int descLen = (data[pos] << 24) |
          (data[pos + 1] << 16) |
          (data[pos + 2] << 8) |
          data[pos + 3];
      pos += 4;
      if (descLen < 0 || pos + descLen > length) return null;
      pos += descLen;

      // Width(4) + Height(4) + ColorDepth(4) + IndexedColors(4) = 16 bytes
      if (pos + 16 > length) return null;
      pos += 16;

      // Image data length
      if (pos + 4 > length) return null;
      int picLen = (data[pos] << 24) |
          (data[pos + 1] << 16) |
          (data[pos + 2] << 8) |
          data[pos + 3];
      pos += 4;

      // ignore: avoid_print
      print('[OpusExtractor:isolate] Picture data: $picLen bytes at offset $pos');

      if (picLen <= 0 || pos + picLen > length) return null;
      final imgBytes = data.sublist(pos, pos + picLen);
      final file = File(outPath);
      file.writeAsBytesSync(imgBytes);
      return outPath;
    } catch (e) {
      // ignore: avoid_print
      print('[OpusExtractor:isolate] _extractPictureData ERROR: $e');
      return null;
    }
  }
}
