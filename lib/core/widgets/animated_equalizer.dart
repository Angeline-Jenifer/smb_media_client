import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A sleek, animated audio equalizer visualizer with 3 or 4 pulsing bars.
class AnimatedEqualizer extends StatefulWidget {
  final Color color;
  final double size;
  final int barCount;
  final bool isPlaying;

  const AnimatedEqualizer({
    super.key,
    required this.color,
    this.size = 20,
    this.barCount = 3,
    this.isPlaying = true,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.size;
    final height = widget.size;
    final barWidth = math.max(2.0, (width - (widget.barCount - 1) * 2.5) / widget.barCount);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: width,
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (index) {
              final phaseOffset = (index * 0.35);
              final progress = (_controller.value + phaseOffset) % 1.0;
              
              // Smooth sine-based height modulation
              final factor = widget.isPlaying
                  ? 0.25 + 0.75 * math.sin(progress * math.pi * 2).abs()
                  : 0.25;

              return Container(
                width: barWidth,
                height: math.max(3.0, height * factor),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(barWidth / 2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
