import { notFound } from 'next/navigation';
import Link from 'next/link';

import { prisma } from '@/lib/prisma';
import AuthNav from '@/components/AuthNav';
import EpisodeStudio from '@/components/EpisodeStudio';

export const dynamic = 'force-dynamic';

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
    <main className="market-shell episode-detail-shell">
      <header className="market-nav">
        <Link href="/" className="market-brand">Webtoon Voice Studio</Link>
        <nav className="market-links" aria-label="Episode navigation">
          <Link href="/">Episodes</Link>
          <Link href="/admin">Admin</Link>
          <a href="#studio">Studio</a>
          <a href="#cast">Cast</a>
        </nav>
        <AuthNav />
      </header>

      <section className="episode-studio-card" id="studio">
        <div className="episode-room-heading">
          <div>
            <p>Recording room</p>
            <h1>{episode.title}</h1>
            <span>{episode.logline}</span>
          </div>
          <div className="episode-meta-row">
            <span>{episode.cuts.length} cuts</span>
            <span>{episode.maxSeconds}s max</span>
            <span>{episode._count.performances} versions</span>
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
    </main>
  );
}
