import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';

/// 전역 라우트 옵서버 — 위에 쌓인 화면이 pop되면 아래 화면이
/// didPopNext()로 새로고침할 수 있게 한다(피드/내작품 자동 갱신).
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

/// 탭하면 살짝 눌리는 스케일 피드백 (네이티브 앱 같은 촉감)
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final HitTestBehavior behavior;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.behavior = HitTestBehavior.deferToChild,
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
      behavior: widget.behavior,
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

/// 어떤 비율의 이미지든 잘리지 않게 "흐린 배경 + 전체 보이는 전경"으로 표시.
class BlurredImageBg extends StatelessWidget {
  final String url;
  const BlurredImageBg({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const ColoredBox(color: AppColors.deviceDark);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) 꽉 채운 배경 — 블러 원본
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: AppColors.deviceDark),
        ),
        // 2) 블러 + 반투명 어두운 오버레이
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
        ),
        // 3) 전경 — 잘림 없이 원본 비율 그대로
        Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 탭하면 원본 이미지를 풀스크린으로 보여주는 뷰어.
/// [filePath]가 있으면 로컬 파일을 우선 표시, 없으면 [url]로 네트워크 이미지 표시.
void showFullImage(
  BuildContext context, {
  String? url,
  String? filePath,
}) {
  assert(url != null || filePath != null, 'url 또는 filePath 중 하나는 필요합니다');
  showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    useSafeArea: false,
    builder: (ctx) => Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 핀치 줌 뷰어 + 탭하면 닫기
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: filePath != null
                    ? Image.file(
                        File(filePath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 48,
                        ),
                      )
                    : Image.network(
                        url!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
              ),
            ),
          ),
          // 우상단 닫기 버튼
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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

/// 공용 토스트 — 화면 상단에서 약 20% 내려온 위치에 뜬다.
/// 하단 바텀 네비와 겹치지 않도록 SnackBar(하단) 대신 사용한다.
void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 2400),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastView(
      message: message,
      duration: duration,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _ToastView extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;
  const _ToastView({
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    if (!mounted) return;
    await _c.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return Positioned(
      top: h * 0.2, // 상단에서 20% 내려온 지점
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _c,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.18),
              end: Offset.zero,
            ).animate(curved),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.modal,
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    color: AppColors.paper,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
