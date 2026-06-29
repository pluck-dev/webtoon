// AI 스튜디오 — 영화/촬영 전문 키워드 빌더 + 캐릭터·사물 일관성
//
// 초보자도 빈 텍스트창 대신 한글 키워드(영화 제작 용어)를 드롭다운 섹션에서
// 다중 선택해 장면을 만들 수 있고, 캐릭터를 한 번 만들어 두면 컷마다 같은
// 인물/사물(레퍼런스 이미지)로 일관성을 유지한다.
//
// 규칙:
//  - 아무것도 안 고르면 → 입력한 프롬프트 그대로 생성
//  - 고르면 → 프롬프트 + 선택 키워드(영문 변환) + 레퍼런스 일관성
//
// 진입점:
//  - showAiGenerateSheet(): 컷 1장 생성 (캐릭터 선택 + 키워드 + 자유설명)
//  - showCharacterCreateSheet(): 캐릭터/사물 레퍼런스 생성·저장

import 'dart:io';

import 'package:flutter/material.dart';
import 'widgets/app_widgets.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'cloud.dart';
import 'config.dart';
import 'models.dart';

/// 키워드 한 개: 화면 표시는 한글(ko), 프롬프트엔 영문(en) 사용.
typedef Kw = ({String ko, String en});

/// 키워드 카테고리. [hint]은 초보자용 한 줄 도움말(없으면 null).
typedef KwCategory = ({String title, String? hint, List<Kw> items});

Kw _k(String ko, String en) => (ko: ko, en: en);

