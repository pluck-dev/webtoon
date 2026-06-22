/**
 * 새 밈 에피소드를 meme-episodes.json에 추가(기존 유지). 중복 slug는 교체.
 * 실행: npx tsx scripts/append-new-episodes.ts
 */
import fs from 'node:fs';

const FILE = './prisma/data/meme-episodes.json';

const WT =
  'Korean webtoon/manhwa art, clean lineart, cel shading, soft gradient background, expressive exaggerated comedic faces, vertical 9:16, no text, no speech bubbles, no watermark.';

const newEpisodes = [
  {
    slug: 'carrot-nego-villain',
    title: '당근 네고 빌런',
    category: 'ROLEPLAY',
    genre: '공감·일상 개그',
    logline:
      '거의 새 거 에어프라이어를 3만원에 내놨더니 나타난 네고의 신. 한 번 깎고, 두 번 깎고, 택배비 빼고, 기름값까지 계산하는 그 앞에서 내 멘탈과 자존심이 동시에 매물로 나왔다.',
    maxSeconds: 55,
    characters: [
      {
        name: '민수',
        description:
          '중고거래로 마음의 평화를 찾으려던 30대 직장인. 거래 고수인 척하지만 사실은 거절을 못 하는 호구. 인내심이 한 칸씩 무너진다.',
        voiceGuide:
          '처음엔 여유롭고 쿨하게. 깎일수록 목소리가 갈라지고 빨라진다. 마지막엔 모든 걸 내려놓은 해탈한 무기력 톤.',
        color: '#3A7BD5',
      },
      {
        name: '행복한하마',
        description:
          '닉네임 "행복한하마". 미안함 0%, 죄책감 0%로 끝없이 깎는 네고의 신. 본인은 그저 합리적인 소비자라고 굳게 믿는다.',
        voiceGuide:
          '시종일관 밝고 사근사근. 무리한 요구도 천진난만하게 툭툭. 절대 미안해하지 않는 당당함이 포인트.',
        color: '#FF8C42',
      },
    ],
    cuts: [
      {
        order: 1,
        caption: '드디어 안 쓰는 에어프라이어가 팔린다',
        imgPrompt: `${WT} A tired Korean man in his early 30s, gray hoodie, glasses, messy hair, proudly holding up a white air fryer for a photo in a cramped apartment, relieved confident smile, evening light.`,
        dialogues: [
          { speaker: '민수', text: '3만원, 거의 새 거. 이건 칼같이 나가지.', direction: '뿌듯하게, 거래 고수인 척 여유롭게' },
        ],
      },
      {
        order: 2,
        caption: '채팅이 왔다',
        imgPrompt: `${WT} The same Korean man glancing at his smartphone as a chat notification pops up, one eyebrow slightly raised, faint dread on his face, dark room lit by phone glow.`,
        dialogues: [
          { speaker: '행복한하마', text: '안녕하세요~ 혹시 네고 가능할까요?', direction: '밝고 사근사근하게, 본론은 숨긴 채' },
        ],
      },
      {
        order: 3,
        caption: '예상했다는 듯 한 발 양보',
        imgPrompt: `${WT} The Korean man typing on his phone with a slightly resigned but still composed expression, sitting on a sofa, soft warm lighting.`,
        dialogues: [
          { speaker: '민수', text: '음… 2만 8천까지는 해드릴게요.', direction: '쿨한 척 양보하지만 속으론 살짝 긴장' },
        ],
      },
      {
        order: 4,
        caption: '한 술 더 뜨는 네고',
        imgPrompt: `${WT} A cheerful Korean person in a yellow hoodie, round innocent face, giving a bright carefree smile while texting on a phone, sparkles around, totally guilt-free expression.`,
        dialogues: [
          { speaker: '행복한하마', text: '혹시 만 오천원은 안 될까요? ㅎㅎ', direction: '웃음으로 무장, 미안함 0%로' },
        ],
      },
      {
        order: 5,
        caption: '민수의 영혼이 빠져나간다',
        imgPrompt: `${WT} Extreme comedic shock — the Korean man's soul leaving his body as a pale ghost, jaw dropped, eyes blank white, holding phone limply, despair lines around him.`,
        dialogues: [
          { speaker: '민수', text: '만 오천…? 이거 새 거 6만원인데…', direction: '혼잣말, 영혼이 빠져나가는 무기력한 톤' },
        ],
      },
      {
        order: 6,
        caption: '선심 쓰듯 던지는 한마디',
        imgPrompt: `${WT} The cheerful person in yellow hoodie giving a confident thumbs up, beaming, as if doing a huge favor, bright background.`,
        dialogues: [
          { speaker: '행복한하마', text: '지금 바로 입금 가능해요! 제가 거래는 또 빨라요.', direction: '그게 큰 호의인 양 당당하게' },
        ],
      },
      {
        order: 7,
        caption: '마지노선을 긋는다',
        imgPrompt: `${WT} The Korean man gritting his teeth, gripping his phone tightly with both hands, one final-stand determined but cracking expression, sweat drop.`,
        dialogues: [
          { speaker: '민수', text: '…2만원. 진짜 더는 안 됩니다.', direction: '이 악물고, 마지막 자존심을 쥐어짜며' },
        ],
      },
      {
        order: 8,
        caption: '그 와중에 추가 요구',
        imgPrompt: `${WT} The cheerful person tilting head innocently while texting, finger raised as if asking a totally reasonable question, oblivious sparkle eyes.`,
        dialogues: [
          { speaker: '행복한하마', text: '오 좋아요! 그럼 택배비는 빼주시는 거죠?', direction: '당연하다는 듯 천연덕스럽게' },
        ],
      },
      {
        order: 9,
        caption: '인내심이 바닥났다',
        imgPrompt: `${WT} The Korean man exploding in comedic anger, popping vein mark on forehead, shouting at his phone, motion lines, red angry background.`,
        dialogues: [
          { speaker: '민수', text: '직거래 하자면서요…!', direction: '목소리 갈라지며, 인내심 완전 바닥' },
        ],
      },
      {
        order: 10,
        caption: '진지하게 기름값을 계산하는 네고왕',
        imgPrompt: `${WT} The cheerful person seriously tapping a calculator with a thoughtful business-like face, tiny gas-pump and coin icons floating around, innocent yet calculating.`,
        dialogues: [
          { speaker: '행복한하마', text: '아 근데 제가 가지러 가는데 기름값이 좀…', direction: '진지하게 손익을 계산하듯' },
        ],
      },
      {
        order: 11,
        caption: '민수, 모든 것을 내려놓다',
        imgPrompt: `${WT} The Korean man with a completely enlightened blank peaceful face, holding out the air fryer with both hands like an offering, soft heavenly light, totally defeated calm.`,
        dialogues: [
          { speaker: '민수', text: '그냥… 제가 돈 드릴 테니까 가져가세요.', direction: '모든 걸 내려놓은 해탈한 톤으로' },
        ],
      },
      {
        order: 12,
        caption: '마지막 한 방',
        imgPrompt: `${WT} The cheerful person celebrating with both arms up, super happy, while the tired Korean man stands dead-eyed in the background, comedic contrast.`,
        dialogues: [
          { speaker: '행복한하마', text: '헐 감사해요! 근데 혹시 충전기도 같이 주실 수 있나요?', direction: '신나서, 천진난만하게 (에어프라이어에 충전기는 없다)' },
        ],
      },
    ],
  },
  {
    slug: 'no-spend-day3',
    title: '무지출 챌린지 3일차',
    category: 'ROLEPLAY',
    genre: '공감·일상 개그',
    logline:
      '3일째 한 푼도 안 쓴 내가 좀 멋있는 줄 알았다. 퇴근길 편의점 불빛 앞에서 머릿속 악마가 속삭이기 시작했고, 그 달콤한 합리화 앞에 내 통장과 의지는 사이좋게 무너졌다.',
    maxSeconds: 55,
    characters: [
      {
        name: '지영',
        description:
          '통장 잔고를 지키려는 결연한 의지의 직장인. 의지는 강하지만 야근과 피로 앞에선 한없이 약해진다. 합리화의 늪에 매번 빠진다.',
        voiceGuide:
          '처음엔 자신만만하고 단단하게. 흔들릴수록 목소리가 작아지고 느려진다. 마지막 펀치라인은 장례식 추도사처럼 엄숙하게.',
        color: '#5CC8BA',
      },
      {
        name: '본능',
        description:
          '지영의 머릿속에 사는 작은 악마. 욕망을 달콤하게 의인화한 존재. 책임은 늘 "내일의 너"에게 떠넘긴다.',
        voiceGuide:
          '달콤하고 집요하게 속삭이듯. 여유롭고 자신만만하게. 약 올리는 듯한 친근함이 포인트.',
        color: '#E84A5F',
      },
    ],
    cuts: [
      {
        order: 1,
        caption: '무지출 챌린지 3일차, 퇴근길',
        imgPrompt: `${WT} A Korean woman in her late 20s, beige coat, ponytail, walking down an evening street with a proud little fist-pump, confident self-satisfied smile, city lights.`,
        dialogues: [
          { speaker: '지영', text: '3일째 한 푼도 안 썼어. 나 좀 멋있는 듯.', direction: '뿌듯하게, 자기애 충만하게' },
        ],
      },
      {
        order: 2,
        caption: '편의점 불빛이 시야에 들어온다',
        imgPrompt: `${WT} A tiny cute chibi red devil version of the same woman (small horns, tail) perched on her shoulder, whispering and pointing toward a glowing convenience store ahead, tempting grin.`,
        dialogues: [
          { speaker: '본능', text: '야. 저기 신상 디저트 들어왔대.', direction: '달콤하게 속삭이듯, 유혹적으로' },
        ],
      },
      {
        order: 3,
        caption: '못 들은 척 발걸음을 재촉한다',
        imgPrompt: `${WT} The Korean woman covering her ears with both hands, eyes shut, walking fast past the bright convenience store, exaggerated "not listening" face.`,
        dialogues: [
          { speaker: '지영', text: '안 들려. 나는 무지출 인간이야.', direction: '애써 외면하며 빠르게 지나가려는' },
        ],
      },
      {
        order: 4,
        caption: '악마의 합리화가 시작된다',
        imgPrompt: `${WT} The tiny red devil gesturing persuasively like a lawyer, presenting an invisible argument, tiny halo flipping to horns, smooth convincing expression.`,
        dialogues: [
          { speaker: '본능', text: '딱 하나만. 이건 소비가 아니라 보상이야.', direction: '그럴듯하게, 논리적인 척 차분하게' },
        ],
      },
      {
        order: 5,
        caption: '벌써 반쯤 넘어간다',
        imgPrompt: `${WT} The Korean woman pausing with a wavering thoughtful face, a thought bubble showing herself tiredly working overtime at a desk, weakening resolve.`,
        dialogues: [
          { speaker: '지영', text: '보상…? 하긴 나 오늘 야근도 했지…', direction: '혼잣말, 이미 반쯤 넘어가는 흔들리는 톤' },
        ],
      },
      {
        order: 6,
        caption: '책임은 내일의 너에게',
        imgPrompt: `${WT} The tiny red devil confidently pointing forward, behind it an imagined heroic muscular "future self" silhouette glowing, shifting all blame to tomorrow.`,
        dialogues: [
          { speaker: '본능', text: '내일부터 다시 하면 되잖아. 내일의 너는 강해.', direction: '자신만만하게, 책임을 떠넘기며' },
        ],
      },
      {
        order: 7,
        caption: '마지막 저항',
        imgPrompt: `${WT} The Korean woman weakly raising one hand to stop herself, voice fading, a faint bank-balance number dissolving in a thought bubble, melting willpower.`,
        dialogues: [
          { speaker: '지영', text: '안 돼. 통장 잔고가… 통장 잔고가…', direction: '점점 작아지는 목소리, 의지가 소멸하며' },
        ],
      },
      {
        order: 8,
        caption: '발이 편의점 앞에 멈춰 섰다',
        imgPrompt: `${WT} Close shot of the Korean woman's feet stopped right at the glowing convenience store entrance, the tiny red devil on her shoulder looking smug and victorious.`,
        dialogues: [
          { speaker: '본능', text: '이미 들어왔잖아. 늦었어.', direction: '승리를 직감한 듯 여유롭게' },
        ],
      },
      {
        order: 9,
        caption: '계산대 앞, 현실',
        imgPrompt: `${WT} The Korean woman standing soulless at a convenience store counter, holding an armful of snacks and desserts, dead expression, bright fluorescent store light.`,
        dialogues: [
          { speaker: '지영', text: '…이거 하나랑, 저것도 하나 주세요.', direction: '영혼 없이, 자포자기한 톤으로' },
        ],
      },
      {
        order: 10,
        caption: '영수증을 바라보며',
        imgPrompt: `${WT} The Korean woman solemnly staring at a long receipt held in both hands like reading a eulogy, somber lighting, a single tear glint.`,
        dialogues: [
          { speaker: '지영', text: '무지출 챌린지… 3일차 사망.', direction: '장례식 추도사처럼 엄숙하게' },
        ],
      },
      {
        order: 11,
        caption: '흡족한 악마',
        imgPrompt: `${WT} The tiny red devil patting the woman's cheek comfortingly while smirking, teasing, satisfied expression, soft glow.`,
        dialogues: [
          { speaker: '본능', text: '수고했어. 챌린지는 원래 4일차가 제일 어려운 거야.', direction: '위로하는 척 약 올리며' },
        ],
      },
      {
        order: 12,
        caption: '그리고 새로운 다짐',
        imgPrompt: `${WT} The Korean woman walking away from the store holding a snack, with a knowing peaceful smile and a tiny resolute sparkle in her eye, ironic determination.`,
        dialogues: [
          { speaker: '지영', text: '그래… 무지출은 내일부터.', direction: '깨달은 듯, 그러나 또 같은 실수를 예고하듯' },
        ],
      },
    ],
  },
];

const list = JSON.parse(fs.readFileSync(FILE, 'utf8'));
const bySlug = new Map(list.map((e: any) => [e.slug, e]));
for (const ep of newEpisodes) bySlug.set(ep.slug, ep);
const merged = Array.from(bySlug.values());
fs.writeFileSync(FILE, JSON.stringify(merged, null, 2) + '\n');
console.log(`✅ 총 ${merged.length}편 (추가/갱신: ${newEpisodes.map((e) => e.slug).join(', ')})`);
