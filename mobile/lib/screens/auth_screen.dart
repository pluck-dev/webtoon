import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../repo.dart';

enum _Step { enterEmail, enterCode }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  _Step _step = _Step.enterEmail;
  bool _passwordMode = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _passwordLogin() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Auth.signInWithPassword(email, _password.text);
    } catch (e) {
      setState(() => _error = '이메일 또는 비밀번호가 올바르지 않아요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await Auth.signInWithGoogle();
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = '올바른 이메일을 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await Auth.sendEmailOtp(email);
      setState(() {
        _step = _Step.enterCode;
        _notice = '$email 로 6자리 인증코드를 보냈어요.';
      });
    } catch (e) {
      setState(() => _error = '코드를 보내지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = '6자리 코드를 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Auth.verifyEmailOtp(_email.text.trim(), code);
      // 성공 시 AuthGate가 자동 전환
    } catch (e) {
      setState(() => _error = '코드가 올바르지 않거나 만료됐어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _step == _Step.enterEmail ? _emailStep() : _codeStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(11)),
            child: Text('더',
                style: GoogleFonts.notoSansKr(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Text('더빙고', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900, fontSize: 24)),
        ],
      );

  Widget _emailStep() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(),
        const SizedBox(height: 28),
        Text('내 목소리로 시작해요',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900, fontSize: 30, height: 1.1)),
        const SizedBox(height: 8),
        Text('짧은 상황을 내 목소리로 연기하는 더빙 놀이터',
            style: GoogleFonts.notoSansKr(color: AppColors.muted, fontSize: 15)),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: _busy ? null : _google,
          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
          label: Text('구글로 계속하기',
              style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('또는 이메일로',
                  style: GoogleFonts.notoSansKr(color: AppColors.faint, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const Expanded(child: Divider(color: AppColors.line)),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: _passwordMode ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) => _busy ? null : (_passwordMode ? null : _sendCode()),
          decoration: const InputDecoration(hintText: '이메일'),
        ),
        if (_passwordMode) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _passwordLogin(),
            decoration: const InputDecoration(hintText: '비밀번호'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : (_passwordMode ? _passwordLogin : _sendCode),
          child: _busy ? _spinner() : Text(_passwordMode ? '로그인' : '인증코드 받기'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _passwordMode = !_passwordMode;
                    _error = null;
                  }),
          child: Text(_passwordMode ? '인증코드로 로그인' : '비밀번호로 로그인',
              style: GoogleFonts.notoSansKr(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _codeStep() {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(),
        const SizedBox(height: 28),
        Text('인증코드 입력',
            style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900, fontSize: 30, height: 1.1)),
        const SizedBox(height: 8),
        if (_notice != null)
          Text(_notice!, style: GoogleFonts.notoSansKr(color: AppColors.inkSoft, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 28),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.notoSansKr(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 10),
          decoration: const InputDecoration(counterText: '', hintText: '------'),
          onSubmitted: (_) => _busy ? null : _verify(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy ? _spinner() : const Text('확인하고 시작하기'),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _step = _Step.enterEmail;
                        _code.clear();
                        _error = null;
                        _notice = null;
                      }),
              child: Text('이메일 바꾸기',
                  style: GoogleFonts.notoSansKr(color: AppColors.muted, fontWeight: FontWeight.w800)),
            ),
            const Text('·', style: TextStyle(color: AppColors.faint)),
            TextButton(
              onPressed: _busy ? null : _sendCode,
              child: Text('코드 다시 받기',
                  style: GoogleFonts.notoSansKr(color: AppColors.ink, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _spinner() => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.paper),
      );
}
