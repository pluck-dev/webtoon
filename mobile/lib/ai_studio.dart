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
  (title: '화각 · 샷 크기', items: [
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
  ]),
  (title: '촬영 각도', items: [
    _k('정면(아이레벨)', 'eye-level angle'),
    _k('하이앵글', 'high angle'),
    _k('로우앵글', 'low angle'),
    _k('버드아이뷰', "bird's-eye view"),
    _k('웜즈아이뷰', "worm's-eye view"),
    _k('더치앵글', 'dutch angle tilt'),
    _k('탑다운', 'top-down overhead'),
    _k('뒤에서', 'from behind'),
    _k('POV 시점', 'first-person POV'),
  ]),
  (title: '렌즈 · 심도', items: [
    _k('광각', 'wide-angle lens'),
    _k('망원', 'telephoto lens'),
    _k('어안렌즈', 'fisheye lens'),
    _k('아웃포커스(보케)', 'shallow depth of field, bokeh'),
    _k('팬포커스', 'deep focus'),
    _k('매크로', 'macro close detail'),
    _k('틸트시프트', 'tilt-shift miniature'),
  ]),
  (title: '조명', items: [
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
  ]),
  (title: '연출 기법', items: [
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
  ]),
  (title: '분위기 · 톤', items: [
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
  ]),
  (title: '배경 · 장소', items: [
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
  ]),
  (title: '시간 · 날씨', items: [
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
  ]),
  (title: '표정 · 감정', items: [
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
  ]),
  (title: '동작 · 포즈', items: [
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
  ]),
  (title: '화풍 · 스타일', items: [
    _k('웹툰', 'korean webtoon style'),
    _k('순정만화', 'shoujo manga style'),
    _k('소년만화', 'shonen manga style'),
    _k('수채화', 'watercolor painting'),
    _k('셀 애니', 'cel-shaded anime'),
    _k('느와르 흑백', 'noir black and white'),
    _k('파스텔', 'soft pastel colors'),
    _k('비비드', 'vivid saturated colors'),
    _k('미니멀 라인', 'minimal clean line art'),
  ]),
];

/// 캐릭터·사물 외형 키워드 — 레퍼런스 생성용.
final List<KwCategory> kCharacterKeywords = [
  (title: '종류', items: [
    _k('소녀', 'a young girl'),
    _k('소년', 'a young boy'),
    _k('여성', 'a young woman'),
    _k('남성', 'a young man'),
    _k('중년 여성', 'a middle-aged woman'),
    _k('중년 남성', 'a middle-aged man'),
    _k('동물', 'an animal character'),
    _k('사물·소품', 'an object prop'),
  ]),
  (title: '머리', items: [
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
  ]),
  (title: '의상', items: [
    _k('교복', 'school uniform'),
    _k('캐주얼', 'casual clothes'),
    _k('후드티', 'hoodie'),
    _k('정장', 'business suit'),
    _k('드레스', 'dress'),
    _k('운동복', 'sportswear'),
    _k('한복', 'hanbok'),
    _k('판타지 의상', 'fantasy outfit'),
    _k('교련복/제복', 'military-style uniform'),
  ]),
  (title: '특징', items: [
    _k('안경', 'wearing glasses'),
    _k('주근깨', 'freckles'),
    _k('보조개', 'dimples'),
    _k('흉터', 'a scar'),
    _k('모자', 'wearing a hat'),
    _k('액세서리', 'accessories'),
    _k('문신', 'tattoo'),
  ]),
  (title: '분위기', items: [
    _k('명랑한', 'cheerful'),
    _k('차분한', 'calm'),
    _k('새침한', 'cool aloof'),
    _k('청순한', 'innocent'),
    _k('카리스마', 'charismatic'),
    _k('귀여운', 'cute'),
    _k('시크한', 'chic'),
  ]),
  (title: '화풍', items: [
    _k('웹툰', 'korean webtoon style'),
    _k('순정만화', 'shoujo manga style'),
    _k('소년만화', 'shonen manga style'),
    _k('파스텔', 'soft pastel colors'),
    _k('미니멀 라인', 'minimal clean line art'),
  ]),
];

/// 선택된 영문 조각 + 자유 텍스트 → 최종 프롬프트
String _composePrompt(Set<String> frags, String free) {
  final parts = <String>[
    if (free.trim().isNotEmpty) free.trim(),
    ...frags,
  ];
  return parts.join(', ');
}

// ───────────────────────── 공용 위젯 ─────────────────────────

