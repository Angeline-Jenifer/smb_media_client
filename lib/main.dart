import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'audio/audio_provider.dart';
import 'audio/media_kit_audio_handler.dart';
import 'services/local_storage_service.dart';
import 'services/local_proxy_server.dart';
import 'services/google_drive_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('Failed to set high refresh rate: $e');
    }
  }

  // System UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize media_kit (required for libmpv)
  MediaKit.ensureInitialized();

  // Initialize local storage
  await LocalStorageService.init();

  // Restore Google login session silently if exists
  await GoogleDriveService.instance.signInSilently();

  // Initialize audio_service with our custom handler
  globalAudioHandler = await AudioService.init(
    builder: () => MediaKitAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.rexon.homeclient.audio',
      androidNotificationChannelName: 'HomeClient Audio',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: true,
    ),
  );

  // Start the local proxy server for SMB streaming
  await LocalProxyServer.instance.start();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
