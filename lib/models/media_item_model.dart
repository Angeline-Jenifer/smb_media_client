
class MediaItemModel {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? albumArtUrl;
  final String? lyrics;
  final Duration? duration;
  final String filePath;
  final String fileName;
  final MediaType type;
  final MediaSource source;
  final int? fileSize;
  final String? mimeType;

  final String sourceId;

  const MediaItemModel({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.albumArtUrl,
    this.lyrics,
    this.duration,
    required this.filePath,
    required this.fileName,
    required this.type,
    required this.source,
    this.fileSize,
    this.mimeType,
    required this.sourceId,
  });


  factory MediaItemModel.fromFileName({
    required String id,
    required String fileName,
    required String filePath,
    required MediaType type,
    required MediaSource source,
    required String sourceId,
    int? fileSize,
    String? mimeType,
  }) {

    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    String title = nameWithoutExt;
    String? artist;

    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      artist = parts[0].trim();
      title = parts.sublist(1).join(' - ').trim();
    }

    return MediaItemModel(
      id: id,
      title: title,
      artist: artist,
      filePath: filePath,
      fileName: fileName,
      type: type,
      source: source,
      sourceId: sourceId,
      fileSize: fileSize,
      mimeType: mimeType,
      lyrics: null,
    );
  }

  MediaItemModel copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtUrl,
    String? lyrics,
    Duration? duration,
  }) {
    return MediaItemModel(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      lyrics: lyrics ?? this.lyrics,
      duration: duration ?? this.duration,
      filePath: filePath,
      fileName: fileName,
      type: type,
      source: source,
      sourceId: sourceId,
      fileSize: fileSize,
      mimeType: mimeType,
    );
  }


  String get formattedSize {
    if (fileSize == null) return '';
    final bytes = fileSize!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtUrl': albumArtUrl,
        'lyrics': lyrics,
        'durationMs': duration?.inMilliseconds,
        'filePath': filePath,
        'fileName': fileName,
        'type': type.name,
        'source': source.name,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'sourceId': sourceId,
      };

  factory MediaItemModel.fromJson(Map<String, dynamic> json) {
    return MediaItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      albumArtUrl: json['albumArtUrl'] as String?,
      lyrics: json['lyrics'] as String?,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      filePath: (json['filePath'] as String?) ?? '',
      fileName: (json['fileName'] as String?) ?? '',
      type: MediaType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MediaType.audio,
      ),
      source: MediaSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => MediaSource.smb,
      ),
      fileSize: json['fileSize'] as int?,
      mimeType: json['mimeType'] as String?,
      sourceId: (json['sourceId'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItemModel && id == other.id && source == other.source;

  @override
  int get hashCode => id.hashCode ^ source.hashCode;
}

enum MediaType { audio, video }

enum MediaSource { googleDrive, smb }
