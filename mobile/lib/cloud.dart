import 'dart:io';

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
    final existing = await sb
        .from('User')
        .select('id')
        .eq('supabaseUserId', authUser.id)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final id = _uuid.v4();
    final email = authUser.email;
    await sb.from('User').insert({
      'id': id,
      'handle': authUser.id, // 고유 보장
      'supabaseUserId': authUser.id,
      'email': email,
      'displayName': email != null ? email.split('@').first : '더빙고 유저',
      'updatedAt': _now(),
    });
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
}
