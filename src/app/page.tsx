/* eslint-disable @next/next/no-img-element */
import Link from 'next/link';

import AuthNav from '@/components/AuthNav';
import SiteFooter from '@/components/SiteFooter';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

const categories = ['All', 'Romance', 'Office', 'Revenge', 'Horror', 'Comedy', 'Open Casting'];

// 자동 스크롤 인스피레이션 보드용 정적 컷 이미지
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

const kicker = 'mb-2.5 text-xs font-black uppercase tracking-wider text-muted';

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
  const marqueeLoop = [...marqueeImages, ...marqueeImages];

  const stats = [
    { value: String(episodes.length), label: 'Published episodes', accent: false },
    { value: String(totalCuts), label: 'Recordable cuts', accent: false },
    { value: String(totalVersions), label: 'Actor versions', accent: false },
    { value: '∞', label: 'Open casting slots', accent: true }
  ];

  return (
    <main className="market-shell">
      <header className="market-nav">
        <Link href="/" className="market-brand">
          <span className="grid h-[30px] w-[30px] place-items-center rounded-[9px] bg-ink text-base font-black text-gold">
            W
          </span>
          <span>Webtoon Voice Studio</span>
        </Link>
        <nav className="market-links" aria-label="Main navigation">
          <Link href="/">Episodes</Link>
          <a href="#collection">Collection</a>
          <Link href="/admin">Admin</Link>
        </nav>
        <AuthNav />
      </header>

      {/* 히어로 */}
      <section className="grid items-end gap-9 py-14 pb-8 lg:grid-cols-[minmax(320px,1fr)_minmax(280px,420px)]">
        <div>
          <span className="mb-5 inline-flex items-center gap-2 rounded-full border border-line bg-card/80 px-3.5 py-2 text-xs font-black tracking-wide text-muted">
            <i className="h-2 w-2 animate-soft-pulse rounded-full bg-coral" aria-hidden="true" />
            Voice-over marketplace for AI webtoons
          </span>
          <h1 className="text-[clamp(48px,9vw,118px)] font-black leading-[0.9] tracking-tight text-ink">
            One original webtoon,
            <br />
            <em className="italic text-coral">endless</em> actor versions.
          </h1>
          <p className="mt-5 max-w-xl text-lg leading-relaxed text-ink-soft">
            Admins publish fixed webtoon episodes with cut images, dialogue, and role guides. Members sign in, record
            every speech bubble, and ship their own shareable voice version.
          </p>
          <div className="mt-6 flex flex-wrap gap-2.5">
            <a
              href="#collection"
              className="inline-flex min-h-12 items-center gap-2 rounded-full bg-ink px-6 text-[15px] font-black text-paper transition-transform hover:-translate-y-0.5"
            >
              Browse episodes
              <span aria-hidden="true">→</span>
            </a>
            <Link
              href="/episodes/ex-interviewer"
              className="inline-flex min-h-12 items-center rounded-full border border-ink px-6 text-[15px] font-black text-ink transition-colors hover:bg-ink/5"
            >
              Try recording
            </Link>
          </div>
        </div>
        <aside className="grid grid-cols-2 gap-2.5" aria-label="Marketplace stats">
          {stats.map((stat) => (
            <div
              key={stat.label}
              className={`grid min-h-[104px] content-center gap-1 rounded-2xl border px-5 py-4 ${
                stat.accent ? 'border-ink bg-ink text-paper' : 'border-line bg-card'
              }`}
            >
              <strong className={`text-[clamp(28px,4vw,40px)] leading-none ${stat.accent ? 'text-gold' : ''}`}>
                {stat.value}
              </strong>
              <span className={`text-xs font-extrabold ${stat.accent ? 'text-paper/70' : 'text-muted'}`}>
                {stat.label}
              </span>
            </div>
          ))}
        </aside>
      </section>

      {/* 자동 스크롤 이미지 보드 */}
      <section className="group mask-fade-x my-2 overflow-hidden border-y border-line-soft py-4" aria-hidden="true">
        <div className="flex w-max gap-3 animate-marquee group-hover:[animation-play-state:paused]">
          {marqueeLoop.map((src, index) => (
            <span
              key={`${src}-${index}`}
              className="h-[200px] w-[150px] shrink-0 overflow-hidden rounded-xl bg-[#ded8cc] shadow-[0_10px_24px_rgba(23,21,18,.1)]"
            >
              <img src={src} alt="" loading="lazy" className="h-full w-full object-cover" />
            </span>
          ))}
        </div>
      </section>

      {/* 카테고리 */}
      <section className="flex gap-2 overflow-x-auto py-3 pb-6" aria-label="Episode categories">
        {categories.map((category, index) => (
          <button
            type="button"
            key={category}
            className={`min-h-[38px] shrink-0 rounded-full border px-3.5 text-[13px] font-extrabold transition-colors ${
              index === 0
                ? 'border-ink bg-ink text-paper'
                : 'border-line bg-card/70 text-ink hover:bg-ink/5'
            }`}
          >
            {category}
          </button>
        ))}
      </section>

      {/* 피처드 에피소드 */}
      <section className="mb-10 grid items-stretch gap-4 rounded-2xl border border-line bg-card p-3.5 md:grid-cols-[minmax(260px,390px)_minmax(0,1fr)]">
        <div className="flex min-h-[420px] flex-col justify-end p-6">
          <span className={kicker}>Featured episode</span>
          <h2 className="text-[clamp(30px,4vw,56px)] font-black leading-none text-ink">
            Former lover, current interviewer
          </h2>
          <p className="mb-6 mt-3.5 leading-relaxed text-ink-soft">
            An interview room turns into a tense reunion when the interviewer is someone from three years ago.
          </p>
          <Link
            href="/episodes/ex-interviewer"
            className="inline-flex min-h-[42px] w-fit items-center rounded-full bg-ink px-4 font-black text-paper transition-transform hover:-translate-y-0.5"
          >
            Record your version
          </Link>
        </div>
        <div className="relative grid grid-cols-[1.2fr_1fr_1fr] gap-2.5" aria-hidden="true">
          {['/sample/interview-cut-01.png', '/sample/interview-cut-02.png', '/sample/interview-cut-03.png'].map((src) => (
            <img key={src} src={src} alt="" className="h-full min-h-[420px] w-full rounded-md object-cover" />
          ))}
          <span className="absolute right-3.5 top-3.5 inline-flex items-center gap-1.5 rounded-full bg-ink/85 px-3 py-2 text-xs font-black text-paper backdrop-blur">
            <i className="h-2 w-2 animate-soft-pulse rounded-full bg-teal" aria-hidden="true" />
            Live casting
          </span>
        </div>
      </section>

      {/* 텍스트 티커 */}
      <div className="my-11 mb-2 overflow-hidden border-y border-ink py-3.5" aria-hidden="true">
        <div className="flex w-max animate-marquee-fast text-[clamp(22px,3vw,34px)] font-black uppercase tracking-tight text-ink">
          {Array.from({ length: 2 }).map((_, loop) => (
            <span key={loop} className="whitespace-nowrap">
              AI Webtoon&nbsp;·&nbsp;Voice Acting&nbsp;·&nbsp;Speech Bubbles&nbsp;·&nbsp;Hyperlapse Render&nbsp;·&nbsp;Open
              Casting&nbsp;·&nbsp;Shorts Ready&nbsp;·&nbsp;
            </span>
          ))}
        </div>
      </div>

      {/* 컬렉션 헤딩 */}
      <section id="collection" className="mb-3.5 mt-9 flex items-end justify-between gap-5">
        <div>
          <p className={kicker}>Episode collection</p>
          <h2 className="max-w-3xl text-[clamp(28px,4vw,54px)] font-black leading-none text-ink">
            Pick a webtoon and perform it your way
          </h2>
        </div>
        <span className="shrink-0 font-black text-muted">{episodes.length} published</span>
      </section>

      {/* 에피소드 그리드 */}
      <section className="grid grid-cols-[repeat(auto-fill,minmax(260px,1fr))] gap-4">
        {episodes.map((episode, index) => {
          const tags = episodeTags[episode.slug] ?? ['Drama'];
          return (
            <Link
              key={episode.id}
              href={`/episodes/${episode.slug}`}
              className="group grid overflow-hidden rounded-2xl border border-line bg-card transition duration-200 hover:-translate-y-1 hover:border-ink hover:shadow-[0_22px_50px_rgba(23,21,18,.16)]"
            >
              <div className="relative overflow-hidden bg-[#ded8cc]">
                <img
                  src={episode.thumbnailUrl ?? '/sample/interview-cut-01.png'}
                  alt=""
                  className="aspect-[4/5] w-full object-cover transition-transform duration-500 group-hover:scale-105"
                />
                <span className="absolute left-3 top-2.5 text-[13px] font-black tracking-wide text-paper [text-shadow:0_1px_8px_rgba(0,0,0,.55)]">
                  {String(index + 1).padStart(2, '0')}
                </span>
                <span className="absolute bottom-2.5 left-2.5 rounded-full bg-ink/85 px-2.5 py-1.5 text-xs font-black text-paper backdrop-blur">
                  {episode.maxSeconds}s shorts
                </span>
                <div className="absolute inset-0 flex items-end bg-gradient-to-b from-transparent via-transparent to-ink/80 p-3.5 opacity-0 transition-opacity duration-300 group-hover:opacity-100">
                  <span className="translate-y-2 text-sm font-black text-gold transition-transform duration-300 group-hover:translate-y-0">
                    Record your version →
                  </span>
                </div>
              </div>
              <div className="grid gap-3 p-4">
                <div className="flex flex-wrap gap-1.5">
                  {tags.map((tag) => (
                    <span
                      key={tag}
                      className="rounded-full border border-line-soft bg-cream px-2.5 py-1 text-[11px] font-black uppercase tracking-wide text-muted"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
                <div className="flex items-start justify-between gap-3.5">
                  <h3 className="text-[22px] leading-tight text-ink">{episode.title}</h3>
                  <p className="whitespace-nowrap text-xs font-black text-faint">{episode._count.cuts} cuts</p>
                </div>
                <p className="leading-snug text-ink-soft">{episode.logline}</p>
                <div className="flex justify-between gap-2.5 border-t border-line-soft pt-3 text-xs font-black text-muted">
                  <span>{episode._count.performances} versions</span>
                  <span className="text-coral">Open ↗</span>
                </div>
              </div>
            </Link>
          );
        })}
      </section>

      {/* CTA 밴드 */}
      <section className="mt-12 grid gap-5 overflow-hidden rounded-2xl bg-ink px-7 py-12 text-paper md:grid-cols-[1fr_auto] md:items-center">
        <div>
          <p className="mb-2.5 text-xs font-black uppercase tracking-wider text-gold">Ready when you are</p>
          <h2 className="text-[clamp(28px,4vw,48px)] font-black leading-none">Record your version in minutes.</h2>
          <p className="mt-3.5 max-w-md leading-relaxed text-paper/70">
            Pick an episode, sign in, and voice every speech bubble right in the browser.
          </p>
        </div>
        <div className="flex flex-wrap gap-2.5 md:justify-end">
          <a
            href="#collection"
            className="inline-flex min-h-12 items-center rounded-full bg-gold px-6 font-black text-ink transition-transform hover:-translate-y-0.5"
          >
            Browse episodes
          </a>
          <Link
            href="/admin"
            className="inline-flex min-h-12 items-center rounded-full border border-paper/30 px-6 font-black text-paper transition-colors hover:bg-paper/10"
          >
            Open admin
          </Link>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
