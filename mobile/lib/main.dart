import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'repo.dart';
import 'screens/auth_screen.dart';
import 'screens/root_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // sb_publishable_ 키는 클라이언트 공개용 (구 anonKey 대체)
    anonKey: Env.supabaseAnonKey,
    // ignore: deprecated_member_use
  );
  runApp(const DubbingoApp());
}

class DubbingoApp extends StatelessWidget {
  const DubbingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '더빙고',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
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
