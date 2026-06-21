import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../models.dart';
import '../repo.dart';
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
  late Future<List<EpisodeSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = Repo.fetchEpisodes();
  }

  Future<void> _refresh() async {
    setState(() => _future = Repo.fetchEpisodes());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.coral,
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              FutureBuilder<List<EpisodeSummary>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
                    );
                  }
                  if (snap.hasError) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _errorBox('${snap.error}'),
                    );
                  }
                  final episodes = snap.data ?? [];
                  if (episodes.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('아직 공개된 작품이 없어요.')),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _EpisodeCard(episode: episodes[i], index: i),
                        childCount: episodes.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final email = Auth.currentUser?.email ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(9)),
                child: Text('더',
                    style: GoogleFonts.notoSansKr(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              const SizedBox(width: 10),
              Text('더빙고', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900, fontSize: 20)),
              const Spacer(),
              IconButton(
                tooltip: '로그아웃',
                onPressed: () => Auth.signOut(),
                icon: const Icon(Icons.logout_rounded, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '짧은 상황,\n내 목소리로 연기하세요.',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900, fontSize: 30, height: 1.15),
          ),
          const SizedBox(height: 8),
          Text(
            email.isEmpty ? '작품을 골라 첫 더빙을 시작해보세요.' : '$email 님, 오늘은 어떤 역을 맡아볼까요?',
            style: GoogleFonts.notoSansKr(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Text('작품', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.muted, size: 40),
            const SizedBox(height: 12),
            const Text('작품을 불러오지 못했어요.', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.faint, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _refresh, child: const Text('다시 시도')),
          ],
        ),
      );
}

class _EpisodeCard extends StatelessWidget {
  final EpisodeSummary episode;
  final int index;
  const _EpisodeCard({required this.episode, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PerformerScreen(episodeId: episode.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFFDED8CC)),
                  if (episode.thumbnailUrl != null)
                    Image.network(episode.thumbnailUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox()),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${episode.maxSeconds}초',
                          style: GoogleFonts.notoSansKr(
                              color: AppColors.paper, fontSize: 11, fontWeight: FontWeight.w900)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Text(categoryLabels[episode.category] ?? episode.category,
                        style: GoogleFonts.notoSansKr(
                            fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.muted)),
                  ),
                  const SizedBox(height: 7),
                  Text(episode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 3),
                  Text(episode.logline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(fontSize: 12, color: AppColors.muted, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
