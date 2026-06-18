import { PrismaClient, EpisodeStatus, UserRole } from '@prisma/client';

const prisma = new PrismaClient();

type CharacterSeed = {
  key: string;
  name: string;
  description: string;
  voiceGuide: string;
  color: string;
};

type CutSeed = {
  imageUrl: string;
  caption: string;
  characterKey: string;
  text: string;
  direction: string;
};

type EpisodeSeed = {
  slug: string;
  title: string;
  logline: string;
  maxSeconds: number;
  thumbnailUrl: string;
  characters: CharacterSeed[];
  cuts: CutSeed[];
};

const episodes: EpisodeSeed[] = [
  {
    slug: 'ex-interviewer',
    title: '전남친이 면접관이었다',
    logline: '면접장에서 3년 전 사라진 전남친을 면접관으로 마주친다.',
    maxSeconds: 58,
    thumbnailUrl: '/sample/interview-cut-01.png',
    characters: [
      {
        key: 'seoyoon',
        name: '서윤',
        description: '27세. 코랄 니트 재킷을 입은 지원자. 상처를 숨기지만 말끝이 날카롭다.',
        voiceGuide: '웃는 척하지만 감정이 눌려 있다. 마지막 단어에서 힘을 빼지 않는다.',
        color: '#ef6f5e'
      },
      {
        key: 'doha',
        name: '도하',
        description: '29세. 네이비 셔츠의 차분한 면접관. 미안함을 숨기고 있다.',
        voiceGuide: '낮고 차분하게 말한다. 질문처럼 들리지만 속으로는 흔들린다.',
        color: '#31435f'
      }
    ],
    cuts: [
      {
        imageUrl: '/sample/interview-cut-01.png',
        caption: '면접실 문이 열리는 순간, 서윤은 숨을 멈췄다.',
        characterKey: 'seoyoon',
        text: '면접관이... 당신이라고요?',
        direction: '숨을 한 번 삼키고 작게 시작'
      },
      {
        imageUrl: '/sample/interview-cut-02.png',
        caption: '도하는 이력서를 내려놓고 사적인 질문처럼 말했다.',
        characterKey: 'doha',
        text: '아직도 사람 쉽게 믿습니까?',
        direction: '낮게, 감정을 누르면서'
      },
      {
        imageUrl: '/sample/interview-cut-03.png',
        caption: '서윤은 웃었다. 이번엔 도망치는 쪽이 자신이 아니었다.',
        characterKey: 'seoyoon',
        text: '아니요. 3년 전에 좋은 선생님을 만났거든요.',
        direction: '웃으며 찌르듯이'
      }
    ]
  },
  {
    slug: 'borrowed-tomorrow',
    title: '내일을 빌린 아이',
    logline: '내일 날짜가 찍힌 깨진 휴대폰을 주운 여고생이 하루를 바꾸려 한다.',
    maxSeconds: 55,
    thumbnailUrl: '/generated/borrowed-tomorrow-01.png',
    characters: [
      {
        key: 'yena',
        name: '예나',
        description: '18세. 네이비 교복과 묶은 머리. 무서워도 먼저 뛰어드는 학생.',
        voiceGuide: '빠르고 숨이 찬 톤. 중요한 말은 낮춰서 진심을 만든다.',
        color: '#5cc8ba'
      },
      {
        key: 'jun',
        name: '준',
        description: '18세. 은테 안경을 쓴 같은 반 친구. 농담으로 불안을 숨긴다.',
        voiceGuide: '가볍게 시작하지만 중간부터 진지해진다.',
        color: '#f0bd62'
      }
    ],
    cuts: [
      {
        imageUrl: '/generated/borrowed-tomorrow-01.png',
        caption: '새벽 지하철 플랫폼. 예나는 내일 날짜가 뜬 휴대폰을 들고 있었다.',
        characterKey: 'yena',
        text: '이거... 오늘이 아니라 내일이잖아.',
        direction: '믿기지 않아 작게 중얼거림'
      },
      {
        imageUrl: '/generated/borrowed-tomorrow-02.png',
        caption: '예나는 복도를 가로질러 준이 문을 열기 전에 붙잡으려 했다.',
        characterKey: 'yena',
        text: '준아, 그 문 열지 마. 오늘은 네가 다쳐.',
        direction: '숨차게, 거의 울 듯이'
      },
      {
        imageUrl: '/generated/borrowed-tomorrow-03.png',
        caption: '음악실 피아노 위에는 누군가 남긴 경고 메모들이 놓여 있었다.',
        characterKey: 'jun',
        text: '너만 본 게 아니었네. 누가 우리보다 먼저 반복한 거야.',
        direction: '농담기를 빼고 낮게'
      },
      {
        imageUrl: '/generated/borrowed-tomorrow-04.png',
        caption: '해질녘 보도교. 예나는 휴대폰을 놓아버리려 했다.',
        characterKey: 'yena',
        text: '내일을 고치려다 오늘의 너를 잃는 건 싫어.',
        direction: '떨리지만 또렷하게'
      }
    ]
  },
  {
    slug: 'moonlit-audit',
    title: '달빛 감사관',
    logline: '한밤중 기록보관소에서 시작된 감사는 도시 전체의 비밀로 이어진다.',
    maxSeconds: 60,
    thumbnailUrl: '/generated/moonlit-audit-01.png',
    characters: [
      {
        key: 'arin',
        name: '아린',
        description: '29세. 베이지 트렌치코트를 입은 시청 감사관. 원칙적이지만 위험을 감수한다.',
        voiceGuide: '정확하고 차갑게. 감정은 짧은 침묵 뒤에 드러난다.',
        color: '#c8a36a'
      },
      {
        key: 'taeoh',
        name: '태오',
        description: '32세. 야간 경비원. 평범해 보이지만 기록보관소의 진실을 알고 있다.',
        voiceGuide: '조용하고 느리게. 아는 것이 많지만 바로 말하지 않는다.',
        color: '#5c7d72'
      }
    ],
    cuts: [
      {
        imageUrl: '/generated/moonlit-audit-01.png',
        caption: '비 내리는 자정, 아린은 봉인된 파란 봉투를 들고 기록실로 들어갔다.',
        characterKey: 'arin',
        text: '오늘 밤 이 문서가 사라지면, 내 이름도 같이 지워지겠죠.',
        direction: '차분하지만 압박감 있게'
      },
      {
        imageUrl: '/generated/moonlit-audit-02.png',
        caption: '출구를 막아선 태오는 열쇠를 흔들며 아린을 바라봤다.',
        characterKey: 'taeoh',
        text: '나가려면 봉투는 두고 가요. 그게 당신을 살리는 길입니다.',
        direction: '협박처럼 들리지만 걱정이 섞이게'
      },
      {
        imageUrl: '/generated/moonlit-audit-03.png',
        caption: '낡은 복사기 안쪽에서 메모리카드와 찢어진 지도가 발견됐다.',
        characterKey: 'arin',
        text: '이건 회계 장부가 아니야. 도시를 팔아넘긴 지도잖아.',
        direction: '숨을 낮추고 분노를 눌러서'
      },
      {
        imageUrl: '/generated/moonlit-audit-04.png',
        caption: '새벽 옥상, 두 사람은 불빛이 남은 구역을 내려다봤다.',
        characterKey: 'taeoh',
        text: '저 불이 꺼지기 전에 공개해야 합니다. 아니면 전부 묻혀요.',
        direction: '결심한 사람처럼 단단하게'
      }
    ]
  },
  {
    slug: 'last-delivery',
    title: '마지막 배송',
    logline: '비 오는 밤, 배달 라이더가 받은 검은 상자는 누군가의 삶을 바꿀 증거였다.',
    maxSeconds: 57,
    thumbnailUrl: '/generated/last-delivery-01.png',
    characters: [
      {
        key: 'mira',
        name: '미라',
        description: '31세. 빨간 우비를 입은 배달 라이더. 거칠지만 약한 사람을 지나치지 못한다.',
        voiceGuide: '짧고 툭 던지듯 말한다. 중요한 순간엔 목소리가 낮아진다.',
        color: '#ef6f5e'
      },
      {
        key: 'hyun',
        name: '현우',
        description: '34세. 지친 회사원. 검은 상자의 정체를 알고 두려워한다.',
        voiceGuide: '처음엔 소심하게, 점점 절박하게 올라간다.',
        color: '#31435f'
      }
    ],
    cuts: [
      {
        imageUrl: '/generated/last-delivery-01.png',
        caption: '네온이 번지는 골목, 미라는 은색 봉인이 붙은 검은 상자를 받았다.',
        characterKey: 'mira',
        text: '주소도 없고, 받는 사람도 없고... 돈은 두 배라.',
        direction: '비웃듯이 낮게'
      },
      {
        imageUrl: '/generated/last-delivery-02.png',
        caption: '편의점에서 상자를 본 현우는 한 걸음 뒤로 물러났다.',
        characterKey: 'hyun',
        text: '그거 열면 안 됩니다. 그 안에 제 인생이 들어 있어요.',
        direction: '겁먹었지만 급하게'
      },
      {
        imageUrl: '/generated/last-delivery-03.png',
        caption: '버스정류장 아래, 상자 속 작은 프로젝터가 가족사진을 비췄다.',
        characterKey: 'mira',
        text: '협박장인 줄 알았는데... 이건 구조 요청이네.',
        direction: '놀람을 누르고 조용히'
      },
      {
        imageUrl: '/generated/last-delivery-04.png',
        caption: '한강변 새벽, 검은 차가 다가오자 미라는 상자를 등 뒤로 숨겼다.',
        characterKey: 'mira',
        text: '배송 완료는 내가 정해. 오늘은 당신들한테 안 가.',
        direction: '단호하고 짧게'
      }
    ]
  }
];