/// 토글 알약(칩). Wrap 안에서 사용.
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill(
      {required this.label, required this.selected, required this.onTap});

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
              color: selected ? AppColors.ink : AppColors.line, width: 1),
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
            width: count > 0 ? 1.5 : 1),
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
                  Text(title,
                      style: GoogleFonts.notoSansKr(
                          fontSize: 14.5, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text('$count',
                          style: GoogleFonts.notoSansKr(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: AppMotion.fast,
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppColors.muted),
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
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
  const _KeywordPicker(
      {required this.categories,
      required this.selected,
      required this.onChanged});

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
  const _PrimaryButton(
      {required this.label,
      required this.onTap,
      this.enabled = true,
      this.busy = false});

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
                    strokeWidth: 2.4, color: AppColors.paper))
            : Text(label,
                style: GoogleFonts.notoSansKr(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.paper)),
      ),
    );
  }
}

void _toast(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content:
        Text(msg, style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w700)),
    behavior: SnackBarBehavior.floating,
  ));
}

/// 선택 개수 요약 줄 ("키워드 N개 선택됨")
class _SelectedSummary extends StatelessWidget {
  final int count;
  final VoidCallback onClear;
  const _SelectedSummary({required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Text('키워드를 안 골라도 돼요 — 그러면 적은 설명대로 그려요.',
          style:
              GoogleFonts.notoSansKr(fontSize: 12.5, color: AppColors.faint));
    }
    return Row(
      children: [
        Text('키워드 $count개 선택됨',
            style: GoogleFonts.notoSansKr(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.coral)),
        const Spacer(),
        GestureDetector(
          onTap: onClear,
          child: Text('모두 해제',
              style: GoogleFonts.notoSansKr(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted)),
        ),
      ],
    );
  }
}

// ───────────────────────── 컷 생성 시트 ─────────────────────────

/// 컷 이미지 생성 시트. 성공 시 생성 결과를 pop으로 반환.
/// [initialPrompt] : 스토리보드가 추천한 장면 묘사를 미리 채워 줌.
Future<({String path, int remaining, bool stub})?> showAiGenerateSheet(
  BuildContext context, {
  String? initialPrompt,
}) {
  return showModalBottomSheet<({String path, int remaining, bool stub})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AiGenerateSheet(initialPrompt: initialPrompt),
  );
}

class _AiGenerateSheet extends StatefulWidget {
  final String? initialPrompt;
  const _AiGenerateSheet({this.initialPrompt});
  @override
  State<_AiGenerateSheet> createState() => _AiGenerateSheetState();
}

class _AiGenerateSheetState extends State<_AiGenerateSheet> {
  final _frags = <String>{};
  late final _free =
      TextEditingController(text: widget.initialPrompt ?? '');
  List<AiCharacter> _chars = [];
  AiCharacter? _picked;
  bool _loadingChars = true;
  bool _busy = false;

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

  Future<void> _generate() async {
    if (!_canGen || _busy) return;
    setState(() => _busy = true);
    try {
      final refs = <String>[];
      if (_picked != null) {
        try {
          refs.add(await Cloud.characterLocalImage(_picked!));
        } catch (_) {/* 레퍼런스 실패 시 일관성만 포기 */}
      }
      final prompt = _composePrompt(_frags, _free.text);
      final res = await Cloud.generateAiImage(prompt, refImagePaths: refs);
      if (!mounted) return;
      Navigator.of(context).pop(res);
    } on AiQuotaException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context,
          '이번 달 AI 생성 ${e.limit}회를 모두 썼어요. 구독하면 더 만들 수 있어요.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, 'AI 생성에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> _newCharacter() async {
    final c = await showCharacterCreateSheet(context);
    if (c != null && mounted) {
      setState(() {
        _chars = [c, ..._chars];
        _picked = c;
      });
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
                  borderRadius: BorderRadius.circular(99)),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Text('✨ AI로 장면 만들기',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),

                  // 1) 어떤 장면? — 주 입력(맨 위)
                  Text('어떤 장면을 그릴까요?',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 15, fontWeight: FontWeight.w900)),
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
                  Text('아래에서 촬영·연출 키워드를 더하면 더 정확해져요 (선택).',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 12, color: AppColors.faint)),

