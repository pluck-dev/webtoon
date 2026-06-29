/* eslint-disable @next/next/no-img-element */
import type { Metadata } from 'next';
import Link from 'next/link';

import SiteFooter from '@/components/SiteFooter';
import SiteHeader from '@/components/SiteHeader';
import { prisma } from '@/lib/prisma';
import { CATEGORY_LABELS } from '@/lib/taxonomy';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: '더빙고 앱 소개',
  description:
    '짧은 상황극과 웹툰 컷을 내 목소리로 더빙하는 더빙고. 웹에서는 작품을 구경하고 앱 설치로 이어집니다.',
  openGraph: {
    title: '더빙고 — 구경하고 앱에서 만들기',
    description: 'AI 웹툰 컷과 짧은 상황극에 목소리를 입혀 더빙 숏폼을 만드는 앱입니다. 웹에서는 예시 작품을 구경할 수 있어요.'
  }
};

const proofImages = [
  '/sample/interview-cut-01.png',
  '/generated/borrowed-tomorrow-01.png',
  '/generated/moonlit-audit-01.png',
  '/sample/interview-cut-02.png',
  '/generated/last-delivery-01.png',
  '/generated/borrowed-tomorrow-03.png'
];

const webScope = [
  {
    title: '작품 둘러보기',
    copy: '웹툰체·상황극·애니 화풍의 공개 작품을 바로 탐색합니다.',
    badge: 'SEO / 공유'
  },
  {
    title: '제작 예시 구경',
    copy: '앱에서 만들 수 있는 장면과 웹툰 컷 분위기를 먼저 확인합니다.',
    badge: '갤러리'
  },
  {
    title: '앱 설치로 전환',
    copy: '직접 만들고 싶을 때는 앱 설치 안내로 연결합니다.',
    badge: '앱 전환'
  }
];

const appScope = [
  'AI로 웹툰 컷 만들기',
  '작품 수정과 임시저장',
  '반복 녹음과 업로드 복구',
  '내 작업 관리와 본격 영상 제작'
];

const steps = [
  ['01', '작품 선택', '짧은 장면을 고르고 캐릭터와 대사를 확인합니다.'],
  ['02', '장면 구경', '웹툰 컷, 대사, 분위기를 보며 어떤 결과물이 나오는지 확인합니다.'],
  ['03', '앱 설치', '직접 만들고 싶어지면 앱 설치 안내로 이동합니다.'],
  ['04', '앱에서 완성', 'AI 웹툰 제작, 녹음, 영상 완성은 앱에서 이어갑니다.']
];

