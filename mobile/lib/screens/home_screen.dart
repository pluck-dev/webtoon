import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../models.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import '../widgets/brand_logo.dart';
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
              if (_error == null && _episodes != null && _episodes!.isNotEmpty)
                SliverToBoxAdapter(child: _filterChips()),
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
    final list = _visible;
    if (list.isEmpty) {
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

  Widget _header() {
    final email = Auth.currentUser?.email ?? '';
    final name = email.isEmpty ? '' : email.split('@').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandLogo(size: 32, animate: true),
              const SizedBox(width: 10),
              Text(
                '더빙고',
                style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '짧은 상황,\n내 목소리로 연기하세요.',
            style: GoogleFonts.notoSansKr(
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name.isEmpty ? '작품을 골라 첫 더빙을 시작해보세요.' : '$name 님, 오늘은 어떤 역을 맡아볼까요?',
            style: GoogleFonts.notoSansKr(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PerformerScreen(episodeId: episode.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
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
