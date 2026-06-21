import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';

SupabaseClient get sb => Supabase.instance.client;

class Repo {
  /// 공개된 에피소드 목록
  static Future<List<EpisodeSummary>> fetchEpisodes() async {
    final rows = await sb
        .from('Episode')
        .select('id,slug,title,logline,thumbnailUrl,maxSeconds,category,format,createdAt')
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
    final characters = charRows.map<Character>((r) => Character.fromMap(r)).toList();
    final charById = {for (final c in characters) c.id: c};

    final cutRows = await sb
        .from('Cut')
        .select('id,order,imageUrl,caption')
        .eq('episodeId', episodeId)
        .order('order');

    final cutIds = cutRows.map((r) => r['id'] as String).toList();
    final dialogueRows = cutIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await sb
            .from('Dialogue')
            .select('id,cutId,characterId,order,text,direction')
            .inFilter('cutId', cutIds)
            .order('order');

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

  /// 이메일로 6자리 인증코드 발송 (신규면 계정 자동 생성)
  static Future<void> sendEmailOtp(String email) =>
      sb.auth.signInWithOtp(email: email, shouldCreateUser: true);

  /// 인증코드 검증 → 성공 시 로그인 완료
  static Future<AuthResponse> verifyEmailOtp(String email, String token) =>
      sb.auth.verifyOTP(email: email, token: token, type: OtpType.email);

  static Future<void> signOut() => sb.auth.signOut();

  static bool get isGoogleConfigured => Env.googleWebClientId.isNotEmpty;

  /// 네이티브 구글 로그인 → Supabase에 idToken으로 인증
  static Future<void> signInWithGoogle() async {
    if (!isGoogleConfigured) {
      throw '구글 로그인 설정이 아직 안 됐어요. (Env.googleWebClientId)';
    }
    final google = GoogleSignIn(
      clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
      serverClientId: Env.googleWebClientId,
    );
    final account = await google.signIn();
    if (account == null) return; // 사용자가 취소
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw '구글 인증 토큰을 받지 못했어요.';
    }
    await sb.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
  }
}