/// 장면(컷) 키워드 — 영화/촬영 전문 용어 기반. 드롭다운 섹션별 다중 선택.
final List<KwCategory> kSceneKeywords = [
  (
    title: '화각 · 샷 크기',
    hint: '인물을 얼마나 가까이/멀리 잡을지 정해요.',
    items: [
      _k('익스트림 클로즈업', 'extreme close-up'),
      _k('클로즈업', 'close-up shot'),
      _k('페이스샷', 'face shot'),
      _k('바스트샷', 'bust shot'),
      _k('미디엄샷', 'medium shot'),
      _k('카우보이샷', 'cowboy shot'),
      _k('풀샷(전신)', 'full body shot'),
      _k('와이드샷', 'wide shot'),
      _k('익스트림 와이드', 'extreme wide establishing shot'),
      _k('마스터샷', 'master shot'),
      _k('투샷', 'two shot'),
      _k('그룹샷', 'group shot'),
      _k('오버더숄더', 'over-the-shoulder shot'),
      _k('디테일 컷', 'insert detail shot'),
    ],
  ),
  (
    title: '촬영 각도',
    hint: '카메라가 인물을 바라보는 높이·기울기. 더치앵글은 화면을 비스듬히 기울여 불안·긴장을 줘요.',
    items: [
      _k('정면(아이레벨)', 'eye-level angle'),
      _k('하이앵글', 'high angle'),
      _k('로우앵글', 'low angle'),
      _k('버드아이뷰', "bird's-eye view"),
      _k('웜즈아이뷰', "worm's-eye view"),
      _k('더치앵글(기운 화면)', 'dutch angle tilt'),
      _k('탑다운', 'top-down overhead'),
      _k('측면(프로필)', 'side profile angle'),
      _k('3/4 측면', 'three-quarter angle'),
      _k('뒤에서', 'from behind'),
      _k('POV 시점', 'first-person POV'),
    ],
  ),
  (
    title: '렌즈 · 심도',
    hint: '초점과 배경 흐림. 아웃포커스는 배경이 흐려져 인물이 또렷하고, 틸트시프트는 미니어처처럼 보여요.',
    items: [
      _k('광각', 'wide-angle lens'),
      _k('표준렌즈', 'standard 50mm lens'),
      _k('망원', 'telephoto lens'),
      _k('어안렌즈', 'fisheye lens'),
      _k('아웃포커스(보케)', 'shallow depth of field, bokeh'),
      _k('팬포커스', 'deep focus'),
      _k('매크로', 'macro close detail'),
      _k('틸트시프트', 'tilt-shift miniature'),
      _k('아나모픽', 'anamorphic widescreen'),
      _k('소프트 포커스', 'soft focus glow'),
    ],
  ),
  (
    title: '구도 · 프레이밍',
    hint: '화면 안에서 인물·사물을 어디에 둘지. 여백을 두거나 한쪽으로 치우치게 배치해요.',
    items: [
      _k('삼분할 구도', 'rule of thirds composition'),
      _k('중앙 배치', 'centered composition'),
      _k('대칭 구도', 'symmetrical composition'),
      _k('비대칭 구도', 'asymmetrical composition'),
      _k('프레임 인 프레임', 'frame within a frame'),
      _k('여백 강조', 'negative space'),
      _k('리딩 라인', 'leading lines'),
      _k('대각선 구도', 'diagonal composition'),
      _k('가득 채움', 'tightly framed'),
      _k('로우 포지션', 'low framing'),
      _k('황금비', 'golden ratio composition'),
      _k('패턴 반복', 'repeating pattern'),
    ],
  ),
  (
    title: '조명',
    hint: '빛의 방향·세기·색. 로우키는 어둡고 그림자 많은 무드, 하이키는 밝고 화사한 느낌이에요.',
    items: [
      _k('자연광', 'natural light'),
      _k('황금시간대', 'golden hour light'),
      _k('블루아워', 'blue hour light'),
      _k('역광', 'backlight'),
      _k('림라이트', 'rim lighting'),
      _k('실루엣', 'silhouette'),
      _k('하드라이트', 'hard directional light'),
      _k('소프트라이트', 'soft diffused light'),
      _k('사이드라이트', 'side lighting'),
      _k('탑라이트', 'top lighting'),
      _k('네온', 'neon lighting'),
      _k('캔들라이트', 'candlelight glow'),
      _k('스포트라이트', 'dramatic spotlight'),
      _k('로우키(어두운 무드)', 'low-key moody lighting'),
      _k('하이키(밝은)', 'high-key bright lighting'),
      _k('창문빛', 'window light'),
    ],
  ),
  (
    title: '색감 · 팔레트',
    hint: '전체 색의 느낌. 보색 대비는 반대색을 써 강렬하고, 모노톤은 한 색 계열로 차분해요.',
    items: [
      _k('따뜻한 색', 'warm color palette'),
      _k('차가운 색', 'cool color palette'),
      _k('모노톤', 'monochromatic palette'),
      _k('보색 대비', 'complementary color contrast'),
      _k('파스텔톤', 'pastel color palette'),
      _k('세피아', 'sepia tone'),
      _k('네온 파스텔', 'neon pastel palette'),
      _k('어스톤', 'earthy natural tones'),
      _k('비비드', 'vivid saturated colors'),
      _k('탈색(데세추레이션)', 'desaturated muted colors'),
      _k('틸&오렌지', 'teal and orange grading'),
      _k('흑백', 'black and white'),
    ],
  ),
  (
    title: '질감 · 마감',
    hint: '이미지 표면의 질감과 마감 느낌이에요.',
    items: [
      _k('필름 사진', 'analog film look'),
      _k('필름 그레인', 'film grain texture'),
      _k('매끈한 디지털', 'clean digital finish'),
      _k('거친 질감', 'gritty rough texture'),
      _k('유화 느낌', 'oil painting texture'),
      _k('종이 질감', 'paper grain texture'),
      _k('빈티지', 'vintage faded look'),
      _k('광택(글로시)', 'glossy polished finish'),
      _k('무광(매트)', 'matte finish'),
      _k('HDR 선명', 'crisp hdr detail'),
      _k('하프톤', 'halftone print texture'),
      _k('수채 번짐', 'watercolor bleed texture'),
    ],
  ),
  (
    title: '연출 기법',
    hint: '장면을 강조하는 시각 효과. 집중선·스피드라인은 만화식 속도감·긴박함을 줘요.',
    items: [
      _k('모션블러', 'motion blur'),
      _k('스피드라인', 'manga speed lines'),
      _k('집중선', 'focus concentration lines'),
      _k('더블 익스포저', 'double exposure'),
      _k('렌즈플레어', 'lens flare'),
      _k('비네팅', 'vignette'),
      _k('필름그레인', 'film grain'),
      _k('god ray(빛줄기)', 'volumetric god rays'),
      _k('보케 배경', 'bokeh background'),
      _k('롱 익스포저', 'long exposure light trails'),
      _k('반사', 'reflection'),
      _k('그림자 강조', 'dramatic shadows'),
      _k('빛 번짐', 'light bloom glow'),
      _k('입자 효과', 'floating particles'),
    ],
  ),
  (
    title: '카메라 무빙 느낌',
    hint: '정지 그림이지만 움직임의 인상을 줘요. 핸드헬드는 손으로 든 듯 흔들리고, 돌리는 레일 이동감이에요.',
    items: [
      _k('패닝(좌우 흐름)', 'panning motion blur'),
      _k('줌인 느낌', 'zoom-in motion'),
      _k('줌아웃 느낌', 'zoom-out motion'),
      _k('핸드헬드', 'handheld camera shake'),
      _k('돌리 인', 'dolly-in perspective'),
      _k('트래킹샷', 'tracking shot motion'),
      _k('크레인샷', 'sweeping crane shot'),
      _k('드론뷰', 'aerial drone perspective'),
      _k('회전', 'rotating camera motion'),
      _k('흔들림', 'shaky cam energy'),
    ],
  ),
  (
    title: '분위기 · 톤',
    hint: '장면이 주는 감정적 분위기예요.',
    items: [
      _k('따뜻한 톤', 'warm color tone'),
      _k('차가운 톤', 'cool color tone'),
      _k('몽환적', 'dreamy atmosphere'),
      _k('음울한', 'gloomy somber'),
      _k('긴장감', 'tense suspenseful'),
      _k('로맨틱', 'romantic'),
      _k('코믹', 'comedic lighthearted'),
      _k('서사적', 'epic cinematic'),
      _k('노스탤지어', 'nostalgic'),
      _k('공포', 'eerie horror'),
      _k('평화로운', 'peaceful serene'),
      _k('신비로운', 'mysterious'),
      _k('활기찬', 'energetic vibrant'),
      _k('쓸쓸한', 'melancholic lonely'),
    ],
  ),
  (
    title: '배경 · 장소',
    hint: '장면이 펼쳐지는 공간이에요.',
    items: [
      _k('교실', 'classroom'),
      _k('카페', 'cozy cafe'),
      _k('도시 거리', 'city street'),
      _k('골목', 'narrow alley'),
      _k('공원', 'park'),
      _k('침실', 'bedroom'),
      _k('옥상', 'rooftop'),
      _k('바닷가', 'beach'),
      _k('숲', 'forest'),
      _k('지하철', 'subway train'),
      _k('사무실', 'office'),
      _k('학교 운동장', 'schoolyard'),
      _k('도서관', 'library'),
      _k('편의점', 'convenience store'),
      _k('판타지 성', 'fantasy castle'),
      _k('우주', 'outer space'),
    ],
  ),
  (
    title: '시간 · 날씨',
    hint: '시간대와 날씨를 정해요.',
    items: [
      _k('아침', 'morning light'),
      _k('한낮', 'midday'),
      _k('노을', 'sunset glow'),
      _k('황혼', 'dusk twilight'),
      _k('밤', 'night'),
      _k('새벽', 'dawn'),
      _k('비', 'rain'),
      _k('폭우', 'heavy downpour'),
      _k('눈', 'snow'),
      _k('안개', 'fog mist'),
      _k('맑음', 'clear sky'),
      _k('흐림', 'overcast'),
      _k('천둥번개', 'thunderstorm'),
      _k('벚꽃', 'cherry blossoms'),
      _k('단풍', 'autumn leaves'),
      _k('바람', 'windy'),
    ],
  ),
  (
    title: '표정 · 감정',
    hint: '인물의 표정과 감정이에요.',
    items: [
      _k('미소', 'gentle smile'),
      _k('환한 웃음', 'big bright grin'),
      _k('놀람', 'surprised shocked'),
      _k('눈물', 'crying tearful'),
      _k('분노', 'angry furious'),
      _k('무표정', 'deadpan neutral'),
      _k('부끄러움', 'blushing shy'),
      _k('진지함', 'serious'),
      _k('졸림', 'sleepy'),
      _k('설렘', 'excited fluttering'),
      _k('절망', 'despair'),
      _k('결의', 'determined'),
      _k('미묘한 미소', 'subtle smirk'),
      _k('당황', 'flustered'),
      _k('슬픔', 'sad sorrowful'),
      _k('두려움', 'fearful'),
    ],
  ),
  (
    title: '동작 · 포즈',
    hint: '인물의 자세와 동작이에요.',
    items: [
      _k('서있기', 'standing'),
      _k('앉기', 'sitting'),
      _k('달리기', 'running'),
      _k('걷기', 'walking'),
      _k('점프', 'jumping mid-air'),
      _k('뒤돌아보기', 'looking back over shoulder'),
      _k('손 흔들기', 'waving hand'),
      _k('팔짱', 'arms crossed'),
      _k('기대기', 'leaning against wall'),
      _k('쓰러지기', 'collapsing'),
      _k('포옹', 'hugging'),
      _k('전투 자세', 'fighting stance'),
      _k('눕기', 'lying down'),
      _k('손 뻗기', 'reaching out hand'),
      _k('무릎 꿇기', 'kneeling'),
      _k('춤추기', 'dancing'),
    ],
  ),
  (
    title: '소품 · 오브젝트',
    hint: '장면에 더할 소품·사물을 넣어요.',
    items: [
      _k('꽃', 'flowers'),
      _k('우산', 'umbrella'),
      _k('커피잔', 'coffee cup'),
      _k('스마트폰', 'smartphone'),
      _k('책', 'book'),
      _k('검', 'sword'),
      _k('총', 'gun'),
      _k('가방', 'bag'),
      _k('편지', 'letter'),
      _k('풍선', 'balloons'),
      _k('촛불', 'candles'),
      _k('우유팩', 'milk carton'),
      _k('노트북', 'laptop'),
      _k('기타(악기)', 'guitar'),
      _k('반려동물', 'pet animal'),
      _k('자전거', 'bicycle'),
    ],
  ),
  (
    title: '화풍 · 스타일',
    hint: '그림체·렌더링 스타일을 골라요.',
    items: [
      _k('실사(사진)', 'photorealistic, realistic photography'),
      _k('시네마틱 실사', 'cinematic photorealistic film still'),
      _k('반실사', 'semi-realistic rendering'),
      _k('3D 렌더', '3d rendered cgi style'),
      _k('웹툰', 'korean webtoon style'),
      _k('순정만화', 'shoujo manga style'),
      _k('소년만화', 'shonen manga style'),
      _k('극화체', 'gritty realistic manhwa style'),
      _k('수채화', 'watercolor painting'),
      _k('유화', 'oil painting style'),
      _k('셀 애니', 'cel-shaded anime'),
      _k('지브리풍', 'ghibli-inspired anime style'),
      _k('느와르 흑백', 'noir black and white'),
      _k('파스텔', 'soft pastel colors'),
      _k('동화풍', 'storybook illustration style'),
      _k('미니멀 라인', 'minimal clean line art'),
    ],
  ),
];

