/* eslint-disable @next/next/no-img-element */
import Link from 'next/link';

import AuthNav from '@/components/AuthNav';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

const categories = ['All', 'Romance', 'Office', 'Revenge', 'Horror', 'Comedy', 'Open Casting'];

// 자동 스크롤 인스피레이션 보드에 쓰는 정적 컷 이미지 모음
const marqueeImages = [
  '/sample/interview-cut-01.png',
  '/generated/borrowed-tomorrow-01.png',
  '/generated/moonlit-audit-01.png',
  '/sample/interview-cut-02.png',
  '/generated/last-delivery-01.png',
  '/generated/borrowed-tomorrow-03.png',
  '/sample/interview-cut-03.png',
  '/generated/moonlit-audit-03.png',
  '/generated/last-delivery-02.png',
  '/generated/borrowed-tomorrow-02.png',
  '/generated/moonlit-audit-02.png',
  '/generated/last-delivery-04.png'
];

// 슬러그별 장르 태그 (카드 오버레이용)
const episodeTags: Record<string, string[]> = {
  'ex-interviewer': ['Romance', 'Office'],
  'borrowed-tomorrow': ['Mystery', 'Youth'],
  'moonlit-audit': ['Thriller', 'Noir'],
  'last-delivery': ['Thriller', 'Rain']
};

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

  const totalCuts = episodes.reduce((sum, episode) => sum + episode._count.cuts, 0);
  const totalVersions = episodes.reduce((sum, episode) => sum + episode._count.performances, 0);
  // 끊김 없는 무한 루프를 위해 트랙을 2번 반복
  const marqueeLoop = [...marqueeImages, ...marqueeImages];

  return (
    <main className="market-shell">
      <header className="market-nav">
        <Link href="/" className="market-brand">
          <span className="market-brand-mark">W</span>
          <span>Webtoon Voice Studio</span>
        </Link>
        <nav className="market-links" aria-label="Main navigation">
          <Link href="/">Episodes</Link>
          <a href="#collection">Collection</a>
          <Link href="/admin">Admin</Link>
        </nav>
        <AuthNav />
      </header>

      <section className="market-hero">
        <div className="market-hero-main">
          <span className="hero-badge">
            <i className="hero-badge-dot" aria-hidden="true" />
            Voice-over marketplace for AI webtoons
          </span>
          <h1>
            One original webtoon,
            <br />
            <em>endless</em> actor versions.
          </h1>
          <p>
            Admins publish fixed webtoon episodes with cut images, dialogue, and role guides.
            Members sign in, record every speech bubble, and ship their own shareable voice version.
          </p>
          <div className="hero-actions">
            <a className="hero-btn hero-btn-primary" href="#collection">
              Browse episodes
              <span aria-hidden="true">→</span>
            </a>
            <Link className="hero-btn hero-btn-ghost" href="/episodes/ex-interviewer">
              Try recording
            </Link>
          </div>
        </div>
        <aside className="hero-stats" aria-label="Marketplace stats">
          <div className="hero-stat">
            <strong>{episodes.length}</strong>
            <span>Published episodes</span>
          </div>
          <div className="hero-stat">
            <strong>{totalCuts}</strong>
            <span>Recordable cuts</span>
          </div>
          <div className="hero-stat">
            <strong>{totalVersions}</strong>
            <span>Actor versions</span>
          </div>
          <div className="hero-stat hero-stat-accent">
            <strong>∞</strong>
            <span>Open casting slots</span>
          </div>
        </aside>
      </section>

      <section className="marquee" aria-hidden="true">
        <div className="marquee-track">
          {marqueeLoop.map((src, index) => (
            <span className="marquee-item" key={`${src}-${index}`}>
              <img src={src} alt="" loading="lazy" />
            </span>
          ))}
        </div>
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
          <span className="feature-live">
            <i aria-hidden="true" />
            Live casting
          </span>
        </div>
      </section>

      <div className="ticker" aria-hidden="true">
        <div className="ticker-track">
          {Array.from({ length: 2 }).map((_, loop) => (
            <span key={loop}>
              AI Webtoon&nbsp;·&nbsp;Voice Acting&nbsp;·&nbsp;Speech Bubbles&nbsp;·&nbsp;Hyperlapse Render&nbsp;·&nbsp;Open Casting&nbsp;·&nbsp;Shorts Ready&nbsp;·&nbsp;
            </span>
          ))}
        </div>
      </div>

      <section className="section-heading" id="collection">
        <div>
          <p>Episode collection</p>
          <h2>Pick a webtoon and perform it your way</h2>
        </div>
        <span>{episodes.length} published</span>
      </section>

      <section className="market-grid">
        {episodes.map((episode, index) => {
          const tags = episodeTags[episode.slug] ?? ['Drama'];
          return (
            <Link className="market-card" href={`/episodes/${episode.slug}`} key={episode.id}>
              <div className="market-card-image">
                <img src={episode.thumbnailUrl ?? '/sample/interview-cut-01.png'} alt="" />
                <span className="market-card-index">{String(index + 1).padStart(2, '0')}</span>
                <span className="market-card-duration">{episode.maxSeconds}s shorts</span>
                <div className="market-card-overlay">
                  <span className="market-card-cta">Record your version →</span>
                </div>
              </div>
              <div className="market-card-body">
                <div className="market-card-tags">
                  {tags.map((tag) => (
                    <span key={tag}>{tag}</span>
                  ))}
                </div>
                <div className="market-card-titleline">
                  <h3>{episode.title}</h3>
                  <p>{episode._count.cuts} cuts</p>
                </div>
                <p className="market-card-logline">{episode.logline}</p>
                <div className="market-card-meta">
                  <span>{episode._count.performances} versions</span>
                  <span className="market-card-open">Open ↗</span>
                </div>
              </div>
            </Link>
          );
        })}
      </section>

      <footer className="market-footer">
        <div className="market-footer-top">
          <div className="market-footer-brand">
            <span className="market-brand-mark">W</span>
            <div>
              <strong>Webtoon Voice Studio</strong>
              <span>One original webtoon, endless actor versions.</span>
            </div>
          </div>
          <nav className="market-footer-links" aria-label="Footer navigation">
            <a href="#collection">Episodes</a>
            <Link href="/admin">Admin</Link>
            <Link href="/terms">이용약관</Link>
            <Link href="/privacy" className="footer-link-strong">개인정보처리방침</Link>
          </nav>
        </div>

        <dl className="market-footer-biz">
          <div>
            <dt>상호</dt>
            <dd>플럭 (Pluck)</dd>
          </div>
          <div>
            <dt>대표</dt>
            <dd>심재형</dd>
          </div>
          <div>
            <dt>사업자등록번호</dt>
            <dd>709-19-02368</dd>
          </div>
          <div>
            <dt>이메일</dt>
            <dd><a href="mailto:hello@pluck.co.kr">hello@pluck.co.kr</a></dd>
          </div>
        </dl>

        <div className="market-footer-bottom">
          <p className="market-footer-note">© 2026 플럭 (Pluck). All rights reserved.</p>
          <nav className="market-footer-legal" aria-label="Legal">
            <Link href="/terms">이용약관</Link>
            <span aria-hidden="true">·</span>
            <Link href="/privacy">개인정보처리방침</Link>
          </nav>
        </div>
      </footer>
    </main>
  );
}
