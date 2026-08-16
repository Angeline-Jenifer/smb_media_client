import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/animated_toggle.dart';
import '../../../providers/mode_provider.dart';
import '../../../providers/media_list_provider.dart';

class ModeToggle extends ConsumerWidget {
  const ModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeProvider);

    return AnimatedToggle(
      value: mode == AppMode.indoor,
      leftLabel: AppStrings.outdoorMode,
      rightLabel: AppStrings.indoorMode,
      leftIcon: Icons.cloud_outlined,
      rightIcon: Icons.wifi,
      onChanged: (isIndoor) async {
        final success = await ref.read(modeProvider.notifier).toggle();
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.errorNoWifi)),
          );
        } else {
          
          ref.read(mediaListProvider.notifier).fetchMedia();
        }
      },
    );
  }
}
