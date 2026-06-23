import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cloud.dart';
import '../config.dart';
import '../widgets/app_widgets.dart';
import 'collab_manage_screen.dart';

/// 내 초대 더빙 — 호스트/참여 중인 콜라보 목록
class CollabListScreen extends StatefulWidget {
  const CollabListScreen({super.key});

  @override
  State<CollabListScreen> createState() => _CollabListScreenState();
}

class _CollabListScreenState extends State<CollabListScreen> with RouteAware {
  List<Map<String, dynamic>>? _items;
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
  void didPopNext() => _load();

  Future<void> _load() async {
    try {
      final items = await Cloud.myCollabs();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  String _statusText(Map<String, dynamic> m) {
    final s = m['status'] as String? ?? 'OPEN';
    final rec = m['recorded'] ?? 0;
    final total = m['total'] ?? 0;
    if (s == 'COMPLETE') return '✅ 완성됨';
    if (s == 'READY') return '🎬 완성 대기';
    return '🎭 배역 $rec/$total';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 초대 더빙',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
      ),
      body: _error != null
          ? _msg('목록을 불러오지 못했어요.')
          : _items == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.coral))
              : _items!.isEmpty
                  ? _msg('진행 중인 초대 더빙이 없어요.\n만화를 만들 때 "친구와 같이 더빙"을 골라보세요!')
                  : RefreshIndicator(
                      color: AppColors.coral,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        itemCount: _items!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _row(_items![i]),
                      ),
                    ),
    );
  }

  Widget _row(Map<String, dynamic> m) {
    final thumb = m['thumbnailUrl'] as String?;
    final isHost = m['isHost'] == true;
    return Pressable(
      onTap: () => Navigator.of(context).push(fadeThroughRoute(
          CollabManageScreen(shareCode: m['shareCode'] as String))),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: thumb != null
                  ? Image.network(thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.cream))
                  : Container(color: AppColors.cream),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text((m['title'] ?? '') as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansKr(
                            fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isHost ? AppColors.gold : AppColors.teal)
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(isHost ? '내가 호스트' : '참여 중',
                              style: GoogleFonts.notoSansKr(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color:
                                      isHost ? AppColors.ink : AppColors.teal)),
                        ),
                        const SizedBox(width: 8),
                        Text(_statusText(m),
                            style: GoogleFonts.notoSansKr(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child:
                  Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _msg(String m) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(m,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w700, color: AppColors.muted)),
        ),
      );
}
