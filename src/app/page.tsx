/* eslint-disable @next/next/no-img-element */
import Link from 'next/link';

import EpisodeBrowser from '@/components/EpisodeBrowser';
import SiteFooter from '@/components/SiteFooter';
import SiteHeader from '@/components/SiteHeader';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

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

const kicker = 'mb-2.5 text-xs font-black uppercase tracking-wider text-muted';

export default async function Home() {
  const episodes = await prisma.episode.findMany({
    where: { status: 'PUBLISHED' },
    orderBy: { createdAt: 'desc' },
    include: {
      _count: {
        select: { cuts: true, performances: true }
      },
      cuts: {
        take: 3,
        orderBy: { order: 'asc' },
        select: { imageUrl: true }
      }
    }
  });

  const totalCuts = episodes.reduce((sum, episode) => sum + episode._count.cuts, 0);
  const totalVersions = episodes.reduce((sum, episode) => sum + episode._count.performances, 0);
  const marqueeLoop = [...marqueeImages, ...marqueeImages];

  // 그리드/필터에 전달할 직렬화 데이터
  const browserEpisodes = episodes.map((episode) => ({
    id: episode.id,
    slug: episode.slug,
    title: episode.title,
    logline: episode.logline,
    thumbnailUrl: episode.thumbnailUrl,
    maxSeconds: episode.maxSeconds,
    cutCount: episode._count.cuts,
    versionCount: episode._count.performances,
    format: episode.format,
    category: episode.category
  }));

  // 최신 에피소드를 Featured로 사용
  const featured = episodes[0];
  const featuredImages = (featured?.cuts ?? [])
    .map((cut) => cut.imageUrl)
    .filter(Boolean);
  while (featuredImages.length < 3 && featured?.thumbnailUrl) {
    featuredImages.push(featured.thumbnailUrl);
  }

  const stats = [
    { value: String(episodes.length), label: '공개 작품', accent: false },
    { value: String(totalCuts), label: '연기할 컷', accent: false },
    { value: String(totalVersions), label: '만들어진 버전', accent: false },
    { value: '∞', label: '오픈 캐스팅', accent: true }
  ];

  return (
    <main className="market-shell">
      <SiteHeader />
      <div className="mx-auto w-full max-w-[1760px] px-4 py-4 sm:px-6 lg:px-10">

      {/* 히어로 */}
      <section className="pb-7 pt-14 md:pt-20">
        <span className="mb-6 inline-flex items-center gap-2 rounded-full border border-line bg-card/80 px-3.5 py-2 text-xs font-black tracking-wide text-muted">
          <i className="h-2 w-2 animate-soft-pulse rounded-full bg-coral" aria-hidden="true" />
          짧은 상황을 내 목소리로 — 더빙 놀이터
        </span>
        <h1 className="max-w-[18ch] text-[clamp(44px,7.2vw,104px)] font-black leading-[0.92] tracking-tight text-ink">
          짧은 상황극, <em className="italic text-coral">내 목소리</em>로 연기하다.
        </h1>
        <p className="mt-6 max-w-2xl text-lg leading-relaxed text-ink-soft">
          AI가 그린 짧은 상황극에 컷마다 대사를 녹음해보세요. 웹툰체·상황극·애니 화풍의 더빙 숏폼이 완성됩니다.
          누구나 성우가 되는 곳.
        </p>
        <div className="mt-7 flex flex-wrap gap-2.5">
          <a
            href="#collection"
            className="inline-flex min-h-12 items-center gap-2 rounded-full bg-ink px-6 text-[15px] font-black text-paper transition-transform hover:-translate-y-0.5"
          >
            작품 둘러보기
            <span aria-hidden="true">→</span>
          </a>
          <Link
            href="/episodes/read-mark-but-no-reply"
            className="inline-flex min-h-12 items-center rounded-full border border-ink px-6 text-[15px] font-black text-ink transition-colors hover:bg-ink/5"
          >
            지금 연기하기
          </Link>
        </div>
      </section>

      {/* 통계 밴드 */}
      <section className="grid grid-cols-2 gap-3 md:grid-cols-4" aria-label="Marketplace stats">
        {stats.map((stat) => (
          <div
            key={stat.label}
            className={`grid min-h-[128px] content-center gap-1.5 rounded-2xl border px-6 py-6 ${
              stat.accent ? 'border-ink bg-ink text-paper' : 'border-line bg-card'
            }`}
          >
            <strong className={`text-[clamp(32px,4vw,44px)] leading-none ${stat.accent ? 'text-gold' : 'text-ink'}`}>
              {stat.value}
            </strong>
            <span className={`text-[13px] font-extrabold ${stat.accent ? 'text-paper/70' : 'text-muted'}`}>
              {stat.label}
            </span>
          </div>
        ))}
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

      {/* 피처드 에피소드 (최신 에피소드 자동 노출) */}
      {featured && (
        <section className="mb-10 grid items-stretch gap-4 rounded-2xl border border-line bg-card p-3.5 md:grid-cols-[minmax(300px,440px)_minmax(0,1fr)]">
          <div className="flex min-h-[340px] flex-col justify-end p-6">
            <span className={kicker}>오늘의 추천</span>
            <h2 className="text-[clamp(26px,3.2vw,44px)] font-black leading-[1.08] tracking-tight text-ink">
              {featured.title}
            </h2>
            <p className="mb-6 mt-4 leading-relaxed text-ink-soft">{featured.logline}</p>
            <Link
              href={`/episodes/${featured.slug}`}
              className="inline-flex min-h-[42px] w-fit items-center rounded-full bg-ink px-4 font-black text-paper transition-transform hover:-translate-y-0.5"
            >
              내 목소리로 연기하기
            </Link>
          </div>
          <div className="relative grid grid-cols-[1.2fr_1fr_1fr] gap-2.5" aria-hidden="true">
            {featuredImages.slice(0, 3).map((src, index) => (
              <img
                key={`${src}-${index}`}
                src={src}
                alt=""
                className="h-full min-h-[340px] w-full rounded-md object-cover"
              />
            ))}
            <span className="absolute right-3.5 top-3.5 inline-flex items-center gap-1.5 rounded-full bg-ink/85 px-3 py-2 text-xs font-black text-paper backdrop-blur">
              <i className="h-2 w-2 animate-soft-pulse rounded-full bg-teal" aria-hidden="true" />
              라이브 캐스팅
            </span>
          </div>
        </section>
      )}

      {/* 텍스트 티커 */}
      <div className="my-11 mb-2 overflow-hidden border-y border-ink py-3.5" aria-hidden="true">
        <div className="flex w-max animate-marquee-fast text-[clamp(22px,3vw,34px)] font-black uppercase tracking-tight text-ink">
          {Array.from({ length: 2 }).map((_, loop) => (
            <span key={loop} className="whitespace-nowrap">
              보이스 연기&nbsp;·&nbsp;짧은 상황극&nbsp;·&nbsp;더빙 숏폼&nbsp;·&nbsp;웹툰체&nbsp;·&nbsp;상황극&nbsp;·&nbsp;애니메이션&nbsp;·&nbsp;오픈
              캐스팅&nbsp;·&nbsp;누구나 성우&nbsp;·&nbsp;
            </span>
          ))}
        </div>
      </div>

      {/* 컬렉션: 카테고리 필터 + 그리드 */}
      <EpisodeBrowser episodes={browserEpisodes} />

      {/* CTA 밴드 */}
      <section className="mt-12 grid gap-5 overflow-hidden rounded-2xl bg-ink px-7 py-12 text-paper md:grid-cols-[1fr_auto] md:items-center">
        <div>
          <p className="mb-2.5 text-xs font-black uppercase tracking-wider text-gold">준비됐나요?</p>
          <h2 className="text-[clamp(28px,4vw,48px)] font-black leading-none">몇 분이면 내 더빙 완성.</h2>
          <p className="mt-3.5 max-w-md leading-relaxed text-paper/70">
            작품을 고르고 로그인하면, 브라우저에서 바로 컷마다 목소리를 입힐 수 있어요.
          </p>
        </div>
        <div className="flex flex-wrap gap-2.5 md:justify-end">
          <a
            href="#collection"
            className="inline-flex min-h-12 items-center rounded-full bg-gold px-6 font-black text-ink transition-transform hover:-translate-y-0.5"
          >
            작품 둘러보기
          </a>
          <Link
            href="/admin"
            className="inline-flex min-h-12 items-center rounded-full border border-paper/30 px-6 font-black text-paper transition-colors hover:bg-paper/10"
          >
            관리자
          </Link>
        </div>
      </section>

      <SiteFooter />
      </div>
    </main>
  );
}
