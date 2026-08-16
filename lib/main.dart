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


  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));


  MediaKit.ensureInitialized();


  await LocalStorageService.init();


  await GoogleDriveService.instance.signInSilently();


  globalAudioHandler = await AudioService.init(
    builder: () => MediaKitAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.rexon.homeclient.audio',
      androidNotificationChannelName: 'HomeClient Audio',
      androidNotificationOngoing: false,
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: true,
    ),
  );


  await LocalProxyServer.instance.start();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
