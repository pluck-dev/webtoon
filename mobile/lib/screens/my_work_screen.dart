import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import 'library_screen.dart';
import 'my_episodes_screen.dart';

/// "내 작업" 탭 — 상단 세그먼트로 [내 만화 | 더빙] 전환
class MyWorkScreen extends StatefulWidget {
  const MyWorkScreen({super.key});

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> {
  int _seg = 0; // 0: 내 만화, 1: 더빙

  void _selectSeg(int i) {
    if (_seg == i) return;
    HapticFeedback.selectionClick();
    setState(() => _seg = i);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 제목 + 세그먼트 토글
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내 작업',
                  style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 12),
                _SegmentToggle(selected: _seg, onSelect: _selectSeg),
              ],
            ),
          ),
          // 본문: IndexedStack으로 두 탭 상태 유지
          Expanded(
            child: IndexedStack(
              index: _seg,
              children: const [
                MyEpisodesScreen(embedded: true),
                LibraryScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// cream 배경 둥근 컨테이너 안에 [내 만화 | 더빙] 토글
class _SegmentToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _SegmentToggle({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        children: [
          _tab(0, '내 만화'),
          _tab(1, '더빙'),
        ],
      ),
    );
  }

  Widget _tab(int i, String label) {
    final on = selected == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: on ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.notoSansKr(
              fontSize: 13.5,
              fontWeight: on ? FontWeight.w800 : FontWeight.w700,
              color: on ? AppColors.paper : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
