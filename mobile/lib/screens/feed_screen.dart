import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cloud.dart';
import '../config.dart';
import '../models.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import 'author_screen.dart';
import 'comments_sheet.dart';
import 'creator_screen.dart';
import 'join_screen.dart';
import 'performer_screen.dart';

/// 공개 피드 — 사용자들이 만든 만화를 둘러보고 좋아요/나도 더빙
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with RouteAware {
  List<EpisodeSummary>? _eps;
  String? _error;
  String _sort = 'recent'; // recent | popular

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

  // 위에 쌓였던 화면(작가 에디터/더빙 등)이 닫혀 피드로 돌아오면 자동 새로고침
  @override
  void didPopNext() => _load();

  Future<void> _load() async {
    try {
      final eps = await Repo.fetchFeed(sort: _sort);
      if (mounted) {
        setState(() {
          _eps = eps;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _refresh() async {
    setState(() => _eps = null);
    await _load();
  }

  void _setSort(String s) {
    if (_sort == s) return;
    HapticFeedback.selectionClick();
    setState(() {
      _sort = s;
      _eps = null;
    });
    _load();
  }

  Future<void> _toggleLike(int index) async {
    final ep = _eps![index];
    // 낙관적 업데이트
    final liked = !ep.likedByMe;
    setState(() {
      _eps![index] = ep.copyWith(
        likedByMe: liked,
        likeCount: ep.likeCount + (liked ? 1 : -1),
      );
    });
    HapticFeedback.lightImpact();
    try {
      await Cloud.toggleLike(ep.id);
    } catch (_) {
      // 실패 시 롤백
      if (mounted) setState(() => _eps![index] = ep);
    }
  }

  void _openDub(EpisodeSummary ep) => Navigator.of(
    context,
  ).push(fadeThroughRoute(PerformerScreen(episodeId: ep.id)));

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
              SliverToBoxAdapter(child: _header()),
              if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _msgBox('피드를 불러오지 못했어요.\n당겨서 새로고침 해주세요.'),
                )
              else if (_eps == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  ),
                )
              else if (_eps!.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyBox())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: _eps!.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _card(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '피드',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '모두가 만든 만화',
                style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
            ),
            const Spacer(),
            // 초대 코드로 참여
            Pressable(
              onTap: _joinByCode,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_add_rounded,
                        size: 16, color: AppColors.ink),
                    const SizedBox(width: 5),
                    Text('초대코드',
                        style: GoogleFonts.notoSansKr(
                            fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _sortChip('최신', 'recent'),
            const SizedBox(width: 8),
            _sortChip('인기', 'popular'),
          ],
        ),
      ],
    ),
  );

  Widget _sortChip(String label, String value) {
    final sel = _sort == value;
    return Pressable(
      onTap: () => _setSort(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? AppColors.ink : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: sel ? AppColors.ink : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value == 'popular'
                  ? Icons.local_fire_department_rounded
                  : Icons.schedule_rounded,
              size: 15,
              color: sel ? AppColors.gold : AppColors.muted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: sel ? AppColors.paper : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(int i) {
    final ep = _eps![i];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 썸네일 (탭 → 더빙)
          Pressable(
            onTap: () => _openDub(ep),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (ep.thumbnailUrl != null)
                    Image.network(
                      ep.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.cream),
                      loadingBuilder: (c, w, p) => p == null
                          ? w
                          : Container(color: AppColors.cream),
                    )
                  else
                    Container(color: AppColors.cream),
                  // 하단 스크림 + 제목
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 28, 14, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.62),
                          ],
                        ),
                      ),
                      child: Text(
                        ep.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansKr(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  // 댓글 · 좋아요 알약 (탭 → 시트 / 토글)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _commentPill(i, ep),
                        const SizedBox(width: 6),
                        _likePill(i, ep),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 푸터: 작가 + 나도 더빙
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
            child: Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: ep.creatorId == null
                        ? null
                        : () => Navigator.of(context).push(
                            fadeThroughRoute(
                              AuthorScreen(
                                creatorId: ep.creatorId!,
                                authorName: ep.author ?? '익명 작가',
                              ),
                            ),
                          ),
                    child: Row(
                      children: [
                        _avatar(ep.author),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            ep.author ?? '익명 작가',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansKr(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onTap: () => _openDub(ep),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mic_rounded,
                          size: 15,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '나도 더빙',
                          style: GoogleFonts.notoSansKr(
                            color: AppColors.paper,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinByCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('초대 코드로 참여',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(hintText: '예: a1b2c3d4'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소',
                style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w800, color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('참여',
                style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty && mounted) {
      Navigator.of(context).push(fadeThroughRoute(JoinScreen(shareCode: code)));
    }
  }

  Future<void> _openComments(EpisodeSummary ep) async {
    await showCommentsSheet(context, ep.id, ep.commentCount);
    // 시트는 PageRoute가 아니라 자동 새로고침이 안 되므로 직접 갱신
    if (mounted) _load();
  }

  Widget _commentPill(int i, EpisodeSummary ep) => Pressable(
    onTap: () => _openComments(ep),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.mode_comment_outlined,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            '${ep.commentCount}',
            style: GoogleFonts.notoSansKr(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _likePill(int i, EpisodeSummary ep) => Pressable(
    onTap: () => _toggleLike(i),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ep.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 15,
            color: ep.likedByMe ? AppColors.coral : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            '${ep.likeCount}',
            style: GoogleFonts.notoSansKr(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _avatar(String? name) {
    final ch = (name == null || name.isEmpty) ? '?' : name.characters.first;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.teal,
        shape: BoxShape.circle,
      ),
      child: Text(
        ch,
        style: GoogleFonts.notoSansKr(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _emptyBox() => Padding(
    padding: const EdgeInsets.fromLTRB(32, 40, 32, 80),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.gold),
        const SizedBox(height: 16),
        Text(
          '아직 공개된 창작 만화가 없어요',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '첫 번째 작가가 되어보세요!',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(fadeThroughRoute(const CreatorScreen())),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: Text(
            '만화 만들기',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );

  Widget _msgBox(String m) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        m,
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSansKr(
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    ),
  );
}
