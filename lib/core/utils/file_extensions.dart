/// File extension helpers for categorizing media files.
class FileExtensions {
  FileExtensions._();

  static const audioExtensions = {
    '.flac',
    '.alac',
    '.mp3',
    '.aac',
    '.m4a',
    '.wav',
    '.ogg',
    '.opus',
    '.wma',
    '.aiff',
  };

  static const videoExtensions = {
    '.mkv',
    '.mp4',
    '.avi',
    '.mov',
    '.wmv',
    '.flv',
    '.webm',
    '.m4v',
    '.ts',
    '.mpg',
    '.mpeg',
  };

  static const hiFiAudioExtensions = {
    '.flac',
    '.alac',
    '.wav',
    '.aiff',
  };

  static bool isAudio(String filename) {
    final ext = _getExtension(filename);
    return audioExtensions.contains(ext);
  }

  static bool isVideo(String filename) {
    final ext = _getExtension(filename);
    return videoExtensions.contains(ext);
  }

  static bool isHiFiAudio(String filename) {
    final ext = _getExtension(filename);
    return hiFiAudioExtensions.contains(ext);
  }

  static bool isMedia(String filename) => isAudio(filename) || isVideo(filename);

  static String _getExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filename.substring(lastDot).toLowerCase();
  }

  static String getFormatBadge(String filename) {
    final ext = _getExtension(filename);
    return ext.replaceFirst('.', '').toUpperCase();
  }
}
