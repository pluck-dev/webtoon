import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config.dart';

/// 쩌렁쩌렁 심볼 — 음성 파형(이퀄라이저) 막대.
/// animate=true 면 막대가 사인파로 진동(라이브 더빙 느낌).
class BrandLogo extends StatefulWidget {
  final double size;
  final bool animate;
  final bool badge; // 다크 라운드 배경 포함 여부
  final Color barColor;
  final Color badgeColor;

  const BrandLogo({
    super.key,
    this.size = 40,
    this.animate = false,
    this.badge = true,
    this.barColor = AppColors.gold,
    this.badgeColor = AppColors.ink,
  });

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant BrandLogo old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _LogoPainter(
            t: widget.animate ? _c.value : -1,
            badge: widget.badge,
            barColor: widget.barColor,
            badgeColor: widget.badgeColor,
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double t; // 0..1 진행도, -1 = 정적
  final bool badge;
  final Color barColor;
  final Color badgeColor;

  _LogoPainter({
    required this.t,
    required this.badge,
    required this.barColor,
    required this.badgeColor,
  });

  static const _ratios = [0.42, 0.70, 1.0, 0.62, 0.5];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    if (badge) {
      final rect = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(s * 0.26),
      );
      canvas.drawRRect(rect, Paint()..color = badgeColor);
    }

    final area = badge ? 0.56 : 0.92;
    final maxh = badge ? 0.46 : 0.74;
    final ratios = _ratios;
    final n = ratios.length;
    final total = area * s;
    final w = total / (n * 1.8);
    final gap = (total - n * w) / (n - 1);
    final x0 = s / 2 - total / 2;
    final midy = s / 2;
    final paint = Paint()..color = barColor;

    for (var i = 0; i < n; i++) {
      double ratio;
      if (t < 0) {
        ratio = ratios[i]; // 정적: 아이콘과 동일한 패턴
      } else {
        final phase = i * 0.7;
        final osc = 0.5 + 0.5 * math.sin(t * 2 * math.pi + phase);
        ratio = 0.32 + 0.68 * osc; // 0.32~1.0 진동
      }
      final h = ratio * maxh * s;
      final x = x0 + i * (w + gap);
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, midy - h / 2, w, h),
        Radius.circular(w / 2),
      );
      canvas.drawRRect(rr, paint);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.t != t ||
      old.badge != badge ||
      old.barColor != barColor ||
      old.badgeColor != badgeColor;
}