/// 캐릭터·사물 외형 키워드 — 레퍼런스 생성용.
final List<KwCategory> kCharacterKeywords = [
  (
    title: '종류',
    hint: '캐릭터의 기본 유형이에요.',
    items: [
      _k('소녀', 'a young girl'),
      _k('소년', 'a young boy'),
      _k('여성', 'a young woman'),
      _k('남성', 'a young man'),
      _k('중년 여성', 'a middle-aged woman'),
      _k('중년 남성', 'a middle-aged man'),
      _k('노인 여성', 'an elderly woman'),
      _k('노인 남성', 'an elderly man'),
      _k('어린아이', 'a small child'),
      _k('동물', 'an animal character'),
      _k('의인화 캐릭터', 'an anthropomorphic character'),
      _k('사물·소품', 'an object prop'),
    ],
  ),
  (
    title: '나이대',
    hint: '캐릭터의 나이 느낌이에요.',
    items: [
      _k('갓난아기', 'infant'),
      _k('유아', 'toddler age'),
      _k('어린이', 'child age'),
      _k('10대 초반', 'early teens'),
      _k('10대 후반', 'late teens'),
      _k('대학생 나이', 'college age'),
      _k('20대', 'in their twenties'),
      _k('30대', 'in their thirties'),
      _k('40대', 'in their forties'),
      _k('중년', 'middle-aged'),
      _k('노년', 'elderly'),
    ],
  ),
  (
    title: '체형',
    hint: '키와 몸의 형태예요.',
    items: [
      _k('마른', 'slim build'),
      _k('보통 체형', 'average build'),
      _k('글래머', 'curvy figure'),
      _k('근육질', 'muscular build'),
      _k('통통한', 'chubby build'),
      _k('키 큰', 'tall'),
      _k('키 작은', 'short stature'),
      _k('호리호리한', 'slender'),
      _k('다부진', 'stocky build'),
      _k('가냘픈', 'petite frame'),
    ],
  ),
  (
    title: '머리',
    hint: '머리 길이·스타일·색을 정해요.',
    items: [
      _k('긴 머리', 'long hair'),
      _k('단발', 'bob cut hair'),
      _k('숏컷', 'short hair'),
      _k('포니테일', 'ponytail'),
      _k('트윈테일', 'twin tails'),
      _k('곱슬', 'curly hair'),
      _k('웨이브', 'wavy hair'),
      _k('생머리', 'straight hair'),
      _k('땋은 머리', 'braided hair'),
      _k('묶은 머리(번)', 'hair bun'),
      _k('검은 머리', 'black hair'),
      _k('갈색 머리', 'brown hair'),
      _k('금발', 'blonde hair'),
      _k('은발', 'silver hair'),
      _k('분홍 머리', 'pink hair'),
      _k('파란 머리', 'blue hair'),
    ],
  ),
  (
    title: '의상',
    hint: '옷차림·복장이에요.',
    items: [
      _k('교복', 'school uniform'),
      _k('캐주얼', 'casual clothes'),
      _k('후드티', 'hoodie'),
      _k('정장', 'business suit'),
      _k('드레스', 'elegant dress'),
      _k('운동복', 'sportswear'),
      _k('한복', 'hanbok'),
      _k('코트', 'long coat'),
      _k('니트 스웨터', 'knit sweater'),
      _k('청바지 차림', 'jeans outfit'),
      _k('판타지 의상', 'fantasy outfit'),
      _k('갑옷', 'armor'),
      _k('제복', 'military-style uniform'),
      _k('메이드복', 'maid outfit'),
      _k('수영복', 'swimsuit'),
      _k('트렌치코트', 'trench coat'),
    ],
  ),
  (
    title: '특징',
    hint: '얼굴·신체의 개성 포인트예요.',
    items: [
      _k('안경', 'wearing glasses'),
      _k('선글라스', 'sunglasses'),
      _k('주근깨', 'freckles'),
      _k('보조개', 'dimples'),
      _k('흉터', 'a facial scar'),
      _k('점(뷰티스팟)', 'beauty mark'),
      _k('모자', 'wearing a hat'),
      _k('액세서리', 'accessories'),
      _k('귀걸이', 'earrings'),
      _k('문신', 'tattoo'),
      _k('마스크', 'face mask'),
      _k('안대', 'eyepatch'),
      _k('수염', 'beard'),
      _k('날카로운 눈매', 'sharp eyes'),
      _k('큰 눈', 'big round eyes'),
      _k('이종족 귀(엘프)', 'pointed elf ears'),
    ],
  ),
  (
    title: '직업 · 역할',
    hint: '캐릭터의 직업이나 역할이에요.',
    items: [
      _k('학생', 'student'),
      _k('직장인', 'office worker'),
      _k('의사', 'doctor'),
      _k('간호사', 'nurse'),
      _k('교사', 'teacher'),
      _k('경찰', 'police officer'),
      _k('군인', 'soldier'),
      _k('요리사', 'chef'),
      _k('전사', 'warrior'),
      _k('마법사', 'wizard'),
      _k('기사', 'knight'),
      _k('아이돌', 'pop idol'),
      _k('운동선수', 'athlete'),
      _k('예술가', 'artist'),
      _k('메이드', 'maid'),
      _k('사업가', 'businessperson'),
    ],
  ),
  (
    title: '소품 · 아이템',
    hint: '캐릭터가 들거나 착용한 아이템이에요.',
    items: [
      _k('가방', 'carrying a bag'),
      _k('백팩', 'wearing a backpack'),
      _k('책', 'holding a book'),
      _k('스마트폰', 'holding a smartphone'),
      _k('악기', 'holding an instrument'),
      _k('검', 'holding a sword'),
      _k('활', 'holding a bow'),
      _k('지팡이', 'holding a staff'),
      _k('우산', 'holding an umbrella'),
      _k('꽃다발', 'holding a bouquet'),
      _k('커피', 'holding a coffee'),
      _k('헤드폰', 'wearing headphones'),
      _k('시계', 'wristwatch'),
      _k('목걸이', 'necklace'),
      _k('장갑', 'gloves'),
      _k('망토', 'wearing a cape'),
    ],
  ),
  (
    title: '분위기',
    hint: '캐릭터가 풍기는 인상이에요.',
    items: [
      _k('명랑한', 'cheerful'),
      _k('차분한', 'calm'),
      _k('새침한', 'cool aloof'),
      _k('청순한', 'innocent'),
      _k('카리스마', 'charismatic'),
      _k('귀여운', 'cute'),
      _k('시크한', 'chic'),
      _k('다정한', 'warm friendly'),
      _k('도도한', 'proud elegant'),
      _k('장난기', 'playful mischievous'),
      _k('우아한', 'graceful'),
      _k('강인한', 'strong tough'),
      _k('신비로운', 'mysterious'),
      _k('순박한', 'wholesome'),
    ],
  ),
  (
    title: '화풍',
    hint: '캐릭터 그림체를 골라요.',
    items: [
      _k('실사(사진)', 'photorealistic, realistic photo of a real person'),
      _k('시네마틱 실사', 'cinematic photorealistic portrait'),
      _k('반실사', 'semi-realistic character art'),
      _k('3D 캐릭터', '3d rendered character'),
      _k('웹툰', 'korean webtoon style'),
      _k('순정만화', 'shoujo manga style'),
      _k('소년만화', 'shonen manga style'),
      _k('극화체', 'gritty realistic manhwa style'),
      _k('셀 애니', 'cel-shaded anime character'),
      _k('지브리풍', 'ghibli-inspired character'),
      _k('치비(SD)', 'chibi deformed style'),
      _k('수채화', 'watercolor character painting'),
      _k('파스텔', 'soft pastel colors'),
      _k('미니멀 라인', 'minimal clean line art'),
    ],
  ),
];

