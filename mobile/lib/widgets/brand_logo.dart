import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config.dart';

/// 쩌렁쩌렁 심볼 — 음성 파형(이퀄라이저) 막대.
/// animate=true 면 막대가 계속 사인파로 진동(스플래시 등).
/// tapToAnimate=true 면 평소엔 정지, 탭하면 잠깐 진동 후 다시 멈춘다.
class BrandLogo extends StatefulWidget {
  final double size;
  final bool animate;
  final bool tapToAnimate;
  final bool badge; // 다크 라운드 배경 포함 여부
  final Color barColor;
  final Color badgeColor;

  const BrandLogo({
    super.key,
    this.size = 40,
    this.animate = false,
    this.tapToAnimate = false,
    this.badge = true,
    this.barColor = AppColors.gold,
    this.badgeColor = AppColors.ink,
  });

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  // 진동 진폭 0→1. 시작 순간엔 0이라 정적 패턴(네이티브 스플래시)과 모양이 같고,
  // 부드럽게 커지면서 막대가 진동하기 시작한다.
  late final AnimationController _amp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  Timer? _burstTimer;

  @override
  void initState() {
    super.initState();
    _amp.addStatusListener(_onAmp);
    if (widget.animate) {
      _start();
    } else if (widget.tapToAnimate) {
      // 화면 진입 시 한 번 인사하듯 재생(계속 X) → 이후엔 탭할 때만
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _burst();
      });
    }
  }

  void _start() {
    _c.repeat();
    // 잠깐 정적 모양을 유지(네이티브 스플래시와 동일) → 진폭을 서서히 키움
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _amp.forward();
    });
  }

  // 탭 한 번 → 잠깐 진동했다가 부드럽게 멈춤
  void _burst() {
    _burstTimer?.cancel();
    if (!_c.isAnimating) _c.repeat();
    _amp.forward(from: 0);
    _burstTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) _amp.reverse(); // 진폭을 0으로 되돌려 정적으로 안착
    });
  }

  void _onAmp(AnimationStatus s) {
    // 버스트가 끝나(진폭 0 복귀) 정적이 되면 반복 컨트롤러 정지
    if (s == AnimationStatus.dismissed && !widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void didUpdateWidget(covariant BrandLogo old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _start();
    } else if (!widget.animate && !widget.tapToAnimate && _c.isAnimating) {
      _c.stop();
      _amp.reset();
    }
  }

  @override
  void dispose() {
    _burstTimer?.cancel();
    _amp.removeStatusListener(_onAmp);
    _c.dispose();
    _amp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 연속 진동이거나 탭 버스트로 컨트롤러가 도는 동안만 움직임 표시
    Widget child = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _amp]),
        builder: (_, _) {
          final live = widget.animate || _c.isAnimating;
          return CustomPaint(
            painter: _LogoPainter(
              t: live ? _c.value : -1,
              amp: live ? Curves.easeInOut.transform(_amp.value) : 0,
              badge: widget.badge,
              barColor: widget.barColor,
              badgeColor: widget.badgeColor,
            ),
          );
        },
      ),
    );
    if (widget.tapToAnimate) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _burst,
        child: child,
      );
    }
    return child;
  }
}

class _LogoPainter extends CustomPainter {
  final double t; // 0..1 진행도, -1 = 정적
  final double amp; // 진동 진폭 0..1 (0이면 정적 패턴과 동일)
  final bool badge;
  final Color barColor;
  final Color badgeColor;

  _LogoPainter({
    required this.t,
    required this.amp,
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
      if (t < 0 || amp <= 0) {
        ratio = ratios[i]; // 정적: 네이티브 스플래시 아이콘과 동일한 패턴
      } else {
        // 각 막대가 자기 정적 높이(ratios[i]) 주변에서 진동 → 시작 모양 유지
        final phase = i * 0.7;
        final osc = math.sin(t * 2 * math.pi + phase); // -1..1
        ratio = (ratios[i] + amp * 0.26 * osc).clamp(0.14, 1.0);
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
      old.amp != amp ||
      old.badge != badge ||
      old.barColor != barColor ||
      old.badgeColor != badgeColor;
}
