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
    likedByMe: (m['liked_by_me'] ?? false) as bool,
  );

  EpisodeSummary copyWith({int? likeCount, bool? likedByMe}) => EpisodeSummary(
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
