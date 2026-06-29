import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cloud.dart';
import '../config.dart';
import '../models.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import 'auth_screen.dart';
import 'collab_manage_screen.dart';
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
      showAppToast(context, '이미 다른 사람이 맡은 배역이에요.');
      await _load();
    }
  }

  Future<void> _dub(CollabRoleView r) async {
    Navigator.of(context).push(
      fadeThroughRoute(
        PerformerScreen(
          episodeId: _collab!.episodeId,
          roleCharacterIds: {r.characterId},
          collabSessionId: _collab!.sessionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_needLogin) return _loginPrompt();
    final c = _collab;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '초대 더빙',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
        ),
      ),
      body: c == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(color: AppColors.coral),
            )
          : RefreshIndicator(
              color: AppColors.coral,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: c.isRemix
                    ? _remixBody(c)
                    : [
                        _intro(c),
                        const SizedBox(height: 20),
                        Text(
                          '배역을 골라 맡아주세요',
                          style: GoogleFonts.notoSansKr(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
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

  // REMIX(각자 버전): 내가 더빙해 내 영상 만들기
  List<Widget> _remixBody(CollabView c) {
    final hostRoles = c.roles.where((r) => r.assignedUserId == c.hostUserId);
    final openRoles = c.roles.where((r) => r.assignedUserId != c.hostUserId);
    return [
      _intro(c),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.movie_filter_rounded, size: 15),
                const SizedBox(width: 6),
                Text(
                  '각자 버전 더빙',
                  style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${c.hostName}님의 배역(${hostRoles.map((r) => r.characterName).join(', ')})은 그대로 두고, '
              '나머지(${openRoles.map((r) => r.characterName).join(', ')})를 내가 더빙해서 '
              '나만의 영상을 만들어요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                height: 1.4,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _busyRole == 'remix' ? null : _startRemix,
          icon: _busyRole == 'remix'
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.paper,
                  ),
                )
              : const Icon(Icons.mic_rounded, size: 20),
          label: Text(
            '나도 더빙 시작하기',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    ];
  }

  Future<void> _startRemix() async {
    setState(() => _busyRole = 'remix');
    try {
      final forkCode = await Cloud.joinRemix(widget.shareCode);
      if (forkCode == null) {
        if (mounted) {
          setState(() => _busyRole = null);
          showAppToast(context, '참여하지 못했어요. 잠시 후 다시 시도해 주세요.');
        }
        return;
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          fadeThroughRoute(CollabManageScreen(shareCode: forkCode)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busyRole = null);
        showAppToast(context, '참여하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  // 비로그인 상태에서 로그인 화면으로 이동 — 코드 보존 후 로그인 성공 시 복귀
  Future<void> _goLogin() async {
    await Navigator.of(context).push(
      fadeThroughRoute(const AuthScreen(returnOnAuth: true)),
    );
    if (!mounted) return;
    if (Auth.isSignedIn) {
      setState(() => _needLogin = false);
      await _load();
    }
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
                ? Image.network(
                    c.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: AppColors.cream),
                  )
                : Container(color: AppColors.cream),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${c.hostName}님의 초대',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                c.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '같이 더빙하고 한 영상으로 완성해요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSoft,
                ),
              ),
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

    // 앱 표준 Pressable 알약 버튼 (Material 버튼은 Row 안에서 렌더 이슈가 있어 사용 안 함)
    Widget pill(
      String label,
      Color bg,
      Color fg,
      VoidCallback? onTap, {
      bool spin = false,
      bool outline = false,
    }) => Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: outline ? Border.all(color: AppColors.line) : null,
        ),
        child: spin
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                label,
                style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: fg,
                ),
              ),
      ),
    );

    Widget trailing;
    if (mine && !r.isRecorded) {
      trailing = pill('더빙하기', AppColors.ink, AppColors.paper, () => _dub(r));
    } else if (r.isRecorded) {
      trailing = Text(
        mine ? '내 녹음 완료' : '완료',
        style: GoogleFonts.notoSansKr(
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
          color: AppColors.teal,
        ),
      );
    } else if (r.isOpen) {
      trailing = pill(
        '맡기',
        AppColors.gold,
        AppColors.ink,
        busy ? null : () => _claim(r),
        spin: busy,
      );
    } else {
      trailing = Flexible(
        child: Text(
          '${r.assigneeName ?? "친구"}님이 맡음',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: AppColors.muted,
          ),
        ),
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
            decoration: BoxDecoration(
              color: hex(r.color),
              shape: BoxShape.circle,
            ),
            child: Text(
              r.characterName.isEmpty ? '?' : r.characterName.characters.first,
              style: GoogleFonts.notoSansKr(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              r.characterName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
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
            const Icon(
              Icons.lock_outline_rounded,
              size: 44,
              color: AppColors.faint,
            ),
            const SizedBox(height: 14),
            Text(
              '로그인하고 참여해요',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '초대 더빙에 참여하려면 로그인이 필요해요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 13.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _goLogin,
                icon: const Icon(Icons.login_rounded, size: 20),
                label: Text(
                  '로그인하러 가기',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(
                '돌아가기',
                style: GoogleFonts.notoSansKr(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
