import 'package:flutter/material.dart';

/// 브랜드 전용 커스텀 벡터 아이콘 모음.
/// Material 기본 아이콘 대신 코드로 그린 벡터라 BrandLogo 와 톤이 일관되고,
/// outline(미선택)·filled(선택) 두 상태를 같은 실루엣으로 매끄럽게 전환한다.
enum BrandIconType { home, feed, library, profile, create }

class BrandIcon extends StatelessWidget {
  final BrandIconType type;
  final bool filled; // true = 채움(선택), false = 라인(미선택)
  final double size;
  final Color color;
  final double strokeWidth;

  const BrandIcon(
    this.type, {
    super.key,
    this.filled = false,
    this.size = 24,
    required this.color,
    this.strokeWidth = 1.9,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandIconPainter(type, filled, color, strokeWidth),
      ),
    );
  }
}

class _BrandIconPainter extends CustomPainter {
  final BrandIconType type;
  final bool filled;
  final Color color;
  final double strokeWidth;

  _BrandIconPainter(this.type, this.filled, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0; // viewBox 24
    canvas.save();
    canvas.scale(scale);

    final fill = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    switch (type) {
      case BrandIconType.home:
        _home(canvas, fill, line);
      case BrandIconType.feed:
        _feed(canvas, fill, line);
      case BrandIconType.library:
        _library(canvas, fill, line);
      case BrandIconType.profile:
        _profile(canvas, fill, line);
      case BrandIconType.create:
        _create(canvas, fill, line);
    }
    canvas.restore();
  }

  // 집 — 넓은 지붕 + 둥근 몸체 + 문
  void _home(Canvas c, Paint fill, Paint line) {
    final body = Path()
      ..addRRect(RRect.fromLTRBR(5, 11, 19, 20.4, const Radius.circular(1.9)));
    final roof = Path()
      ..moveTo(12, 3.3)
      ..lineTo(21.4, 11.4)
      ..lineTo(2.6, 11.4)
      ..close();
    final house = Path.combine(PathOperation.union, roof, body);
    final door = Path()
      ..addRRect(RRect.fromLTRBR(10.1, 15, 13.9, 20.4, const Radius.circular(1.1)));
    if (filled) {
      c.drawPath(Path.combine(PathOperation.difference, house, door), fill);
    } else {
      c.drawPath(house, line);
      c.drawPath(door, line);
    }
  }

  // 피드(탐색) — 원형 컴퍼스 + 4방향 별 바늘
  void _feed(Canvas c, Paint fill, Paint line) {
    final circle = Path()
      ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.7));
    const cx = 12.0, cy = 12.0;
    const ro = 5.4, ri = 1.9;
    final star = Path()
      ..moveTo(cx, cy - ro)
      ..lineTo(cx + ri, cy - ri)
      ..lineTo(cx + ro, cy)
      ..lineTo(cx + ri, cy + ri)
      ..lineTo(cx, cy + ro)
      ..lineTo(cx - ri, cy + ri)
      ..lineTo(cx - ro, cy)
      ..lineTo(cx - ri, cy - ri)
      ..close();
    if (filled) {
      c.drawPath(Path.combine(PathOperation.difference, circle, star), fill);
    } else {
      c.drawPath(circle, line);
      c.drawPath(star, fill); // 미선택도 바늘은 작게 채워 또렷하게
    }
  }

  // 보관함 — 둥근 프레임 + 재생 삼각형
  void _library(Canvas c, Paint fill, Paint line) {
    final frame = Path()
      ..addRRect(RRect.fromLTRBR(4, 5.4, 20, 18.6, const Radius.circular(3.2)));
    final play = Path()
      ..moveTo(10.2, 9.1)
      ..lineTo(15.4, 12)
      ..lineTo(10.2, 14.9)
      ..close();
    if (filled) {
      c.drawPath(Path.combine(PathOperation.difference, frame, play), fill);
    } else {
      c.drawPath(frame, line);
      c.drawPath(play, fill);
    }
  }

  // 프로필 — 머리 + 어깨
  void _profile(Canvas c, Paint fill, Paint line) {
    final head = Path()
      ..addOval(Rect.fromCircle(center: const Offset(12, 8.4), radius: 3.6));
    final shoulders = Path()
      ..moveTo(5.2, 19.4)
      ..cubicTo(5.2, 15.2, 8.2, 13.8, 12, 13.8)
      ..cubicTo(15.8, 13.8, 18.8, 15.2, 18.8, 19.4)
      ..close();
    if (filled) {
      c.drawPath(Path.combine(PathOperation.union, head, shoulders), fill);
    } else {
      c.drawPath(head, line);
      c.drawPath(shoulders, line);
    }
  }

  // 만들기 — 심플한 플러스(+). 얇고 둥근 라운드 캡(여백 넉넉히, 세련되게)
  void _create(Canvas c, Paint fill, Paint line) {
    final p = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(12, 6.8), const Offset(12, 17.2), p);
    c.drawLine(const Offset(6.8, 12), const Offset(17.2, 12), p);
  }

  @override
  bool shouldRepaint(_BrandIconPainter old) =>
      old.type != type ||
      old.filled != filled ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
