import type { Metadata } from 'next';
import { notFound } from 'next/navigation';

import { prisma } from '@/lib/prisma';
import SiteHeader from '@/components/SiteHeader';
import EpisodeStudio from '@/components/EpisodeStudio';

export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const episode = await prisma.episode.findUnique({
    where: { slug },
    select: { title: true, logline: true, thumbnailUrl: true }
  });

  if (!episode) return { title: '에피소드를 찾을 수 없어요' };

  const image = episode.thumbnailUrl ?? '/sample/interview-cut-01.png';
  return {
    title: episode.title,
    description: episode.logline,
    openGraph: {
      type: 'article',
      title: episode.title,
      description: episode.logline,
      images: [image]
    },
    twitter: {
      card: 'summary_large_image',
      title: episode.title,
      description: episode.logline,
      images: [image]
    }
  };
}

export default async function EpisodePage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const episode = await prisma.episode.findUnique({
    where: { slug },
    include: {
      characters: { orderBy: { name: 'asc' } },
      cuts: {
        orderBy: { order: 'asc' },
        include: {
          dialogues: {
            orderBy: { order: 'asc' },
            include: { character: true }
          }
        }
      },
      _count: {
        select: { performances: true }
      }
    }
  });

  if (!episode) notFound();

  return (
    <main className="market-shell">
      <SiteHeader />

      <div className="mx-auto w-full max-w-[1760px] px-4 py-4 sm:px-6 lg:px-10">
      <section
        className="mt-[18px] rounded-lg border border-line bg-card p-[14px]"
        id="studio"
      >
        <div className="mb-[14px] flex items-end justify-between gap-[18px] border-b border-line-soft pb-4 pt-[6px] px-0.5">
          <div>
            <p className="mb-[7px] text-[12px] font-black uppercase text-muted">녹음 스튜디오</p>
            <h1 className="m-0 text-[clamp(30px,4vw,56px)] leading-none">{episode.title}</h1>
            <span className="mt-[10px] block text-[#5d564c] leading-[1.55]">{episode.logline}</span>
          </div>
          <div className="flex flex-wrap gap-2">
            <span className="rounded-full border border-line bg-[#f7f2e8] px-[11px] py-2 text-[12px] font-black text-[#5d564c]">{episode.cuts.length}컷</span>
            <span className="rounded-full border border-line bg-[#f7f2e8] px-[11px] py-2 text-[12px] font-black text-[#5d564c]">{episode.maxSeconds}초 이하</span>
            <span className="rounded-full border border-line bg-[#f7f2e8] px-[11px] py-2 text-[12px] font-black text-[#5d564c]">{episode._count.performances}개 버전</span>
          </div>
        </div>
        <EpisodeStudio
          episode={{
            id: episode.id,
            title: episode.title,
            maxSeconds: episode.maxSeconds,
            characters: episode.characters.map((character) => ({
              id: character.id,
              name: character.name,
              description: character.description,
              voiceGuide: character.voiceGuide,
              color: character.color
            })),
            cuts: episode.cuts.map((cut) => ({
              id: cut.id,
              order: cut.order,
              imageUrl: cut.imageUrl,
              caption: cut.caption,
              dialogues: cut.dialogues.map((dialogue) => ({
                id: dialogue.id,
                text: dialogue.text,
                direction: dialogue.direction,
                characterName: dialogue.character?.name ?? 'Narration'
              }))
            }))
          }}
        />
      </section>
      </div>
    </main>
  );
}
