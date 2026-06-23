import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'notify.dart';
import 'repo.dart';
import 'widgets/app_widgets.dart';
import 'screens/auth_screen.dart';
import 'screens/join_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/root_screen.dart';
import 'theme.dart';
import 'widgets/brand_logo.dart';

/// 딥링크 등에서 화면 전환하기 위한 전역 네비게이터 키
final GlobalKey<NavigatorState> appNavKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // sb_publishable_ 키는 클라이언트 공개용 (구 anonKey 대체)
    anonKey: Env.supabaseAnonKey,
    // ignore: deprecated_member_use
  );
  await Notify.init(); // 포그라운드 서비스 + 로컬 알림 채널
  runApp(const DubbingoApp());
}

class DubbingoApp extends StatefulWidget {
  const DubbingoApp({super.key});

  @override
  State<DubbingoApp> createState() => _DubbingoAppState();
}

class _DubbingoAppState extends State<DubbingoApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // 콜드 스타트로 들어온 링크
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        // 첫 프레임 후 네비게이터가 준비되면 처리
        WidgetsBinding.instance.addPostFrameCallback((_) => _handle(initial));
      }
    } catch (_) {}
    // 앱 실행 중 들어온 링크
    _appLinks.uriLinkStream.listen(_handle, onError: (_) {});
  }

  void _handle(Uri uri) {
    // kr.co.pluck.dubbingo://collab/{code}  (login-callback은 supabase가 처리)
    if (uri.host != 'collab') return;
    final code = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (code.isEmpty) return;
    final nav = appNavKey.currentState;
    if (nav == null) return;
    nav.push(fadeThroughRoute(JoinScreen(shareCode: code)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '쩌렁쩌렁',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: appNavKey,
      navigatorObservers: [routeObserver],
      home: const SplashGate(),
    );
  }
}

/// 콜드 스타트 시 애니메이션 스플래시를 잠깐 보여준 뒤 앱으로 전환
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;
  bool _needsOnboarding = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_onboarding') ?? false;
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _needsOnboarding = !seen;
      _ready = true;
    });
  }

  void _finishOnboarding() {
    _prefs?.setBool('seen_onboarding', true);
    setState(() => _needsOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!_ready) {
      child = const _SplashView();
    } else if (_needsOnboarding) {
      child = OnboardingScreen(onDone: _finishOnboarding);
    } else {
      child = const AuthGate();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: child,
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Transform.scale(
                scale: 0.6 + 0.4 * t.clamp(0, 1),
                child: Opacity(opacity: t.clamp(0, 1), child: child),
              ),
              child: const BrandLogo(size: 104, animate: true, badge: false),
            ),
            const SizedBox(height: 22),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, t, child) =>
                  Opacity(opacity: t.clamp(0, 1), child: child),
              child: Text(
                '쩌렁쩌렁',
                style: GoogleFonts.notoSansKr(
                  color: AppColors.paper,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로그인 상태에 따라 홈/로그인 화면 분기
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Auth.changes,
      builder: (context, _) {
        return Auth.isSignedIn ? const RootScreen() : const AuthScreen();
      },
    );
  }
}
