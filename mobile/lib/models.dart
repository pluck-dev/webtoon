// Supabase row(Map) → 모델. 컬럼명은 Prisma 컨벤션(camelCase) 그대로.

class EpisodeSummary {
  final String id;
  final String slug;
  final String title;
  final String logline;
  final String? thumbnailUrl;
  final int maxSeconds;
  final String category; // WEBTOON / ROLEPLAY / ANIMATION
  final String format; // SHORT / SERIES

  // 공개 피드용(없으면 기본값) — 작가/좋아요 정보
  final String? author;
  final String? creatorId;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  EpisodeSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.logline,
    required this.thumbnailUrl,
    required this.maxSeconds,
    required this.category,
    required this.format,
    this.author,
    this.creatorId,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  factory EpisodeSummary.fromMap(Map<String, dynamic> m) => EpisodeSummary(
    id: m['id'] as String,
    slug: m['slug'] as String,
    title: m['title'] as String,
    logline: (m['logline'] ?? '') as String,
    thumbnailUrl: m['thumbnailUrl'] as String?,
    maxSeconds: (m['maxSeconds'] ?? 60) as int,
    category: (m['category'] ?? 'WEBTOON') as String,
    format: (m['format'] ?? 'SHORT') as String,
  );

  /// feed_episodes RPC 결과(snake_case) → 모델
  factory EpisodeSummary.fromFeedMap(Map<String, dynamic> m) => EpisodeSummary(
    id: m['id'] as String,
    slug: m['slug'] as String,
    title: m['title'] as String,
    logline: (m['logline'] ?? '') as String,
    thumbnailUrl: m['thumbnailUrl'] as String?,
    maxSeconds: (m['maxSeconds'] ?? 60) as int,
    category: (m['category'] ?? 'WEBTOON') as String,
    format: (m['format'] ?? 'SHORT') as String,
    author: m['author'] as String?,
    creatorId: m['creator_id'] as String?,
    likeCount: (m['like_count'] ?? 0) as int,
    commentCount: (m['comment_count'] ?? 0) as int,
    likedByMe: (m['liked_by_me'] ?? false) as bool,
  );

  EpisodeSummary copyWith({int? likeCount, int? commentCount, bool? likedByMe}) =>
      EpisodeSummary(
        id: id,
        slug: slug,
        title: title,
        logline: logline,
        thumbnailUrl: thumbnailUrl,
        maxSeconds: maxSeconds,
        category: category,
        format: format,
        author: author,
        creatorId: creatorId,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );
}

class Character {
  final String id;
  final String name;
  final String description;
  final String voiceGuide;
  final String color;

  Character({
    required this.id,
    required this.name,
    required this.description,
    required this.voiceGuide,
    required this.color,
  });

  factory Character.fromMap(Map<String, dynamic> m) => Character(
    id: m['id'] as String,
    name: (m['name'] ?? '') as String,
    description: (m['description'] ?? '') as String,
    voiceGuide: (m['voiceGuide'] ?? '') as String,
    color: (m['color'] ?? '#7c5cff') as String,
  );
}

/// 재사용 가능한 AI 캐릭터(레퍼런스 이미지). 컷 생성 시 같은 인물 유지에 사용.
/// [localPath]는 다운로드 캐시 경로(없을 수 있음).
class AiCharacter {
  final String id;
  final String name;
  final String imageUrl;
  final String? localPath;

  AiCharacter({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.localPath,
  });

  factory AiCharacter.fromMap(Map<String, dynamic> m) => AiCharacter(
    id: m['id'] as String,
    name: (m['name'] ?? '') as String,
    imageUrl: (m['imageUrl'] ?? '') as String,
  );
}

class Dialogue {
  final String id;
  final String cutId;
  final String? characterId;
  final int order;
  final String text;
  final String direction;
  Character? character;

  Dialogue({
    required this.id,
    required this.cutId,
    required this.characterId,
    required this.order,
    required this.text,
    required this.direction,
    this.character,
  });

  String get speaker => character?.name ?? 'Narration';

  factory Dialogue.fromMap(Map<String, dynamic> m) => Dialogue(
    id: m['id'] as String,
    cutId: m['cutId'] as String,
    characterId: m['characterId'] as String?,
    order: (m['order'] ?? 0) as int,
    text: (m['text'] ?? '') as String,
    direction: (m['direction'] ?? '') as String,
  );
}