/// 원탭 분위기 프리셋: (한글 이름, 아이콘, 적용할 영문 키워드 묶음).
/// 키워드는 모두 kSceneKeywords 안에 존재해 → 적용 시 아래 아코디언 칩도 같이 켜져요.
typedef ScenePreset = ({String ko, IconData icon, Set<String> frags});

ScenePreset _preset(String ko, IconData icon, Set<String> frags) =>
    (ko: ko, icon: icon, frags: frags);

final List<ScenePreset> kScenePresets = [
  _preset('로맨스 감성', Icons.favorite_rounded, {
    'soft diffused light',
    'warm color tone',
    'romantic',
    'shallow depth of field, bokeh',
    'cherry blossoms',
    'soft pastel colors',
  }),
  _preset('청춘 일상', Icons.wb_sunny_rounded, {
    'natural light',
    'warm color tone',
    'medium shot',
    'nostalgic',
    'cozy cafe',
    'morning light',
  }),
  _preset('긴장감 액션', Icons.bolt_rounded, {
    'low angle',
    'dutch angle tilt',
    'motion blur',
    'tense suspenseful',
    'hard directional light',
    'fighting stance',
  }),
  _preset('호러 · 스릴러', Icons.dark_mode_rounded, {
    'low-key moody lighting',
    'eerie horror',
    'fog mist',
    'silhouette',
    'cool color tone',
    'night',
  }),
  _preset('코미디', Icons.sentiment_very_satisfied_rounded, {
    'high-key bright lighting',
    'comedic lighthearted',
    'big bright grin',
    'vivid saturated colors',
    'manga speed lines',
  }),
  _preset('판타지 서사', Icons.auto_stories_rounded, {
    'epic cinematic',
    'volumetric god rays',
    'fantasy castle',
    'wide shot',
    'golden hour light',
    'cinematic photorealistic film still',
  }),
  _preset('느와르 누아르', Icons.nightlife_rounded, {
    'noir black and white',
    'low-key moody lighting',
    'hard directional light',
    'rain',
    'narrow alley',
    'silhouette',
  }),
  _preset('드라마 감성', Icons.theaters_rounded, {
    'cinematic photorealistic film still',
    'soft diffused light',
    'shallow depth of field, bokeh',
    'nostalgic',
    'close-up shot',
    'warm color tone',
  }),
  _preset('일상 브이로그', Icons.videocam_rounded, {
    'natural light',
    'first-person POV',
    'wide-angle lens',
    'warm color tone',
    'cozy cafe',
  }),
  _preset('SF', Icons.rocket_launch_rounded, {
    'neon lighting',
    'cool color tone',
    'outer space',
    '3d rendered cgi style',
    'lens flare',
    'wide shot',
  }),
];

/// 선택된 영문 조각 + 자유 텍스트 → 최종 프롬프트
String _composePrompt(Set<String> frags, String free) {
  final parts = <String>[if (free.trim().isNotEmpty) free.trim(), ...frags];
  return parts.join(', ');
}

