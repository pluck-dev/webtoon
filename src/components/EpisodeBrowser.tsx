/* eslint-disable @next/next/no-img-element */
'use client';

import { useMemo, useState } from 'react';

import {
  CATEGORY_LABELS,
  CATEGORY_ORDER,
  FORMAT_LABELS,
  FORMAT_ORDER,
  type EpisodeCategory,
  type EpisodeFormat
} from '@/lib/taxonomy';

export type BrowserEpisode = {
  id: string;
  slug: string;
  title: string;
  logline: string;
  thumbnailUrl: string | null;
  maxSeconds: number;
  cutCount: number;
  versionCount: number;
  format: EpisodeFormat;
  category: EpisodeCategory;
};

export default function EpisodeBrowser({ episodes }: { episodes: BrowserEpisode[] }) {
  const [format, setFormat] = useState<EpisodeFormat>('SHORT');
  const [category, setCategory] = useState<EpisodeCategory | 'ALL'>('ALL');

  // 대분류(format)별 개수
  const formatCounts = useMemo(() => {
    const map: Record<string, number> = {};
    episodes.forEach((episode) => {
      map[episode.format] = (map[episode.format] ?? 0) + 1;
    });
    return map;
  }, [episodes]);

  // 현재 대분류에 속한 에피소드
  const inFormat = useMemo(
    () => episodes.filter((episode) => episode.format === format),
    [episodes, format]
  );

  // 현재 대분류 안에서 화풍별 개수 (필터 칩 카운트)
  const categoryCounts = useMemo(() => {
    const map: Record<string, number> = {};
    inFormat.forEach((episode) => {
      map[episode.category] = (map[episode.category] ?? 0) + 1;
    });
    return map;
  }, [inFormat]);

  const filtered = useMemo(
    () => (category === 'ALL' ? inFormat : inFormat.filter((episode) => episode.category === category)),
    [inFormat, category]
  );

  return (
    <>
      {/* 대분류 탭: 숏츠 / 시리즈 */}
      <section id="collection" className="mt-10 flex gap-2 border-b border-line" aria-label="콘텐츠 대분류">
        {FORMAT_ORDER.map((key) => {
          const isActive = key === format;
          return (
            <button
              type="button"
              key={key}
              aria-pressed={isActive}
              onClick={() => {
                setFormat(key);
                setCategory('ALL');
              }}
              className={`-mb-px border-b-2 px-4 pb-3 pt-1 text-lg font-black transition-colors ${
                isActive ? 'border-ink text-ink' : 'border-transparent text-faint hover:text-ink'
              }`}
            >
              {FORMAT_LABELS[key]}
              <span className="ml-1.5 text-sm font-extrabold text-muted">{formatCounts[key] ?? 0}</span>
            </button>
          );
        })}
      </section>

      {/* 화풍 필터: 전체 / 웹툰체 / 상황극 / 애니메이션 */}
      <section className="flex gap-2 overflow-x-auto py-5" aria-label="화풍 필터">
        {(['ALL', ...CATEGORY_ORDER] as const).map((key) => {
          const isActive = key === category;
          const label = key === 'ALL' ? '전체' : CATEGORY_LABELS[key];
          const count = key === 'ALL' ? inFormat.length : (categoryCounts[key] ?? 0);
          return (
            <button
              type="button"
              key={key}
              aria-pressed={isActive}
              onClick={() => setCategory(key)}
              className={`min-h-[38px] shrink-0 rounded-full border px-4 text-[13px] font-extrabold transition-colors ${
                isActive ? 'border-ink bg-ink text-paper' : 'border-line bg-card/70 text-ink hover:bg-ink/5'
              }`}
            >
              {label}
              <span className={`ml-1.5 ${isActive ? 'text-paper/60' : 'text-faint'}`}>{count}</span>
            </button>
          );
        })}
      </section>

      {/* 헤딩 */}
      <section className="mb-3.5 flex items-end justify-between gap-5">
        <div>
          <p className="mb-2.5 text-xs font-black uppercase tracking-wider text-muted">
            {FORMAT_LABELS[format]} 컬렉션
          </p>
          <h2 className="max-w-3xl text-[clamp(28px,4vw,54px)] font-black leading-none text-ink">
            사람들이 만들 수 있는 장면을 구경해보세요
          </h2>
        </div>
        <span className="shrink-0 font-black text-muted">{filtered.length}편</span>
      </section>

      {/* 그리드 / 빈 상태 */}
      {filtered.length === 0 ? (
        <div className="grid place-items-center rounded-2xl border border-dashed border-line bg-card py-16 text-center">
          {format === 'SERIES' ? (
            <>
              <p className="text-lg font-black text-ink">시리즈물은 곧 공개됩니다.</p>
              <p className="mt-1.5 text-muted">지금은 숏츠 단편을 즐겨보세요.</p>
              <button
                type="button"
                onClick={() => setFormat('SHORT')}
                className="mt-4 inline-flex min-h-10 items-center rounded-full border border-ink px-4 text-sm font-black text-ink transition-colors hover:bg-ink/5"
              >
                숏츠 보러가기
              </button>
            </>
          ) : (
            <>
              <p className="text-lg font-black text-ink">이 화풍의 에피소드가 아직 없어요.</p>
              <button
                type="button"
                onClick={() => setCategory('ALL')}
                className="mt-4 inline-flex min-h-10 items-center rounded-full border border-ink px-4 text-sm font-black text-ink transition-colors hover:bg-ink/5"
              >
                전체 보기
              </button>
            </>
          )}
        </div>
      ) : (
        <section className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
          {filtered.map((episode, index) => (
            <article
              key={episode.id}
              className="group flex h-full flex-col overflow-hidden rounded-2xl border border-line bg-card transition duration-200 hover:-translate-y-1 hover:border-ink hover:shadow-[0_22px_50px_rgba(23,21,18,.16)]"
            >
              <div className="relative shrink-0 overflow-hidden bg-[#ded8cc]">
                <img
                  src={episode.thumbnailUrl ?? '/sample/interview-cut-01.png'}
                  alt={`${episode.title} 썸네일`}
                  className="aspect-[4/5] w-full object-cover transition-transform duration-500 group-hover:scale-105"
                />
                <span className="absolute left-3 top-2.5 text-[13px] font-black tracking-wide text-paper [text-shadow:0_1px_8px_rgba(0,0,0,.55)]">
                  {String(index + 1).padStart(2, '0')}
                </span>
                <span className="absolute bottom-2.5 left-2.5 rounded-full bg-ink/85 px-2.5 py-1.5 text-xs font-black text-paper backdrop-blur">
                  {episode.maxSeconds}s
                </span>
                <div className="absolute inset-0 flex items-end bg-gradient-to-b from-transparent via-transparent to-ink/80 p-3.5 opacity-0 transition-opacity duration-300 group-hover:opacity-100">
                  <span className="translate-y-2 text-sm font-black text-gold transition-transform duration-300 group-hover:translate-y-0">
                    앱에서 만들 수 있어요
                  </span>
                </div>
              </div>
              <div className="flex flex-1 flex-col gap-3 p-4">
                <div className="flex flex-wrap gap-1.5">
                  <span className="rounded-full border border-line-soft bg-cream px-2.5 py-1 text-[11px] font-black uppercase tracking-wide text-muted">
                    {CATEGORY_LABELS[episode.category]}
                  </span>
                </div>
                <div className="flex items-start justify-between gap-3.5">
                  <h3 className="min-w-0 flex-1 truncate text-[22px] leading-tight text-ink">{episode.title}</h3>
                  <p className="whitespace-nowrap text-xs font-black text-faint">{episode.cutCount}컷</p>
                </div>
                <p className="line-clamp-2 leading-snug text-ink-soft">{episode.logline}</p>
                <div className="mt-auto flex justify-between gap-2.5 border-t border-line-soft pt-3 text-xs font-black text-muted">
                  <span>{episode.versionCount}개 버전</span>
                  <span className="text-coral">앱에서 만들기</span>
                </div>
              </div>
            </article>
          ))}
        </section>
      )}
    </>
  );
}