class Cut {
  final String id;
  final int order;
  final String imageUrl;
  final String caption;
  final List<Dialogue> dialogues;

  Cut({
    required this.id,
    required this.order,
    required this.imageUrl,
    required this.caption,
    required this.dialogues,
  });
}

/// 퍼포머 화면이 쓰는 완전한 에피소드
class EpisodeDetail {
  final EpisodeSummary summary;
  final List<Cut> cuts;
  final List<Character> characters;

  EpisodeDetail({
    required this.summary,
    required this.cuts,
    required this.characters,
  });

  /// 전체 대사를 순서대로 펼친 리스트 (퍼포머 순차 진행용)
  List<({Cut cut, Dialogue dialogue})> get lines {
    final out = <({Cut cut, Dialogue dialogue})>[];
    for (final cut in cuts) {
      for (final d in cut.dialogues) {
        out.add((cut: cut, dialogue: d));
      }
    }
    return out;
  }
}

/// 댓글 1건 (작가 이름 임베드)
class CommentItem {
  final String id;
  final String userId;
  final String author;
  final String text;
  final DateTime createdAt;

  CommentItem({
    required this.id,
    required this.userId,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  /// episode_comments RPC 결과(security definer로 작가명 포함)
  factory CommentItem.fromRpcMap(Map<String, dynamic> m) {
    final name = m['author'] as String?;
    return CommentItem(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      author: (name == null || name.isEmpty) ? '익명' : name,
      text: (m['body'] ?? '') as String,
      createdAt:
          DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime(2000),
    );
  }
}

/// 초대 더빙 배역(collab_by_code RPC의 roles 원소)
class CollabRoleView {
  final String roleId;
  final String characterId;
  final String characterName;
  final String color;
  final String status; // OPEN | CLAIMED | RECORDED
  final String? assignedUserId;
  final String? assigneeName;

  CollabRoleView({
    required this.roleId,
    required this.characterId,
    required this.characterName,
    required this.color,
    required this.status,
    required this.assignedUserId,
    required this.assigneeName,
  });

  factory CollabRoleView.fromMap(Map<String, dynamic> m) => CollabRoleView(
        roleId: m['roleId'] as String,
        characterId: m['characterId'] as String,
        characterName: (m['characterName'] ?? '배역') as String,
        color: (m['color'] ?? '#5CC8BA') as String,
        status: (m['status'] ?? 'OPEN') as String,
        assignedUserId: m['assignedUserId'] as String?,
        assigneeName: m['assigneeName'] as String?,
      );

  bool get isOpen => status == 'OPEN';
  bool get isRecorded => status == 'RECORDED';
}

/// 초대 더빙 세션 (collab_by_code RPC 결과)
class CollabView {
  final String sessionId;
  final String status; // OPEN | READY | COMPLETE | CANCELLED
  final String mode; // TEAM | REMIX
  final String shareCode;
  final String hostName;
  final String hostUserId;
  final String? videoId; // 완성 영상 storage key
  final String episodeId;
  final String title;
  final String? thumbnailUrl;
  final List<CollabRoleView> roles;

  CollabView({
    required this.sessionId,
    required this.status,
    required this.mode,
    required this.shareCode,
    required this.hostName,
    required this.hostUserId,
    required this.videoId,
    required this.episodeId,
    required this.title,
    required this.thumbnailUrl,
    required this.roles,
  });

  factory CollabView.fromMap(Map<String, dynamic> m) => CollabView(
        sessionId: m['sessionId'] as String,
        status: (m['status'] ?? 'OPEN') as String,
        mode: (m['mode'] ?? 'TEAM') as String,
        shareCode: (m['shareCode'] ?? '') as String,
        hostName: (m['hostName'] ?? '익명') as String,
        hostUserId: (m['hostUserId'] ?? '') as String,
        videoId: m['videoId'] as String?,
        episodeId: m['episodeId'] as String,
        title: (m['title'] ?? '') as String,
        thumbnailUrl: m['thumbnailUrl'] as String?,
        roles: ((m['roles'] ?? []) as List)
            .map((r) => CollabRoleView.fromMap(r as Map<String, dynamic>))
            .toList(),
      );

  bool get isReady => status == 'READY';
  bool get isComplete => status == 'COMPLETE';
  bool get isRemix => mode == 'REMIX';
  int get recordedCount => roles.where((r) => r.isRecorded).length;
}
