import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cloud.dart';
import '../config.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';
import 'creator_screen.dart';
import 'performer_screen.dart';

/// 내가 만든(발행한) 만화 목록 — 더빙하러 가기 / 삭제
class MyEpisodesScreen extends StatefulWidget {
  /// embedded=true 이면 Scaffold의 appBar를 null로(상위 MyWorkScreen이 제목 표시)
  final bool embedded;
  const MyEpisodesScreen({super.key, this.embedded = false});

  @override
  State<MyEpisodesScreen> createState() => _MyEpisodesScreenState();
}

class _MyEpisodesScreenState extends State<MyEpisodesScreen> {
  List<({EpisodeSummary ep, int likes})>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await Cloud.myEpisodes();
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

  Future<void> _confirmDelete(EpisodeSummary ep) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          '만화를 삭제할까요?',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '"${ep.title}"이(가) 피드에서 사라지고 되돌릴 수 없어요.',
          style: GoogleFonts.notoSansKr(fontSize: 14),
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
              '삭제',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w900,
                color: AppColors.coral,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Cloud.deleteEpisode(ep.id);
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() => _items?.removeWhere((x) => x.ep.id == ep.id));
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, '삭제에 실패했어요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // embedded 모드: 상위 MyWorkScreen이 제목을 표시하므로 appBar 숨김
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                '내가 만든 만화',
                style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
              ),
            ),
      body: _error != null
          ? _errorView()
          : _items == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
          : _items!.isEmpty
          ? _empty()
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

  Widget _row(({EpisodeSummary ep, int likes}) item) {
    final ep = item.ep;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Pressable(
            onTap: () async {
              await Navigator.of(context).push(
                fadeThroughRoute(
                  PerformerScreen(episodeId: ep.id, canEdit: true),
                ),
              );
              if (mounted) _load();
            },
            child: SizedBox(
              width: 92,
              height: 92,
              child: ep.thumbnailUrl != null
                  ? Image.network(
                      ep.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.cream),
                    )
                  : Container(color: AppColors.cream),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ep.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: AppColors.coral,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '좋아요 ${item.likes}',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '수정',
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(fadeThroughRoute(CreatorScreen(episodeId: ep.id)));
              if (mounted) _load();
            },
            icon: const Icon(
              Icons.edit_rounded,
              color: AppColors.faint,
            ),
          ),
          IconButton(
            tooltip: '삭제',
            onPressed: () => _confirmDelete(ep),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.faint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Padding(
    padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
    child: Column(
      children: [
        const Icon(Icons.auto_stories_rounded, size: 48, color: AppColors.gold),
        const SizedBox(height: 16),
        Text(
          '아직 만든 만화가 없어요',
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () async {
            await Navigator.of(
              context,
            ).push(fadeThroughRoute(const CreatorScreen()));
            if (mounted) _load();
          },
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: Text(
            '만화 만들기',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.faint, size: 46),
          const SizedBox(height: 14),
          Text(
            '목록을 불러오지 못했어요.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansKr(
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _items = null;
                _error = null;
              });
              _load();
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    ),
  );

}