                  // 2) 캐릭터/사물 선택 (일관성)
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 2),
                    child: Text('캐릭터 · 사물 (일관성 유지)',
                        style: GoogleFonts.notoSansKr(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.muted)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('같은 인물·사물을 여러 컷에 똑같이 그리고 싶을 때만 골라요.',
                        style: GoogleFonts.notoSansKr(
                            fontSize: 11.5, color: AppColors.faint)),
                  ),
                  _CharacterStrip(
                    chars: _chars,
                    loading: _loadingChars,
                    picked: _picked,
                    onPick: (c) => setState(() => _picked = c),
                    onNew: _newCharacter,
                  ),

                  // 3) 촬영·연출 키워드 (아코디언, 보조)
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 4),
                    child: Row(
                      children: [
                        Text('촬영 · 연출 키워드',
                            style: GoogleFonts.notoSansKr(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.muted)),
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
                    label: _busy ? '그리는 중…' : '이 장면 그리기',
                    enabled: _canGen,
                    busy: _busy,
                    onTap: _generate,
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

/// 캐릭터 가로 스트립: [없음] + 캐릭터 아바타들 + [새로 만들기]
class _CharacterStrip extends StatelessWidget {
  final List<AiCharacter> chars;
  final bool loading;
  final AiCharacter? picked;
  final ValueChanged<AiCharacter?> onPick;
  final VoidCallback onNew;
  const _CharacterStrip({
    required this.chars,
    required this.loading,
    required this.picked,
    required this.onPick,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _miniTile(
            label: '안 정함',
            selected: picked == null,
            onTap: () => onPick(null),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.faint, size: 24),
          ),
          for (final c in chars)
            _miniTile(
              label: c.name,
              selected: picked?.id == c.id,
              onTap: () => onPick(c),
              child: ClipOval(
                child: Image.network(c.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => const Icon(Icons.person_rounded,
                        color: AppColors.faint)),
              ),
            ),
          _miniTile(
            label: '새로 만들기',
            selected: false,
            onTap: onNew,
            child:
                const Icon(Icons.add_rounded, color: AppColors.coral, size: 26),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
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
      final prompt = _composePrompt(_frags,
          '${_free.text}, full body character reference, plain background');
      final res = await Cloud.generateAiImage(prompt);
      if (!mounted) return;
      setState(() {
        _previewPath = res.path;
        _busy = false;
      });
    } on AiQuotaException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context,
          '이번 달 AI 생성 ${e.limit}회를 모두 썼어요. 구독하면 더 만들 수 있어요.');
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
          name: _name.text.trim(), localImagePath: _previewPath!);
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
                  borderRadius: BorderRadius.circular(99)),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Text('🎭 캐릭터 · 사물 만들기',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('한 번 만들면 컷마다 같은 모습으로 그릴 수 있어요.',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 12.5, color: AppColors.muted)),

                  // 이름
                  const SizedBox(height: 18),
                  Text('이름',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.muted)),
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
                      child: Image.file(File(_previewPath!),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text('마음에 안 들면 키워드를 바꿔 다시 생성하세요',
                          style: GoogleFonts.notoSansKr(
                              fontSize: 11.5, color: AppColors.faint)),
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
                  Text('추가 설명 (선택)',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.muted)),
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

/// 스토리보드 추천 결과 (창작 화면에서 컷으로 변환)
typedef StoryboardResult = ({
  String title,
  String logline,
  List<({String scenePrompt, String speaker, String dialogue, String direction})> cuts,
});

/// 전체 상황 → AI 컷 추천 시트. "이 구성으로 만들기" 시 결과를 pop으로 반환.
Future<StoryboardResult?> showStoryboardSheet(BuildContext context) {
  return showModalBottomSheet<StoryboardResult>(
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

  @override
  void dispose() {
    _situation.dispose();
    super.dispose();
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
                  borderRadius: BorderRadius.circular(99)),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Text('🎬 AI 스토리보드',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('전체 상황을 적으면 AI가 컷(장면+대사)으로 나눠줘요.',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 12.5, color: AppColors.muted)),

                  // 상황 입력
                  const SizedBox(height: 16),
                  Text('어떤 이야기인가요?',
                      style: GoogleFonts.notoSansKr(
                          fontSize: 15, fontWeight: FontWeight.w900)),
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

                  // 추천 결과
                  if (r != null) ...[
                    const SizedBox(height: 22),
                    Text(r.title,
                        style: GoogleFonts.notoSansKr(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(r.logline,
                        style: GoogleFonts.notoSansKr(
                            fontSize: 12.5, color: AppColors.muted)),
                    const SizedBox(height: 14),
                    for (var i = 0; i < r.cuts.length; i++)
                      _StoryCutPreview(index: i + 1, cut: r.cuts[i]),
                    const SizedBox(height: 16),
                    _PrimaryButton(
                      label: '이 구성으로 만들기 (컷 ${r.cuts.length}개)',
                      onTap: () => Navigator.of(context).pop(r),
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

/// 추천된 컷 한 개 미리보기 카드
class _StoryCutPreview extends StatelessWidget {
  final int index;
  final ({String scenePrompt, String speaker, String dialogue, String direction}) cut;
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
                    borderRadius: BorderRadius.circular(8)),
                child: Text('컷 $index',
                    style: GoogleFonts.notoSansKr(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.paper)),
              ),
              const SizedBox(width: 8),
              Text(cut.speaker,
                  style: GoogleFonts.notoSansKr(
                      fontSize: 13, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Text('"${cut.dialogue}"',
              style: GoogleFonts.notoSansKr(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.image_outlined,
                  size: 14, color: AppColors.faint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(cut.scenePrompt,
                    style: GoogleFonts.notoSansKr(
                        fontSize: 11.5, color: AppColors.faint)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
