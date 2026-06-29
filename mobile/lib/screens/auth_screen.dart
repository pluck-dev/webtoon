import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../repo.dart';
import '../widgets/brand_logo.dart';

enum _Step { form, verify, reset }

class AuthScreen extends StatefulWidget {
  /// true면 루트(AuthGate)가 아닌, 다른 화면 위에 올라온 경우.
  /// 로그인 성공 시 AuthGate 전환에 의존하지 않고 스스로 pop 해 호출 화면으로 복귀한다.
  final bool returnOnAuth;
  const AuthScreen({super.key, this.returnOnAuth = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  _Step _step = _Step.form;
  bool _isSignup = false; // false=로그인(기본), true=회원가입
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _notice;
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    // 다른 화면 위에 올라온 경우: 로그인(구글 딥링크 포함) 완료를 감지해 스스로 닫는다.
    if (widget.returnOnAuth) {
      _authSub = Auth.changes.listen((_) {
        if (!mounted) return;
        if (Auth.isSignedIn) {
          _authSub?.cancel();
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _email.text.trim();
    if (!email.contains('@')) return '올바른 이메일을 입력해 주세요.';
    if (_password.text.length < 6) return '비밀번호는 6자 이상이어야 해요.';
    return null;
  }

  Future<void> _login() async {
    final v = _validate();
    if (v != null) {
      setState(() => _error = v);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Auth.signInWithPassword(_email.text.trim(), _password.text);
      // 성공 시 AuthGate가 자동 전환
    } catch (_) {
      setState(() => _error = '이메일 또는 비밀번호가 올바르지 않아요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signup() async {
    final v = _validate();
    if (v != null) {
      setState(() => _error = v);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final res = await Auth.signUp(_email.text.trim(), _password.text);
      if (res.session != null) return; // 이메일 확인 꺼짐 → 바로 로그인됨
      setState(() {
        _step = _Step.verify;
        _notice = '${_email.text.trim()} 로 인증코드를 보냈어요.';
      });
    } catch (e) {
      final msg = '$e';
      setState(
        () => _error = msg.contains('registered')
            ? '이미 가입된 이메일이에요. 로그인해 주세요.'
            : '가입에 실패했어요. 잠시 후 다시 시도해 주세요.',
      );
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
      await Auth.verifySignup(_email.text.trim(), code);
      // 성공 시 AuthGate가 자동 전환
    } catch (_) {
      setState(() => _error = '코드가 올바르지 않거나 만료됐어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Auth.resendSignup(_email.text.trim());
      setState(() => _notice = '인증코드를 다시 보냈어요.');
    } catch (_) {
      setState(() => _error = '코드를 다시 보내지 못했어요.');
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
    } catch (_) {
      setState(() => _error = '구글 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 비밀번호 재설정 메일 발송 — 보수적으로 발송 안내까지만 처리.
  /// (메일 링크를 통한 실제 재설정은 Supabase 기본 흐름을 따른다.)
  Future<void> _sendReset() async {
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
      await sb.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() {
        _step = _Step.form;
        _notice = '$email 로 재설정 메일을 보냈어요. 메일의 링크에서 새 비밀번호를 설정해 주세요.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = '재설정 메일을 보내지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignup = !_isSignup;
      _error = null;
      _notice = null;
    });
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
                child: switch (_step) {
                  _Step.form => _formStep(),
                  _Step.verify => _codeStep(),
                  _Step.reset => _resetStep(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() => Row(
    children: [
      const BrandLogo(size: 42, animate: true),
      const SizedBox(width: 12),
      Text(
        '쩌렁쩌렁',
        style: GoogleFonts.notoSansKr(
          fontWeight: FontWeight.w900,
          fontSize: 24,
        ),
      ),
    ],
  );

  Widget _formStep() {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(),
        const SizedBox(height: 28),
        Text(
          _isSignup ? '쩌렁쩌렁 시작하기' : '내 목소리로 시작해요',
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w900,
            fontSize: 30,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignup ? '이메일·비밀번호로 가입하면 인증코드를 보내드려요' : '이메일과 비밀번호로 로그인하세요',
          style: GoogleFonts.notoSansKr(color: AppColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: _busy ? null : _google,
          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
          label: Text(
            '구글로 계속하기',
            style: GoogleFonts.notoSansKr(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '또는 이메일로',
                style: GoogleFonts.notoSansKr(
                  color: AppColors.faint,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.line)),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: '이메일'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : (_isSignup ? _signup() : _login()),
          decoration: InputDecoration(
            hintText: _isSignup ? '비밀번호 (6자 이상)' : '비밀번호',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.faint,
                size: 20,
              ),
            ),
          ),
        ),
        if (!_isSignup)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _step = _Step.reset;
                      _error = null;
                      _notice = null;
                    }),
              child: Text(
                '비밀번호를 잊으셨나요?',
                style: GoogleFonts.notoSansKr(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.coral,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (_notice != null) ...[
          const SizedBox(height: 12),
          Text(
            _notice!,
            style: GoogleFonts.notoSansKr(
              color: AppColors.teal,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : (_isSignup ? _signup : _login),
          child: _busy ? _spinner() : Text(_isSignup ? '회원가입' : '로그인'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _toggleMode,
          child: Text.rich(
            TextSpan(
              style: GoogleFonts.notoSansKr(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              children: [
                TextSpan(text: _isSignup ? '이미 계정이 있으신가요?  ' : '처음이신가요?  '),
                TextSpan(
                  text: _isSignup ? '로그인' : '회원가입',
                  style: GoogleFonts.notoSansKr(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
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
        Text(
          '이메일 인증',
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w900,
            fontSize: 30,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        if (_notice != null)
          Text(
            _notice!,
            style: GoogleFonts.notoSansKr(
              color: AppColors.inkSoft,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '코드는 잠시 후 만료돼요. 메일이 안 보이면 스팸함을 확인하거나 아래에서 다시 받아주세요.',
          style: GoogleFonts.notoSansKr(
            color: AppColors.faint,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.notoSansKr(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 10,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '------',
          ),
          onSubmitted: (_) => _busy ? null : _verify(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.coral,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy ? _spinner() : const Text('인증하고 시작하기'),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _step = _Step.form;
                      _code.clear();
                      _error = null;
                      _notice = null;
                    }),
              child: Text(
                '이메일 바꾸기',
                style: GoogleFonts.notoSansKr(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Text('·', style: TextStyle(color: AppColors.faint)),
            TextButton(
              onPressed: _busy ? null : _resend,
              child: Text(
                '코드 다시 받기',
                style: GoogleFonts.notoSansKr(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resetStep() {
    return Column(
      key: const ValueKey('reset'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(),
        const SizedBox(height: 28),
        Text(
          '비밀번호 재설정',
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w900,
            fontSize: 30,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '가입한 이메일로 재설정 링크를 보내드려요',
          style: GoogleFonts.notoSansKr(color: AppColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _sendReset(),
          decoration: const InputDecoration(hintText: '이메일'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.coral,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _sendReset,
          child: _busy ? _spinner() : const Text('재설정 메일 보내기'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _step = _Step.form;
                  _error = null;
                  _notice = null;
                }),
          child: Text(
            '로그인으로 돌아가기',
            style: GoogleFonts.notoSansKr(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
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