// ───────────────────────── 공용 위젯 ─────────────────────────

/// 토글 알약(칩). Wrap 안에서 사용.
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.paper,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.paper : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// 원탭 분위기 프리셋 칩 (아이콘 + 이름, 활성 시 강조). 가로 스크롤에서 사용.
class _PresetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _PresetChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.coral : AppColors.paper,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.coral : AppColors.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 접히는 드롭다운 섹션 하나 (헤더 탭 → 펼침/접힘, 선택 카운트 배지)
class _AccordionSection extends StatelessWidget {
  final String title;
  final String? hint;
  final List<Kw> items;
  final Set<String> selected;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  const _AccordionSection({
    required this.title,
    required this.hint,
    required this.items,
    required this.selected,
    required this.open,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final count = items.where((i) => selected.contains(i.en)).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: count > 0 ? AppColors.ink : AppColors.lineSoft,
          width: count > 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // 헤더
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: AppMotion.fast,
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 본문 (펼침)
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hint != null) ...[
                    Text(
                      hint!,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.faint,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kw in items)
                        _Pill(
                          label: kw.ko,
                          selected: selected.contains(kw.en),
                          onTap: () {
                            if (!selected.add(kw.en)) selected.remove(kw.en);
                            onChanged();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: AppMotion.fast,
          ),
        ],
      ),
    );
  }
}

/// 카테고리별 키워드 빌더 (아코디언 섹션들)
class _KeywordPicker extends StatefulWidget {
  final List<KwCategory> categories;
  final Set<String> selected; // 영문 조각 집합 (상위에서 보유)
  final VoidCallback onChanged;
  const _KeywordPicker({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_KeywordPicker> createState() => _KeywordPickerState();
}

class _KeywordPickerState extends State<_KeywordPicker> {
  final _open = <String>{}; // 펼쳐진 섹션 title 집합

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final cat in widget.categories)
          _AccordionSection(
            title: cat.title,
            hint: cat.hint,
            items: cat.items,
            selected: widget.selected,
            open: _open.contains(cat.title),
            onToggle: () => setState(() {
              if (!_open.add(cat.title)) _open.remove(cat.title);
            }),
            onChanged: () {
              setState(() {});
              widget.onChanged();
            },
          ),
      ],
    );
  }
}

/// 큰 1차 액션 버튼(알약)
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final on = enabled && !busy;
    return GestureDetector(
      onTap: on ? onTap : null,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.ink : AppColors.line,
          borderRadius: BorderRadius.circular(16),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.paper,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.notoSansKr(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.paper,
                ),
              ),
      ),
    );
  }
}

void _toast(BuildContext ctx, String msg) {
  showAppToast(ctx, msg);
}

