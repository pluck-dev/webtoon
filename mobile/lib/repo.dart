import 'package:supabase_flutter/supabase_flutter.dart';

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

  static Future<void> signInWithPassword(String email, String password) =>
      sb.auth.signInWithPassword(email: email, password: password);

  static Future<void> signUp(String email, String password) =>
      sb.auth.signUp(email: email, password: password);

  static Future<void> signOut() => sb.auth.signOut();
}
