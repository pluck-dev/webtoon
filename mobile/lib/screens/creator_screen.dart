import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai_studio.dart';
import '../cloud.dart';
import '../config.dart';
import '../models.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import 'casting_screen.dart';
import 'performer_screen.dart';

/// 작가 모드 — 컷마다 사진 + 대사로 내 만화 만들기.
/// [episodeId]가 있으면 '수정' 모드(기존 발행물을 같은 id로 in-place 갱신).
class CreatorScreen extends StatefulWidget {
  final String? episodeId;
  const CreatorScreen({super.key, this.episodeId});

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CutDraft {
  String? cutId; // 수정 모드: 기존 컷 id (유지 시 녹음 보존)
  String? dialogueId; // 수정 모드: 기존 대사 id
  String? imageUrl; // 수정 모드: 기존 원격 이미지(로컬 교체 전까지 표시·유지)
  String? imagePath; // 신규/교체 로컬 이미지 (있으면 업로드 대상)
  String? scenePrompt; // AI 스토리보드가 추천한 장면 묘사(이미지 생성 프리필용)
  bool generating = false; // AI 이미지 생성 중 → 컷 영역에 스피너
  final speaker = TextEditingController();
  final text = TextEditingController();
  final direction = TextEditingController();

  // 표시·검증용: 로컬이든 원격이든 이미지가 있는지
  bool get hasImage =>
      imagePath != null || (imageUrl != null && imageUrl!.isNotEmpty);

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

  // 등장인물(AI 캐릭터) — 먼저 만들면 컷마다 같은 인물로 일관성 유지
  List<AiCharacter> _characters = [];

  // 임시저장(자동) — 앱이 꺼져도 작업이 안 날아가게
  static const _draftKey = 'creator_draft_v1';
  Timer? _saveDebounce;
  bool _restoring = true; // 복원 중엔 자동저장 막기

  bool get _isEdit => widget.episodeId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadForEdit(); // 기존 발행물 불러와 채움(임시저장은 쓰지 않음)
    } else {
      _loadCharacters();
      _restoreDraft();
    }
  }

  // 수정 모드 — 발행된 에피소드를 불러와 컷/대사/대본을 채움
  Future<void> _loadForEdit() async {
    _loadCharacters();
    try {
      final d = await Repo.fetchEpisodeDetail(widget.episodeId!);
      if (!mounted) return;
      setState(() {
        _title.text = d.summary.title;
        _logline.text = d.summary.logline;
        _category = _categories.containsKey(d.summary.category)
            ? d.summary.category
            : 'ROLEPLAY';
        for (final c in _cuts) {
          c.dispose();
        }
        _cuts
          ..clear()
          ..addAll(d.cuts.map((cut) {
            final dia = cut.dialogues.isNotEmpty ? cut.dialogues.first : null;
            final draft = _CutDraft();
            draft.cutId = cut.id;
            draft.dialogueId = dia?.id;
            draft.imageUrl = cut.imageUrl;
            draft.speaker.text = dia?.character?.name ?? '';
            draft.text.text = dia?.text ?? '';
            draft.direction.text = dia?.direction ?? '';
            return draft;
          }));
        if (_cuts.isEmpty) _cuts.add(_CutDraft());
      });
    } catch (_) {
      if (mounted) _toast('만화를 불러오지 못했어요.');
    } finally {
      _restoring = false; // 수정 모드는 자동 임시저장을 쓰지 않음
    }
  }

  Future<void> _loadCharacters() async {
    try {
      final list = await Cloud.listAiCharacters();
      if (!mounted) return;
      setState(() {
        _characters = list;
      });
    } catch (_) {
      // 목록 로드 실패 — 인물 없이 진행(섹션은 숨겨짐)
    }
  }

  // ── 임시저장(자동) ──────────────────────────────────────────────
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _saveDraft);
  }

  void _attachAutosave(_CutDraft c) {
    c.speaker.addListener(_scheduleSave);
    c.text.addListener(_scheduleSave);
    c.direction.addListener(_scheduleSave);
  }

  void _wireInitialAutosave() {
    _title.addListener(_scheduleSave);
    _logline.addListener(_scheduleSave);
    for (final c in _cuts) {
      _attachAutosave(c);
    }
  }

  Future<void> _saveDraft() async {
    if (_restoring || _isEdit) return;
    final empty = _title.text.trim().isEmpty &&
        _logline.text.trim().isEmpty &&
        _cuts.every((c) =>
            c.imagePath == null &&
            c.text.text.trim().isEmpty &&
            c.speaker.text.trim().isEmpty);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (empty) {
        await prefs.remove(_draftKey);
        return;
      }
      final data = {
        'title': _title.text,
        'logline': _logline.text,
        'category': _category,
        'cuts': _cuts
            .map((c) => {
                  'imagePath': c.imagePath,
                  'scenePrompt': c.scenePrompt,
                  'speaker': c.speaker.text,
                  'text': c.text.text,
                  'direction': c.direction.text,
                })
            .toList(),
      };
      await prefs.setString(_draftKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  // 생성/촬영 이미지를 영구 폴더로 복사 → 앱 꺼져도 안 사라지게
  Future<String> _persistImage(String tempPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final d = Directory('${dir.path}/draft_images');
      if (!await d.exists()) await d.create(recursive: true);
      final dest =
          '${d.path}/cut_${DateTime.now().microsecondsSinceEpoch}.png';
      await File(tempPath).copy(dest);
      return dest;
    } catch (_) {
      return tempPath;
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null) {
        _restoring = false;
        _wireInitialAutosave();
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cutsJson = (data['cuts'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _title.text = (data['title'] ?? '') as String;
        _logline.text = (data['logline'] ?? '') as String;
        _category = (data['category'] ?? 'ROLEPLAY') as String;
        for (final c in _cuts) {
          c.dispose();
        }
        _cuts
          ..clear()
          ..addAll(cutsJson.map((j) {
            final m = j as Map<String, dynamic>;
            final d = _CutDraft();
            final p = m['imagePath'] as String?;
            d.imagePath = (p != null && File(p).existsSync()) ? p : null;
            d.scenePrompt = m['scenePrompt'] as String?;
            d.speaker.text = (m['speaker'] ?? '') as String;
            d.text.text = (m['text'] ?? '') as String;
            d.direction.text = (m['direction'] ?? '') as String;
            return d;
          }));
        if (_cuts.isEmpty) _cuts.add(_CutDraft());
      });
      _restoring = false;
      _wireInitialAutosave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('이전에 만들던 작업을 불러왔어요.',
              style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w700)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: '새로 시작', onPressed: _startFresh),
        ));
      }
    } catch (_) {
      _restoring = false;
      _wireInitialAutosave();
    }
  }

  void _startFresh() {
    setState(() {
      _title.clear();
      _logline.clear();
      _category = 'ROLEPLAY';
      for (final c in _cuts) {
        c.dispose();
      }
      _cuts
        ..clear()
        ..add(_CutDraft());
      _attachAutosave(_cuts.first);
    });
    _clearDraft();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveDraft(); // 화면 빠져나갈 때 마지막 저장
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
              title: Text('AI로 생성',
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
          _scheduleSave();
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
          _attachAutosave(d);
          return d;
        }).toList();
        if (extras.isNotEmpty) _cuts.insertAll(at, extras);
      });
      HapticFeedback.selectionClick();
      _scheduleSave();
      if (xs.length > 1) _toast('사진 ${xs.length}장으로 컷 ${xs.length}개를 만들었어요!');
    } catch (_) {
      if (mounted) _toast('사진을 불러오지 못했어요.');
    }
  }

  // ✨ AI 컷 이미지 생성 — 캐릭터 선택 + 한글 키워드 빌더 시트
  // (생성/로딩/한도 처리는 시트 내부에서. 성공 시 결과만 받아 컷에 적용)
  Future<void> _generateAi(_CutDraft cut) async {
    // 시트는 '무엇을 그릴지'만 받고 바로 닫힘 → 생성은 컷 영역에서 진행
    final req = await showAiGenerateSheet(context,
        initialPrompt: cut.scenePrompt);
    _loadCharacters(); // 시트에서 새 캐릭터를 만들었을 수도 있으니 갱신
    if (req == null || !mounted) return;

    setState(() => cut.generating = true); // 컷 영역에 스피너
    _scheduleSave();
    try {
      final refs = <String>[];
      for (final c in req.characters.take(3)) {
        try {
          refs.add(await Cloud.characterLocalImage(c));
        } catch (_) {/* 그 인물만 포기 */}
      }
      final res = await Cloud.generateAiImage(req.prompt, refImagePaths: refs);
      final saved = await _persistImage(res.path); // 앱 꺼져도 남게 복사
      if (!mounted) return;
      setState(() {
        cut.imagePath = saved;
        cut.scenePrompt = req.prompt; // 다시 만들 때 프리필용
        cut.generating = false;
      });
      _scheduleSave();
      HapticFeedback.selectionClick();
      _toast(res.stub
          ? 'AI 미리보기(데모) 적용 — 실제 생성은 키 설정 후'
          : 'AI 이미지 생성 완료! (남은 횟수 ${res.remaining})');
    } on AiQuotaException catch (e) {
      if (!mounted) return;
      setState(() => cut.generating = false);
      _toast('이번 달 AI 생성 ${e.limit}회를 모두 썼어요. 구독하면 더 만들 수 있어요.');
    } on AiNoImageException catch (e) {
      if (!mounted) return;
      setState(() => cut.generating = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => cut.generating = false);
      _toast('AI 생성에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  void _addCut() {
    setState(() {
      final c = _CutDraft();
      _attachAutosave(c);
      _cuts.add(c);
    });
    HapticFeedback.selectionClick();
    _scheduleSave();
  }

  Future<void> _deleteCharacter(AiCharacter c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('“${c.name}” 삭제할까요?',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
        content: Text('이미 만든 컷 그림은 그대로 남아요.',
            style: GoogleFonts.notoSansKr(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제',
                style: GoogleFonts.notoSansKr(
                    color: AppColors.coral, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Cloud.deleteAiCharacter(c.id);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _characters = _characters.where((x) => x.id != c.id).toList();
    });
  }

  // 등장인물 현황판 — 만들어 둔 인물 목록을 보여주기만 한다. 생성·선택은 컷 만들기/
  // 스토리보드(인물이 실제 필요한 순간)에서 하므로 여기선 '기본 선택'을 두지 않는다.
  // 캐릭터가 하나도 없으면(=사진만 쓰는 경우) 섹션을 숨김. (길게 누르면 삭제)
  Widget _charactersSection() {
    if (_characters.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('등장인물',
              style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w900, fontSize: 17)),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: Text('만들어 둔 인물이에요. 컷·스토리를 만들 때 골라서 써요. (길게 누르면 삭제)',
              style:
                  GoogleFonts.notoSansKr(color: AppColors.muted, fontSize: 12)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 98,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in _characters) _charTile(c),
            ],
          ),
        ),
      ],
    );
  }

  Widget _charTile(AiCharacter c) {
    return GestureDetector(
      onLongPress: () => _deleteCharacter(c),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
              child: ClipOval(
                child: Image.network(c.imageUrl,
                    width: 66,
                    height: 66,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded, color: AppColors.faint)),
              ),
            ),
            const SizedBox(height: 4),
            Text(c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  // 🎬 AI 스토리보드 — 상황 입력 → 컷(장면+대사) 추천 + 화자별 캐릭터 배정
  Future<void> _openStoryboard() async {
    final r = await showStoryboardSheet(context);
    _loadCharacters(); // 스토리보드에서 새 캐릭터를 만들었을 수 있으니 갱신
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
          _attachAutosave(d);
          return d;
        }));
      if (_cuts.isEmpty) _cuts.add(_CutDraft());
    });
    HapticFeedback.selectionClick();
    _scheduleSave();
    // 대본·대사 채웠으니 → 컷 그림도 한 번에 만들지 물어봄 (화자별 캐릭터로)
    _offerGenerateAll(r.castBySpeaker);
  }

  // 스토리보드/추천 장면이 있는 컷들 그림을 한 번에 자동 생성할지 제안
  Future<void> _offerGenerateAll(Map<String, AiCharacter> castBySpeaker) async {
    final pending = _cuts
        .where((c) => (c.scenePrompt ?? '').trim().isNotEmpty && c.imagePath == null)
        .toList();
    if (pending.isEmpty || !mounted) return;
    final castCount = castBySpeaker.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('컷 그림도 자동으로 만들까요?',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
        content: Text(
          castCount > 0
              ? '${pending.length}개 컷을 배정한 캐릭터($castCount명)로 일관되게 그려요. (조금 걸려요)'
              : '${pending.length}개 컷을 그려요.\n캐릭터를 배정하지 않아서 컷마다 인물이 달라질 수 있어요. (스토리보드에서 화자별 캐릭터를 정하면 같은 인물로 나와요)',
          style: GoogleFonts.notoSansKr(color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('나중에',
                style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w800, color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('그림 만들기',
                style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok == true) {
      _generateAllCuts(castBySpeaker);
    } else if (mounted) {
      _toast('각 컷에서 "AI로 생성"으로 그림을 만들 수 있어요.');
    }
  }

  // 추천 장면이 있는 컷들을 순서대로 생성 — 컷의 화자에 배정된 캐릭터로 일관성 유지
  Future<void> _generateAllCuts(Map<String, AiCharacter> castBySpeaker) async {
    // 캐릭터 레퍼런스 로컬 경로 캐시 (id → 경로). 같은 캐릭터 반복 다운로드 방지.
    final refCache = <String, String>{};
    Future<List<String>> refsFor(String speaker) async {
      final c = castBySpeaker[speaker.trim()];
      if (c == null) return const [];
      final cached = refCache[c.id];
      if (cached != null) return [cached];
      try {
        final p = await Cloud.characterLocalImage(c);
        refCache[c.id] = p;
        return [p];
      } catch (_) {
        return const [];
      }
    }

    for (final cut in List<_CutDraft>.of(_cuts)) {
      if (!mounted) return;
      if (cut.imagePath != null || (cut.scenePrompt ?? '').trim().isEmpty) {
        continue;
      }
      setState(() => cut.generating = true);
      try {
        final refs = await refsFor(cut.speaker.text);
        final res = await Cloud.generateAiImage(cut.scenePrompt!,
            refImagePaths: refs);
        final saved = await _persistImage(res.path);
        if (!mounted) return;
        setState(() {
          cut.imagePath = saved;
          cut.generating = false;
        });
        _scheduleSave();
      } on AiQuotaException catch (e) {
        if (!mounted) return;
        setState(() => cut.generating = false);
        _toast('이번 달 한도(${e.limit}회) 도달 — 나머지 컷은 못 만들었어요.');
        break;
      } catch (_) {
        if (!mounted) return;
        setState(() => cut.generating = false);
        // 이 컷만 실패하고 계속
      }
    }
    if (mounted) _toast('컷 그림 생성을 마쳤어요!');
  }

  void _removeCut(int i) {
    setState(() {
      _cuts[i].dispose();
      _cuts.removeAt(i);
      if (_cuts.isEmpty) {
        final c = _CutDraft();
        _attachAutosave(c);
        _cuts.add(c);
      }
    });
    HapticFeedback.selectionClick();
    _scheduleSave();
  }

  // 내용 있는 컷은 확인 후 삭제
  Future<void> _confirmRemoveCut(int i) async {
    final cut = _cuts[i];
    final hasContent =
        cut.imagePath != null || cut.text.text.trim().isNotEmpty;
    if (hasContent) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('컷 ${i + 1}을 삭제할까요?',
              style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
          content: Text('그림과 대사가 함께 지워져요.',
              style: GoogleFonts.notoSansKr(color: AppColors.muted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소',
                  style: GoogleFonts.notoSansKr(
                      fontWeight: FontWeight.w800, color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('삭제',
                  style: GoogleFonts.notoSansKr(
                      color: AppColors.coral, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _removeCut(i);
  }

  // 전체 초기화 — 제목·컷·이미지 모두 지우고 새로
  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('전부 지우고 새로 시작할까요?',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
        content: Text('제목·컷·그림이 모두 지워져요. (등장인물은 남아요)',
            style: GoogleFonts.notoSansKr(color: AppColors.muted, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소',
                style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w800, color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('초기화',
                style: GoogleFonts.notoSansKr(
                    color: AppColors.coral, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok == true) _startFresh();
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return '제목을 입력해 주세요.';
    if (_cuts.isEmpty) return '컷을 하나 이상 추가해 주세요.';
    for (var i = 0; i < _cuts.length; i++) {
      if (!_cuts[i].hasImage) return '컷 ${i + 1}의 사진을 넣어주세요.';
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
    if (_isEdit) {
      await _saveEdit();
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
      _clearDraft(); // 발행 완료 → 임시저장 비움
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

  // 수정 모드 저장 — 같은 epId로 in-place 갱신 후 이전 화면으로 복귀
  Future<void> _saveEdit() async {
    setState(() => _publishing = true);
    try {
      final cuts = _cuts
          .map((c) => (
                cutId: c.cutId,
                dialogueId: c.dialogueId,
                imagePath: c.imagePath,
                imageUrl: c.imageUrl,
                speaker: c.speaker.text.trim().isEmpty
                    ? '내레이션'
                    : c.speaker.text.trim(),
                text: c.text.text.trim(),
                direction: c.direction.text.trim(),
              ))
          .toList();
      await Cloud.updateEpisode(
        episodeId: widget.episodeId!,
        title: _title.text.trim(),
        logline: _logline.text.trim().isEmpty
            ? '내가 만든 만화'
            : _logline.text.trim(),
        category: _category,
        cuts: cuts,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _toast('수정을 저장했어요.');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _publishing = false);
        _toast('수정 저장에 실패했어요. 잠시 후 다시 시도해 주세요.');
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

  void _toast(String m) => showAppToast(context, m);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '만화 수정' : '만화 만들기',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
        actions: [
          // 전체 초기화 (새로 만들 때만 — 수정 중엔 원본 컷이 날아갈 수 있어 숨김)
          if (!_isEdit)
            IconButton(
              tooltip: '초기화',
              onPressed: _publishing ? null : _confirmReset,
              icon:
                  const Icon(Icons.restart_alt_rounded, color: AppColors.muted),
            ),
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
                  : Text(_isEdit ? '저장' : '발행',
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
          // 🎬 AI 스토리보드 — 맨 위, 명확한 버튼(광고 아님)
          _storyboardCta(),
          const SizedBox(height: 18),
          _infoCard(),
          const SizedBox(height: 22),
          _charactersSection(),
          const SizedBox(height: 22),
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
                : Text(_isEdit ? '수정 저장하기' : '발행하고 더빙하기',
                    style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
          ),
        ),
      );

  // AI 스토리보드 진입 — 광고 배너처럼 안 보이게 '버튼' 느낌으로
  Widget _storyboardCta() {
    return Pressable(
      onTap: _openStoryboard,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.movie_filter_rounded, color: AppColors.ink, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI로 웹툰 시작하기',
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text('상황만 적으면 컷·대사·그림까지 자동',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 명확한 버튼 알약
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('시작',
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: AppColors.paper)),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.paper, size: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  // AI 생성 중 — 컷 이미지 영역에 표시
  Widget _generatingBox(_CutDraft cut) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cut.imagePath != null)
          Image.file(File(cut.imagePath!), fit: BoxFit.cover)
        else if (cut.imageUrl != null && cut.imageUrl!.isNotEmpty)
          Image.network(cut.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppColors.cream))
        else
          Container(color: AppColors.cream),
        Container(color: Colors.black.withValues(alpha: 0.55)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 3),
              ),
              const SizedBox(height: 12),
              Text('AI가 그리는 중…',
                  style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
              const SizedBox(height: 3),
              Text('다른 컷 작업해도 돼요',
                  style: GoogleFonts.notoSansKr(
                      color: Colors.white70, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }

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
            onTap: cut.generating ? null : () => _pickImage(cut),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: cut.generating
                  ? _generatingBox(cut)
                  : cut.hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        if (cut.imagePath != null)
                          Image.file(File(cut.imagePath!), fit: BoxFit.cover)
                        else
                          Image.network(cut.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: AppColors.cream)),
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
                        // 전체보기 버튼 — AI 생성 중엔 숨김
                        Positioned(
                          left: 10,
                          top: 10,
                          child: GestureDetector(
                            onTap: () => showFullImage(
                              context,
                              filePath: cut.imagePath,
                              url: cut.imageUrl,
                            ),
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
                                  const Icon(Icons.fullscreen_rounded,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text('크게',
                                      style: GoogleFonts.notoSansKr(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12)),
                                ],
                              ),
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
                    GestureDetector(
                      onTap: () => _confirmRemoveCut(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.lineSoft),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_outline_rounded,
                                color: AppColors.muted, size: 15),
                            const SizedBox(width: 3),
                            Text('삭제',
                                style: GoogleFonts.notoSansKr(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5)),
                          ],
                        ),
                      ),
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
