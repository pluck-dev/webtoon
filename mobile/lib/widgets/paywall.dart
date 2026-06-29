// 쩌렁쩌렁 Pro 구독 — 페이월 시트 + 프로필용 구독 카드
//
// 인앱결제(RevenueCat)는 스토어 셋업 후 연결. 지금은 UI만 준비(구독 버튼은
// '곧 제공' 안내). 한도 초과/프로필 등 어디서든 showPaywallSheet로 띄움.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';

const _proBenefits = [
  (Icons.palette_rounded, 'AI 이미지 더 많이', '월 생성 한도 대폭 상향'),
  (Icons.block_rounded, '영상 워터마크 제거', '깔끔한 영상으로 공유'),
  (Icons.bolt_rounded, '우선 생성', '더 빠르게 만들기'),
  (Icons.chat_bubble_rounded, '우선 지원', '문의 빠른 응대'),
];

/// 프로필 등에 넣는 Pro 구독 유도 카드
class ProSubscribeCard extends StatelessWidget {
  const ProSubscribeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showPaywallSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2B2622), AppColors.ink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
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
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: AppColors.ink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('쩌렁쩌렁 Pro',
                          style: GoogleFonts.notoSansKr(
                              color: AppColors.paper,
                              fontWeight: FontWeight.w900,
                              fontSize: 16.5)),
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('출시 예정',
                            style: GoogleFonts.notoSansKr(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 9.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('AI 더 많이 · 영상 워터마크 제거',
                      style: GoogleFonts.notoSansKr(
                          color: AppColors.paper.withValues(alpha: 0.72),
                          fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('보기',
                      style: GoogleFonts.notoSansKr(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.ink, size: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pro 페이월 바텀시트
Future<void> showPaywallSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PaywallSheet(),
  );
}

class _PaywallSheet extends StatelessWidget {
  const _PaywallSheet();

  void _notReady(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('구독은 곧 제공돼요',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
        content: Text(
          '스토어 출시와 함께 Pro 구독을 열어요.\n조금만 기다려 주세요!',
          style: GoogleFonts.notoSansKr(color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('알겠어요',
                style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            22, 12, 22, 18 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 28),
                const SizedBox(width: 10),
                Text('쩌렁쩌렁 Pro',
                    style: GoogleFonts.notoSansKr(
                        fontSize: 24, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 6),
            Text('더 많이 만들고, 워터마크 없이 공유하세요.',
                style:
                    GoogleFonts.notoSansKr(fontSize: 13.5, color: AppColors.muted)),
            const SizedBox(height: 22),
            for (final b in _proBenefits) _benefit(b.$1, b.$2, b.$3),
            const SizedBox(height: 18),
            // 요금(예시 — 스토어 상품 연결 시 실제 가격으로)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('월 구독',
                            style: GoogleFonts.notoSansKr(
                                fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('언제든 해지 가능',
                            style: GoogleFonts.notoSansKr(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text('₩4,900',
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w900, fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 구독 버튼 (현재는 준비중 안내)
            GestureDetector(
              onTap: () => _notReady(context),
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Pro 시작하기',
                    style: GoogleFonts.notoSansKr(
                        color: AppColors.paper,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _notReady(context),
                child: Text('구매 복원',
                    style: GoogleFonts.notoSansKr(
                        color: AppColors.muted, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w800, fontSize: 14.5)),
                  Text(sub,
                      style: GoogleFonts.notoSansKr(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded,
                color: AppColors.gold, size: 20),
          ],
        ),
      );
}
