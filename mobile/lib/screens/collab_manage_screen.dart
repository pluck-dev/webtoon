import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../cloud.dart';
import '../config.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';

/// 콜라보 관리 — 호스트/참여자가 배역 진행 상황을 보고 초대 링크를 공유
class CollabManageScreen extends StatefulWidget {
  final String shareCode;
  const CollabManageScreen({super.key, required this.shareCode});

  @override
  State<CollabManageScreen> createState() => _CollabManageScreenState();
}

class _CollabManageScreenState extends State<CollabManageScreen> with RouteAware {
  CollabView? _collab;
  String? _myId;
  String? _error;

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
  void didPopNext() => _load(); // 더빙 화면 등에서 돌아오면 새로고침

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

  void _share() {
    final c = _collab;
    if (c == null) return;
    final open = c.roles.where((r) => r.isOpen).map((r) => r.characterName).join(', ');
    final msg = StringBuffer()
      ..writeln('쩌렁쩌렁에서 "${c.title}" 같이 더빙해요! 🎭')
      ..writeln(open.isEmpty ? '' : '비어있는 배역: $open')
      ..writeln(Env.collabLink(c.shareCode))
      ..write('(앱에서 초대코드: ${c.shareCode})');
    Share.share(msg.toString().trim());
    HapticFeedback.selectionClick();
  }

  String _statusLabel(CollabRoleView r) {
    if (r.isRecorded) return '완료';
    if (r.isOpen) return '초대 대기';
    final me = r.assignedUserId == _myId;
    return me ? '내 차례 (녹음 전)' : '${r.assigneeName ?? "친구"} 녹음 중';
  }

  Color _statusColor(CollabRoleView r) {
    if (r.isRecorded) return AppColors.teal;
    if (r.isOpen) return AppColors.coral;
    return AppColors.gold;
  }

  @override
  Widget build(BuildContext context) {
    final c = _collab;
    return Scaffold(
      appBar: AppBar(
        title: Text('초대 더빙',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
      ),
      body: c == null
          ? Center(
              child: _error != null
                  ? Text(_error!,
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w700, color: AppColors.muted))
                  : const CircularProgressIndicator(color: AppColors.coral),
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
      bottomSheet: c == null ? null : _shareBar(c),
    );
  }

  Widget _headerCard(CollabView c) {
    final done = c.roles.where((r) => r.isRecorded).length;
    return Container(
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
                Text('배역 $done/${c.roles.length} 완료',
                    style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(
                    c.status == 'COMPLETE'
                        ? '✅ 완성됨'
                        : c.status == 'READY'
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
  }

  Widget _roleRow(CollabRoleView r) {
    Color hex(String s) {
      final v = s.replaceFirst('#', '');
      return Color(int.parse('FF$v', radix: 16));
    }

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
            decoration: BoxDecoration(color: hex(r.color), shape: BoxShape.circle),
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
          Container(
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
          ),
        ],
      ),
    );
  }

  Widget _shareBar(CollabView c) => Container(
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          border: Border(top: BorderSide(color: AppColors.lineSoft)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text('초대 링크 공유',
                style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
          ),
        ),
      );
}
