import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cloud.dart';
import '../config.dart';
import '../models.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import 'performer_screen.dart';

/// 초대 참여 — 공유 코드로 들어와 빈 배역을 맡고 내 배역만 더빙
class JoinScreen extends StatefulWidget {
  final String shareCode;
  const JoinScreen({super.key, required this.shareCode});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> with RouteAware {
  CollabView? _collab;
  String? _myId;
  String? _error;
  bool _needLogin = false;
  String? _busyRole;

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
  void didPopNext() => _load(); // 녹음 후 돌아오면 상태 갱신

  Future<void> _load() async {
    try {
      if (!Auth.isSignedIn) {
        if (mounted) setState(() => _needLogin = true);
        return;
      }
      final mine = await Cloud.myUserId();
      final c = await Cloud.collabByCode(widget.shareCode);
      if (mounted) {
        setState(() {
          _myId = mine;
          _collab = c;
          _error = c == null ? '초대를 찾을 수 없어요. 코드를 확인해 주세요.' : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _claim(CollabRoleView r) async {
    setState(() => _busyRole = r.roleId);
    final ok = await Cloud.claimRole(r.roleId);
    if (!mounted) return;
    setState(() => _busyRole = null);
    if (ok) {
      HapticFeedback.mediumImpact();
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 다른 사람이 맡은 배역이에요.')),
      );
      await _load();
    }
  }

  Future<void> _dub(CollabRoleView r) async {
    Navigator.of(context).push(fadeThroughRoute(PerformerScreen(
      episodeId: _collab!.episodeId,
      roleCharacterId: r.characterId,
      collabRoleId: r.roleId,
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_needLogin) return _loginPrompt();
    final c = _collab;
    return Scaffold(
      appBar: AppBar(
        title: Text('초대 더빙',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
      ),
      body: c == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansKr(
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted)),
                    )
                  : const CircularProgressIndicator(color: AppColors.coral),
            )
          : RefreshIndicator(
              color: AppColors.coral,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  _intro(c),
                  const SizedBox(height: 20),
                  Text('배역을 골라 맡아주세요',
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 10),
                  for (final r in c.roles) ...[
                    _roleRow(r),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _intro(CollabView c) => Container(
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
                  Text('${c.hostName}님의 초대',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted)),
                  const SizedBox(height: 3),
                  Text(c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('🎭 같이 더빙하고 한 영상으로 완성해요',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _roleRow(CollabRoleView r) {
    Color hex(String s) =>
        Color(int.parse('FF${s.replaceFirst('#', '')}', radix: 16));
    final mine = r.assignedUserId == _myId;
    final busy = _busyRole == r.roleId;

    Widget trailing;
    if (mine && !r.isRecorded) {
      trailing = FilledButton(
        onPressed: () => _dub(r),
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14)),
        child: Text('더빙하기',
            style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w900, fontSize: 13)),
      );
    } else if (r.isRecorded) {
      trailing = Text(mine ? '내 녹음 완료 ✓' : '완료 ✓',
          style: GoogleFonts.notoSansKr(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: AppColors.teal));
    } else if (r.isOpen) {
      trailing = OutlinedButton(
        onPressed: busy ? null : () => _claim(r),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14)),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text('맡기',
                style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w900, fontSize: 13)),
      );
    } else {
      trailing = Text('${r.assigneeName ?? "친구"}님이 맡음',
          style: GoogleFonts.notoSansKr(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: AppColors.muted));
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
                BoxDecoration(color: hex(r.color), shape: BoxShape.circle),
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

  Widget _loginPrompt() => Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 44, color: AppColors.faint),
                const SizedBox(height: 14),
                Text('로그인하고 참여해요',
                    style: GoogleFonts.notoSansKr(
                        fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 6),
                Text('초대 더빙에 참여하려면 로그인이 필요해요.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansKr(
                        fontSize: 13.5, color: AppColors.muted)),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text('확인',
                      style:
                          GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      );
}
