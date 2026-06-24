import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'models.dart';
import 'repo.dart';

const _uuid = Uuid();
String _now() => DateTime.now().toUtc().toIso8601String();

/// AI 생성 월 한도 초과
class AiQuotaException implements Exception {
  final int used;
  final int limit;
  AiQuotaException({required this.used, required this.limit});
}

/// Supabase Auth 유저 ↔ User 테이블 + 공연/녹음/렌더 (RLS로 본인 것만)
class Cloud {
  /// 현재 로그인 유저에 대응하는 User 행을 보장하고 User.id 반환
  static Future<String> ensureUser() async {
    final authUser = sb.auth.currentUser!;
    // 이미 이 인증 계정에 연결된 User
    final byUid = await sb
        .from('User')
        .select('id')
        .eq('supabaseUserId', authUser.id)
        .maybeSingle();
    if (byUid != null) return byUid['id'] as String;

    final email = authUser.email;
    final id = _uuid.v4();
    final row = {
      'id': id,
      'handle': authUser.id, // 고유 보장
      'supabaseUserId': authUser.id,
      'email': email,
      'displayName': email != null ? email.split('@').first : '쩌렁쩌렁 유저',
      'updatedAt': _now(),
    };
    try {
      await sb.from('User').insert(row);
    } on PostgrestException catch (e) {
      // 같은 이메일이 이미 존재(웹 계정 등)해 유니크 충돌 → 이메일 없이 생성
      // (RLS상 기존 행을 읽거나 연결할 수 없어 모바일용 행을 별도 생성)
      if (e.code == '23505') {
        await sb.from('User').insert({...row, 'email': null});
      } else {
        rethrow;
      }
    }
    return id;
  }

