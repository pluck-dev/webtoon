import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'repo.dart';

const _uuid = Uuid();
String _now() => DateTime.now().toUtc().toIso8601String();

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
      'displayName': email != null ? email.split('@').first : '더빙고 유저',
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
      'width': 720,
      'height': 1280,
    });
    return sb.storage.from(Env.bucketVideos).createSignedUrl(key, 60 * 60);
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
