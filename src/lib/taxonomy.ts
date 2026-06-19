// 콘텐츠 분류 표시명 단일 소스.
// 축 3개는 서로 독립(태그): format(대분류) · category(화풍) · genre(자유 문자열).

export type EpisodeFormat = 'SHORT' | 'SERIES';
export type EpisodeCategory = 'WEBTOON' | 'ROLEPLAY' | 'ANIMATION';

// 대분류 — "웹툰"이란 단어와 겹치지 않게 숏츠/시리즈로
export const FORMAT_LABELS: Record<EpisodeFormat, string> = {
  SHORT: '숏츠',
  SERIES: '시리즈'
};

// 화풍 — bare "웹툰" 대신 "웹툰체"
export const CATEGORY_LABELS: Record<EpisodeCategory, string> = {
  WEBTOON: '웹툰체',
  ROLEPLAY: '상황극',
  ANIMATION: '애니메이션'
};

// 이미지 생성 화풍 프리픽스 (category별 스타일)
export const CATEGORY_STYLE: Record<EpisodeCategory, string> = {
  WEBTOON:
    'Korean webtoon/manhwa art, clean lineart, cel shading, soft gradient backgrounds, expressive faces, vertical 9:16',
  ROLEPLAY:
    'cinematic semi-realistic K-drama still, natural soft lighting, muted film tones, shallow depth of field, film grain, vertical 9:16',
  ANIMATION:
    'Japanese anime style, cel shading, vibrant saturated colors, Makoto Shinkai-like lighting, expressive big eyes, vertical 9:16'
};

export const FORMAT_ORDER: EpisodeFormat[] = ['SHORT', 'SERIES'];
export const CATEGORY_ORDER: EpisodeCategory[] = ['WEBTOON', 'ROLEPLAY', 'ANIMATION'];
