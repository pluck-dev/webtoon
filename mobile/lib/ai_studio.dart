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

import 'cloud.dart';
import 'config.dart';
import 'models.dart';

/// 키워드 한 개: 화면 표시는 한글(ko), 프롬프트엔 영문(en) 사용.
typedef Kw = ({String ko, String en});
typedef KwCategory = ({String title, List<Kw> items});

Kw _k(String ko, String en) => (ko: ko, en: en);

/// 장면(컷) 키워드 — 영화/촬영 전문 용어 기반. 드롭다운 섹션별 다중 선택.
final List<KwCategory> kSceneKeywords = [
  (
    title: '화각 · 샷 크기',
    items: [
      _k('익스트림 클로즈업', 'extreme close-up'),
      _k('클로즈업', 'close-up shot'),
      _k('바스트샷', 'bust shot'),
      _k('미디엄샷', 'medium shot'),
      _k('카우보이샷', 'cowboy shot'),
      _k('풀샷', 'full body shot'),
      _k('와이드샷', 'wide shot'),
      _k('익스트림 와이드', 'extreme wide establishing shot'),
      _k('투샷', 'two shot'),
      _k('오버더숄더', 'over-the-shoulder shot'),
    ],
  ),
  (
    title: '촬영 각도',
    items: [
      _k('정면(아이레벨)', 'eye-level angle'),
      _k('하이앵글', 'high angle'),
      _k('로우앵글', 'low angle'),
      _k('버드아이뷰', "bird's-eye view"),
      _k('웜즈아이뷰', "worm's-eye view"),
      _k('더치앵글', 'dutch angle tilt'),
      _k('탑다운', 'top-down overhead'),
      _k('뒤에서', 'from behind'),
      _k('POV 시점', 'first-person POV'),
    ],
  ),
  (
    title: '렌즈 · 심도',
    items: [
      _k('광각', 'wide-angle lens'),
      _k('망원', 'telephoto lens'),
      _k('어안렌즈', 'fisheye lens'),
      _k('아웃포커스(보케)', 'shallow depth of field, bokeh'),
      _k('팬포커스', 'deep focus'),
      _k('매크로', 'macro close detail'),
      _k('틸트시프트', 'tilt-shift miniature'),
    ],
  ),
  (
    title: '조명',
    items: [
      _k('자연광', 'natural light'),
      _k('황금시간대', 'golden hour light'),
      _k('역광', 'backlight'),
      _k('림라이트', 'rim lighting'),
      _k('실루엣', 'silhouette'),
      _k('하드라이트', 'hard directional light'),
      _k('소프트라이트', 'soft diffused light'),
      _k('네온', 'neon lighting'),
      _k('캔들라이트', 'candlelight glow'),
      _k('로우키(무드)', 'low-key moody lighting'),
      _k('하이키(밝은)', 'high-key bright lighting'),
    ],
  ),
  (
    title: '연출 기법',
    items: [
      _k('모션블러', 'motion blur'),
      _k('스피드라인', 'manga speed lines'),
      _k('집중선', 'focus concentration lines'),
      _k('더블 익스포저', 'double exposure'),
      _k('렌즈플레어', 'lens flare'),
      _k('비네팅', 'vignette'),
      _k('필름그레인', 'film grain'),
      _k('god ray(광선)', 'volumetric god rays'),
      _k('보케 배경', 'bokeh background'),
      _k('롱 익스포저', 'long exposure light trails'),
    ],
  ),
  (
    title: '분위기 · 톤',
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
    ],
  ),
  (
    title: '배경 · 장소',
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
      _k('판타지 성', 'fantasy castle'),
      _k('우주', 'outer space'),
    ],
  ),
  (
    title: '시간 · 날씨',
    items: [
      _k('아침', 'morning light'),
      _k('한낮', 'midday'),
      _k('노을', 'sunset glow'),
      _k('황혼', 'dusk twilight'),
      _k('밤', 'night'),
      _k('비', 'rain'),
      _k('폭우', 'heavy downpour'),
      _k('눈', 'snow'),
      _k('안개', 'fog mist'),
      _k('맑음', 'clear sky'),
      _k('흐림', 'overcast'),
      _k('벚꽃', 'cherry blossoms'),
      _k('단풍', 'autumn leaves'),
    ],
  ),
  (
    title: '표정 · 감정',
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
    ],
  ),
  (
    title: '동작 · 포즈',
    items: [
      _k('서있기', 'standing'),
      _k('앉기', 'sitting'),
      _k('달리기', 'running'),
      _k('점프', 'jumping mid-air'),
      _k('뒤돌아보기', 'looking back over shoulder'),
      _k('손 흔들기', 'waving hand'),
      _k('팔짱', 'arms crossed'),
      _k('기대기', 'leaning against wall'),
      _k('쓰러지기', 'collapsing'),
      _k('포옹', 'hugging'),
      _k('전투 자세', 'fighting stance'),
    ],
  ),
  (
    title: '화풍 · 스타일',
    items: [
      _k('웹툰', 'korean webtoon style'),
      _k('순정만화', 'shoujo manga style'),
      _k('소년만화', 'shonen manga style'),
      _k('수채화', 'watercolor painting'),
      _k('셀 애니', 'cel-shaded anime'),
      _k('느와르 흑백', 'noir black and white'),
      _k('파스텔', 'soft pastel colors'),
      _k('비비드', 'vivid saturated colors'),
      _k('미니멀 라인', 'minimal clean line art'),
    ],
  ),
];