async function seedEpisode(seed: EpisodeSeed) {
  const episode = await prisma.episode.upsert({
    where: { slug: seed.slug },
    update: {
      title: seed.title,
      logline: seed.logline,
      status: EpisodeStatus.PUBLISHED,
      maxSeconds: seed.maxSeconds,
      thumbnailUrl: seed.thumbnailUrl
    },
    create: {
      slug: seed.slug,
      title: seed.title,
      logline: seed.logline,
      status: EpisodeStatus.PUBLISHED,
      maxSeconds: seed.maxSeconds,
      thumbnailUrl: seed.thumbnailUrl
    }
  });

  await prisma.character.deleteMany({ where: { episodeId: episode.id } });
  await prisma.cut.deleteMany({ where: { episodeId: episode.id } });

  const characterIds = new Map<string, string>();
  for (const character of seed.characters) {
    const created = await prisma.character.create({
      data: {
        episodeId: episode.id,
        name: character.name,
        description: character.description,
        voiceGuide: character.voiceGuide,
        color: character.color
      }
    });
    characterIds.set(character.key, created.id);
  }

  for (const [index, cut] of seed.cuts.entries()) {
    const createdCut = await prisma.cut.create({
      data: {
        episodeId: episode.id,
        order: index + 1,
        imageUrl: cut.imageUrl,
        caption: cut.caption
      }
    });

    await prisma.dialogue.create({
      data: {
        cutId: createdCut.id,
        characterId: characterIds.get(cut.characterKey),
        order: 1,
        text: cut.text,
        direction: cut.direction
      }
    });
  }
}

async function main() {
  await prisma.user.upsert({
    where: { handle: 'admin' },
    update: { displayName: '관리자', role: UserRole.ADMIN },
    create: { handle: 'admin', displayName: '관리자', role: UserRole.ADMIN }
  });

  await prisma.user.upsert({
    where: { handle: 'sample-actor' },
    update: { displayName: '샘플 배우', role: UserRole.ACTOR },
    create: { handle: 'sample-actor', displayName: '샘플 배우', role: UserRole.ACTOR }
  });

  for (const episode of episodes) {
    await seedEpisode(episode);
  }
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
