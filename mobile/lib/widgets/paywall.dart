// 쩌렁쩌렁 Pro 구독 — 페이월 시트 + 프로필용 구독 카드
//
// Subscription.instance.isConfigured 에 따라:
//   true  → 실제 구독 버튼 활성 (purchaseMonthly/purchaseYearly/restore)
//   false → '구독 준비 중' 비활성 UI + "스토어 출시 후 가능" 안내

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../subscription.dart';
import 'app_widgets.dart';

// ─────────────────────────────────────────────────────────
// 혜택 목록 (아이콘, 제목, 부제) — 구체 수치 포함
// ─────────────────────────────────────────────────────────

const _proBenefits = [
  (
    Icons.auto_awesome_rounded,
    'AI 월 생성 ${Env.aiProLimit}회',
    '무료 ${Env.aiFreeLimit}회 대비 10배',
  ),
  (
    Icons.view_column_rounded,
    '스토리보드 ${Env.storyboardProCuts}컷',
    '무료 ${Env.storyboardFreeCuts}컷 대비 4배',
  ),
  (
    Icons.block_rounded,
    '영상 워터마크 제거',
    '깔끔한 영상으로 공유',
  ),
  (
    Icons.bolt_rounded,
    '우선 생성',
    '큐 우선순위로 더 빠르게',
  ),
];

// ─────────────────────────────────────────────────────────
// Pro 구독 카드 (프로필 등에 삽입)
// ─────────────────────────────────────────────────────────

/// 프로필 등에 넣는 Pro 구독 카드.
/// isPro면 "이용 중" 상태, 아니면 구독 유도 버튼으로 표시한다.
class ProSubscribeCard extends StatelessWidget {
  const ProSubscribeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Subscription.instance.isProListenable,
      builder: (context, isPro, _) =>
          isPro ? const _ProActiveCard() : const _ProUpsellCard(),
    );
  }
}

/// Pro 구독 중인 사용자에게 보이는 카드 (탭 시 가벼운 안내)
class _ProActiveCard extends StatelessWidget {
  const _ProActiveCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showAppToast(context, 'Pro 구독 이용 중이에요.');
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
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.ink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('쩌렁쩌렁 Pro 이용 중',
                      style: GoogleFonts.notoSansKr(
                          color: AppColors.paper,
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5)),
                  const SizedBox(height: 3),
                  Text(
                    'AI ${Env.aiProLimit}회 · 스토리보드 ${Env.storyboardProCuts}컷',
                    style: GoogleFonts.notoSansKr(
                        color: AppColors.paper.withValues(alpha: 0.72),
                        fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.workspace_premium_rounded,
                color: AppColors.gold, size: 24),
          ],
        ),
      ),
    );
  }
}

/// Pro 비구독 사용자에게 보이는 구독 유도 카드.
/// isConfigured가 false일 때만 '출시 예정' 뱃지를 표시한다.
class _ProUpsellCard extends StatelessWidget {
  const _ProUpsellCard();

  @override
  Widget build(BuildContext context) {
    final isConfigured = Subscription.instance.isConfigured;
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
              child: const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.ink, size: 22),
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
                      if (!isConfigured) ...[
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
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

// ─────────────────────────────────────────────────────────
// 페이월 바텀시트
// ─────────────────────────────────────────────────────────

/// Pro 페이월 바텀시트를 띄운다.
/// 구매/복원 성공 시 호출자 컨텍스트에서 showAppToast를 실행한다.
Future<void> showPaywallSheet(BuildContext context) async {
  final message = await showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PaywallSheet(),
  );
  if (context.mounted && message != null) {
    showAppToast(context, message);
  }
}

enum _Plan { monthly, yearly }

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet();

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  _Plan _selected = _Plan.yearly;
  bool _loading = false;

