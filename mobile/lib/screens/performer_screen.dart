import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../cloud.dart';
import '../config.dart';
import '../local_render.dart';
import '../models.dart';
import '../notify.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import '../widgets/brand_logo.dart';
import '../widgets/celebration.dart';
import 'video_sheet.dart';

class PerformerScreen extends StatefulWidget {
  final String episodeId;
  // 초대 더빙: 이 배역(캐릭터)들 대사만 녹음. null이면 전체(혼자 더빙).
  final Set<String>? roleCharacterIds;
  final String? collabSessionId; // 콜라보 세션(완료 시 내 배역 표시)
  const PerformerScreen({
    super.key,
    required this.episodeId,
    this.roleCharacterIds,
    this.collabSessionId,
  });

  @override
  State<PerformerScreen> createState() => _PerformerScreenState();
}

class _PerformerScreenState extends State<PerformerScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  EpisodeDetail? _detail;
  String? _loadError;
  int _index = 0;
  bool _recording = false;
  final Map<String, String> _takes = {}; // dialogueId → 로컬 파일 경로
  final Map<String, int> _takeMs = {}; // dialogueId → 녹음 길이(ms)
  final Set<String> _saved = {}; // 클라우드 저장된 dialogueId
  final Set<String> _uploading = {}; // 업로드 중
  String? _userId;
  String? _performanceId;
  bool _rendering = false;
  double _renderProgress = 0; // 온디바이스 렌더 진행률 0~1
  int _recordStartMs = 0;
  double _level = 0; // 실시간 마이크 입력 레벨 0~1
  final List<double> _levels = List<double>.filled(32, 0); // 파형 띠 히스토리
  StreamSubscription<Amplitude>? _ampSub;
  bool _celebrated = false; // 완성 축하 1회만
  int _countdown = 0; // 3-2-1 카운트다운
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await Repo.fetchEpisodeDetail(widget.episodeId);
      if (mounted) setState(() => _detail = detail);
      // 클라우드: 유저/공연 보장 + 저장된 녹음 복원
      final userId = await Cloud.ensureUser();
      final perfId = await Cloud.getOrCreatePerformance(
        widget.episodeId,
        userId,
      );
      final saved = await Cloud.loadSavedRecordings(perfId);
      if (mounted) {
        setState(() {
          _userId = userId;
          _performanceId = perfId;
          _saved.addAll(saved.keys);
          _takeMs.addAll(saved); // 저장된 녹음 길이도 보관
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  // 녹음 전부 초기화 — 처음부터 다시
  Future<void> _resetRecordings() async {
    final pid = _performanceId;
    if (pid == null || _recording || _rendering) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          '녹음을 전부 지울까요?',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '지금까지 녹음한 게 모두 지워지고 처음부터 다시 녹음해요.',
          style: GoogleFonts.notoSansKr(color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '전부 지우기',
              style: GoogleFonts.notoSansKr(
                color: AppColors.coral,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Cloud.clearRecordings(pid);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _takes.clear();
      _takeMs.clear();
      _saved.clear();
      _uploading.clear();
      _index = 0;
      _celebrated = false;
    });
    HapticFeedback.mediumImpact();
    showAppToast(context, '녹음을 초기화했어요. 처음부터 다시 녹음하세요.');
  }

  Future<void> _uploadTake(
    String dialogueId,
    String path,
    int durationMs,
  ) async {
    final perfId = _performanceId, userId = _userId;
    if (perfId == null || userId == null) return;
    setState(() => _uploading.add(dialogueId));
    try {
      await Cloud.uploadRecording(
        performanceId: perfId,
        dialogueId: dialogueId,
        userId: userId,
        filePath: path,
        durationMs: durationMs,
      );
      if (mounted) {
        setState(() => _saved.add(dialogueId));
        final allSaved =
            _lines.isNotEmpty &&
            _lines.every((l) => _saved.contains(l.dialogue.id));
        if (allSaved && !_celebrated) {
          _celebrated = true;
          if (_isCollabRole) {
            _markRoleDone(); // 콜라보: 내 배역 완료 표시
          } else {
            HapticFeedback.heavyImpact();
            showCelebration(context);
          }
        }
      }
    } catch (_) {
      if (mounted) _toast('클라우드 저장에 실패했어요. 다시 녹음해 주세요.');
    } finally {
      if (mounted) setState(() => _uploading.remove(dialogueId));
    }
  }

  Future<void> _makeVideo() async {
    final perfId = _performanceId;
    if (perfId == null || _rendering) return;
    setState(() {
      _rendering = true;
      _renderProgress = 0;
    });
    await Notify.requestPermission();
    await Notify.startRender(); // 백그라운드 유지 + 진행 알림
    try {
      // 모든 대사의 로컬 오디오 확보 (이번 세션 녹음 우선, 없으면 클라우드 다운로드)
      final meta = await Cloud.recordingMeta(perfId);
      final renderLines = <RenderLine>[];
      for (final l in _lines) {
        final id = l.dialogue.id;
        var path = _takes[id];
        final ms = _takeMs[id] ?? meta[id]?.durationMs ?? 1200;
        if (path == null) {
          final key = meta[id]?.storageKey;
          if (key == null) {
            throw Exception('녹음 누락: ${l.dialogue.speaker}');
          }
          path = await Cloud.downloadRecording(key);
        }
        renderLines.add(
          RenderLine(
            imageUrl: l.cut.imageUrl,
            speaker: l.dialogue.speaker,
            direction: l.dialogue.direction,
            text: l.dialogue.text,
            color: _colorOf(l.dialogue.character?.color),
            audioPath: path,
            durationMs: ms,
          ),
        );
      }
      // 폰에서 직접 렌더
      final out = await LocalRender.render(
        renderLines,
        onProgress: (p) {
          if (mounted) setState(() => _renderProgress = p);
          Notify.updateRender((p * 100).round());
        },
      );
      // 보관함에도 저장(클라우드 업로드) — 실패해도 로컬 재생은 가능
      String url = out;
      try {
        final totalMs = renderLines.fold<int>(0, (a, r) => a + r.durationMs);
        url = await Cloud.saveRenderedVideo(perfId, out, totalMs);
      } catch (_) {}
      await Notify.stopRender();
      await Notify.renderDone(); // 완료 알림(앱 나가있어도 받음)
      if (mounted) {
        setState(() => _rendering = false);
        showVideoSheet(context, url);
      }
    } catch (e) {
      await Notify.stopRender();
      if (mounted) {
        setState(() => _rendering = false);
        _toast('영상 생성에 실패했어요.');
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  bool get _isCollabRole => widget.collabSessionId != null;
  bool _roleMarked = false;

  // 초대 더빙이면 내 배역(들) 대사만, 아니면 전체
  List<({Cut cut, Dialogue dialogue})> get _lines {
    final all = _detail?.lines ?? [];
    final ids = widget.roleCharacterIds;
    if (ids == null || ids.isEmpty) return all;
    return all.where((l) => ids.contains(l.dialogue.characterId)).toList();
  }

  // 콜라보 내 배역 녹음 완료 표시(+축하). 1회만.
  Future<void> _markRoleDone() async {
    if (_roleMarked) return;
    _roleMarked = true;
    try {
      await Cloud.setMyRolesRecorded(widget.collabSessionId!);
    } catch (_) {}
    if (mounted) {
      HapticFeedback.heavyImpact();
      showCelebration(context);
    }
  }

  ({Cut cut, Dialogue dialogue})? get _current =>
      _lines.isEmpty ? null : _lines[_index];

  void _onRecordTap() {
    if (_recording) {
      _stopRecording();
    } else if (_countdown > 0) {
      _startNow(); // 카운트다운 중 다시 탭하면 즉시 시작
    } else {
      _beginCountdown();
    }
  }

  void _beginCountdown() {
    if (_current == null) return;
    HapticFeedback.lightImpact();
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 450), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        _startNow();
      } else {
        HapticFeedback.lightImpact();
        setState(() => _countdown--);
      }
    });
  }

  void _startNow() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != 0) setState(() => _countdown = 0);
    _startRecording();
  }

  Future<void> _startRecording() async {
    final line = _current;
    if (line == null) return;
    try {
      if (!await _recorder.hasPermission()) {
        _toast('마이크 권한이 필요해요.');
        return;
      }
      // 이전 녹음이 아직 안 끝났을 수 있어 확실히 정지
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      await _player.stop();
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/take_${line.dialogue.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      HapticFeedback.mediumImpact();
      _recordStartMs = DateTime.now().millisecondsSinceEpoch;
      // 레벨 스트림은 1회만 구독(record amplitude는 재구독 불가) → 세션 내내 유지.
      // 고정 길이 버퍼를 add/removeAt 없이 in-place 시프트.
      _ampSub ??= _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 90))
          .listen((amp) {
            if (!_recording || !mounted) return;
            final norm = ((amp.current + 50) / 50).clamp(0.0, 1.0);
            setState(() {
              _level = norm;
              for (var i = 0; i < _levels.length - 1; i++) {
                _levels[i] = _levels[i + 1];
              }
              _levels[_levels.length - 1] = norm;
            });
          }, onError: (_) {});
      setState(() => _recording = true);
    } catch (_) {
      if (mounted) {
        setState(() => _recording = false);
        _toast('녹음을 시작하지 못했어요.');
      }
    }
  }

  Future<void> _stopRecording() async {
    final line = _current;
    if (line == null) return;
    HapticFeedback.mediumImpact();
    final path = await _recorder.stop();
    final durationMs = DateTime.now().millisecondsSinceEpoch - _recordStartMs;
    // _ampSub은 취소하지 않고 유지(재구독 불가) — _recording=false면 무시됨
    setState(() {
      _recording = false;
      _level = 0;
      _levels.fillRange(0, _levels.length, 0);
      if (path != null) {
        _takes[line.dialogue.id] = path;
        _takeMs[line.dialogue.id] = durationMs < 300 ? 300 : durationMs;
      }
    });
    // 정지 즉시 클라우드 업로드
    if (path != null) {
      await _uploadTake(
        line.dialogue.id,
        path,
        durationMs < 300 ? 300 : durationMs,
      );
      // 아직 안 한 다음 장면으로 부드럽게 자동 이동
      if (mounted &&
          !_recording &&
          _index < _lines.length - 1 &&
          !_saved.contains(_lines[_index + 1].dialogue.id)) {
        await Future.delayed(const Duration(milliseconds: 380));
        if (mounted && !_recording) _go(1, auto: true);
      }
    }
  }

  Future<void> _playTake() async {
    final line = _current;
    final path = line == null ? null : _takes[line.dialogue.id];
    if (path == null) return;
    try {
      await _player.setFilePath(path);
      await _player.play();
    } catch (_) {
      _toast('재생할 수 없어요.');
    }
  }

  int _autoAdvanceAtMs = 0; // 자동 이동 시각 — 직후 무심코 누른 '다음' 흡수용

  void _go(int delta, {bool auto = false}) {
    if (_recording || _countdown > 0) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (auto) {
      _autoAdvanceAtMs = nowMs;
    } else if (delta > 0 && nowMs - _autoAdvanceAtMs < 900) {
      // 방금 녹음 후 자동으로 넘어갔는데 또 '다음'을 누름 → 건너뜀 방지(1회 흡수)
      _autoAdvanceAtMs = 0;
      return;
    }
    final next = _index + delta;
    if (next < 0 || next >= _lines.length) return;
    HapticFeedback.selectionClick();
    setState(() => _index = next);
  }

  void _toast(String msg) {
    showAppToast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.white54,
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  '작품을 불러오지 못했어요.',
                  style: GoogleFonts.notoSansKr(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    setState(() => _loadError = null);
                    _load();
                  },
                  child: const Text('다시 시도'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    '돌아가기',
                    style: GoogleFonts.notoSansKr(color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 76, animate: true, badge: false),
              const SizedBox(height: 18),
              Text(
                '무대를 준비하고 있어요…',
                style: GoogleFonts.notoSansKr(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final line = _current;
    if (line == null) {
      return Scaffold(
        appBar: AppBar(title: Text(detail.summary.title)),
        body: const Center(child: Text('녹음할 대사가 없어요.')),
      );
    }

    final doneCount = _lines
        .where((l) => _saved.contains(l.dialogue.id))
        .length;

    return Scaffold(
      backgroundColor: AppColors.deviceDark,
      // 영상 만들기는 그림을 가리지 않도록 floating 제거 → 하단 녹음 버튼이
      // 다 녹음되면 초록으로 바뀌고, 누르면 [영상 만들기/다시 녹음하기] 팝업.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 장면 (현재 컷) — 컷이 바뀌면 부드럽게 크로스페이드
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: SizedBox.expand(
              key: ValueKey(line.cut.id),
              child: NetworkThumb(url: line.cut.imageUrl),
            ),
          ),
          // 하단 가독성용 스크림 (장면은 비치되 자막은 또렷하게)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 440,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x73000000),
                      Color(0xE0000000),
                    ],
                    stops: [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // 상단 어둡게 + 컨트롤
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _topBar(detail, line, doneCount),
          ),
          // 하단 자막 + 컨트롤
          Positioned(left: 0, right: 0, bottom: 0, child: _bottomPanel(line)),
          // 3-2-1 카운트다운 오버레이
          if (_countdown > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: Tween(begin: 1.4, end: 0.8).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text(
                      '$_countdown',
                      key: ValueKey(_countdown),
                      style: GoogleFonts.notoSansKr(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 120,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 영상 만드는 중 오버레이
          if (_rendering) _renderOverlay(),
        ],
      ),
    );
  }

  Widget _renderOverlay() {
    final pct = (_renderProgress * 100).round();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 84, animate: true, badge: false),
              const SizedBox(height: 24),
              Text(
                '영상 만드는 중',
                style: GoogleFonts.notoSansKr(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              // 진행 바
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: _renderProgress.clamp(0.0, 1.0),
                      ),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, t, _) => FractionallySizedBox(
                        widthFactor: t,
                        child: Container(
                          height: 8,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.gold, AppColors.coral],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$pct%',
                style: GoogleFonts.notoSansKr(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '폰에서 직접 만들고 있어요.\n다른 작품 더빙하러 가도 돼요 — 완료되면 알림으로 알려드릴게요 🔔',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.home_rounded, size: 20),
                label: Text(
                  '나가서 기다리기',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(
    EpisodeDetail detail,
    ({Cut cut, Dialogue dialogue}) line,
    int done,
  ) {
    final total = _lines.length;
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.of(context).padding.top + 4,
        12,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 코너: 뒤로 / 초기화
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const Spacer(),
              if (done > 0 && !_isCollabRole)
                IconButton(
                  tooltip: '녹음 초기화',
                  onPressed: (_recording || _rendering)
                      ? null
                      : _resetRecordings,
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _progressBar(total == 0 ? 0 : done / total),
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  'CUT ${line.cut.order} / ${detail.cuts.length}',
                  style: GoogleFonts.notoSansKr(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '녹음 $done / $total',
                  style: GoogleFonts.notoSansKr(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(double value) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: Stack(
      children: [
        Container(height: 5, color: Colors.white.withValues(alpha: 0.18)),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          builder: (context, t, _) => FractionallySizedBox(
            widthFactor: t,
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gold, AppColors.coral],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // 다 녹음됐을 때 초록 버튼 → [영상 만들기 / 다시 녹음하기] 팝업
  Future<void> _showFinishSheet() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isCollabRole ? '내 배역 다 녹음했어요!' : '모든 컷을 다 녹음했어요! 🎉',
                style: GoogleFonts.notoSansKr(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isCollabRole ? '완료하면 합본 영상에 반영돼요.' : '이제 영상으로 만들 수 있어요.',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 20),
              if (_isCollabRole)
                _sheetButton(
                  '✓ 내 배역 완료하기',
                  filled: true,
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final nav = Navigator.of(context);
                    await _markRoleDone();
                    if (mounted) nav.maybePop();
                  },
                )
              else ...[
                _sheetButton(
                  '🎬 영상 만들기',
                  filled: true,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _makeVideo();
                  },
                ),
                const SizedBox(height: 10),
                _sheetButton(
                  '🎙 다시 녹음하기',
                  filled: false,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _onRecordTap(); // 현재 컷 다시 녹음
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetButton(
    String label, {
    required bool filled,
    required VoidCallback onTap,
  }) {
    const green = Color(0xFF35C75A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? green : AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: AppColors.line),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: filled ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel(({Cut cut, Dialogue dialogue}) line) {
    final hasTake = _takes.containsKey(line.dialogue.id);
    final next = _index < _lines.length - 1
        ? _lines[_index + 1].dialogue
        : null;
    final color = _colorOf(line.dialogue.character?.color);
    final d = line.dialogue;
    final allSaved =
        _lines.isNotEmpty &&
        _lines.every((l) => _saved.contains(l.dialogue.id));
    final readyToMake = allSaved && !_recording;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 화자 (작은 칩)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  d.speaker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
          // 지문(연기 지시) — 대사와 분리해 작고 흐리게
          if (d.direction.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              d.direction,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansKr(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                fontSize: 12.5,
                height: 1.3,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 현재 대사 — 노래방 메인 (크게·중앙·또렷)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.12),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              d.text,
              key: ValueKey(d.id),
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 30,
                height: 1.28,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 14,
                    offset: Offset(0, 2),
                  ),
                  Shadow(color: Colors.black54, blurRadius: 30),
                ],
              ),
            ),
          ),
          // 다음 한 줄 살짝 미리
          if (next != null) ...[
            const SizedBox(height: 14),
            Text(
              '다음  ${next.text}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansKr(
                color: Colors.white.withValues(alpha: 0.45),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ],
          if (_recording) ...[
            const SizedBox(height: 16),
            _WaveStrip(levels: _levels),
          ],
          // 완료 안내 (다 녹음됨)
          if (readyToMake) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF35C75A).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF35C75A).withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                '🎉 다 녹음했어요! 초록 버튼으로 영상 만들기',
                style: GoogleFonts.notoSansKr(
                  color: const Color(0xFF8FE3A6),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
          // 자동 이동 안내(처음 헷갈리지 않게)
          if (!_recording && !readyToMake) ...[
            const SizedBox(height: 14),
            Text(
              '녹음을 마치면 다음 컷으로 자동으로 넘어가요',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ],
          const SizedBox(height: 22),
          // 컨트롤
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleBtn(
                Icons.chevron_left_rounded,
                enabled: _index > 0 && !_recording,
                onTap: () => _go(-1),
              ),
              const SizedBox(width: 30),
              _RecordButton(
                recording: _recording,
                hasTake: hasTake,
                level: _level,
                done: readyToMake,
                onTap: readyToMake ? _showFinishSheet : _onRecordTap,
              ),
              const SizedBox(width: 30),
              _circleBtn(
                Icons.chevron_right_rounded,
                enabled: _index < _lines.length - 1 && !_recording,
                onTap: () => _go(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 듣기 + 상태 (한 줄, 중앙)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: hasTake ? _playTake : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  Icons.play_arrow_rounded,
                  color: hasTake ? Colors.white : Colors.white24,
                  size: 18,
                ),
                label: Text(
                  '내 녹음 듣기',
                  style: GoogleFonts.notoSansKr(
                    color: hasTake ? Colors.white70 : Colors.white24,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
              Builder(
                builder: (_) {
                  final id = d.id;
                  final up = _uploading.contains(id);
                  final saved = _saved.contains(id);
                  final (String label, Color c) = _recording
                      ? ('● 녹음 중', AppColors.coral)
                      : up
                      ? ('저장 중…', AppColors.gold)
                      : saved
                      ? ('저장됨 ✓', const Color(0xFF6FCF97))
                      : hasTake
                      ? ('녹음됨', Colors.white70)
                      : ('미녹음', Colors.white38);
                  return Text(
                    label,
                    style: GoogleFonts.notoSansKr(
                      color: c,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Color _colorOf(String? hex) {
    if (hex == null) return AppColors.coral;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return value == null ? AppColors.coral : Color(value);
  }
}

/// 녹음 버튼 — 펄스 링 + 목소리 크기(level)에 반응하는 글로우
class _RecordButton extends StatefulWidget {
  final bool recording;
  final bool hasTake;
  final bool done; // 모든 컷 녹음 완료 → 초록(영상 만들기 진입)
  final double level; // 0~1 실시간 입력 레벨
  final VoidCallback onTap;
  const _RecordButton({
    required this.recording,
    required this.hasTake,
    required this.level,
    required this.onTap,
    this.done = false,
  });

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.recording) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.recording && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF35C75A);
    final base = widget.recording
        ? AppColors.coral
        : (widget.done ? green : AppColors.gold);
    final level = widget.recording ? widget.level : 0.0;
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 펄스 링 2겹 (녹음 중에만)
          if (widget.recording)
            AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [_ring(_c.value), _ring((_c.value + 0.5) % 1.0)],
                );
              },
            ),
          // 목소리 크기에 반응하는 글로우
          if (widget.recording)
            AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              width: 70 + level * 42,
              height: 70 + level * 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coral.withValues(alpha: 0.18 + level * 0.22),
              ),
            ),
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: 1 + level * 0.07,
              duration: const Duration(milliseconds: 110),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: base,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: base.withValues(alpha: 0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(
                  widget.recording
                      ? Icons.stop_rounded
                      : widget.done
                      ? Icons.movie_creation_rounded
                      : widget.hasTake
                      ? Icons.refresh_rounded
                      : Icons.mic_rounded,
                  color: widget.done ? Colors.white : AppColors.ink,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double t) {
    final size = 64.0 + t * 40.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.coral.withValues(alpha: (1 - t) * 0.30),
      ),
    );
  }
}

/// 녹음 중 실시간 입력 파형 띠 (오른쪽이 최신)
class _WaveStrip extends StatelessWidget {
  final List<double> levels;
  const _WaveStrip({required this.levels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: double.infinity,
      child: CustomPaint(painter: _WavePainter(List<double>.of(levels))),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> levels;
  _WavePainter(this.levels);

  @override
  void paint(Canvas canvas, Size size) {
    final n = levels.length;
    if (n == 0) return;
    const gap = 3.0;
    final bw = (size.width - gap * (n - 1)) / n;
    final midy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      final h = 3 + levels[i] * (size.height - 3);
      final x = i * (bw + gap);
      paint.color = AppColors.coral.withValues(alpha: 0.25 + 0.6 * (i / n));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, midy - h / 2, bw, h),
          Radius.circular(bw / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}
