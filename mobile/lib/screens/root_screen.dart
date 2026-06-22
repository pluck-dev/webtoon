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

  // 보관함은 탭 진입 때마다 새로 읽도록 key 교체
  Key _libraryKey = const ValueKey('lib-0');
  int _libVisits = 0;

  late final List<Widget> _pages = [
    const HomeScreen(),
    const SizedBox.shrink(), // 보관함은 동적 key로 빌드
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _pages[0],
          LibraryScreen(key: _libraryKey),
          _pages[2],
        ],
      ),
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
            setState(() {
              _index = i;
              if (i == 1) {
                _libVisits++;
                _libraryKey = ValueKey('lib-$_libVisits'); // 재진입 시 새로고침
              }
            });
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