  /// 에피소드에 대한 내 공연을 가져오거나 생성
  static Future<String> getOrCreatePerformance(
    String episodeId,
    String userId,
  ) async {
    final existing = await sb
        .from('Performance')
        .select('id')
        .eq('episodeId', episodeId)
        .eq('userId', userId)
        .order('updatedAt', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final id = _uuid.v4();
    await sb.from('Performance').insert({
      'id': id,
      'episodeId': episodeId,
      'userId': userId,
      'title': '내 더빙 버전',
      'updatedAt': _now(),
    });
    return id;
  }

  /// 이 공연의 저장된 녹음(대사별 최신) — dialogueId → durationMs
  static Future<Map<String, int>> loadSavedRecordings(
    String performanceId,
  ) async {
    final rows = await sb
        .from('Recording')
        .select('dialogueId,durationMs,createdAt')
        .eq('performanceId', performanceId)
        .order('createdAt', ascending: false);
    final out = <String, int>{};
    for (final r in rows) {
      final d = r['dialogueId'] as String;
      out.putIfAbsent(d, () => (r['durationMs'] ?? 0) as int);
    }
    return out;
  }

  /// 로컬 녹음 파일을 Storage에 올리고 Recording 행 생성
  static Future<void> uploadRecording({
    required String performanceId,
    required String dialogueId,
    required String userId,
    required String filePath,
    required int durationMs,
  }) async {
    final key =
        '$performanceId/$dialogueId-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await sb.storage
        .from(Env.bucketRecordings)
        .upload(
          key,
          File(filePath),
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
    await sb.from('Recording').insert({
      'id': _uuid.v4(),
      'performanceId': performanceId,
      'dialogueId': dialogueId,
      'userId': userId,
      'audioUrl': key,
      'storageKey': key,
      'durationMs': durationMs,
    });
  }

  /// 렌더 잡 생성(워커가 처리) → jobId
  static Future<String> createRenderJob(String performanceId) async {
    final id = _uuid.v4();
    await sb.from('RenderJob').insert({
      'id': id,
      'performanceId': performanceId,
      // 워커가 buildRenderInput으로 재계산하므로 placeholder
      'timeline': {},
      'updatedAt': _now(),
    });
    return id;
  }

  /// 렌더 잡 상태 + 완료 시 영상 서명 URL
  static Future<({String status, String? videoUrl})> fetchRender(
    String jobId,
  ) async {
    final job = await sb
        .from('RenderJob')
        .select('status')
        .eq('id', jobId)
        .maybeSingle();
    final status = (job?['status'] ?? 'QUEUED') as String;
    if (status != 'DONE') return (status: status, videoUrl: null);

    final video = await sb
        .from('RenderedVideo')
        .select('videoUrl')
        .eq('renderJobId', jobId)
        .maybeSingle();
    if (video == null) return (status: status, videoUrl: null);

    final signed = await sb.storage
        .from(Env.bucketVideos)
        .createSignedUrl(video['videoUrl'] as String, 60 * 60);
    return (status: status, videoUrl: signed);
  }

  /// 이 공연의 최신 완성 영상(있으면) 서명 URL
  static Future<String?> latestVideoUrl(String performanceId) async {
    final video = await sb
        .from('RenderedVideo')
        .select('videoUrl,createdAt')
        .eq('performanceId', performanceId)
        .order('createdAt', ascending: false)
        .limit(1)
        .maybeSingle();
    if (video == null) return null;
    return sb.storage
        .from(Env.bucketVideos)
        .createSignedUrl(video['videoUrl'] as String, 60 * 60);
  }

  /// storage key → 1시간 서명 URL (영상 재생용)
  static Future<String> signVideo(String storageKey) =>
      sb.storage.from(Env.bucketVideos).createSignedUrl(storageKey, 60 * 60);

  /// 내 보관함: 내 공연 목록 + 에피소드 정보 + 녹음 수 + 영상 여부
  static Future<List<MyWork>> myWorks() async {
    final userId = await ensureUser();
    final perfs = await sb
        .from('Performance')
        .select('id,episodeId,updatedAt')
        .eq('userId', userId)
        .order('updatedAt', ascending: false);
    if (perfs.isEmpty) return [];

    final perfIds = perfs.map((p) => p['id'] as String).toList();
    final epIds = perfs.map((p) => p['episodeId'] as String).toSet().toList();

    final eps = await sb
        .from('Episode')
        .select('id,title,thumbnailUrl,category')
        .inFilter('id', epIds);
    final epById = {for (final e in eps) e['id'] as String: e};

    final recs = await sb
        .from('Recording')
        .select('performanceId')
        .inFilter('performanceId', perfIds);
    final recCount = <String, int>{};
    for (final r in recs) {
      final pid = r['performanceId'] as String;
      recCount[pid] = (recCount[pid] ?? 0) + 1;
    }

    final vids = await sb
        .from('RenderedVideo')
        .select('performanceId,videoUrl,createdAt')
        .inFilter('performanceId', perfIds)
        .order('createdAt', ascending: false);
    final latestVid = <String, String>{};
    for (final v in vids) {
      final pid = v['performanceId'] as String;
      latestVid.putIfAbsent(pid, () => v['videoUrl'] as String);
    }

    return perfs.map<MyWork>((p) {
      final pid = p['id'] as String;
      final ep = epById[p['episodeId']];
      return MyWork(
        performanceId: pid,
        episodeId: p['episodeId'] as String,
        episodeTitle: (ep?['title'] as String?) ?? '삭제된 작품',
        thumbnailUrl: ep?['thumbnailUrl'] as String?,
        category: (ep?['category'] as String?) ?? 'WEBTOON',
        recordingCount: recCount[pid] ?? 0,
        videoStorageKey: latestVid[pid],
        updatedAt: p['updatedAt'] as String?,
      );
    }).toList();
  }

  /// 이 공연의 대사별 최신 녹음 메타 (dialogueId → storageKey, durationMs)
  static Future<Map<String, ({String storageKey, int durationMs})>>
  recordingMeta(String performanceId) async {
    final rows = await sb
        .from('Recording')
        .select('dialogueId,storageKey,durationMs,createdAt')
        .eq('performanceId', performanceId)
        .order('createdAt', ascending: false);
    final out = <String, ({String storageKey, int durationMs})>{};
    for (final r in rows) {
      final d = r['dialogueId'] as String;
      out.putIfAbsent(
        d,
        () => (
          storageKey: r['storageKey'] as String,
          durationMs: (r['durationMs'] ?? 1000) as int,
        ),
      );
    }
    return out;
  }

  /// recordings 버킷에서 녹음 다운로드 → 로컬 파일 경로
  static Future<String> downloadRecording(String storageKey) async {
    final bytes = await sb.storage
        .from(Env.bucketRecordings)
        .download(storageKey);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/dl_${storageKey.replaceAll('/', '_')}');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  /// 폰에서 만든 mp4를 rendered-videos에 올리고 (완료된)RenderJob+RenderedVideo
  /// 행을 만들어 보관함에도 뜨게 함 → 서명 URL 반환
  static Future<String> saveRenderedVideo(
    String performanceId,
    String localPath,
    int durationMs,
  ) async {
    final key = '$performanceId/${_uuid.v4()}.mp4';
    await sb.storage
        .from(Env.bucketVideos)
        .upload(
          key,
          File(localPath),
          fileOptions: const FileOptions(
            contentType: 'video/mp4',
            upsert: true,
          ),
        );
    // 온디바이스 렌더는 잡을 즉시 완료 상태로 기록
    final jobId = _uuid.v4();
    await sb.from('RenderJob').insert({
      'id': jobId,
      'performanceId': performanceId,
      'status': 'DONE',
      'timeline': {},
      'updatedAt': _now(),
    });
    await sb.from('RenderedVideo').insert({
      'id': _uuid.v4(),
      'performanceId': performanceId,
      'renderJobId': jobId,
      'videoUrl': key,
      'durationMs': durationMs,
      'width': 1080,
      'height': 1920,
    });
    return sb.storage.from(Env.bucketVideos).createSignedUrl(key, 60 * 60);
  }

  /// 작가 발행: 컷 이미지 업로드 + Episode/Character/Cut/Dialogue 생성
  /// → episodeId + 생성된 캐릭터(배역) 목록(초대 더빙 캐스팅용)
  static Future<({String epId, List<({String id, String name})> characters})>
  publishEpisode({
    required String title,
    required String logline,
    required String category, // WEBTOON / ROLEPLAY / ANIMATION
    required List<({String imagePath, String speaker, String text, String direction})>
    cuts,
  }) async {
    final uid = await ensureUser();
    final epId = _uuid.v4();
    final slug = 'u-${epId.substring(0, 8)}';

    // 1) 컷 이미지 업로드 → public URL
    final imageUrls = <String>[];
    for (var i = 0; i < cuts.length; i++) {
      final key = 'user/$epId/cut-${i + 1}.jpg';
      await sb.storage
          .from(Env.bucketImages)
          .upload(
            key,
            File(cuts[i].imagePath),
            // upsert는 ON CONFLICT DO UPDATE라 UPDATE RLS까지 요구해 403이 난다.
            // 경로가 매번 새 UUID라 충돌이 없으므로 일반 INSERT(upsert=false)로 업로드한다.
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      imageUrls.add(Env.publicImageUrl(key));
    }

    // 2) 에피소드(PUBLISHED → 홈 노출)
    //    Character/Cut이 episodeId를 FK로 참조하므로 Episode를 먼저 만든다.
    await sb.from('Episode').insert({
      'id': epId,
      'slug': slug,
      'title': title,
      'logline': logline,
      'status': 'PUBLISHED',
      'format': 'SHORT',
      'category': category,
      'maxSeconds': 60,
      'thumbnailUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
      'creatorId': uid, // 사용자 창작물 → 공개 피드 노출
      'updatedAt': _now(),
    });

    // 3) 화자 → 캐릭터 생성(자동 색 배정)
    const palette = [
      '#EF6F5E',
      '#5CC8BA',
      '#F0BD62',
      '#3A7BD5',
      '#FF6B9D',
      '#9B8CFF',
    ];
    final speakers = <String>[];
    for (final c in cuts) {
      final s = c.speaker.trim();
      if (s.isNotEmpty && !speakers.contains(s)) speakers.add(s);
    }
    final charIdByName = <String, String>{};
    for (var i = 0; i < speakers.length; i++) {
      final cid = _uuid.v4();
      await sb.from('Character').insert({
        'id': cid,
        'episodeId': epId,
        'name': speakers[i],
        'description': '',
        'voiceGuide': '',
        'color': palette[i % palette.length],
      });
      charIdByName[speakers[i]] = cid;
    }

    // 4) 컷 + 대사
    for (var i = 0; i < cuts.length; i++) {
      final cutId = _uuid.v4();
      await sb.from('Cut').insert({
        'id': cutId,
        'episodeId': epId,
        'order': i + 1,
        'imageUrl': imageUrls[i],
        'caption': '',
      });
      await sb.from('Dialogue').insert({
        'id': _uuid.v4(),
        'cutId': cutId,
        'characterId': charIdByName[cuts[i].speaker.trim()],
        'order': 1,
        'text': cuts[i].text,
        'direction': cuts[i].direction,
      });
    }
    final characters =
        charIdByName.entries.map((e) => (id: e.value, name: e.key)).toList();
    return (epId: epId, characters: characters);
  }

  /// AI 컷 이미지 생성 → 로컬 파일 경로 + 남은 횟수.
  /// [refImagePaths] : 캐릭터 일관성용 참조 이미지(로컬 경로, 최대 3장).
  /// 월 한도 초과 시 [AiQuotaException].
  static Future<({String path, int remaining, bool stub})> generateAiImage(
    String prompt, {
    List<String> refImagePaths = const [],
  }) async {
    await ensureUser();
    final refs = <String>[];
    for (final p in refImagePaths.take(3)) {
      try {
        refs.add(base64Encode(await File(p).readAsBytes()));
      } catch (_) {
        // 참조 이미지 못 읽으면 일관성만 포기하고 생성은 진행
      }
    }
    final res = await sb.functions.invoke(
      'generate-image',
      body: {'prompt': prompt, if (refs.isNotEmpty) 'refImages': refs},
    );
    final data = (res.data ?? {}) as Map<String, dynamic>;
    if (res.status == 402 || data['error'] == 'quota_exceeded') {
      throw AiQuotaException(
        used: (data['used'] ?? 0) as int,
        limit: (data['limit'] ?? 0) as int,
      );
    }
    if (res.status != 200 || data['image'] == null) {
      throw Exception('ai_gen_failed: ${data['error'] ?? res.status}');
    }
    final bytes = base64Decode(data['image'] as String);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ai_${_uuid.v4()}.png');
    await file.writeAsBytes(bytes);
    return (
      path: file.path,
      remaining: (data['remaining'] ?? 0) as int,
      stub: data['stub'] == true,
    );
  }

  /// 내 AI 캐릭터 목록 (최신순)
  static Future<List<AiCharacter>> listAiCharacters() async {
    final uid = await ensureUser();
    final rows = await sb
        .from('AiCharacter')
        .select('id,name,imageUrl,createdAt')
        .eq('userId', uid)
        .order('createdAt', ascending: false);
    return (rows as List)
        .map((r) => AiCharacter.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// AI 캐릭터 저장: 로컬 이미지 업로드 → 행 생성.
  /// 반환 객체에 방금 만든 [localPath]를 캐시해 바로 컷 생성에 쓸 수 있음.
  static Future<AiCharacter> createAiCharacter({
    required String name,
    required String localImagePath,
  }) async {
    final uid = await ensureUser();
    final id = _uuid.v4();
    final key = 'user/characters/$id.png';
    // 경로가 매번 새 UUID라 충돌 없음 → 일반 INSERT(upsert=false), RLS UPDATE 회피
    await sb.storage.from(Env.bucketImages).upload(
          key,
          File(localImagePath),
          fileOptions: const FileOptions(contentType: 'image/png', upsert: false),
        );
    final url = Env.publicImageUrl(key);
    await sb.from('AiCharacter').insert({
      'id': id,
      'userId': uid,
      'name': name,
      'imageUrl': url,
      'createdAt': _now(),
    });
    return AiCharacter(
        id: id, name: name, imageUrl: url, localPath: localImagePath);
  }

  /// AI 캐릭터 삭제 (행만; 스토리지 이미지는 남겨도 무방)
  static Future<void> deleteAiCharacter(String id) async {
    await sb.from('AiCharacter').delete().eq('id', id);
  }

  /// 캐릭터 레퍼런스 이미지를 로컬 파일로 확보(캐시). 컷 생성 시 refImagePaths용.
  static Future<String> characterLocalImage(AiCharacter c) async {
    if (c.localPath != null && await File(c.localPath!).exists()) {
      return c.localPath!;
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/char_${c.id}.png');
    if (await f.exists()) return f.path;
    final bytes =
        await sb.storage.from(Env.bucketImages).download('user/characters/${c.id}.png');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  /// 초대 더빙 세션 생성 → (sessionId, shareCode)
  /// [assignments] : 배역별 {characterId, mine(내가 더빙 여부)}
  /// [mode] : 'TEAM'(같이 한 영상) | 'REMIX'(각자 버전)
  static Future<({String sessionId, String shareCode})> createCollab({
    required String episodeId,
    required List<({String characterId, bool mine})> assignments,
    String mode = 'TEAM',
  }) async {
    await ensureUser();
    final res = await sb.rpc('create_collab', params: {
      'p_episode': episodeId,
      'p_assignments': assignments
          .map((a) => {'characterId': a.characterId, 'mine': a.mine})
          .toList(),
      'p_mode': mode,
    }) as Map<String, dynamic>;
    return (
      sessionId: res['sessionId'] as String,
      shareCode: res['shareCode'] as String,
    );
  }

  /// REMIX 참여 → 내 전용 포크 세션의 shareCode (없으면 null)
  static Future<String?> joinRemix(String code) async {
    await ensureUser();
    final res =
        await sb.rpc('join_remix', params: {'p_code': code}) as Map<String, dynamic>;
    if (res['ok'] != true) return null;
    return res['shareCode'] as String;
  }

  /// 세션에서 내 모든 배역 녹음완료 표시 → 전부 끝났는지(allDone)
  static Future<bool> setMyRolesRecorded(String sessionId) async {
    final res = await sb.rpc('set_my_roles_recorded',
        params: {'p_session': sessionId}) as Map<String, dynamic>;
    return res['allDone'] == true;
  }

  /// 공유 코드로 콜라보 세션 조회(참여/관리 화면). 없으면 null.
  static Future<CollabView?> collabByCode(String code) async {
    final res = await sb.rpc('collab_by_code', params: {'p_code': code});
    if (res == null) return null;
    return CollabView.fromMap(res as Map<String, dynamic>);
  }

  /// 빈 배역 맡기 → 성공 여부
  static Future<bool> claimRole(String roleId) async {
    await ensureUser();
    final res = await sb.rpc('claim_collab_role', params: {'p_role': roleId})
        as Map<String, dynamic>;
    return res['ok'] == true;
  }

  /// 배역 녹음 완료 표시 → 전부 끝났는지(allDone) 반환
  static Future<bool> setRoleRecorded(String roleId) async {
    final res = await sb
            .rpc('set_collab_role_recorded', params: {'p_role': roleId})
        as Map<String, dynamic>;
    return res['allDone'] == true;
  }

  /// 내 초대 더빙 목록(호스트/참여) — 진행 상황 포함
  static Future<List<Map<String, dynamic>>> myCollabs() async {
    await ensureUser();
    final res = await sb.rpc('my_collabs') as List;
    return res.cast<Map<String, dynamic>>();
  }

  /// storage key → 재생용 signed URL (완성 영상 다시보기)
  static Future<String> signedVideoUrl(String key) =>
      sb.storage.from(Env.bucketVideos).createSignedUrl(key, 60 * 60);

  /// 콜라보 합본 영상 저장 → (재생용 signed URL, 영구 storage key)
  static Future<({String url, String key})> saveCollabVideo(
    String performanceId,
    String localPath,
    int durationMs,
  ) async {
    final key = '$performanceId/collab-${_uuid.v4()}.mp4';
    await sb.storage.from(Env.bucketVideos).upload(
          key,
          File(localPath),
          fileOptions:
              const FileOptions(contentType: 'video/mp4', upsert: true),
        );
    final jobId = _uuid.v4();
    await sb.from('RenderJob').insert({
      'id': jobId,
      'performanceId': performanceId,
      'status': 'DONE',
      'timeline': {},
      'updatedAt': _now(),
    });
    await sb.from('RenderedVideo').insert({
      'id': _uuid.v4(),
      'performanceId': performanceId,
      'renderJobId': jobId,
      'videoUrl': key,
      'durationMs': durationMs,
      'width': 1080,
      'height': 1920,
    });
    final url =
        await sb.storage.from(Env.bucketVideos).createSignedUrl(key, 60 * 60);
    return (url: url, key: key);
  }

  /// 합본 렌더 입력: dialogueId → (담당자 녹음 storageKey, 길이ms)
  static Future<Map<String, ({String storageKey, int durationMs})>>
  collabRenderMeta(String sessionId) async {
    final rows = await sb
        .rpc('collab_render_meta', params: {'p_session': sessionId}) as List;
    final out = <String, ({String storageKey, int durationMs})>{};
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      out[m['dialogue_id'] as String] = (
        storageKey: m['storage_key'] as String,
        durationMs: (m['duration_ms'] ?? 1200) as int,
      );
    }
    return out;
  }

  /// 호스트가 콜라보 완성 처리(합본 영상 연결)
  static Future<bool> completeCollab(String sessionId, String videoId) async {
    final res = await sb.rpc('complete_collab',
        params: {'p_session': sessionId, 'p_video': videoId})
        as Map<String, dynamic>;
    return res['ok'] == true;
  }

  /// 좋아요 토글 → 토글 후 좋아요 여부 반환
  static Future<bool> toggleLike(String episodeId) async {
    final uid = await ensureUser();
    final existing = await sb
        .from('Like')
        .select('id')
        .eq('episodeId', episodeId)
        .eq('userId', uid)
        .maybeSingle();
    if (existing != null) {
      await sb.from('Like').delete().eq('id', existing['id'] as String);
      return false;
    }
    await sb.from('Like').insert({
      'id': _uuid.v4(),
      'userId': uid,
      'episodeId': episodeId,
    });
    return true;
  }

  /// 내가 창작한 에피소드 목록(최신순) — 좋아요 수 포함
  static Future<List<({EpisodeSummary ep, int likes})>> myEpisodes() async {
    final uid = await ensureUser();
    final rows = await sb
        .from('Episode')
        .select(
          'id,slug,title,logline,thumbnailUrl,maxSeconds,category,format,createdAt',
        )
        .eq('creatorId', uid)
        .order('createdAt', ascending: false);
    final result = <({EpisodeSummary ep, int likes})>[];
    for (final r in rows) {
      final ep = EpisodeSummary.fromMap(r);
      final likeRows = await sb.from('Like').select('id').eq('episodeId', ep.id);
      result.add((ep: ep, likes: (likeRows as List).length));
    }
    return result;
  }

  /// 특정 작가의 공개 에피소드 목록(최신순) — 좋아요 수 포함
  static Future<List<({EpisodeSummary ep, int likes})>> authorEpisodes(
    String creatorId,
  ) async {
    final rows = await sb
        .from('Episode')
        .select(
          'id,slug,title,logline,thumbnailUrl,maxSeconds,category,format,createdAt',
        )
        .eq('creatorId', creatorId)
        .eq('status', 'PUBLISHED')
        .order('createdAt', ascending: false);
    final result = <({EpisodeSummary ep, int likes})>[];
    for (final r in rows) {
      final ep = EpisodeSummary.fromMap(r);
      final likeRows = await sb.from('Like').select('id').eq('episodeId', ep.id);
      result.add((ep: ep, likes: (likeRows as List).length));
    }
    return result;
  }

  /// 내 창작 에피소드 삭제 (RLS상 본인 것만; Cut/Dialogue/Character는 FK Cascade)
  static Future<void> deleteEpisode(String episodeId) async {
    await sb.from('Episode').delete().eq('id', episodeId);
  }

  /// 현재 로그인 사용자의 User.id (댓글 본인 여부 판별용)
  static Future<String> myUserId() => ensureUser();

  /// 에피소드 댓글 목록(오래된 순) — 작가명 포함(security definer RPC)
  static Future<List<CommentItem>> fetchComments(String episodeId) async {
    final rows =
        await sb.rpc('episode_comments', params: {'p_episode': episodeId})
            as List;
    return rows
        .map((r) => CommentItem.fromRpcMap(r as Map<String, dynamic>))
        .toList();
  }

  /// 댓글 작성 → 생성된 댓글 반환
  static Future<CommentItem> addComment(String episodeId, String text) async {
    final uid = await ensureUser();
    final id = _uuid.v4();
    await sb.from('Comment').insert({
      'id': id,
      'episodeId': episodeId,
      'userId': uid,
      'text': text,
    });
    // 본인 User 행은 RLS상 읽을 수 있으므로 작가명 조회
    final me = await sb
        .from('User')
        .select('displayName')
        .eq('id', uid)
        .maybeSingle();
    final name = (me?['displayName'] as String?) ?? '';
    return CommentItem(
      id: id,
      userId: uid,
      author: name.isEmpty ? '익명' : name,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  /// 댓글 삭제 (RLS상 본인 것만)
  static Future<void> deleteComment(String id) async {
    await sb.from('Comment').delete().eq('id', id);
  }

  /// 공연 1건 삭제 (녹음/영상/렌더잡 → 공연 순서로, RLS상 본인 것만)
  static Future<void> deleteWork(String performanceId) async {
    await sb.from('Recording').delete().eq('performanceId', performanceId);
    await sb.from('RenderedVideo').delete().eq('performanceId', performanceId);
    await sb.from('RenderJob').delete().eq('performanceId', performanceId);
    await sb.from('Performance').delete().eq('id', performanceId);
  }
}

/// 보관함 항목 (공연 1건 요약)
class MyWork {
  final String performanceId;
  final String episodeId;
  final String episodeTitle;
  final String? thumbnailUrl;
  final String category;
  final int recordingCount;
  final String? videoStorageKey;
  final String? updatedAt;

  MyWork({
    required this.performanceId,
    required this.episodeId,
    required this.episodeTitle,
    required this.thumbnailUrl,
    required this.category,
    required this.recordingCount,
    required this.videoStorageKey,
    required this.updatedAt,
  });

  bool get hasVideo => videoStorageKey != null;
}
