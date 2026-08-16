import "package:flutter_test/flutter_test.dart";
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:smb_connect/smb_connect.dart';

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

void debugPrint(String message) {
  print(message);
}

Future<void> main() async {
  final client = await SmbConnect.connectAuth(
    host: '192.168.1.7',
    domain: 'WORKGROUP',
    username: 'guest',
    password: '',
  );

  final shares = await client.listShares();
  for (var share in shares) {
    if (share.name.endsWith('\$')) continue;
    print('Checking share: ${share.name}');
    
    final folder = await client.file('/${share.name}');
    try {
        final entries = await client.listFiles(folder);
        for (var entry in entries) {
            if (entry.name.toLowerCase().endsWith('.flac')) {
                print('Found FLAC: ${entry.name}');
                
                final smbFile = await client.file('/${share.name}/${entry.name}');
                final raf = await client.open(smbFile);
                
                try {
                  final headBytes = await raf.read(4);
                  if (headBytes.length < 4 || ascii.decode(headBytes) != 'fLaC') {
                    print('Not a valid FLAC file (Header: ${headBytes.length})');
                    continue;
                  }
                  
                  bool isLast = false;
                  int blockCount = 0;
                  
                  while (!isLast && blockCount < 10) {
                    final headerBytes = await raf.read(4);
                    if (headerBytes.length < 4) break;
                    
                    final flags = headerBytes[0];
                    isLast = (flags & 0x80) != 0;
                    final type = flags & 0x7F;
                    final length = (headerBytes[1] << 16) | (headerBytes[2] << 8) | headerBytes[3];
                    
                    print('Block type: $type, length: $length, isLast: $isLast');
                    
                    if (type == 4) { // VORBIS_COMMENT
                      final dataBytes = await raf.read(length);
                      print('Read VORBIS_COMMENT of length ${dataBytes.length}');
                      
                      // Check little endian vendor string length
                      int pos = 0;
                      int vendorLen = dataBytes[pos] | (dataBytes[pos+1]<<8) | (dataBytes[pos+2]<<16) | (dataBytes[pos+3]<<24);
                      pos += 4 + vendorLen;
                      
                      int commentListLen = dataBytes[pos] | (dataBytes[pos+1]<<8) | (dataBytes[pos+2]<<16) | (dataBytes[pos+3]<<24);
                      pos += 4;
                      print('Vendor length: $vendorLen, Comments count: $commentListLen');
                    } else if (type == 6) { // PICTURE
                      final dataBytes = await raf.read(length);
                      print('Read PICTURE of length ${dataBytes.length}');
                    } else {
                      await raf.setPosition(await raf.position() + length);
                      print('Skipped block');
                    }
                    blockCount++;
                  }
                } finally {
                  await raf.close();
                }
            }
        }
    } catch(e) {
        print('Error in share ${share.name}: $e');
    }
  }
}
