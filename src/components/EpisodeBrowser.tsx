/* eslint-disable @next/next/no-img-element */
'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';

export type BrowserEpisode = {
  id: string;
  slug: string;
  title: string;
  logline: string;
  thumbnailUrl: string | null;
  maxSeconds: number;
  cutCount: number;
  versionCount: number;
  tags: string[];
};

export default function EpisodeBrowser({ episodes }: { episodes: BrowserEpisode[] }) {
  const categories = useMemo(() => {
    const set = new Set<string>();
    episodes.forEach((episode) => episode.tags.forEach((tag) => set.add(tag)));
    return ['All', ...Array.from(set)];
  }, [episodes]);

  const [active, setActive] = useState('All');

  const filtered = useMemo(
    () => (active === 'All' ? episodes : episodes.filter((episode) => episode.tags.includes(active))),
    [active, episodes]
  );

  return (
    <>
      {/* 카테고리 필터 */}
      <section className="flex gap-2 overflow-x-auto py-3 pb-6" aria-label="Episode categories">
        {categories.map((category) => {
          const isActive = category === active;
          return (
            <button
              type="button"
              key={category}
              aria-pressed={isActive}
              onClick={() => setActive(category)}
              className={`min-h-[38px] shrink-0 rounded-full border px-3.5 text-[13px] font-extrabold transition-colors ${
                isActive ? 'border-ink bg-ink text-paper' : 'border-line bg-card/70 text-ink hover:bg-ink/5'
              }`}
            >
              {category}
            </button>
          );
        })}
      </section>

      {/* 컬렉션 헤딩 */}
      <section id="collection" className="mb-3.5 mt-9 flex items-end justify-between gap-5">
        <div>
          <p className="mb-2.5 text-xs font-black uppercase tracking-wider text-muted">Episode collection</p>
          <h2 className="max-w-3xl text-[clamp(28px,4vw,54px)] font-black leading-none text-ink">
            Pick a webtoon and perform it your way
          </h2>
        </div>
        <span className="shrink-0 font-black text-muted">{filtered.length} shown</span>
      </section>

      {/* 그리드 */}
      {filtered.length === 0 ? (
        <div className="grid place-items-center rounded-2xl border border-dashed border-line bg-card py-16 text-center">
          <p className="text-lg font-black text-ink">해당 카테고리의 에피소드가 아직 없어요.</p>
          <button
            type="button"
            onClick={() => setActive('All')}
            className="mt-4 inline-flex min-h-10 items-center rounded-full border border-ink px-4 text-sm font-black text-ink transition-colors hover:bg-ink/5"
          >
            전체 보기
          </button>
        </div>
      ) : (
        <section className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
          {filtered.map((episode, index) => (
            <Link
              key={episode.id}
              href={`/episodes/${episode.slug}`}
              className="group grid overflow-hidden rounded-2xl border border-line bg-card transition duration-200 hover:-translate-y-1 hover:border-ink hover:shadow-[0_22px_50px_rgba(23,21,18,.16)]"
            >
              <div className="relative overflow-hidden bg-[#ded8cc]">
                <img
                  src={episode.thumbnailUrl ?? '/sample/interview-cut-01.png'}
                  alt={`${episode.title} 썸네일`}
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
                  {episode.tags.map((tag) => (
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
                  <p className="whitespace-nowrap text-xs font-black text-faint">{episode.cutCount} cuts</p>
                </div>
                <p className="leading-snug text-ink-soft">{episode.logline}</p>
                <div className="flex justify-between gap-2.5 border-t border-line-soft pt-3 text-xs font-black text-muted">
                  <span>{episode.versionCount} versions</span>
                  <span className="text-coral">Open ↗</span>
                </div>
              </div>
            </Link>
          ))}
        </section>
      )}
    </>
  );
}