  Future<void> _purchase() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final ok = _selected == _Plan.yearly
          ? await Subscription.instance.purchaseYearly()
          : await Subscription.instance.purchaseMonthly();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop('Pro 구독을 시작했어요!');
      } else {
        showAppToast(context, '구독에 실패했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final ok = await Subscription.instance.restore();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop('구독이 복원됐어요!');
      } else {
        showAppToast(context, '복원할 구독 내역이 없어요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = Subscription.instance.isConfigured;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            22, 12, 22, 18 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
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
            // 헤더
            Row(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.gold, size: 28),
                const SizedBox(width: 10),
                Text('쩌렁쩌렁 Pro',
                    style: GoogleFonts.notoSansKr(
                        fontSize: 24, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 6),
            Text('더 많이 만들고, 워터마크 없이 공유하세요.',
                style: GoogleFonts.notoSansKr(
                    fontSize: 13.5, color: AppColors.muted)),
            const SizedBox(height: 22),
            // 혜택 목록
            for (final b in _proBenefits)
              _buildBenefit(b.$1, b.$2, b.$3),
            const SizedBox(height: 18),
            // 플랜 선택 (연간 기본 추천)
            _PlanSelector(
              selected: _selected,
              onChanged: (p) => setState(() => _selected = p),
            ),
            const SizedBox(height: 16),
            // 구독 버튼
            if (isConfigured) _buildActiveButton() else _buildDisabledButton(),
            const SizedBox(height: 12),
            // 복원 버튼 (Apple 심사 필수)
            Center(
              child: isConfigured
                  ? TextButton(
                      onPressed: _loading ? null : _restore,
                      child: Text('구매 복원',
                          style: GoogleFonts.notoSansKr(
                            color: AppColors.faint,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.faint,
                          )),
                    )
                  : Text(
                      '스토어 출시 후 구독 및 복원이 가능해요.',
                      style: GoogleFonts.notoSansKr(
                          color: AppColors.faint, fontSize: 12),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveButton() {
    return GestureDetector(
      onTap: _loading ? null : _purchase,
      child: AnimatedOpacity(
        opacity: _loading ? 0.65 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.paper,
                  ),
                )
              : Text(
                  _selected == _Plan.yearly ? '연간 구독 시작하기' : '월간 구독 시작하기',
                  style: GoogleFonts.notoSansKr(
                      color: AppColors.paper,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildDisabledButton() {
    return Opacity(
      opacity: 0.45,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text('구독 준비 중',
            style: GoogleFonts.notoSansKr(
                color: AppColors.paper,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String title, String sub) {
    return Padding(
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
}

// ─────────────────────────────────────────────────────────
// 플랜 선택 위젯
// ─────────────────────────────────────────────────────────

class _PlanSelector extends StatelessWidget {
  final _Plan selected;
  final ValueChanged<_Plan> onChanged;

  const _PlanSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlanTile(
          selected: selected == _Plan.yearly,
          title: '연간',
          price: Env.proYearlyPriceText,
          unit: '/ 년',
          badge: '약 34% 절약',
          sub: '월 환산 ₩3,250',
          onTap: () => onChanged(_Plan.yearly),
        ),
        const SizedBox(height: 10),
        _PlanTile(
          selected: selected == _Plan.monthly,
          title: '월간',
          price: Env.proMonthlyPriceText,
          unit: '/ 월',
          sub: '언제든 해지 가능',
          onTap: () => onChanged(_Plan.monthly),
        ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String price;
  final String unit;
  final String? badge;
  final String sub;
  final VoidCallback onTap;

  const _PlanTile({
    required this.selected,
    required this.title,
    required this.price,
    required this.unit,
    this.badge,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.line,
            width: selected ? 2.0 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // 라디오 인디케이터
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.line,
                  width: 2,
                ),
                color: selected ? AppColors.gold : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.ink, size: 13)
                  : null,
            ),
            const SizedBox(width: 12),
            // 플랜명 + 뱃지 + 부제
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: GoogleFonts.notoSansKr(
                              fontWeight: FontWeight.w900, fontSize: 15)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge!,
                              style: GoogleFonts.notoSansKr(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9.5)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: GoogleFonts.notoSansKr(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            // 가격
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(price,
                    style: GoogleFonts.notoSansKr(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(width: 2),
                Text(unit,
                    style: GoogleFonts.notoSansKr(
                        color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