/// 캐릭터·사물 외형 키워드 — 레퍼런스 생성용.
final List<KwCategory> kCharacterKeywords = [
  (
    title: '종류',
    items: [
      _k('소녀', 'a young girl'),
      _k('소년', 'a young boy'),
      _k('여성', 'a young woman'),
      _k('남성', 'a young man'),
      _k('중년 여성', 'a middle-aged woman'),
      _k('중년 남성', 'a middle-aged man'),
      _k('동물', 'an animal character'),
      _k('사물·소품', 'an object prop'),
    ],
  ),
  (
    title: '머리',
    items: [
      _k('긴 머리', 'long hair'),
      _k('단발', 'bob cut hair'),
      _k('숏컷', 'short hair'),
      _k('포니테일', 'ponytail'),
      _k('곱슬', 'curly hair'),
      _k('검은 머리', 'black hair'),
      _k('갈색 머리', 'brown hair'),
      _k('금발', 'blonde hair'),
      _k('분홍 머리', 'pink hair'),
      _k('파란 머리', 'blue hair'),
    ],
  ),
  (
    title: '의상',
    items: [
      _k('교복', 'school uniform'),
      _k('캐주얼', 'casual clothes'),
      _k('후드티', 'hoodie'),
      _k('정장', 'business suit'),
      _k('드레스', 'dress'),
      _k('운동복', 'sportswear'),
      _k('한복', 'hanbok'),
      _k('판타지 의상', 'fantasy outfit'),
      _k('교련복/제복', 'military-style uniform'),
    ],
  ),
  (
    title: '특징',
    items: [
      _k('안경', 'wearing glasses'),
      _k('주근깨', 'freckles'),
      _k('보조개', 'dimples'),
      _k('흉터', 'a scar'),
      _k('모자', 'wearing a hat'),
      _k('액세서리', 'accessories'),
      _k('문신', 'tattoo'),
    ],
  ),
  (
    title: '분위기',
    items: [
      _k('명랑한', 'cheerful'),
      _k('차분한', 'calm'),
      _k('새침한', 'cool aloof'),
      _k('청순한', 'innocent'),
      _k('카리스마', 'charismatic'),
      _k('귀여운', 'cute'),
      _k('시크한', 'chic'),
    ],
  ),
  (
    title: '화풍',
    items: [
      _k('웹툰', 'korean webtoon style'),
      _k('순정만화', 'shoujo manga style'),
      _k('소년만화', 'shonen manga style'),
      _k('파스텔', 'soft pastel colors'),
      _k('미니멀 라인', 'minimal clean line art'),
    ],
  ),
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

/// 접히는 드롭다운 섹션 하나 (헤더 탭 → 펼침/접힘, 선택 카운트 배지)
class _AccordionSection extends StatelessWidget {
  final String title;
  final List<Kw> items;
  final Set<String> selected;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  const _AccordionSection({
    required this.title,
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
              child: Wrap(
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
Future<({String prompt, List<AiCharacter> characters})?> showAiGenerateSheet(
  BuildContext context, {
  String? initialPrompt,
  AiCharacter? initialCharacter,
}) {
  return showModalBottomSheet<({String prompt, List<AiCharacter> characters})>(
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
    ));
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
