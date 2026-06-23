import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud.dart';
import '../config.dart';
import '../repo.dart';
import '../widgets/app_widgets.dart';
import 'creator_screen.dart';
import 'my_episodes_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('링크를 열 수 없어요: $url')));
    }
  }

  Future<void> _mail(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: Env.supportEmail);
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메일 앱을 열 수 없어요: ${Env.supportEmail}')),
      );
    }
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '로그아웃',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
        ),
        content: const Text('정말 로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              minimumSize: const Size(88, 44),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Auth.signOut();
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = Auth.currentUser?.email ?? '';
    final initial = email.isEmpty ? '더' : email.characters.first.toUpperCase();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(
              '프로필',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w900,
                fontSize: 28,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 24),
            // 계정 카드
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      initial,
                      style: GoogleFonts.notoSansKr(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email.isEmpty ? '쩌렁쩌렁 유저' : email.split('@').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansKr(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansKr(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _statsCard(),
            const SizedBox(height: 24),
            _section('내 콘텐츠'),
            _tile(
              Icons.auto_stories_rounded,
              '내가 만든 만화',
              subtitle: '발행한 작품 관리 · 삭제',
              onTap: () => Navigator.of(
                context,
              ).push(fadeThroughRoute(const MyEpisodesScreen())),
            ),
            _tile(
              Icons.edit_rounded,
              '새 만화 만들기',
              onTap: () => Navigator.of(
                context,
              ).push(fadeThroughRoute(const CreatorScreen())),
            ),
            const SizedBox(height: 24),
            _section('지원'),
            _tile(
              Icons.mail_outline_rounded,
              '문의하기',
              subtitle: Env.supportEmail,
              onTap: () => _mail(context),
            ),
            _tile(
              Icons.description_outlined,
              '이용약관',
              onTap: () => _open(context, Env.termsUrl),
            ),
            _tile(
              Icons.privacy_tip_outlined,
              '개인정보처리방침',
              onTap: () => _open(context, Env.privacyUrl),
            ),
            const SizedBox(height: 24),
            _section('계정'),
            _tile(
              Icons.logout_rounded,
              '로그아웃',
              color: AppColors.coral,
              onTap: () => _confirmSignOut(context),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    '쩌렁쩌렁',
                    style: GoogleFonts.notoSansKr(
                      fontWeight: FontWeight.w900,
                      color: AppColors.faint,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v1.0.0  ·  플럭',
                    style: GoogleFonts.notoSansKr(
                      color: AppColors.faint,
                      fontSize: 12,
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

  Widget _statsCard() {
    return FutureBuilder<List<MyWork>>(
      future: Cloud.myWorks(),
      builder: (context, snap) {
        final works = snap.data ?? const <MyWork>[];
        final loading = snap.connectionState == ConnectionState.waiting;
        final recordings = works.fold<int>(0, (a, w) => a + w.recordingCount);
        final videos = works.where((w) => w.hasVideo).length;
        String v(int n) => loading ? '–' : '$n';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _stat(v(works.length), '더빙 작품'),
              _statDivider(),
              _stat(v(recordings), '녹음'),
              _statDivider(),
              _stat(v(videos), '완성 영상'),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: GoogleFonts.notoSansKr(
            color: AppColors.gold,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.notoSansKr(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Widget _statDivider() => Container(
    width: 1,
    height: 34,
    color: Colors.white.withValues(alpha: 0.12),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
    child: Text(
      title,
      style: GoogleFonts.notoSansKr(
        fontWeight: FontWeight.w900,
        fontSize: 13,
        color: AppColors.faint,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _tile(
    IconData icon,
    String title, {
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Icon(icon, color: c, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: c,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: GoogleFonts.notoSansKr(
                            color: AppColors.faint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (color == null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.faint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
