import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';

/// 모든 대사를 완성했을 때 1회 재생되는 축하 연출 (컨페티 + 메시지)
void showCelebration(BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Celebration(
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _Celebration extends StatefulWidget {
  final VoidCallback onDone;
  const _Celebration({required this.onDone});

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    const colors = [
      AppColors.gold,
      AppColors.coral,
      AppColors.teal,
      AppColors.paper,
    ];
    _particles = List.generate(28, (i) {
      final angle = (i / 28) * 2 * math.pi + rnd.nextDouble() * 0.5;
      return _Particle(
        angle: angle,
        speed: 0.5 + rnd.nextDouble() * 0.6,
        color: colors[rnd.nextInt(colors.length)],
        size: 7 + rnd.nextDouble() * 7,
        spin: rnd.nextDouble() * 6 - 3,
      );
    });
    _c.forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // 메시지: 0.05~0.35 등장, 0.8~1.0 퇴장
          final appear = ((t - 0.05) / 0.3).clamp(0.0, 1.0);
          final fade = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    t: t,
                    origin: Offset(size.width / 2, size.height * 0.42),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * Curves.easeOutBack.transform(appear),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.celebration_rounded, size: 40, color: Colors.white),
                          const SizedBox(height: 10),
                          Text(
                            '모든 장면을 더빙했어요!',
                            style: GoogleFonts.notoSansKr(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '이제 영상을 만들 수 있어요',
                            style: GoogleFonts.notoSansKr(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double spin;
  _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.spin,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final Offset origin;
  _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.origin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final reach = size.height * 0.55;
    for (final p in particles) {
      final dist = p.speed * reach * t;
      final gravity = 260 * t * t;
      final dx = origin.dx + math.cos(p.angle) * dist;
      final dy = origin.dy + math.sin(p.angle) * dist + gravity;
      final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * t * 2 * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
