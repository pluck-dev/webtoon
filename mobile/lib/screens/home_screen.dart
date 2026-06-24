import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../models.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import '../widgets/brand_logo.dart';
import 'creator_screen.dart';
import 'performer_screen.dart';

const categoryLabels = {
  'WEBTOON': '웹툰체',
  'ROLEPLAY': '상황극',
  'ANIMATION': '애니메이션',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<EpisodeSummary>? _episodes;
  String? _error;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final eps = await Repo.fetchEpisodes();
      if (mounted) {
        setState(() {
          _episodes = eps;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _episodes = null;
      _error = null;
    });
    await _load();
  }

  List<EpisodeSummary> get _visible {
    final all = _episodes ?? [];
    if (_filter == 'ALL') return all;
    return all.where((e) => e.category == _filter).toList();
  }

  // 오늘의 추천 캐러셀: 전체 보기 + 작품 2개 이상일 때 상위 5개를 가로 캐러셀로
  List<EpisodeSummary> get _carousel {
    final all = _episodes ?? [];
    if (_filter != 'ALL' || all.length < 2) return [];
    return all.take(5).toList();
  }

  // 둘러보기 그리드 (추천으로 뽑힌 작품은 전체보기일 때 제외해 중복 방지)
  List<EpisodeSummary> get _gridList =>
      _filter != 'ALL' ? _visible : (_episodes ?? []).skip(_carousel.length).toList();

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
              SliverToBoxAdapter(child: _aiBanner()),
              if (_carousel.isNotEmpty)
                SliverToBoxAdapter(child: _carouselSection()),
              if (_error == null && _episodes != null && _episodes!.isNotEmpty)
                SliverToBoxAdapter(child: _browseHeader()),
              _body(),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 100,
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
        child: _errorBox(_error!),
      );
    }
    if (_episodes == null) {
      // 로딩 스켈레톤
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        sliver: SliverGrid(
          gridDelegate: _gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (_, _) => const SkeletonCard(),
            childCount: 6,
          ),
        ),
      );
    }
    final list = _gridList;
    if (list.isEmpty) {
      // 추천 캐러셀이 떠 있으면 빈 박스 대신 아무것도 안 보여줌
      if (_carousel.isNotEmpty) {
        return const SliverToBoxAdapter(child: SizedBox());
      }
      return SliverFillRemaining(hasScrollBody: false, child: _emptyBox());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, i) => FadeInUp(
            index: i,
            child: _EpisodeCard(episode: list[i]),
          ),
          childCount: list.length,
        ),
      ),
    );
  }

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 14,
    mainAxisSpacing: 14,
    childAspectRatio: 0.62,
  );

  // 오늘의 추천 — 가로 캐러셀 섹션
  Widget _carouselSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text(
            '오늘의 추천',
            style: GoogleFonts.notoSansKr(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        _FeaturedCarousel(items: _carousel),
      ],
    );
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    final who = name.isEmpty ? '' : '$name 님, ';
    if (h < 6) return '$who늦은 밤이에요 🌙';
    if (h < 12) return '$who좋은 아침이에요 ☀️';
    if (h < 18) return '$who좋은 오후예요 🎬';
    return '$who편안한 저녁이에요 🌆';
  }

  // AI 창작 전면 배너 — 홈 상단에서 핵심 기능(AI로 만들기)을 바로 진입
  Widget _aiBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Pressable(
        onTap: () => Navigator.of(context)
            .push(fadeThroughRoute(const CreatorScreen())),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2B2622), AppColors.ink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppShadows.elevated,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF6CE7E), AppColors.gold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.ink, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI로 웹툰 만들기',
                          style: GoogleFonts.notoSansKr(
                            color: AppColors.paper,
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'NEW',
                            style: GoogleFonts.notoSansKr(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '상황만 적으면 컷·대사·그림까지 자동으로',
                      style: GoogleFonts.notoSansKr(
                        color: AppColors.paper.withValues(alpha: 0.72),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.gold, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 컴팩트 헤더 — 로고 + (제목/인사) 한 줄. 콘텐츠를 빨리 노출.
  Widget _header() {
    final email = Auth.currentUser?.email ?? '';
    final name = email.isEmpty ? '' : email.split('@').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 18, 4),
      child: Row(
        children: [
          const BrandLogo(size: 34, animate: true),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '쩌렁쩌렁',
                  style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _greeting(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // '둘러보기' 섹션 헤더 + 필터칩
  Widget _browseHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Text(
            '둘러보기',
            style: GoogleFonts.notoSansKr(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        _filterChips(),
      ],
    );
  }

  Widget _filterChips() {
    final cats = <String>[
      'ALL',
      ...{for (final e in _episodes!) e.category},
    ];
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = cats[i];
          final selected = _filter == cat;
          final label = cat == 'ALL' ? '전체' : (categoryLabels[cat] ?? cat);
          return Pressable(
            onTap: () => setState(() => _filter = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppColors.ink : AppColors.line,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: selected ? AppColors.paper : AppColors.inkSoft,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyBox() => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.theaters_outlined, color: AppColors.faint, size: 44),
        const SizedBox(height: 14),
        Text(
          _filter == 'ALL' ? '아직 공개된 작품이 없어요.' : '이 카테고리엔 작품이 없어요.',
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
          ),
        ),
        if (_filter != 'ALL') ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _filter = 'ALL'),
            child: const Text('전체 보기'),
          ),
        ],
      ],
    ),
  );

  Widget _errorBox(String msg) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.muted, size: 40),
        const SizedBox(height: 12),
        Text(
          '작품을 불러오지 못했어요.',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.faint, fontSize: 12),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _refresh, child: const Text('다시 시도')),
      ],
    ),
  );
}

class _EpisodeCard extends StatelessWidget {
  final EpisodeSummary episode;
  const _EpisodeCard({required this.episode});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.of(
        context,
      ).push(fadeThroughRoute(PerformerScreen(episodeId: episode.id))),
      child: Container(
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
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkThumb(url: episode.thumbnailUrl),
                  // 하단 가독성 그라데이션
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x55000000)],
                        stops: [0.55, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mic_rounded,
                            color: AppColors.gold,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${episode.maxSeconds}초',
                            style: GoogleFonts.notoSansKr(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Text(
                      categoryLabels[episode.category] ?? episode.category,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    episode.logline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 오늘의 추천 가로 캐러셀 (스와이프 + 페이지 점)
class _FeaturedCarousel extends StatefulWidget {
  final List<EpisodeSummary> items;
  const _FeaturedCarousel({required this.items});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  late final PageController _ctrl =
      PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: items.length,
            padEnds: false,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(left: 16, right: i == items.length - 1 ? 16 : 4),
              child: _card(items[i]),
            ),
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final on = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: on ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: on ? AppColors.ink : AppColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _card(EpisodeSummary ep) {
    return Pressable(
      onTap: () => Navigator.of(context)
          .push(fadeThroughRoute(PerformerScreen(episodeId: ep.id))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadows.elevated,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkThumb(url: ep.thumbnailUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xD9000000)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      categoryLabels[ep.category] ?? ep.category,
                      style: GoogleFonts.notoSansKr(
                        color: AppColors.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ep.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ep.logline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansKr(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mic_rounded,
                                size: 15, color: AppColors.ink),
                            const SizedBox(width: 4),
                            Text(
                              '더빙하기',
                              style: GoogleFonts.notoSansKr(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
