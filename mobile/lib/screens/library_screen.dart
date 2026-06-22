import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cloud.dart';
import '../config.dart';
import '../widgets/app_widgets.dart';
import 'home_screen.dart' show categoryLabels;
import 'performer_screen.dart';
import 'video_sheet.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<MyWork>? _works;
  String? _error;
  String? _opening; // 영상 여는 중인 performanceId

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final works = await Cloud.myWorks();
      if (mounted) {
        setState(() {
          _works = works;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _works = null;
      _error = null;
    });
    await _load();
  }

  Future<void> _openVideo(MyWork w) async {
    if (w.videoStorageKey == null) return;
    setState(() => _opening = w.performanceId);
    try {
      final url = await Cloud.signVideo(w.videoStorageKey!);
      if (mounted) showVideoSheet(context, url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('영상을 불러오지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _continue(MyWork w) async {
    await Navigator.of(
      context,
    ).push(fadeThroughRoute(PerformerScreen(episodeId: w.episodeId)));
    _refresh(); // 돌아오면 새 상태 반영
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '삭제할까요?',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
        ),
        content: const Text('이 더빙과 만든 영상이 모두 삭제돼요. 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deleteWork(MyWork w) async {
    setState(
      () => _works!.removeWhere((x) => x.performanceId == w.performanceId),
    );
    try {
      await Cloud.deleteWork(w.performanceId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해 주세요.')));
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.coral,
          backgroundColor: AppColors.card,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '보관함',
                        style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '내가 더빙한 작품과 완성한 영상',
                        style: GoogleFonts.notoSansKr(
                          color: AppColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _body(),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _centered(
          Icons.cloud_off_rounded,
          '보관함을 불러오지 못했어요.',
          action: OutlinedButton(
            onPressed: _refresh,
            child: const Text('다시 시도'),
          ),
        ),
      );
    }
    if (_works == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.coral),
          ),
        ),
      );
    }
    if (_works!.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _centered(
          Icons.mic_none_rounded,
          '아직 더빙한 작품이 없어요.',
          sub: '홈에서 작품을 골라 첫 더빙을 시작해보세요.',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      sliver: SliverList.separated(
        itemCount: _works!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final w = _works![i];
          return FadeInUp(
            index: i,
            child: Dismissible(
              key: ValueKey(w.performanceId),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(),
              onDismissed: (_) => _deleteWork(w),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              child: _WorkCard(
                work: w,
                opening: _opening == w.performanceId,
                onPlay: () => _openVideo(w),
                onContinue: () => _continue(w),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _centered(
    IconData icon,
    String title, {
    String? sub,
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.faint, size: 46),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.faint, fontSize: 13),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 16), action],
      ],
    ),
  );
}

class _WorkCard extends StatelessWidget {
  final MyWork work;
  final bool opening;
  final VoidCallback onPlay;
  final VoidCallback onContinue;
  const _WorkCard({
    required this.work,
    required this.opening,
    required this.onPlay,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      // IntrinsicHeight: Row(stretch) 안의 Stack(fit:expand) 썸네일이 무한 높이를
      // 받아 뷰포트가 안 그려지던 문제 방지(행 높이를 콘텐츠 기준으로 확정)
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 92,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkThumb(url: work.thumbnailUrl),
                  if (work.hasVideo)
                    Container(
                      color: Colors.black.withValues(alpha: 0.28),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        _tag(categoryLabels[work.category] ?? work.category),
                        const SizedBox(width: 6),
                        if (work.hasVideo)
                          _tag('영상 완성', bg: AppColors.gold, fg: AppColors.ink),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      work.episodeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '녹음 ${work.recordingCount}개',
                      style: GoogleFonts.notoSansKr(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (work.hasVideo)
                          _btn(
                            icon: Icons.play_arrow_rounded,
                            label: '영상 보기',
                            filled: true,
                            loading: opening,
                            onTap: onPlay,
                          ),
                        if (work.hasVideo) const SizedBox(width: 8),
                        _btn(
                          icon: Icons.mic_rounded,
                          label: '이어서 더빙',
                          filled: !work.hasVideo,
                          onTap: onContinue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, {Color? bg, Color? fg}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg ?? AppColors.cream,
      borderRadius: BorderRadius.circular(999),
      border: bg == null ? Border.all(color: AppColors.lineSoft) : null,
    ),
    child: Text(
      text,
      style: GoogleFonts.notoSansKr(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: fg ?? AppColors.muted,
      ),
    ),
  );

  Widget _btn({
    required IconData icon,
    required String label,
    required bool filled,
    bool loading = false,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: filled ? AppColors.ink : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.paper,
                ),
              )
            else
              Icon(
                icon,
                size: 16,
                color: filled ? AppColors.paper : AppColors.ink,
              ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: filled ? AppColors.paper : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
