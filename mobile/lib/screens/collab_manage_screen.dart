import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../cloud.dart';
import '../config.dart';
import '../local_render.dart';
import '../models.dart';
import '../notify.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import 'performer_screen.dart';
import 'video_sheet.dart';

/// 콜라보 관리 — 배역 진행 상황, 초대 공유, 내 배역 더빙, (호스트) 완성하기
class CollabManageScreen extends StatefulWidget {
  final String shareCode;
  const CollabManageScreen({super.key, required this.shareCode});

  @override
  State<CollabManageScreen> createState() => _CollabManageScreenState();
}

class _CollabManageScreenState extends State<CollabManageScreen>
    with RouteAware {
  CollabView? _collab;
  String? _myId;
  String? _error;
  bool _rendering = false;
  double _renderProgress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _load();

  bool get _isHost => _collab != null && _collab!.hostUserId == _myId;

  Future<void> _load() async {
    try {
      final mine = await Cloud.myUserId();
      final c = await Cloud.collabByCode(widget.shareCode);
      if (mounted) {
        setState(() {
          _myId = mine;
          _collab = c;
          _error = c == null ? '세션을 찾을 수 없어요.' : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Color _hexColor(String? s) {
    if (s == null) return AppColors.coral;
    final v = s.replaceAll('#', '');
    final n = int.tryParse(v.length == 6 ? 'FF$v' : v, radix: 16);
    return n == null ? AppColors.coral : Color(n);
  }

  void _share() {
    final c = _collab;
    if (c == null) return;
    final open =
        c.roles.where((r) => r.isOpen).map((r) => r.characterName).join(', ');
    final msg = StringBuffer()
      ..writeln('쩌렁쩌렁에서 "${c.title}" 같이 더빙해요! 🎭')
      ..writeln(open.isEmpty ? '' : '비어있는 배역: $open')
      ..writeln(Env.collabLink(c.shareCode))
      ..write('(앱 피드 > 초대코드: ${c.shareCode})');
    Share.share(msg.toString().trim());
    HapticFeedback.selectionClick();
  }

  void _dubRole(CollabRoleView r) {
    final c = _collab!;
    // 내 미녹음 배역 전부를 한 번에 녹음(여러 배역이면 모두)
    final myChars = c.roles
        .where((x) => x.assignedUserId == _myId && !x.isRecorded)
        .map((x) => x.characterId)
        .toSet();
    if (myChars.isEmpty) myChars.add(r.characterId);
    Navigator.of(context).push(fadeThroughRoute(PerformerScreen(
      episodeId: c.episodeId,
      roleCharacterIds: myChars,
      collabSessionId: c.sessionId,
    )));
  }

  Future<void> _viewVideo() async {
    final key = _collab?.videoId;
    if (key == null) return;
    try {
      final url = await Cloud.signedVideoUrl(key);
      if (mounted) showVideoSheet(context, url);
    } catch (_) {
      if (mounted) _snack('영상을 불러오지 못했어요.');
    }
  }

  Future<void> _compose() async {
    final c = _collab;
    if (c == null || _rendering) return;
    setState(() {
      _rendering = true;
      _renderProgress = 0;
    });
    await Notify.requestPermission();
    await Notify.startRender();
    try {
      final detail = await Repo.fetchEpisodeDetail(c.episodeId);
      final meta = await Cloud.collabRenderMeta(c.sessionId);
      final hostPerf = await Cloud.getOrCreatePerformance(c.episodeId, _myId!);
      final lines = <RenderLine>[];
      var total = 0;
      for (final l in detail.lines) {
        final m = meta[l.dialogue.id];
        if (m == null) throw Exception('녹음 누락');
        final path = await Cloud.downloadRecording(m.storageKey);
        total += m.durationMs;
        lines.add(RenderLine(
          imageUrl: l.cut.imageUrl,
          speaker: l.dialogue.speaker,
          direction: l.dialogue.direction,
          text: l.dialogue.text,
          color: _hexColor(l.dialogue.character?.color),
          audioPath: path,
          durationMs: m.durationMs,
        ));
      }
      final out = await LocalRender.render(lines, onProgress: (p) {
        if (mounted) setState(() => _renderProgress = p);
        Notify.updateRender((p * 100).round());
      });
      final saved = await Cloud.saveCollabVideo(hostPerf, out, total);
      await Cloud.completeCollab(c.sessionId, saved.key);
      await Notify.stopRender();
      await Notify.renderDone();
      if (mounted) {
        setState(() => _rendering = false);
        await _load();
        if (mounted) showVideoSheet(context, saved.url);
      }
    } catch (_) {
      await Notify.stopRender();
      if (mounted) {
        setState(() => _rendering = false);
        _snack('합본 만들기에 실패했어요. 모든 배역이 녹음됐는지 확인해 주세요.');
      }
    }
  }

  void _snack(String m) => showAppToast(context, m);

  @override
  Widget build(BuildContext context) {
    final c = _collab;
    return Scaffold(
      appBar: AppBar(
        title: Text('초대 더빙',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
      ),
      body: Stack(
        children: [
          c == null
              ? Center(
                  child: _error != null
                      ? Text(_error!,
                          style: GoogleFonts.notoSansKr(
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted))
                      : const CircularProgressIndicator(
                          color: AppColors.coral),
                )
              : RefreshIndicator(
                  color: AppColors.coral,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    children: [
                      _headerCard(c),
                      const SizedBox(height: 20),
                      Text('배역 (${c.roles.length})',
                          style: GoogleFonts.notoSansKr(
                              fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 10),
                      for (final r in c.roles) ...[
                        _roleRow(r),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
          if (_rendering) _renderOverlay(),
        ],
      ),
      bottomSheet: c == null || _rendering ? null : _bottomBar(c),
    );
  }

  Widget _headerCard(CollabView c) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: c.thumbnailUrl != null
                    ? Image.network(c.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: AppColors.cream))
                    : Container(color: AppColors.cream),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('배역 ${c.recordedCount}/${c.roles.length} 완료',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                      c.isComplete
                          ? '✅ 완성됐어요!'
                          : c.isReady
                              ? '🎬 모두 녹음 완료 — 완성할 수 있어요'
                              : '👥 친구를 초대해 배역을 채워주세요',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _roleRow(CollabRoleView r) {
    final mine = r.assignedUserId == _myId;
    Widget trailing;
    if (mine && !r.isRecorded) {
      // Row 안에서는 Material 버튼 대신 Pressable 알약 사용(렌더 이슈 회피)
      trailing = Pressable(
        onTap: () => _dubRole(r),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('더빙',
              style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppColors.paper)),
        ),
      );
    } else {
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor(r).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(_statusLabel(r),
            style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: _statusColor(r))),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? AppColors.gold : AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: _hexColor(r.color), shape: BoxShape.circle),
            child: Text(
                r.characterName.isEmpty ? '?' : r.characterName.characters.first,
                style: GoogleFonts.notoSansKr(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(r.characterName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          trailing,
        ],
      ),
    );
  }

  String _statusLabel(CollabRoleView r) {
    if (r.isRecorded) return '완료';
    if (r.isOpen) return '초대 대기';
    return '${r.assigneeName ?? "친구"} 녹음 중';
  }

  Color _statusColor(CollabRoleView r) {
    if (r.isRecorded) return AppColors.teal;
    if (r.isOpen) return AppColors.coral;
    return AppColors.gold;
  }

  Widget _bottomBar(CollabView c) {
    Widget btn;
    if (c.isComplete) {
      btn = FilledButton.icon(
        onPressed: _viewVideo,
        icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
        label: Text('완성 영상 보기',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
      );
    } else if (c.isReady && _isHost) {
      btn = FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
        onPressed: _compose,
        icon: const Icon(Icons.movie_creation_rounded,
            size: 20, color: AppColors.ink),
        label: Text('합본 영상 완성하기',
            style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w900, color: AppColors.ink)),
      );
    } else {
      btn = FilledButton.icon(
        onPressed: _share,
        icon: const Icon(Icons.ios_share_rounded, size: 18),
        label: Text('초대 링크 공유',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: SizedBox(width: double.infinity, child: btn),
    );
  }

  Widget _renderOverlay() => Container(
        color: AppColors.deviceDark.withValues(alpha: 0.92),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_creation_rounded,
                  color: AppColors.gold, size: 48),
              const SizedBox(height: 16),
              Text('합본 영상 만드는 중',
                  style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 8),
              Text('${(_renderProgress * 100).round()}%',
                  style: GoogleFonts.notoSansKr(
                      color: AppColors.gold, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: _renderProgress == 0 ? null : _renderProgress,
                  backgroundColor: Colors.white24,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ),
      );
}
