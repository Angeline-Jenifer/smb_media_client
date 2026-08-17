import 'dart:typed_data';

Uint8List? _extractOpusTagsPacket(Uint8List bytes) {
    int pos = 0;
    int? opusSerial;
    List<int> tagsPacketBytes = [];
    bool assemblingTags = false;

    while (pos + 27 <= bytes.length) {
      if (bytes[pos] == 0x4F && bytes[pos + 1] == 0x67 && bytes[pos + 2] == 0x67 && bytes[pos + 3] == 0x53) {
        int serial = (bytes[pos + 14]) | (bytes[pos + 15] << 8) | (bytes[pos + 16] << 16) | (bytes[pos + 17] << 24);
        int pageSegments = bytes[pos + 26];

        if (pos + 27 + pageSegments > bytes.length) break;

        List<int> segmentLengths = [];
        for (int i = 0; i < pageSegments; i++) {
          segmentLengths.add(bytes[pos + 27 + i]);
        }

        int dataPos = pos + 27 + pageSegments;
        int currentSegmentIdx = 0;
        
        while (currentSegmentIdx < pageSegments) {
          int packetLength = 0;
          bool packetContinues = false;
          
          while (currentSegmentIdx < pageSegments) {
            int segLen = segmentLengths[currentSegmentIdx];
            packetLength += segLen;
            currentSegmentIdx++;
            if (segLen < 255) {
              packetContinues = false;
              break;
            } else if (currentSegmentIdx == pageSegments) {
              packetContinues = true;
              break;
            }
          }

          if (dataPos + packetLength > bytes.length) return null; 

          Uint8List packetData = bytes.sublist(dataPos, dataPos + packetLength);
          dataPos += packetLength;

          if (!assemblingTags) {
             if (packetData.length >= 8 && 
                 packetData[0] == 0x4F && packetData[1] == 0x70 && packetData[2] == 0x75 && packetData[3] == 0x73 &&
                 packetData[4] == 0x54 && packetData[5] == 0x61 && packetData[6] == 0x67 && packetData[7] == 0x73) {
                opusSerial = serial;
                assemblingTags = true;
                tagsPacketBytes.addAll(packetData);
             }
          } else {
             if (serial == opusSerial) {
                tagsPacketBytes.addAll(packetData);
             }
          }
          
          if (assemblingTags && !packetContinues) {
            return Uint8List.fromList(tagsPacketBytes); 
          }
        }
        pos = dataPos;
      } else {
        int nextOggs = -1;
        for (int i = pos + 1; i <= bytes.length - 4; i++) {
          if (bytes[i] == 0x4F && bytes[i + 1] == 0x67 && bytes[i + 2] == 0x67 && bytes[i + 3] == 0x53) {
            nextOggs = i;
            break;
          }
        }
        if (nextOggs != -1) {
          pos = nextOggs;
        } else {
          break;
        }
      }
    }
    
    if (tagsPacketBytes.isNotEmpty) {
       return Uint8List.fromList(tagsPacketBytes);
    }
    return null;
}

void main() {
  List<int> stream = [];
  
  // Page 1: 3 segments. Seg 1 = OpusHead (19 bytes), Seg 2 = OpusTags (255 bytes), Seg 3 = OpusTags (50 bytes)
  stream.addAll([0x4F, 0x67, 0x67, 0x53]); // OggS
  stream.addAll([0, 2, 0,0,0,0,0,0,0,0]); 
  stream.addAll([0x12, 0x34, 0x56, 0x78]); 
  stream.addAll([0,0,0,0]); 
  stream.addAll([0,0,0,0]); 
  stream.addAll([3]); // 3 segments
  stream.addAll([19, 255, 50]); 
  
  stream.addAll(List.filled(19, 0)); // OpusHead
  
  List<int> tagsData1 = [0x4F, 0x70, 0x75, 0x73, 0x54, 0x61, 0x67, 0x73]; // OpusTags
  tagsData1.addAll(List.filled(255 - 8, 1));
  stream.addAll(tagsData1);
  
  List<int> tagsData2 = List.filled(50, 2);
  stream.addAll(tagsData2);
  
  Uint8List? result = _extractOpusTagsPacket(Uint8List.fromList(stream));
  if (result != null) {
    print("Extracted length: ${result.length}");
    print("Expected length: 305");
  } else {
    print("Failed to extract");
  }
}
