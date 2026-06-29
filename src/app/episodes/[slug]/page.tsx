import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import { prisma } from '@/lib/prisma';
import AuthNav from '@/components/AuthNav';
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
      {/* 녹음 집중용 미니멀 스튜디오 바 */}
      <header className="sticky top-0 z-20 border-b border-line bg-cream/85 backdrop-blur-md">
        <div className="mx-auto flex min-h-[56px] w-full max-w-[1760px] items-center justify-between gap-3 px-4 sm:px-6 lg:px-10">
          <Link
            href="/episodes"
            className="inline-flex shrink-0 items-center gap-1.5 text-sm font-extrabold text-ink-soft transition-colors hover:text-ink"
          >
            <span aria-hidden="true">←</span>
            <span className="hidden sm:inline">에피소드 목록</span>
            <span className="sm:hidden">목록</span>
          </Link>
          <strong className="min-w-0 flex-1 truncate text-center text-sm font-black text-ink sm:text-base">
            {episode.title}
          </strong>
          <AuthNav />
        </div>
      </header>

      <div className="mx-auto w-full max-w-[1760px] px-4 py-4 sm:px-6 lg:px-10">
      <section
        className="mt-3 rounded-2xl p-0 sm:mt-[18px] sm:border sm:border-line sm:bg-card sm:p-[14px]"
        id="studio"
      >
        <div className="mb-[14px] hidden items-end justify-between gap-[18px] border-b border-line-soft pb-4 pt-[6px] px-0.5 lg:flex">
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
