import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

SupabaseClient get sb => Supabase.instance.client;

class Repo {
  /// 공개된 에피소드 목록
  static Future<List<EpisodeSummary>> fetchEpisodes() async {
    final rows = await sb
        .from('Episode')
        .select(
          'id,slug,title,logline,thumbnailUrl,maxSeconds,category,format,createdAt',
        )
        .eq('status', 'PUBLISHED')
        .order('createdAt', ascending: false);
    return rows.map<EpisodeSummary>((r) => EpisodeSummary.fromMap(r)).toList();
  }

  /// 에피소드 상세(컷 + 대사 + 캐릭터)를 조립
  static Future<EpisodeDetail> fetchEpisodeDetail(String episodeId) async {
    final epRow = await sb
        .from('Episode')
        .select('id,slug,title,logline,thumbnailUrl,maxSeconds,category,format')
        .eq('id', episodeId)
        .single();
    final summary = EpisodeSummary.fromMap(epRow);

    final charRows = await sb
        .from('Character')
        .select('id,name,description,voiceGuide,color')
        .eq('episodeId', episodeId);
    final characters = charRows
        .map<Character>((r) => Character.fromMap(r))
        .toList();
    final charById = {for (final c in characters) c.id: c};

    final cutRows = await sb
        .from('Cut')
        .select('id,order,imageUrl,caption')
        .eq('episodeId', episodeId)
        .order('order', ascending: true);

    final cutIds = cutRows.map((r) => r['id'] as String).toList();
    final dialogueRows = cutIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await sb
              .from('Dialogue')
              .select('id,cutId,characterId,order,text,direction')
              .inFilter('cutId', cutIds)
              .order('order', ascending: true);

    final dialoguesByCut = <String, List<Dialogue>>{};
    for (final r in dialogueRows) {
      final d = Dialogue.fromMap(r);
      d.character = d.characterId != null ? charById[d.characterId] : null;
      dialoguesByCut.putIfAbsent(d.cutId, () => []).add(d);
    }

    final cuts = cutRows.map<Cut>((r) {
      final id = r['id'] as String;
      return Cut(
        id: id,
        order: (r['order'] ?? 0) as int,
        imageUrl: r['imageUrl'] as String,
        caption: (r['caption'] ?? '') as String,
        dialogues: dialoguesByCut[id] ?? [],
      );
    }).toList();

    return EpisodeDetail(summary: summary, cuts: cuts, characters: characters);
  }
}

class Auth {
  static User? get currentUser => sb.auth.currentUser;
  static bool get isSignedIn => currentUser != null;
  static Stream<AuthState> get changes => sb.auth.onAuthStateChange;

  /// 이메일+비밀번호 로그인
  static Future<void> signInWithPassword(String email, String password) =>
      sb.auth.signInWithPassword(email: email, password: password);

  /// 회원가입 — 이메일 확인이 켜져 있으면 가입 확인 코드가 메일로 발송됨.
  /// (세션은 코드 인증 후 생성, 확인이 꺼져 있으면 즉시 session 반환)
  static Future<AuthResponse> signUp(String email, String password) =>
      sb.auth.signUp(email: email, password: password);

  /// 회원가입 확인 코드 검증 → 성공 시 가입 완료 + 로그인
  static Future<AuthResponse> verifySignup(String email, String token) =>
      sb.auth.verifyOTP(email: email, token: token, type: OtpType.signup);

  /// 가입 확인 코드 재발송
  static Future<void> resendSignup(String email) =>
      sb.auth.resend(type: OtpType.signup, email: email);

  static Future<void> signOut() => sb.auth.signOut();

  /// 구글 로그인 — Supabase OAuth(딥링크) 플로우.
  /// 브라우저(커스텀 탭)로 구글 동의 → kr.co.pluck.dubbingo://login-callback 로
  /// 돌아오면 supabase_flutter가 세션을 자동 처리한다.
  /// (Supabase 대시보드에서 Google provider 활성화 + 위 redirect URL 등록 필요)
  static Future<void> signInWithGoogle() => sb.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: 'kr.co.pluck.dubbingo://login-callback',
  );
}
