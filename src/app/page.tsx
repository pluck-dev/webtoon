/* eslint-disable @next/next/no-img-element */
import Link from 'next/link';

import AuthNav from '@/components/AuthNav';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

const categories = ['All', 'Romance', 'Office', 'Revenge', 'Horror', 'Comedy', 'Open Casting'];

export default async function Home() {
  const episodes = await prisma.episode.findMany({
    where: { status: 'PUBLISHED' },
    orderBy: { createdAt: 'desc' },
    include: {
      _count: {
        select: { cuts: true, performances: true }
      }
    }
  });

  return (
    <main className="market-shell">
      <header className="market-nav">
        <Link href="/" className="market-brand">
          <span>Webtoon Voice Studio</span>
        </Link>
        <nav className="market-links" aria-label="Main navigation">
          <Link href="/">Episodes</Link>
          <Link href="/admin">Admin</Link>
          <a href="#templates">Templates</a>
          <a href="#how">How it works</a>
        </nav>
        <AuthNav />
      </header>

      <section className="market-hero">
        <div>
          <p className="market-kicker">Voice-over marketplace for AI webtoons</p>
          <h1>One original webtoon, endless actor versions.</h1>
        </div>
        <p>
          Admins publish fixed webtoon episodes with cut images, dialogue, and role guides.
          Members sign in, record every speech bubble, and create their own shareable voice version.
        </p>
      </section>

      <section className="category-strip" aria-label="Episode categories">
        {categories.map((category) => (
          <button type="button" key={category}>{category}</button>
        ))}
      </section>

      <section className="market-feature">
        <div className="feature-copy">
          <span>Featured episode</span>
          <h2>Former lover, current interviewer</h2>
          <p>An interview room turns into a tense reunion when the interviewer is someone from three years ago.</p>
          <Link href="/episodes/ex-interviewer">Record your version</Link>
        </div>
        <div className="feature-gallery" aria-hidden="true">
          <img src="/sample/interview-cut-01.png" alt="" />
          <img src="/sample/interview-cut-02.png" alt="" />
          <img src="/sample/interview-cut-03.png" alt="" />
        </div>
      </section>

      <section className="section-heading">
        <div>
          <p>Episode collection</p>
          <h2>Pick a webtoon and perform it your way</h2>
        </div>
        <span>{episodes.length} published</span>
      </section>

      <section className="market-grid">
        {episodes.map((episode) => (
          <Link className="market-card" href={`/episodes/${episode.slug}`} key={episode.id}>
            <div className="market-card-image">
              <img src={episode.thumbnailUrl ?? '/sample/interview-cut-01.png'} alt="" />
              <span>{episode.maxSeconds}s shorts</span>
            </div>
            <div className="market-card-body">
              <div>
                <p>{episode._count.cuts} cuts</p>
                <h3>{episode.title}</h3>
              </div>
              <p>{episode.logline}</p>
              <div className="market-card-meta">
                <span>{episode._count.performances} versions</span>
                <span>Open</span>
              </div>
            </div>
          </Link>
        ))}
      </section>

      <section className="template-section" id="templates">
        <div className="section-heading">
          <div>
            <p>Creator templates</p>
            <h2>Built for repeatable short-form production</h2>
          </div>
        </div>
        <div className="template-grid">
          <div><strong>Admin originals</strong><span>Admins generate cuts, write dialogue, and publish source episodes.</span></div>
          <div><strong>Member versions</strong><span>Every member keeps the same webtoon but records a unique acting take.</span></div>
          <div><strong>Role casting</strong><span>Solo acting, duo scenes, or open role submissions.</span></div>
          <div><strong>Hyperlapse render</strong><span>Cut duration follows recorded voice length.</span></div>
        </div>
      </section>

      <section className="how-section" id="how">
        <p>How it works</p>
        <ol>
          <li>Admin creates the original webtoon episode.</li>
          <li>Members choose an episode and sign in.</li>
          <li>Actors record each speech bubble in the browser.</li>
          <li>The service saves and renders a personal shorts version.</li>
        </ol>
      </section>
    </main>
  );
}
