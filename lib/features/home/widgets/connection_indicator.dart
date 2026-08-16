import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/mode_provider.dart';
import '../../../services/google_drive_service.dart';
import '../../../services/smb_service.dart';

class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeProvider);

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 3)),
      builder: (context, snapshot) {
        final isConnected = mode == AppMode.outdoor
            ? GoogleDriveService.instance.isSignedIn
            : SmbService.instance.isConnected;

        return Tooltip(
          message: isConnected ? 'Connected' : 'Offline',
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isConnected ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.15),
            ),
            child: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              size: 16,
              color: isConnected ? AppColors.success : AppColors.error,
            ),
          ),
        );
      },
    );
  }
}