/// 선택 개수 요약 줄 ("키워드 N개 선택됨")
class _SelectedSummary extends StatelessWidget {
  final int count;
  final VoidCallback onClear;
  const _SelectedSummary({required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Text(
        '키워드를 안 골라도 돼요 — 그러면 적은 설명대로 그려요.',
        style: GoogleFonts.notoSansKr(fontSize: 12.5, color: AppColors.faint),
      );
    }
    return Row(
      children: [
        Text(
          '키워드 $count개 선택됨',
          style: GoogleFonts.notoSansKr(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.coral,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onClear,
          child: Text(
            '모두 해제',
            style: GoogleFonts.notoSansKr(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 컷 생성 시트 ─────────────────────────

/// 컷 생성 '요청'을 받는 시트 — 실제 생성은 호출부(작가 화면)가 진행해
/// 시트는 바로 닫히고 컷 영역에 스피너가 뜨게 함.
/// 반환: { prompt, characters } / 취소 시 null.
/// [initialPrompt] : 스토리보드가 추천한 장면 묘사를 미리 채워 줌.
/// [initialCharacter] : 작가 화면에서 고른 등장인물을 기본 선택(일관성).
Future<
    ({
      String prompt,
      List<AiCharacter> characters,
      List<String> scenePhotos,
    })?> showAiGenerateSheet(
  BuildContext context, {
  String? initialPrompt,
  AiCharacter? initialCharacter,
}) {
  return showModalBottomSheet<
      ({
        String prompt,
        List<AiCharacter> characters,
        List<String> scenePhotos,
      })>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AiGenerateSheet(
      initialPrompt: initialPrompt,
      initialCharacter: initialCharacter,
    ),
  );
}

class _AiGenerateSheet extends StatefulWidget {
  final String? initialPrompt;
  final AiCharacter? initialCharacter;
  const _AiGenerateSheet({this.initialPrompt, this.initialCharacter});
  @override
  State<_AiGenerateSheet> createState() => _AiGenerateSheetState();
}

class _AiGenerateSheetState extends State<_AiGenerateSheet> {
  final _frags = <String>{};
  late final _free = TextEditingController(text: widget.initialPrompt ?? '');
  List<AiCharacter> _chars = [];
  // 한 컷에 여러 인물이 나올 수 있어 다중 선택(최대 3명)
  late final List<AiCharacter> _picked = widget.initialCharacter != null
      ? [widget.initialCharacter!]
      : [];
  static const _maxChars = 3;
  bool _loadingChars = true;
  bool _suggesting = false; // AI 키워드 추천 진행 중

  // 장면 참고 사진(배경·구도·사물·분위기 참고용, 로컬 경로 최대 3장)
  final List<String> _scenePhotos = [];
  static const _maxScenePhotos = 3;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _free.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await Cloud.listAiCharacters();
      if (mounted) {
        setState(() {
          _chars = list;
          _loadingChars = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChars = false);
    }
  }

  bool get _canGen => _frags.isNotEmpty || _free.text.trim().isNotEmpty;

  // 생성하지 않고 '무엇을 그릴지'만 모아서 닫음 → 작가 화면이 컷에서 생성
  void _submit() {
    if (!_canGen) return;
    Navigator.of(context).pop((
      prompt: _composePrompt(_frags, _free.text),
      characters: List<AiCharacter>.of(_picked.take(_maxChars)),
      scenePhotos: List<String>.of(_scenePhotos),
    ));
  }

  // 장면 참고 사진 추가 — 앨범/카메라에서 골라 _scenePhotos에 담음
  Future<void> _addScenePhoto() async {
    if (_scenePhotos.length >= _maxScenePhotos) {
      _toast(context, '참고 사진은 최대 $_maxScenePhotos장까지예요.');
      return;
    }
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_library_rounded, color: AppColors.ink),
              title: Text('앨범에서 선택',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: AppColors.ink),
              title: Text('사진 찍기',
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (src == null || !mounted) return;
    try {
      final x =
          await _picker.pickImage(source: src, maxWidth: 1280, imageQuality: 88);
      if (x != null && mounted) {
        setState(() => _scenePhotos.add(x.path));
      }
    } catch (_) {
      if (mounted) _toast(context, '사진을 불러오지 못했어요.');
    }
  }

  Widget _scenePhotoTile(int i) {
    return Container(
      width: 72,
      height: 72,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_scenePhotos[i]),
                width: 72, height: 72, fit: BoxFit.cover),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: () => setState(() => _scenePhotos.removeAt(i)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child:
                    const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addScenePhotoTile() {
    return GestureDetector(
      onTap: _addScenePhoto,
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.only(right: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: const Icon(Icons.add_photo_alternate_rounded,
            color: AppColors.faint, size: 26),
      ),
    );
  }

  Future<void> _newCharacter() async {
    final c = await showCharacterCreateSheet(context);
    if (c != null && mounted) {
      setState(() {
        _chars = [c, ..._chars];
        if (_picked.length < _maxChars) _picked.add(c);
      });
    }
  }

  // 프리셋이 활성인지: 그 프리셋의 키워드가 모두 _frags에 들어있으면 활성.
  bool _isPresetActive(ScenePreset p) => p.frags.every(_frags.contains);

  // 프리셋 토글: 활성이면 그 키워드들을 빼고, 아니면 모두 더함.
  void _togglePreset(ScenePreset p) {
    setState(() {
      if (_isPresetActive(p)) {
        _frags.removeAll(p.frags);
      } else {
        _frags.addAll(p.frags);
      }
    });
  }

  // AI 추천 — 장면 설명을 보고 어울리는 키워드를 골라 _frags에 담음
  Future<void> _suggestKw() async {
    final scene = _free.text.trim();
    if (scene.length < 2 || _suggesting) return;
    FocusScope.of(context).unfocus();
    setState(() => _suggesting = true);
    try {
      final cand = [
        for (final cat in kSceneKeywords)
          for (final kw in cat.items) kw.en,
      ];
      final picked = await Cloud.suggestKeywords(scene, cand);
      if (!mounted) return;
      setState(() {
        _frags.addAll(picked);
        _suggesting = false;
      });
      _toast(
        context,
        picked.isEmpty
            ? '딱 맞는 키워드를 못 찾았어요. 장면을 조금 더 적어 주세요.'
            : '추천 키워드 ${picked.length}개를 골라뒀어요.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggesting = false);
      _toast(context, '추천에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  void _toggleChar(AiCharacter c) {
    setState(() {
      final i = _picked.indexWhere((x) => x.id == c.id);
      if (i >= 0) {
        _picked.removeAt(i);
      } else if (_picked.length < _maxChars) {
        _picked.add(c);
      } else {
        _toast(context, '한 컷에는 최대 $_maxChars명까지 넣을 수 있어요.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (_, scroll) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI로 장면 만들기',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 1) 어떤 장면? — 주 입력(맨 위)
                  Text(
                    '어떤 장면을 그릴까요?',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _free,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.notoSansKr(fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: '예: 커피를 들고 창밖을 보며 미소짓는 사람',
                      hintStyle: GoogleFonts.notoSansKr(color: AppColors.faint),
                      filled: true,
                      fillColor: AppColors.paper,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '아래에서 촬영·연출 키워드를 더하면 더 정확해져요 (선택).',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.faint,
                    ),
                  ),

                  // AI 자동 추천 — 장면 설명에 맞는 키워드를 골라줌
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: (_free.text.trim().length < 2 || _suggesting)
                        ? null
                        : _suggestKw,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _free.text.trim().length < 2
                            ? AppColors.paper
                            : AppColors.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _free.text.trim().length < 2
                              ? AppColors.line
                              : AppColors.gold,
                          width: 1.3,
                        ),
                      ),
                      child: _suggesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.gold,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_fix_high_rounded,
                                  size: 17,
                                  color: _free.text.trim().length < 2
                                      ? AppColors.faint
                                      : AppColors.ink,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '이 장면에 맞는 키워드 자동 추천',
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: _free.text.trim().length < 2
                                        ? AppColors.faint
                                        : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // 1-b) 빠른 분위기 — 원탭 프리셋 (초보자용)
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.flash_on_rounded,
                          size: 15,
                          color: AppColors.coral,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '빠른 분위기',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '탭 한 번이면 어울리는 키워드가 자동으로 골라져요.',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11.5,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final p in kScenePresets)
                          _PresetChip(
                            label: p.ko,
                            icon: p.icon,
                            active: _isPresetActive(p),
                            onTap: () => _togglePreset(p),
                          ),
                      ],
                    ),
                  ),

                  // 2) 이 컷에 나올 인물 (다중 선택, 일관성)
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 2),
                    child: Text(
                      _picked.isEmpty
                          ? '이 컷에 나올 인물 (일관성 유지)'
                          : '이 컷에 나올 인물 · ${_picked.length}명 선택',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '여러 명 고르면 한 컷에 같이 나와요 (최대 3명).',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11.5,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                  _CharacterStrip(
                    chars: _chars,
                    loading: _loadingChars,
                    picked: _picked,
                    onToggle: _toggleChar,
                    onClear: () => setState(_picked.clear),
                    onNew: _newCharacter,
                  ),

                  // 2-b) 장면 참고 사진 (배경·구도·사물·분위기 참고)
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 2),
                    child: Text(
                      _scenePhotos.isEmpty
                          ? '장면 참고 사진 (선택)'
                          : '장면 참고 사진 · ${_scenePhotos.length}장',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '배경·구도·사물·분위기를 참고해요. (인물은 위에서 골라요)',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11.5,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 84,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < _scenePhotos.length; i++)
                          _scenePhotoTile(i),
                        if (_scenePhotos.length < _maxScenePhotos)
                          _addScenePhotoTile(),
                      ],
                    ),
                  ),

                  // 3) 촬영·연출 키워드 (아코디언, 보조)
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          '촬영 · 연출 키워드',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SelectedSummary(
                            count: _frags.length,
                            onClear: () => setState(_frags.clear),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _KeywordPicker(
                    categories: kSceneKeywords,
                    selected: _frags,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _PrimaryButton(
                    label: '이 장면 그리기',
                    enabled: _canGen,
                    onTap: _submit,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 캐릭터 가로 스트립(다중 선택): [안 정함] + 캐릭터 아바타들 + [새로 만들기]
class _CharacterStrip extends StatelessWidget {
  final List<AiCharacter> chars;
  final bool loading;
  final List<AiCharacter> picked;
  final ValueChanged<AiCharacter> onToggle;
  final VoidCallback onClear;
  final VoidCallback onNew;
  const _CharacterStrip({
    required this.chars,
    required this.loading,
    required this.picked,
    required this.onToggle,
    required this.onClear,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _miniTile(
            label: '안 정함',
            selected: picked.isEmpty,
            onTap: onClear,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.faint,
              size: 24,
            ),
          ),
          for (final c in chars)
            _miniTile(
              label: c.name,
              selected: picked.any((p) => p.id == c.id),
              onTap: () => onToggle(c),
              child: ClipOval(
                child: Image.network(
                  c.imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) =>
                      const Icon(Icons.person_rounded, color: AppColors.faint),
                ),
              ),
            ),
          _miniTile(
            label: '새로 만들기',
            selected: false,
            onTap: onNew,
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.coral,
              size: 26,
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.ink : AppColors.line,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: child,
                ),
                // 다중 선택 체크 배지
                if (selected && label != '안 정함')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.card, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.paper,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? AppColors.ink : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 캐릭터 생성 시트 ─────────────────────────

/// 캐릭터/사물 레퍼런스를 만들고 저장. 저장 시 [AiCharacter]를 pop으로 반환.
Future<AiCharacter?> showCharacterCreateSheet(BuildContext context) {
  return showModalBottomSheet<AiCharacter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CharacterCreateSheet(),
  );
}

class _CharacterCreateSheet extends StatefulWidget {
  const _CharacterCreateSheet();
  @override
  State<_CharacterCreateSheet> createState() => _CharacterCreateSheetState();
}

class _CharacterCreateSheetState extends State<_CharacterCreateSheet> {
  final _name = TextEditingController();
  final _frags = <String>{};
  final _free = TextEditingController();
  bool _busy = false;
  String? _previewPath; // 생성된 레퍼런스(미저장)

  @override
  void dispose() {
    _name.dispose();
    _free.dispose();
    super.dispose();
  }

  bool get _canGen => _frags.isNotEmpty || _free.text.trim().isNotEmpty;
  bool get _canSave => _previewPath != null && _name.text.trim().isNotEmpty;

  Future<void> _generate() async {
    if (!_canGen || _busy) return;
    setState(() => _busy = true);
    try {
      // 레퍼런스용: 전신 + 단순 배경 지시 추가
      final prompt = _composePrompt(
        _frags,
        '${_free.text}, full body character reference, plain background',
      );
      final res = await Cloud.generateAiImage(prompt);
      if (!mounted) return;
      setState(() {
        _previewPath = res.path;
        _busy = false;
      });
    } on AiQuotaException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, '이번 달 AI 생성 ${e.limit}회를 모두 썼어요. 구독하면 더 만들 수 있어요.');
    } on AiNoImageException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, '생성에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> _save() async {
    if (!_canSave || _busy) return;
    setState(() => _busy = true);
    try {
      final c = await Cloud.createAiCharacter(
        name: _name.text.trim(),
        localImagePath: _previewPath!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, '저장에 실패했어요. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (_, scroll) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.theater_comedy_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '캐릭터 · 사물 만들기',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '한 번 만들면 컷마다 같은 모습으로 그릴 수 있어요.',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),

                  // 이름
                  const SizedBox(height: 18),
                  Text(
                    '이름',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.notoSansKr(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '예: 민지',
                      hintStyle: GoogleFonts.notoSansKr(color: AppColors.faint),
                      filled: true,
                      fillColor: AppColors.paper,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),

                  // 미리보기
                  if (_previewPath != null) ...[
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_previewPath!),
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        '마음에 안 들면 키워드를 바꿔 다시 생성하세요',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11.5,
                          color: AppColors.faint,
                        ),
                      ),
                    ),
                  ],

                  // 외형 키워드 (아코디언)
                  const SizedBox(height: 16),
                  _SelectedSummary(
                    count: _frags.length,
                    onClear: () => setState(_frags.clear),
                  ),
                  const SizedBox(height: 12),
                  _KeywordPicker(
                    categories: kCharacterKeywords,
                    selected: _frags,
                    onChanged: () => setState(() {}),
                  ),

                  // 자유 설명
                  const SizedBox(height: 8),
                  Text(
                    '추가 설명 (선택)',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _free,
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.notoSansKr(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '예: 동그란 안경, 주근깨',
                      hintStyle: GoogleFonts.notoSansKr(color: AppColors.faint),
                      filled: true,
                      fillColor: AppColors.paper,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PrimaryButton(
                    label: _previewPath == null
                        ? (_busy ? '그리는 중…' : '캐릭터 생성')
                        : (_busy ? '저장 중…' : '다시 생성'),
                    enabled: _canGen,
                    busy: _busy && _previewPath == null,
                    onTap: _generate,
                  ),
                  if (_previewPath != null) ...[
                    const SizedBox(height: 10),
                    _PrimaryButton(
                      label: '이 캐릭터로 저장',
                      enabled: _canSave,
                      busy: _busy,
                      onTap: _save,
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── AI 스토리보드 시트 ─────────────────────────

/// 컷 한 개의 추천 데이터 (장면 프롬프트 + 화자 + 대사 + 연기 지시)
typedef StoryCut = ({
  String scenePrompt,
  String speaker,
  String dialogue,
  String direction,
});

/// 스토리보드 추천 결과 (suggestCuts 반환과 동일 구조)
typedef StoryboardResult = ({
  String title,
  String logline,
  List<StoryCut> cuts,
});

/// 스토리보드 시트가 최종 반환하는 값 — 추천 결과 + 화자별 캐릭터 배정.
/// [castBySpeaker] : 화자 이름 → 그 화자를 그릴 캐릭터(레퍼런스). 비우면 자동.
typedef StoryboardPick = ({
  String title,
  String logline,
  List<StoryCut> cuts,
  Map<String, AiCharacter> castBySpeaker,
});

/// 전체 상황 → AI 컷 추천 시트. "이 구성으로 만들기" 시 결과를 pop으로 반환.
Future<StoryboardPick?> showStoryboardSheet(BuildContext context) {
  return showModalBottomSheet<StoryboardPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _StoryboardSheet(),
  );
}

class _StoryboardSheet extends StatefulWidget {
  const _StoryboardSheet();
  @override
  State<_StoryboardSheet> createState() => _StoryboardSheetState();
}

class _StoryboardSheetState extends State<_StoryboardSheet> {
  final _situation = TextEditingController();
  bool _busy = false;
  StoryboardResult? _result;

  // 등장인물 — 화자별로 어떤 캐릭터(레퍼런스)로 그릴지 배정
  List<AiCharacter> _chars = [];
  bool _loadingChars = true;
  final Map<String, AiCharacter> _cast = {}; // 화자 이름 → 캐릭터

  @override
  void initState() {
    super.initState();
    _reloadChars();
  }

  @override
  void dispose() {
    _situation.dispose();
    super.dispose();
  }

  Future<void> _reloadChars() async {
    try {
      final list = await Cloud.listAiCharacters();
      if (mounted) {
        setState(() {
          _chars = list;
          _loadingChars = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChars = false);
    }
  }

  /// 추천 결과의 고유 화자(등장 순서 유지). 빈 화자는 제외.
  List<String> get _speakers {
    final r = _result;
    if (r == null) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final c in r.cuts) {
      final s = c.speaker.trim();
      if (s.isEmpty || !seen.add(s)) continue;
      out.add(s);
    }
    return out;
  }

  void _assign(String speaker, AiCharacter? c) {
    setState(() {
      if (c == null) {
        _cast.remove(speaker);
      } else {
        _cast[speaker] = c;
      }
    });
  }

  Future<void> _newCharacterFor(String speaker) async {
    final c = await showCharacterCreateSheet(context);
    if (c != null && mounted) {
      setState(() {
        _chars = [c, ..._chars];
        _cast[speaker] = c;
      });
    }
  }

  Future<void> _suggest() async {
    final s = _situation.text.trim();
    if (s.length < 4 || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final r = await Cloud.suggestCuts(s);
      if (!mounted) return;
      setState(() {
        _result = r;
        _busy = false;
        // 화자 이름과 같은 캐릭터가 이미 있으면 자동 배정
        _cast.clear();
        for (final c in r.cuts) {
          final sp = c.speaker.trim();
          if (sp.isEmpty || _cast.containsKey(sp)) continue;
          final match = _chars.where((x) => x.name.trim() == sp);
          if (match.isNotEmpty) _cast[sp] = match.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, '추천에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final r = _result;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (_, scroll) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.movie_filter_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI 스토리보드',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '전체 상황을 적으면 AI가 컷(장면+대사)으로 나눠줘요.',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),

                  // 상황 입력
                  const SizedBox(height: 16),
                  Text(
                    '어떤 이야기인가요?',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _situation,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.notoSansKr(fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: '예: 소개팅 나갔는데 상대가 전 여친이었던 남자의 당황',
                      hintStyle: GoogleFonts.notoSansKr(color: AppColors.faint),
                      filled: true,
                      fillColor: AppColors.paper,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PrimaryButton(
                    label: _busy
                        ? '콘티 짜는 중…'
                        : (r == null ? '컷 추천 받기' : '다시 추천'),
                    enabled: _situation.text.trim().length >= 4,
                    busy: _busy,
                    onTap: _suggest,
                  ),

                  // 로딩 중 — 명확한 안내(닫지 말고 기다리게)
                  if (_busy) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.lineSoft),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: AppColors.gold,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'AI가 장면을 컷으로 나누는 중…',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '약 10초 정도 걸려요. 잠깐만 기다려 주세요.',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 추천 결과
                  if (r != null) ...[
                    const SizedBox(height: 22),
                    Text(
                      r.title,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.logline,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),

                    // 등장인물 배정 — 화자마다 어떤 캐릭터로 그릴지 (선택)
                    if (_speakers.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        '누구로 그릴까요?',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '화자별로 캐릭터를 정하면 컷마다 같은 인물로 그려요. (선택)',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final sp in _speakers)
                        _CastAssignRow(
                          speaker: sp,
                          chars: _chars,
                          loading: _loadingChars,
                          selected: _cast[sp],
                          onSelect: (c) => _assign(sp, c),
                          onNew: () => _newCharacterFor(sp),
                        ),
                    ],

                    const SizedBox(height: 14),
                    for (var i = 0; i < r.cuts.length; i++)
                      _StoryCutPreview(index: i + 1, cut: r.cuts[i]),
                    const SizedBox(height: 16),
                    _PrimaryButton(
                      label: '이 구성으로 만들기 (컷 ${r.cuts.length}개)',
                      onTap: () => Navigator.of(context).pop((
                        title: r.title,
                        logline: r.logline,
                        cuts: r.cuts,
                        castBySpeaker: Map<String, AiCharacter>.of(_cast),
                      )),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 화자 한 명의 캐릭터 배정 줄 — [화자명] + 가로(안 정함 · 캐릭터들 · 새로 만들기).
/// 단일 선택. 같은 이름의 캐릭터가 있으면 상위에서 자동 배정됨.
class _CastAssignRow extends StatelessWidget {
  final String speaker;
  final List<AiCharacter> chars;
  final bool loading;
  final AiCharacter? selected;
  final ValueChanged<AiCharacter?> onSelect;
  final VoidCallback onNew;
  const _CastAssignRow({
    required this.speaker,
    required this.chars,
    required this.loading,
    required this.selected,
    required this.onSelect,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected != null ? AppColors.ink : AppColors.lineSoft,
          width: selected != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded,
                  size: 15, color: AppColors.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  speaker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                selected == null ? '안 정함' : selected!.name,
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected == null ? AppColors.faint : AppColors.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _tile(
                  label: '안 정함',
                  selected: selected == null,
                  onTap: () => onSelect(null),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.faint, size: 20),
                ),
                for (final c in chars)
                  _tile(
                    label: c.name,
                    selected: selected?.id == c.id,
                    onTap: () => onSelect(c),
                    child: ClipOval(
                      child: Image.network(
                        c.imageUrl,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => const Icon(
                            Icons.person_rounded, color: AppColors.faint),
                      ),
                    ),
                  ),
                _tile(
                  label: '새로',
                  selected: false,
                  onTap: onNew,
                  child: const Icon(Icons.add_rounded,
                      color: AppColors.coral, size: 22),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 58,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.ink : AppColors.line,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: child,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansKr(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? AppColors.ink : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 추천된 컷 한 개 미리보기 카드
class _StoryCutPreview extends StatelessWidget {
  final int index;
  final ({
    String scenePrompt,
    String speaker,
    String dialogue,
    String direction,
  })
  cut;
  const _StoryCutPreview({required this.index, required this.cut});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '컷 $index',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.paper,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cut.speaker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${cut.dialogue}"',
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.image_outlined,
                size: 14,
                color: AppColors.faint,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  cut.scenePrompt,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11.5,
                    color: AppColors.faint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
