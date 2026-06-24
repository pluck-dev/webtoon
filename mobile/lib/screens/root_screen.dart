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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 82,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // 플로팅 바
            Positioned(
              left: 14,
              right: 14,
              bottom: 8,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.lineSoft),
                  boxShadow: AppShadows.elevated,
                ),
                child: Row(
                  children: [
                    _tab(0, Icons.home_outlined, Icons.home_rounded, '홈'),
                    _tab(1, Icons.explore_outlined, Icons.explore_rounded, '피드'),
                    const SizedBox(width: 64), // 가운데 버튼 자리
                    _tab(2, Icons.video_library_outlined,
                        Icons.video_library_rounded, '보관함'),
                    _tab(3, Icons.person_outline_rounded, Icons.person_rounded,
                        '프로필'),
                  ],
                ),
              ),
            ),
            // 가운데 '만들기' 버튼 (떠있음)
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: onCreate,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF6CE7E), AppColors.gold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.card, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: AppColors.ink, size: 26),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '만들기',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
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
