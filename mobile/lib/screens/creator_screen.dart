import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../cloud.dart';
import '../config.dart';
import '../widgets/app_widgets.dart';
import 'performer_screen.dart';

/// 작가 모드 — 컷마다 사진 + 대사로 내 만화 만들기
class CreatorScreen extends StatefulWidget {
  const CreatorScreen({super.key});

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CutDraft {
  String? imagePath;
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
    final source = await showModalBottomSheet<ImageSource>(
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
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.ink),
              title: Text('사진 찍기',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.ink),
              title: Text('앨범에서 선택',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 88,
      );
      if (x != null && mounted) {
        setState(() => cut.imagePath = x.path);
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      if (mounted) _toast('사진을 불러오지 못했어요.');
    }
  }

  void _addCut() {
    setState(() => _cuts.add(_CutDraft()));
    HapticFeedback.selectionClick();
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

  Future<void> _publish() async {
    final err = _validate();
    if (err != null) {
      _toast(err);
      return;
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
      final epId = await Cloud.publishEpisode(
        title: _title.text.trim(),
        logline: _logline.text.trim().isEmpty
            ? '내가 만든 만화'
            : _logline.text.trim(),
        category: _category,
        cuts: cuts,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // 발행 후 바로 더빙 화면으로
      Navigator.of(context).pushReplacement(
        fadeThroughRoute(PerformerScreen(episodeId: epId)),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _publishing = false);
        _toast('발행에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

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
            16, 8, 16, MediaQuery.of(context).padding.bottom + 100),
        children: [
          _infoCard(),
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
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.line,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: AppColors.ink),
                  const SizedBox(width: 6),
                  Text('컷 추가',
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _publishBar(),
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
