import 'package:flutter/material.dart';

/// 🔵 Point Radar Vivant : pulse et respire chaque seconde
class PulsingRadarDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingRadarDot({
    super.key,
    this.color = const Color(0xFF00D2FF),
    this.size = 10.0,
  });

  @override
  State<PulsingRadarDot> createState() => _PulsingRadarDotState();
}

class _PulsingRadarDotState extends State<PulsingRadarDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.30).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 3.0, end: 10.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final currentSize = widget.size * _scaleAnimation.value;
        return Container(
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.85),
                blurRadius: _glowAnimation.value,
                spreadRadius: (_scaleAnimation.value - 0.85) * 3,
              ),
            ],
          ),
        );
      },
    );
  }
}
