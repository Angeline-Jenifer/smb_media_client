import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';


class AnimatedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String leftLabel;
  final String rightLabel;
  final IconData leftIcon;
  final IconData rightIcon;
  final bool enabled;

  const AnimatedToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.leftLabel = 'Outdoor',
    this.rightLabel = 'Indoor',
    this.leftIcon = Icons.cloud_outlined,
    this.rightIcon = Icons.wifi,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final onActiveColor = isDark ? AppColors.darkBackground : Colors.white;
    final inactiveColor = isDark ? Colors.white : AppColors.lightTextPrimary;

    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        width: 140,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: enabled
              ? activeColor.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          border: Border.all(
            color: enabled
                ? activeColor.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
          
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              left: value ? 70 : 0,
              top: 0,
              bottom: 0,
              width: 70,
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  color: activeColor,
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            leftIcon,
                            size: 14,
                            color: !value ? onActiveColor : (enabled ? inactiveColor : Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            leftLabel,
                            style: googleSansFlex(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: !value ? onActiveColor : (enabled ? inactiveColor : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            rightIcon,
                            size: 14,
                            color: value ? onActiveColor : (enabled ? inactiveColor : Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rightLabel,
                            style: googleSansFlex(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: value ? onActiveColor : (enabled ? inactiveColor : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