export default async function Home() {
  const episodes = await prisma.episode.findMany({
    where: { status: 'PUBLISHED' },
    orderBy: { createdAt: 'desc' },
    take: 3,
    include: {
      _count: { select: { cuts: true, performances: true } }
    }
  });

  const proofLoop = [...proofImages, ...proofImages];

  return (
    <main className="market-shell">
      <SiteHeader />
      <div className="mx-auto w-full max-w-[1760px] px-4 py-4 sm:px-6 lg:px-10">
        <section className="grid min-h-[calc(100vh-88px)] items-center gap-10 py-12 lg:grid-cols-[minmax(0,1fr)_minmax(360px,520px)] lg:py-20">
          <div>
            <span className="mb-6 inline-flex items-center gap-2 rounded-full border border-line bg-card/80 px-3.5 py-2 text-xs font-black tracking-wide text-muted">
              <i className="h-2 w-2 animate-soft-pulse rounded-full bg-coral" aria-hidden="true" />
              구경은 웹에서, 제작은 앱에서
            </span>
            <h1 className="max-w-[11ch] text-[clamp(40px,6.5vw,96px)] font-black leading-[0.92] tracking-tight text-ink">
              짧은 상황극을 <em className="italic text-coral">내 목소리</em>로.
            </h1>
            <p className="mt-6 max-w-2xl text-lg leading-relaxed text-ink-soft sm:text-xl">
              더빙고는 AI 웹툰 컷과 짧은 상황극에 목소리를 입혀 더빙 숏폼을 만드는 앱입니다. 웹에서는 예시 작품을 구경할 수 있어요.
              웹에서는 어떤 장면을 만들 수 있는지 구경하고, 만들고 싶어지면 앱에서 바로 이어갑니다.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link
                href="/episodes"
                className="inline-flex min-h-12 items-center gap-2 rounded-full bg-ink px-6 text-[15px] font-black text-paper transition-transform hover:-translate-y-0.5"
              >
                사람들이 만드는 장면 보기
                <span aria-hidden="true">→</span>
              </Link>
              <a
                href="#app"
                className="inline-flex min-h-12 items-center rounded-full border border-ink px-6 text-[15px] font-black text-ink transition-colors hover:bg-ink/5"
              >
                앱 기능 보기
              </a>
            </div>
            <dl className="mt-8 grid max-w-2xl grid-cols-3 gap-3">
              {[
                ['Web', '소개·구경'],
                ['App', '제작·완성'],
                ['MP4', '영상 결과']
              ].map(([value, label]) => (
                <div key={value} className="rounded-2xl border border-line bg-card p-4">
                  <dt className="text-[clamp(24px,4vw,38px)] font-black leading-none text-ink">{value}</dt>
                  <dd className="mt-1.5 text-xs font-extrabold text-muted sm:text-sm">{label}</dd>
                </div>
              ))}
            </dl>
          </div>

          <div className="relative mx-auto w-full max-w-[520px]">
            <div className="absolute -left-5 top-10 hidden rotate-[-8deg] rounded-2xl border border-line bg-card px-4 py-3 shadow-[0_18px_50px_rgba(23,21,18,.16)] sm:block">
              <p className="text-xs font-black text-muted">WEB GALLERY</p>
              <p className="text-lg font-black text-ink">먼저 구경하기</p>
            </div>
            <div className="absolute -right-4 bottom-16 hidden rotate-[7deg] rounded-2xl border border-ink bg-ink px-4 py-3 text-paper shadow-[0_18px_50px_rgba(23,21,18,.24)] sm:block">
              <p className="text-xs font-black text-gold">APP STUDIO</p>
              <p className="text-lg font-black">직접 만들기</p>
            </div>
            <div className="mx-auto max-w-[360px] rounded-[42px] border-[10px] border-ink bg-ink p-3 shadow-[0_30px_90px_rgba(23,21,18,.32)]">
              <div className="overflow-hidden rounded-[30px] bg-cream">
                <div className="flex items-center justify-between border-b border-line bg-card px-4 py-3">
                  <span className="text-sm font-black text-ink">더빙고</span>
                  <span className="rounded-full bg-gold px-2.5 py-1 text-[10px] font-black text-ink">CREATE</span>
                </div>
                <div className="p-3">
                  <img
                    src="/generated/borrowed-tomorrow-01.png"
                    alt="더빙고 앱에서 더빙할 웹툰 컷 예시"
                    className="aspect-[4/5] w-full rounded-2xl object-cover"
                  />
                  <div className="mt-3 rounded-2xl border border-line bg-paper p-3">
                    <p className="text-xs font-black text-coral">앱 제작 예시</p>
                    <p className="mt-1 text-lg font-black leading-tight text-ink">“지금 답장 안 보면 끝이야.”</p>
                    <div className="mt-3 flex items-end gap-1" aria-hidden="true">
                      {[30, 52, 38, 74, 44, 62, 28, 48, 36, 70, 42, 56].map((height, index) => (
                        <span
                          key={index}
                          className="w-full rounded-full bg-teal"
                          style={{ height: `${height}px`, opacity: 0.35 + index / 28 }}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="group mask-fade-x overflow-hidden border-y border-line-soft py-4" aria-hidden="true">
          <div className="flex w-max gap-3 animate-marquee group-hover:[animation-play-state:paused]">
            {proofLoop.map((src, index) => (
              <span
                key={`${src}-${index}`}
                className="h-[190px] w-[142px] shrink-0 overflow-hidden rounded-xl bg-[#ded8cc] shadow-[0_10px_24px_rgba(23,21,18,.1)]"
              >
                <img src={src} alt="" loading="lazy" className="h-full w-full object-cover" />
              </span>
            ))}
          </div>
        </section>

        <section id="app" className="grid gap-4 py-16 lg:grid-cols-[0.95fr_1.05fr] lg:py-24">
          <div className="rounded-2xl border border-ink bg-ink p-7 text-paper sm:p-9">
            <p className="mb-3 text-xs font-black uppercase tracking-wider text-gold">앱이 메인 제작 공간</p>
            <h2 className="text-[clamp(32px,5vw,64px)] font-black leading-none">
              웹은 입구, 앱은 작업실.
            </h2>
            <p className="mt-5 max-w-xl leading-relaxed text-paper/72">
              웹사이트는 제품을 이해하고 결과물을 구경하는 공간입니다. AI 웹툰 만들기, 녹음, 저장, 영상 완성 같은
              제작 경험은 앱 설치 후 앱 안에서 이어가도록 설계합니다.
            </p>
            <div className="mt-7 flex flex-wrap gap-2">
              {appScope.map((item) => (
                <span key={item} className="rounded-full border border-paper/20 bg-paper/8 px-3.5 py-2 text-sm font-black text-paper">
                  {item}
                </span>
              ))}
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-3">
            {webScope.map((item) => (
              <article key={item.title} className="rounded-2xl border border-line bg-card p-5 transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_6px_20px_rgba(23,21,18,.08)]">
                <span className="mb-8 inline-flex rounded-full bg-cream px-2.5 py-1 text-[11px] font-black text-muted">
                  {item.badge}
                </span>
                <h3 className="text-2xl font-black leading-tight text-ink">{item.title}</h3>
                <p className="mt-3 leading-relaxed text-ink-soft">{item.copy}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="rounded-2xl border border-line bg-card p-6 sm:p-8">
          <div className="mb-8 flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
            <div>
              <p className="mb-2.5 text-xs font-black uppercase tracking-wider text-muted">How it works</p>
              <h2 className="text-[clamp(30px,4.5vw,56px)] font-black leading-none text-ink">처음엔 4단계면 충분해요.</h2>
            </div>
            <Link href="/guidelines" className="w-fit rounded-full border border-ink px-4 py-2 text-sm font-black text-ink hover:bg-ink/5">
              자세한 사용법
            </Link>
          </div>
          <div className="grid gap-3 md:grid-cols-4">
            {steps.map(([num, title, copy]) => (
              <article key={num} className="rounded-2xl border border-line bg-paper p-5 transition-all duration-200 hover:shadow-[0_6px_20px_rgba(23,21,18,.08)]">
                <span className="text-sm font-black text-coral">{num}</span>
                <h3 className="mt-5 text-xl font-black text-ink">{title}</h3>
                <p className="mt-2 leading-relaxed text-ink-soft">{copy}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="py-16 lg:py-24">
          <div className="mb-8 flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
            <div>
              <p className="mb-2.5 text-xs font-black uppercase tracking-wider text-muted">Made with Dubbingo</p>
              <h2 className="text-[clamp(30px,4.5vw,56px)] font-black leading-none text-ink">어떤 장면이 만들어지는지 먼저 구경하세요.</h2>
            </div>
            <Link href="/episodes" className="w-fit rounded-full bg-ink px-5 py-3 text-sm font-black text-paper transition-transform duration-200 hover:-translate-y-0.5">
              전체 작품 보기 →
            </Link>
          </div>

          {episodes.length > 0 ? (
            <div className="grid gap-4 md:grid-cols-3">
              {episodes.map((episode) => (
                <Link
                  key={episode.id}
                  href="#download"
                  className="group overflow-hidden rounded-2xl border border-line bg-card transition duration-200 hover:-translate-y-1 hover:border-ink hover:shadow-[0_22px_50px_rgba(23,21,18,.16)]"
                >
                  <img
                    src={episode.thumbnailUrl ?? '/sample/interview-cut-01.png'}
                    alt={`${episode.title} 썸네일`}
                    className="aspect-[4/3] w-full object-cover transition-transform duration-500 group-hover:scale-105"
                  />
                  <div className="p-5">
                    <div className="mb-3 flex flex-wrap gap-1.5">
                      <span className="rounded-full border border-line-soft bg-cream px-2.5 py-1 text-[11px] font-black text-muted">
                        {CATEGORY_LABELS[episode.category]}
                      </span>
                      <span className="rounded-full border border-line-soft bg-cream px-2.5 py-1 text-[11px] font-black text-muted">
                        {episode._count.cuts}컷
                      </span>
                    </div>
                    <h3 className="text-2xl font-black leading-tight text-ink">{episode.title}</h3>
                    <p className="mt-2 line-clamp-2 leading-relaxed text-ink-soft">{episode.logline}</p>
                    <p className="mt-4 text-sm font-black text-coral">이런 장면 만들기 →</p>
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <div className="rounded-2xl border border-dashed border-line bg-card px-5 py-12 text-center">
              <p className="text-lg font-black text-ink">공개된 체험 작품을 준비 중입니다.</p>
              <p className="mt-2 text-muted">새로운 체험 작품이 준비되면 이 영역에 표시됩니다.</p>
            </div>
          )}
        </section>

        <section id="download" className="grid gap-5 overflow-hidden rounded-2xl bg-ink px-7 py-12 text-paper md:grid-cols-[1fr_auto] md:items-center">
          <div>
            <p className="mb-2.5 text-xs font-black uppercase tracking-wider text-gold">Download</p>
            <h2 className="text-[clamp(28px,4vw,48px)] font-black leading-none">마음에 들면 앱에서 직접 만들어요.</h2>
            <p className="mt-3.5 max-w-md leading-relaxed text-paper/70">
              웹사이트는 소개와 구경에 집중하고, 제작은 앱 설치 후 이어갑니다. 앱스토어 링크가 준비되면 이 버튼에 연결합니다.
            </p>
          </div>
          <div className="flex flex-wrap gap-2.5 md:justify-end">
            <Link href="/episodes" className="inline-flex min-h-12 items-center rounded-full bg-gold px-6 font-black text-ink transition-transform hover:-translate-y-0.5">
              앱 설치 준비중
            </Link>
            <Link href="/episodes" className="inline-flex min-h-12 items-center rounded-full border border-paper/30 px-6 font-black text-paper transition-colors hover:bg-paper/10">
              작품 더 구경하기
            </Link>
          </div>
        </section>

        <SiteFooter />
      </div>
    </main>
  );
}
