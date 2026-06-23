import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'notify.dart';
import 'repo.dart';
import 'widgets/app_widgets.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/root_screen.dart';
import 'theme.dart';
import 'widgets/brand_logo.dart';

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

class DubbingoApp extends StatelessWidget {
  const DubbingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '쩌렁쩌렁',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
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
