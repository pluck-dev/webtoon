import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../ai_studio.dart';
import '../cloud.dart';
import '../config.dart';
import '../widgets/app_widgets.dart';
import 'casting_screen.dart';
import 'performer_screen.dart';

/// 작가 모드 — 컷마다 사진 + 대사로 내 만화 만들기
class CreatorScreen extends StatefulWidget {
  const CreatorScreen({super.key});

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CutDraft {
  String? imagePath;
  String? scenePrompt; // AI 스토리보드가 추천한 장면 묘사(이미지 생성 프리필용)
  final speaker = TextEditingController();
  final text = TextEditingController();
  final direction = TextEditingController();
  void dispose() {
    speaker.dispose();
    text.dispose();
    direction.dispose();
  }
}

const _categories = {'ROLEPLAY': '상황극', 'WEBTOON': '웹툰체', 'ANIMATION': '애니메이션'};

class _CreatorScreenState extends State<CreatorScreen> {
  final _title = TextEditingController();
  final _logline = TextEditingController();
  String _category = 'ROLEPLAY';
  final List<_CutDraft> _cuts = [_CutDraft()];
  final _picker = ImagePicker();
  bool _publishing = false;

  @override
  void dispose() {
    _title.dispose();
    _logline.dispose();
    for (final c in _cuts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(_CutDraft cut) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.ink,
              ),
              title: Text('앨범에서 선택',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800)),
              subtitle: Text('여러 장 고르면 컷이 자동으로 만들어져요',
                  style: GoogleFonts.notoSansKr(
                      fontSize: 12.5, color: AppColors.muted)),
              onTap: () => Navigator.pop(context, 'album'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.ink),
              title: Text('사진 찍기',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.gold),
              title: Text('✨ AI로 생성',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800)),
              subtitle: Text('원하는 장면을 글로 적으면 AI가 그려줘요',
                  style: GoogleFonts.notoSansKr(
                      fontSize: 12.5, color: AppColors.muted)),
              onTap: () => Navigator.pop(context, 'ai'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mode == null) return;
    if (mode == 'ai') {
      await _generateAi(cut);
      return;
    }
    try {
      if (mode == 'camera') {
        final x = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1280,
          imageQuality: 88,
        );
        if (x != null && mounted) {
          setState(() => cut.imagePath = x.path);
          HapticFeedback.selectionClick();
        }
        return;
      }
      // 앨범: 여러 장 → 첫 장은 이 컷, 나머지는 바로 뒤에 새 컷으로 자동 추가
      final xs = await _picker.pickMultiImage(maxWidth: 1280, imageQuality: 88);
      if (xs.isEmpty || !mounted) return;
      setState(() {
        cut.imagePath = xs.first.path;
        final at = _cuts.indexOf(cut) + 1;
        final extras = xs.skip(1).map((x) {
          final d = _CutDraft();
          d.imagePath = x.path;
          return d;
        }).toList();
        if (extras.isNotEmpty) _cuts.insertAll(at, extras);
      });
      HapticFeedback.selectionClick();
      if (xs.length > 1) _toast('사진 ${xs.length}장으로 컷 ${xs.length}개를 만들었어요!');
    } catch (_) {
      if (mounted) _toast('사진을 불러오지 못했어요.');
    }
  }

  // ✨ AI 컷 이미지 생성 — 캐릭터 선택 + 한글 키워드 빌더 시트
  // (생성/로딩/한도 처리는 시트 내부에서. 성공 시 결과만 받아 컷에 적용)
  Future<void> _generateAi(_CutDraft cut) async {
    final res = await showAiGenerateSheet(context,
        initialPrompt: cut.scenePrompt);
    if (res == null || !mounted) return;
    setState(() => cut.imagePath = res.path);
    HapticFeedback.selectionClick();
    _toast(res.stub
        ? 'AI 미리보기(데모) 적용 — 실제 생성은 키 설정 후'
        : 'AI 이미지 생성 완료! (남은 횟수 ${res.remaining})');
  }

  void _addCut() {
    setState(() => _cuts.add(_CutDraft()));
    HapticFeedback.selectionClick();
  }

  // 🎬 AI 스토리보드 — 상황 입력 → 컷(장면+대사) 추천받아 채우기
  Future<void> _openStoryboard() async {
    final r = await showStoryboardSheet(context);
    if (r == null || !mounted) return;
    setState(() {
      if (_title.text.trim().isEmpty) _title.text = r.title;
      if (_logline.text.trim().isEmpty) _logline.text = r.logline;
      // 기존 컷 비우고 추천 컷으로 채움 (대사·화자·장면프롬프트)
      for (final c in _cuts) {
        c.dispose();
      }
      _cuts
        ..clear()
        ..addAll(r.cuts.map((s) {
          final d = _CutDraft();
          d.speaker.text = s.speaker;
          d.text.text = s.dialogue;
          d.direction.text = s.direction;
          d.scenePrompt = s.scenePrompt;
          return d;
        }));
      if (_cuts.isEmpty) _cuts.add(_CutDraft());
    });
    HapticFeedback.selectionClick();
    _toast('컷 ${r.cuts.length}개를 채웠어요! 각 컷에서 "AI로 생성"을 누르면 그림이 그려져요.');
  }

  void _removeCut(int i) {
    setState(() {
      _cuts[i].dispose();
      _cuts.removeAt(i);
    });
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return '제목을 입력해 주세요.';
    if (_cuts.isEmpty) return '컷을 하나 이상 추가해 주세요.';
    for (var i = 0; i < _cuts.length; i++) {
      if (_cuts[i].imagePath == null) return '컷 ${i + 1}의 사진을 넣어주세요.';
      if (_cuts[i].text.text.trim().isEmpty) return '컷 ${i + 1}의 대사를 입력해 주세요.';
    }
    return null;
  }

  // 서로 다른 화자(배역) 수 — 2명 이상이면 초대 더빙 가능
  int get _distinctSpeakers {
    final s = <String>{};
    for (final c in _cuts) {
      final v = c.speaker.text.trim();
      s.add(v.isEmpty ? '내레이션' : v);
    }
    return s.length;
  }

  Future<void> _publish() async {
    final err = _validate();
    if (err != null) {
      _toast(err);
      return;
    }
    // 화자 2명 이상이면 혼자/초대 선택
    bool collab = false;
    if (_distinctSpeakers >= 2) {
      final mode = await _askDubMode();
      if (mode == null) return; // 취소
      collab = mode == 'collab';
    }
    setState(() => _publishing = true);
    try {
      final cuts = _cuts
          .map((c) => (
                imagePath: c.imagePath!,
                speaker: c.speaker.text.trim().isEmpty
                    ? '내레이션'
                    : c.speaker.text.trim(),
                text: c.text.text.trim(),
                direction: c.direction.text.trim(),
              ))
          .toList();
      final res = await Cloud.publishEpisode(
        title: _title.text.trim(),
        logline: _logline.text.trim().isEmpty
            ? '내가 만든 만화'
            : _logline.text.trim(),
        category: _category,
        cuts: cuts,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      if (collab) {
        // 캐스팅 화면으로 (배역 분배 → 초대)
        Navigator.of(context).pushReplacement(
          fadeThroughRoute(CastingScreen(
            episodeId: res.epId,
            characters: res.characters,
          )),
        );
      } else {
        // 혼자 더빙 — 바로 더빙 화면으로
        Navigator.of(context).pushReplacement(
          fadeThroughRoute(PerformerScreen(episodeId: res.epId)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _publishing = false);
        _toast('발행에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  /// 혼자/초대 더빙 선택 시트 → 'solo' | 'collab' | null(취소)
  Future<String?> _askDubMode() => showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text('어떻게 더빙할까요?',
                    style: GoogleFonts.notoSansKr(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 14),
                _modeTile(
                  icon: Icons.person_rounded,
                  title: '혼자 더빙',
                  subtitle: '모든 배역을 내 목소리로',
                  value: 'solo',
                ),
                const SizedBox(height: 10),
                _modeTile(
                  icon: Icons.group_rounded,
                  title: '친구와 같이 더빙 (초대)',
                  subtitle: '배역을 나눠 친구를 초대하고 한 영상으로 완성',
                  value: 'collab',
                  highlight: true,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _modeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    bool highlight = false,
  }) =>
      Pressable(
        onTap: () => Navigator.pop(context, value),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: highlight ? AppColors.gold.withValues(alpha: 0.16) : AppColors.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: highlight ? AppColors.gold : AppColors.line, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.ink, size: 24),
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
              const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            ],
          ),
        ),
      );

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('만화 만들기',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _publishing ? null : _publish,
              child: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.ink),
                    )
                  : Text('발행',
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.ink)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            // 키보드 높이 + 하단 발행 바(약 80) 위로 '컷 추가' 버튼이 확실히 드러나도록 여백 확보
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                170),
        children: [
          _infoCard(),
          const SizedBox(height: 16),
          // 🎬 AI 스토리보드로 시작 — 상황만 적으면 컷 자동 구성
          Pressable(
            onTap: _openStoryboard,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B2622), AppColors.ink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('🎬', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI 스토리보드로 시작',
                            style: GoogleFonts.notoSansKr(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: AppColors.paper)),
                        const SizedBox(height: 2),
                        Text('상황만 적으면 컷·대사를 자동으로 짜줘요',
                            style: GoogleFonts.notoSansKr(
                                fontSize: 12,
                                color: AppColors.paper.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.gold, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('컷 (${_cuts.length})',
                style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          for (var i = 0; i < _cuts.length; i++) ...[
            _cutCard(i),
            const SizedBox(height: 12),
          ],
          Pressable(
            onTap: _addCut,
            child: Container(
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: AppColors.ink),
                  const SizedBox(width: 6),
                  Text('컷 추가 (장면 더 넣기)',
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
      // 키보드가 올라오면 발행 바를 숨겨 입력 필드를 가리지 않게
      bottomSheet:
          MediaQuery.of(context).viewInsets.bottom > 0 ? null : _publishBar(),
    );
  }

  Widget _publishBar() => Container(
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          border: Border(top: BorderSide(color: AppColors.lineSoft)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.paper),
                  )
                : Text('발행하고 더빙하기',
                    style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
          ),
        ),
      );

  Widget _infoCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w900, fontSize: 20),
              decoration: const InputDecoration(
                hintText: '제목',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            const Divider(color: AppColors.lineSoft, height: 16),
            TextField(
              controller: _logline,
              style: GoogleFonts.notoSansKr(fontSize: 14),
              decoration: const InputDecoration(
                hintText: '한 줄 소개 (선택)',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: _categories.entries.map((e) {
                final sel = _category == e.key;
                return Pressable(
                  onTap: () => setState(() => _category = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.ink : AppColors.cream,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: sel ? AppColors.ink : AppColors.line),
                    ),
                    child: Text(e.value,
                        style: GoogleFonts.notoSansKr(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: sel ? AppColors.paper : AppColors.inkSoft)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

  Widget _cutCard(int i) {
    final cut = _cuts[i];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사진 영역
          Pressable(
            onTap: () => _pickImage(cut),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: cut.imagePath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(cut.imagePath!), fit: BoxFit.cover),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_rounded,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text('변경',
                                    style: GoogleFonts.notoSansKr(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.cream,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_a_photo_rounded,
                              color: AppColors.faint, size: 34),
                          const SizedBox(height: 8),
                          Text('사진 추가',
                              style: GoogleFonts.notoSansKr(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('여러 장 선택하면 컷이 자동 생성',
                              style: GoogleFonts.notoSansKr(
                                  color: AppColors.faint, fontSize: 11.5)),
                        ],
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('컷 ${i + 1}',
                          style: GoogleFonts.notoSansKr(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 12)),
                    ),
                    const Spacer(),
                    if (_cuts.length > 1)
                      GestureDetector(
                        onTap: () => _removeCut(i),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.faint, size: 22),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _field(cut.speaker, '화자 이름 (예: 지영)', bold: true),
                const SizedBox(height: 8),
                _field(cut.text, '대사를 입력하세요', lines: 2),
                const SizedBox(height: 8),
                _field(cut.direction, '연기 지시 (선택 · 예: 화내며)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint,
          {bool bold = false, int lines = 1}) =>
      TextField(
        controller: c,
        maxLines: lines,
        style: GoogleFonts.notoSansKr(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: AppColors.cream,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line),
          ),
        ),
      );
}
