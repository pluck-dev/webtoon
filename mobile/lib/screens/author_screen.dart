import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cloud.dart';
import '../config.dart';
import '../models.dart';
import '../widgets/app_widgets.dart';
import 'performer_screen.dart';

/// 작가 프로필 — 한 작가가 만든 공개 만화 모아보기
class AuthorScreen extends StatefulWidget {
  final String creatorId;
  final String authorName;
  const AuthorScreen({
    super.key,
    required this.creatorId,
    required this.authorName,
  });

  @override
  State<AuthorScreen> createState() => _AuthorScreenState();
}

class _AuthorScreenState extends State<AuthorScreen> {
  List<({EpisodeSummary ep, int likes})>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await Cloud.authorEpisodes(widget.creatorId);
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

  int get _totalLikes =>
      _items?.fold<int>(0, (a, x) => a + x.likes) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '작가',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
        ),
      ),
      body: _error != null
          ? _msg('작가 정보를 불러오지 못했어요.')
          : _items == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
          : RefreshIndicator(
              color: AppColors.coral,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _profileHeader()),
                  if (_items!.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _msg('아직 공개한 만화가 없어요.'),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                      sliver: SliverList.separated(
                        itemCount: _items!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _card(_items![i]),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _profileHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.teal,
            shape: BoxShape.circle,
          ),
          child: Text(
            widget.authorName.isEmpty
                ? '?'
                : widget.authorName.characters.first,
            style: GoogleFonts.notoSansKr(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 32,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.authorName,
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '만화 ${_items?.length ?? 0}편  ·  좋아요 $_totalLikes',
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: AppColors.muted,
          ),
        ),
      ],
    ),
  );

  Widget _card(({EpisodeSummary ep, int likes}) item) {
    final ep = item.ep;
    return Pressable(
      onTap: () => Navigator.of(
        context,
      ).push(fadeThroughRoute(PerformerScreen(episodeId: ep.id))),
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
                          '${item.likes}',
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
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.mic_rounded, color: AppColors.faint, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _msg(String m) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        m,
        style: GoogleFonts.notoSansKr(
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    ),
  );
}
