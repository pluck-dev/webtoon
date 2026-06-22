import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../cloud.dart';
import '../config.dart';
import '../models.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import '../widgets/brand_logo.dart';
import 'video_sheet.dart';

class PerformerScreen extends StatefulWidget {
  final String episodeId;
  const PerformerScreen({super.key, required this.episodeId});

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
  final Set<String> _saved = {}; // 클라우드 저장된 dialogueId
  final Set<String> _uploading = {}; // 업로드 중
  String? _userId;
  String? _performanceId;
  bool _rendering = false;
  int _recordStartMs = 0;
  double _level = 0; // 실시간 마이크 입력 레벨 0~1
  StreamSubscription<Amplitude>? _ampSub;

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
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
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
      if (mounted) setState(() => _saved.add(dialogueId));
    } catch (_) {
      if (mounted) _toast('클라우드 저장에 실패했어요. 다시 녹음해 주세요.');
    } finally {
      if (mounted) setState(() => _uploading.remove(dialogueId));
    }
  }

  Future<void> _makeVideo() async {
    final perfId = _performanceId;
    if (perfId == null || _rendering) return;
    setState(() => _rendering = true);
    try {
      final jobId = await Cloud.createRenderJob(perfId);
      // 폴링 (최대 5분)
      for (var i = 0; i < 100; i++) {
        await Future.delayed(const Duration(seconds: 3));
        ({String status, String? videoUrl}) r;
        try {
          r = await Cloud.fetchRender(jobId);
        } catch (_) {
          continue;
        }
        if (r.status == 'DONE' && r.videoUrl != null) {
          if (mounted) {
            setState(() => _rendering = false);
            showVideoSheet(context, r.videoUrl!);
          }
          return;
        }
        if (r.status == 'FAILED') {
          if (mounted) {
            setState(() => _rendering = false);
            _toast('영상 생성에 실패했어요. 잠시 후 다시 시도해 주세요.');
          }
          return;
        }
      }
      if (mounted) {
        setState(() => _rendering = false);
        _toast('영상이 평소보다 오래 걸려요. 잠시 후 다시 확인해 주세요.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _rendering = false);
        _toast('영상 생성을 시작하지 못했어요.');
      }
    }
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  List<({Cut cut, Dialogue dialogue})> get _lines => _detail?.lines ?? [];
  ({Cut cut, Dialogue dialogue})? get _current =>
      _lines.isEmpty ? null : _lines[_index];

  Future<void> _toggleRecord() async {
    final line = _current;
    if (line == null) return;
    if (_recording) {
      HapticFeedback.mediumImpact();
      final path = await _recorder.stop();
      final durationMs = DateTime.now().millisecondsSinceEpoch - _recordStartMs;
      await _ampSub?.cancel();
      _ampSub = null;
      setState(() {
        _recording = false;
        _level = 0;
        if (path != null) _takes[line.dialogue.id] = path;
      });
      // 정지 즉시 클라우드 업로드
      if (path != null) {
        await _uploadTake(
          line.dialogue.id,
          path,
          durationMs < 300 ? 300 : durationMs,
        );
      }
      return;
    }
    if (!await _recorder.hasPermission()) {
      _toast('마이크 권한이 필요해요.');
      return;
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
    // 실시간 입력 레벨 구독 → 버튼 펄스가 목소리에 반응
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 110))
        .listen((amp) {
          // dBFS(-50~0)를 0~1로 정규화
          final norm = ((amp.current + 50) / 50).clamp(0.0, 1.0);
          if (mounted) setState(() => _level = norm);
        });
    setState(() => _recording = true);
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

  void _go(int delta) {
    if (_recording) return;
    final next = _index + delta;
    if (next < 0 || next >= _lines.length) return;
    setState(() => _index = next);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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
    final allSaved = _lines.isNotEmpty && doneCount == _lines.length;

    return Scaffold(
      backgroundColor: AppColors.deviceDark,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (allSaved && !_recording)
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.32,
              ),
              child: FloatingActionButton.extended(
                onPressed: _rendering ? null : _makeVideo,
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
                icon: _rendering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.ink,
                        ),
                      )
                    : const Icon(Icons.movie_creation_rounded),
                label: Text(
                  _rendering ? '영상 만드는 중…' : '영상 만들기',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
                ),
              ),
            )
          : null,
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
                height: 380,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x66000000),
                      Color(0xB3000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
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
        ],
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
              _pill('CUT ${line.cut.order} / ${detail.cuts.length}'),
              const Spacer(),
              _pill('$done / $total 완료', color: AppColors.gold),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _progressBar(total == 0 ? 0 : done / total),
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

  Widget _pill(String text, {Color color = Colors.white}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: GoogleFonts.notoSansKr(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    ),
  );

  Widget _bottomPanel(({Cut cut, Dialogue dialogue}) line) {
    final hasTake = _takes.containsKey(line.dialogue.id);
    final prev = _index > 0 ? _lines[_index - 1].dialogue : null;
    final next = _index < _lines.length - 1
        ? _lines[_index + 1].dialogue
        : null;
    final color = _colorOf(line.dialogue.character?.color);

    return Container(
      margin: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              // 반투명 + 블러: 뒤 장면이 비치되 자막은 또렷하게
              color: AppColors.panelDark.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 노래방 스크립트: 이전 / 현재 / 다음
                if (prev != null)
                  Text(
                    prev.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${line.dialogue.speaker}${line.dialogue.direction.isNotEmpty ? ' · ${line.dialogue.direction}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansKr(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                    line.dialogue.text,
                    key: ValueKey(line.dialogue.id),
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      height: 1.25,
                    ),
                  ),
                ),
                if (next != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '▾ ${next.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // 컨트롤: 이전 · 녹음 · 다음
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _circleBtn(
                      Icons.chevron_left_rounded,
                      enabled: _index > 0 && !_recording,
                      onTap: () => _go(-1),
                    ),
                    const SizedBox(width: 28),
                    _RecordButton(
                      recording: _recording,
                      hasTake: hasTake,
                      level: _level,
                      onTap: _toggleRecord,
                    ),
                    const SizedBox(width: 28),
                    _circleBtn(
                      Icons.chevron_right_rounded,
                      enabled: _index < _lines.length - 1 && !_recording,
                      onTap: () => _go(1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: hasTake ? _playTake : null,
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: hasTake ? Colors.white : Colors.white24,
                        size: 20,
                      ),
                      label: Text(
                        '내 녹음 듣기',
                        style: GoogleFonts.notoSansKr(
                          color: hasTake ? Colors.white70 : Colors.white24,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (_) {
                        final id = line.dialogue.id;
                        final up = _uploading.contains(id);
                        final saved = _saved.contains(id);
                        final (String label, Color c) = _recording
                            ? ('● 녹음 중', AppColors.coral)
                            : up
                            ? ('저장 중…', AppColors.gold)
                            : saved
                            ? ('클라우드 저장됨 ✓', const Color(0xFF6FCF97))
                            : hasTake
                            ? ('녹음됨', Colors.white70)
                            : ('미녹음', Colors.white38);
                        return Text(
                          label,
                          style: GoogleFonts.notoSansKr(
                            color: c,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
  final double level; // 0~1 실시간 입력 레벨
  final VoidCallback onTap;
  const _RecordButton({
    required this.recording,
    required this.hasTake,
    required this.level,
    required this.onTap,
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
    final base = widget.recording ? AppColors.coral : AppColors.gold;
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
                      : widget.hasTake
                      ? Icons.refresh_rounded
                      : Icons.mic_rounded,
                  color: AppColors.ink,
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
