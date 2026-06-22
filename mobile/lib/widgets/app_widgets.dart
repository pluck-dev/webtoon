import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';

/// 탭하면 살짝 눌리는 스케일 피드백 (네이티브 앱 같은 촉감)
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 앱 공용 페이지 전환 — 페이드 + 살짝 위로 슬라이드 (StyleSeed enter: ease-out)
Route<T> fadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 진입 시 아래에서 살짝 떠오르며 페이드인 (index로 스태거)
class FadeInUp extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeInUp({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final delayMs = (index * 55).clamp(0, 600);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// 네트워크 이미지: 로딩 셰이머 → 페이드인, 에러 폴백 포함
class NetworkThumb extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const NetworkThumb({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null || src.isEmpty) return const Shimmer();
    return Image.network(
      src,
      fit: fit,
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const Shimmer(),
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFDED8CC),
        child: Center(
          child: Icon(
            Icons.image_not_supported_rounded,
            color: AppColors.faint,
            size: 28,
          ),
        ),
      ),
    );
  }
}

/// 은은하게 흐르는 로딩 셰이머 (스켈레톤 표면)
class Shimmer extends StatefulWidget {
  final BorderRadius? radius;
  const Shimmer({super.key, this.radius});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final dx = (_c.value * 2.4) - 1.2; // -1.2 → 1.2 스윕
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            gradient: LinearGradient(
              begin: Alignment(dx - 0.4, -0.2),
              end: Alignment(dx + 0.4, 0.2),
              colors: const [
                Color(0xFFE4DED2),
                Color(0xFFF3EEE4),
                Color(0xFFE4DED2),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// 홈 그리드 로딩용 스켈레톤 카드
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: Shimmer()),
          Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(54, 14, 999),
                const SizedBox(height: 10),
                _bar(double.infinity, 13, 6),
                const SizedBox(height: 7),
                _bar(90, 11, 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double w, double h, double r) => ClipRRect(
    borderRadius: BorderRadius.circular(r),
    child: SizedBox(width: w, height: h, child: const Shimmer()),
  );
}
