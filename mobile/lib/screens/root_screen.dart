import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../widgets/app_widgets.dart';
import '../widgets/brand_icons.dart';
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
      // 본문을 네비 뒤까지 깔아 → 바 주변 빈 영역은 투명(콘텐츠 비침 + 터치 통과)
      extendBody: true,
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

  @override
  Widget build(BuildContext context) {
    // 풀폭 솔리드 바(가장자리까지) + 가운데 버튼은 바 윗선에 걸친(raised) 형태
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const barH = 58.0; // 바 컨텐츠 높이
    const headroom = 18.0; // 가운데 버튼이 위로 걸치는 여유(투명)

    return SizedBox(
      height: headroom + barH + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 풀폭 솔리드 바 배경 (하단, 가장자리까지)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barH + bottomInset,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.card,
                border:
                    Border(top: BorderSide(color: AppColors.lineSoft, width: 1)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 16,
                      offset: Offset(0, -3)),
                ],
              ),
            ),
          ),
          // 탭들 (바 컨텐츠 영역) — 가운데는 빈 슬롯
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            height: barH,
            child: Row(
              children: [
                _tab(0, BrandIconType.home, '홈'),
                _tab(1, BrandIconType.feed, '피드'),
                const Expanded(child: SizedBox()),
                _tab(2, BrandIconType.library, '보관함'),
                _tab(3, BrandIconType.profile, '프로필'),
              ],
            ),
          ),
          // 가운데 만들기 — 바 윗선에 걸친 라이즈드 골드 버튼 + 라벨
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            height: barH,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _CreateButton(onTap: onCreate),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(int i, BrandIconType type, String label) {
    final selected = index == i;
    return Expanded(
      // behavior: opaque → 슬롯 전체가 터치 타깃(빈 공간도 눌림)
      child: Pressable(
        onTap: () => onTab(i),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 7),
          // 라벨을 하단 정렬 → 가운데 만들기 라벨과 같은 줄에 맞춤
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedScale(
                scale: selected ? 1.0 : 0.9,
                duration: AppMotion.normal,
                curve: AppMotion.spring,
                child: BrandIcon(
                  type,
                  filled: selected,
                  size: 25,
                  color: selected ? AppColors.ink : AppColors.faint,
                ),
              ),
              const SizedBox(height: 4),
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
      ),
    );
  }
}

/// 가운데 '만들기' 골드 원형 버튼 — 누르면 살짝 줄었다 튀는 탭 모션(OKX 느낌)
class _CreateButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  State<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends State<_CreateButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      // 라이즈드 원 + 라벨 — 다른 탭과 같은 줄에 '만들기'
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _down ? 0.84 : 1.0,
            duration: AppMotion.fast,
            curve: AppMotion.spring,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF6CE7E), AppColors.gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66F0BD62),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const BrandIcon(
                BrandIconType.create,
                filled: true,
                size: 22,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '만들기',
            style: GoogleFonts.notoSansKr(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
