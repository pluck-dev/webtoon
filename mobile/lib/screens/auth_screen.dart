import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../repo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final email = _email.text.trim();
      final password = _password.text;
      if (_isSignUp) {
        await Auth.signUp(email, password);
        if (!Auth.isSignedIn) {
          setState(() => _notice = '가입 확인 메일을 보냈어요. 메일 인증 후 로그인해 주세요.');
        }
      } else {
        await Auth.signInWithPassword(email, password);
      }
    } catch (e) {
      setState(() => _error = _humanize(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(String raw) {
    if (raw.contains('Invalid login')) return '이메일 또는 비밀번호가 올바르지 않아요.';
    if (raw.contains('already registered')) return '이미 가입된 이메일이에요.';
    if (raw.contains('Password')) return '비밀번호는 6자 이상이어야 해요.';
    return '문제가 생겼어요. 잠시 후 다시 시도해 주세요.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 브랜드
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text('더',
                            style: GoogleFonts.notoSansKr(
                                color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Text('더빙고',
                          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900, fontSize: 24)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _isSignUp ? '계정 만들기' : '다시 만나서 반가워요',
                    style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900, fontSize: 30, height: 1.1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '짧은 상황을 내 목소리로 연기하는 더빙 놀이터',
                    style: GoogleFonts.notoSansKr(color: AppColors.muted, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(hintText: '이메일'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '비밀번호 (6자 이상)'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    Text(_notice!,
                        style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.paper))
                        : Text(_isSignUp ? '가입하고 시작하기' : '로그인'),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _error = null;
                              _notice = null;
                            }),
                    child: Text(
                      _isSignUp ? '이미 계정이 있어요 · 로그인' : '계정이 없어요 · 가입하기',
                      style: GoogleFonts.notoSansKr(color: AppColors.ink, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
