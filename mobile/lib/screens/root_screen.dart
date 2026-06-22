import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

/// 로그인 후 메인 셸 — 홈 / 보관함 / 프로필 하단 네비
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack 대신 활성 화면만 빌드 — 오프스테이지 스크롤뷰가
      // 안 그려지던 문제 회피 + 탭 재진입 시 새로 로드(보관함 새로고침)
      body: switch (_index) {
        0 => const HomeScreen(),
        1 => const LibraryScreen(),
        _ => const ProfileScreen(),
      },
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.card,
          indicatorColor: AppColors.ink.withValues(alpha: 0.08),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => GoogleFonts.notoSansKr(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: states.contains(WidgetState.selected)
                  ? AppColors.ink
                  : AppColors.muted,
            ),
          ),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: _index,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            setState(() => _index = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.muted),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.ink),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.video_library_outlined, color: AppColors.muted),
              selectedIcon: Icon(
                Icons.video_library_rounded,
                color: AppColors.ink,
              ),
              label: '보관함',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AppColors.muted),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.ink),
              label: '프로필',
            ),
          ],
        ),
      ),
    );
  }
}
