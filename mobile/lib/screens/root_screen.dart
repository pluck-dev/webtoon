import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../widgets/app_widgets.dart';
import 'creator_screen.dart';
import 'feed_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

/// 로그인 후 메인 셸 — 홈/피드/보관함/프로필 + 가운데 '만들기' 버튼
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  void _openCreator() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(fadeThroughRoute(const CreatorScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack 대신 활성 화면만 빌드 — 탭 재진입 시 새로 로드(보관함 새로고침)
      body: switch (_index) {
        0 => const HomeScreen(),
        1 => const FeedScreen(),
        2 => const LibraryScreen(),
        _ => const ProfileScreen(),
      },
      bottomNavigationBar: _FloatingNav(
        index: _index,
        onTab: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        onCreate: _openCreator,
      ),
    );
  }
}

/// 플로팅 둥근 바 + 가운데 떠있는 골드 '만들기' 버튼
class _FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onCreate;
  const _FloatingNav({
    required this.index,
    required this.onTab,
    required this.onCreate,
  });

  static const double _circle = 58; // 가운데 버튼 지름

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 86,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 노치(홈) 있는 플로팅 바 — CustomPaint로 그림자+노치 직접 그림
            Positioned(
              left: 14,
              right: 14,
              bottom: 8,
              top: 28,
              child: CustomPaint(
                painter: _NavBarPainter(notchRadius: _circle / 2 + 7),
                child: Row(
                  children: [
                    _tab(0, Icons.home_outlined, Icons.home_rounded, '홈'),
                    _tab(1, Icons.explore_outlined, Icons.explore_rounded, '피드'),
                    const SizedBox(width: 78), // 노치(가운데 버튼) 자리
                    _tab(2, Icons.video_library_outlined,
                        Icons.video_library_rounded, '보관함'),
                    _tab(3, Icons.person_outline_rounded, Icons.person_rounded,
                        '프로필'),
                  ],
                ),
              ),
            ),
            // 가운데 '만들기' 버튼 — 노치에 자연스럽게 안김
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: onCreate,
                  child: Container(
                    width: _circle,
                    height: _circle,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF6CE7E), AppColors.gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.ink, size: 27),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(int i, IconData icon, IconData activeIcon, String label) {
    final selected = index == i;
    return Expanded(
      child: Pressable(
        onTap: () => onTab(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: selected ? AppColors.ink : AppColors.faint,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected ? AppColors.ink : AppColors.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상단 가운데에 둥근 홈(notch)이 파인 플로팅 바 — 그림자/테두리 직접 그림
class _NavBarPainter extends CustomPainter {
  final double notchRadius;
  _NavBarPainter({required this.notchRadius});

  @override
  void paint(Canvas canvas, Size size) {
    const r = 24.0; // 바 모서리 라운드
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final nr = notchRadius;

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(cx - nr, 0)
      // 가운데 아래로 파인 둥근 홈 (concave)
      ..arcToPoint(Offset(cx + nr, 0),
          radius: Radius.circular(nr), clockwise: false)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: const Radius.circular(r))
      ..close();

    // 그림자
    canvas.drawShadow(path, const Color(0x33000000), 8, false);
    // 채움
    canvas.drawPath(path, Paint()..color = AppColors.card);
    // 얇은 테두리
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.lineSoft,
    );
  }

  @override
  bool shouldRepaint(_NavBarPainter old) => old.notchRadius != notchRadius;
}
