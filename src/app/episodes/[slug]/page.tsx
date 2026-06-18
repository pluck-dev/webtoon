import { notFound } from 'next/navigation';
import Link from 'next/link';

import { prisma } from '@/lib/prisma';
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
      }
    }
  });

  if (!episode) notFound();

  return (
    <main className="shell">
      <nav className="topbar">
        <Link href="/" className="brand">
          <span className="brand-mark">WV</span>
          <span>
            <strong>{episode.title}</strong>
            <small>{episode.logline}</small>
          </span>
        </Link>
        <div className="nav-actions">
          <Link className="button" href="/">목록</Link>
          <Link className="button" href="/admin">관리자</Link>
        </div>
      </nav>

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
    </main>
  );
}
