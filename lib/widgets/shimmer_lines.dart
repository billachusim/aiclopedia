import 'package:flutter/material.dart';

/// Lightweight pulsing placeholder lines shown while an answer loads.
class ShimmerLines extends StatefulWidget {
  final int lines;
  const ShimmerLines({super.key, this.lines = 2});

  @override
  State<ShimmerLines> createState() => _ShimmerLinesState();
}

class _ShimmerLinesState extends State<ShimmerLines>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final alpha = 0.06 + 0.08 * _controller.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(widget.lines, (i) {
            final widthFactor = i == widget.lines - 1 ? 0.6 : 1.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: base.withValues(alpha: alpha),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
