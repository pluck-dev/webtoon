import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cloud.dart';
import '../config.dart';
import '../widgets/app_widgets.dart';
import 'collab_manage_screen.dart';

/// 배역 캐스팅 — 발행한 만화의 배역을 '내가 / 초대'로 분배
class CastingScreen extends StatefulWidget {
  final String episodeId;
  final List<({String id, String name})> characters;
  const CastingScreen({
    super.key,
    required this.episodeId,
    required this.characters,
  });

  @override
  State<CastingScreen> createState() => _CastingScreenState();
}

class _CastingScreenState extends State<CastingScreen> {
  late final List<bool> _mine; // 배역별 '내가 더빙' 여부
  String _mode = 'TEAM'; // TEAM(같이 한 영상) | REMIX(각자 버전)
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    // 기본: 첫 배역은 내가, 나머지는 친구 초대
    _mine = List.generate(widget.characters.length, (i) => i == 0);
  }

  int get _inviteCount => _mine.where((m) => !m).length;

  Future<void> _create() async {
    if (_inviteCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대할 배역을 하나 이상 비워두세요.')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final assignments = [
        for (var i = 0; i < widget.characters.length; i++)
          (characterId: widget.characters[i].id, mine: _mine[i]),
      ];
      final res = await Cloud.createCollab(
        episodeId: widget.episodeId,
        assignments: assignments,
        mode: _mode,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushReplacement(
        fadeThroughRoute(CollabManageScreen(shareCode: res.shareCode)),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('초대 만들기에 실패했어요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('배역 정하기',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          // 모드 선택
          _modeCard(
            value: 'TEAM',
            title: '같이 한 영상',
            subtitle: '친구들이 배역을 나눠 맡고 다 같이 하나의 영상을 완성',
          ),
          const SizedBox(height: 10),
          _modeCard(
            value: 'REMIX',
            title: '각자 버전',
            subtitle: '친구들이 각자 더빙해서 저마다의 영상을 만들어요 (내 배역은 공유)',
          ),
          const SizedBox(height: 22),
          Text('누가 어떤 배역을 맡을까요?',
              style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text(
              _mode == 'REMIX'
                  ? "'초대' 배역은 참여한 친구가 각자 더빙해요. '내가'는 모든 영상에 공유돼요."
                  : '비워둔 배역은 친구를 초대해 채울 수 있어요.',
              style: GoogleFonts.notoSansKr(
                  fontSize: 13.5, color: AppColors.muted)),
          const SizedBox(height: 18),
          for (var i = 0; i < widget.characters.length; i++) ...[
            _roleRow(i),
            const SizedBox(height: 12),
          ],
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          border: Border(top: BorderSide(color: AppColors.lineSoft)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.paper),
                  )
                : Text('초대 더빙 만들기 ($_inviteCount명 초대)',
                    style:
                        GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }

  Widget _modeCard({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final sel = _mode == value;
    return Pressable(
      onTap: () => setState(() => _mode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? AppColors.gold.withValues(alpha: 0.16) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: sel ? AppColors.gold : AppColors.line,
              width: sel ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
                color: sel ? AppColors.gold : AppColors.faint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.notoSansKr(
                          fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleRow(int i) {
    final name = widget.characters[i].name;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            child: Text(name.isEmpty ? '?' : name.characters.first,
                style: GoogleFonts.notoSansKr(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          // 토글: 내가 / 초대
          _segToggle(i),
        ],
      ),
    );
  }

  Widget _segToggle(int i) {
    Widget seg(String label, bool selected, VoidCallback onTap) => Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label,
                style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: selected ? AppColors.paper : AppColors.muted)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          seg('내가', _mine[i], () {
            HapticFeedback.selectionClick();
            setState(() => _mine[i] = true);
          }),
          seg('초대', !_mine[i], () {
            HapticFeedback.selectionClick();
            setState(() => _mine[i] = false);
          }),
        ],
      ),
    );
  }
}
