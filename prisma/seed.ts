import { PrismaClient, EpisodeStatus, UserRole } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const admin = await prisma.user.upsert({
    where: { handle: 'admin' },
    update: {},
    create: { handle: 'admin', displayName: '관리자', role: UserRole.ADMIN }
  });

  const actor = await prisma.user.upsert({
    where: { handle: 'sample-actor' },
    update: {},
    create: { handle: 'sample-actor', displayName: '샘플 배우', role: UserRole.ACTOR }
  });

  const episode = await prisma.episode.upsert({
    where: { slug: 'ex-interviewer' },
    update: {
      status: EpisodeStatus.PUBLISHED,
      thumbnailUrl: '/sample/interview-cut-01.png'
    },
    create: {
      slug: 'ex-interviewer',
      title: '전남친이 면접관이었다',
      logline: '면접장에서 3년 전 사라진 전남친을 면접관으로 마주친다.',
      status: EpisodeStatus.PUBLISHED,
      maxSeconds: 58,
      thumbnailUrl: '/sample/interview-cut-01.png'
    }
  });

  await prisma.performance.upsert({
    where: { id: 'sample-performance' },
    update: {},
    create: {
      id: 'sample-performance',
      episodeId: episode.id,
      userId: actor.id,
      title: '샘플 배우 버전'
    }
  });

  await prisma.character.deleteMany({ where: { episodeId: episode.id } });
  await prisma.cut.deleteMany({ where: { episodeId: episode.id } });

  const seoyoon = await prisma.character.create({
    data: {
      episodeId: episode.id,
      name: '서윤',
      description: '27세, 블랙 단발, 코랄 니트 재킷, 상처를 숨기는 침착한 눈빛',
      voiceGuide: '감정을 누르다가 마지막 단어에서 날카롭게 찌른다.',
      color: '#ef6f5e'
    }
  });

  const doha = await prisma.character.create({
    data: {
      episodeId: episode.id,
      name: '도하',
      description: '29세, 짙은 갈색 머리, 네이비 셔츠, 죄책감을 숨기는 낮은 목소리',
      voiceGuide: '낮고 차분하지만 대사 끝에 흔들림을 남긴다.',
      color: '#31435f'
    }
  });

  const cuts = [
    {
      imageUrl: '/sample/interview-cut-01.png',
      caption: '면접실 문이 열리는 순간, 서윤은 숨을 멈췄다.',
      characterId: seoyoon.id,
      text: '면접관이... 당신이라고요?',
      direction: '숨을 한 번 삼키고 작게 시작'
    },
    {
      imageUrl: '/sample/interview-cut-02.png',
      caption: '도하는 이력서를 내려놓고 사적인 질문처럼 말했다.',
      characterId: doha.id,
      text: '아직도 사람 쉽게 믿습니까?',
      direction: '낮게, 감정을 누르면서'
    },
    {
      imageUrl: '/sample/interview-cut-03.png',
      caption: '서윤은 웃었다. 이번엔 도망치는 쪽이 자신이 아니었다.',
      characterId: seoyoon.id,
      text: '아니요. 3년 전에 좋은 선생님을 만났거든요.',
      direction: '웃으며 찌르듯이'
    }
  ];

  for (const [index, cut] of cuts.entries()) {
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
        characterId: cut.characterId,
        order: 1,
        text: cut.text,
        direction: cut.direction
      }
    });
  }

  await prisma.user.update({
    where: { id: admin.id },
    data: { displayName: '관리자' }
  });
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
