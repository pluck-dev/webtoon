'use client';

import Link from 'next/link';
import { useState } from 'react';

import type { MyPerformance } from '@/lib/my-performances';

const STATUS_LABEL: Record<string, string> = {
  DRAFT: '작성 중',
  READY: '준비됨',
  RENDERING: '렌더 중',
  RENDERED: '완료',
  FAILED: '실패'
};

const RENDER_LABEL: Record<string, string> = {
  QUEUED: '대기 중',
  RUNNING: '렌더링 중',
  DONE: '완료',
  FAILED: '실패'
};

export default function MyPerformanceCard({ performance }: { performance: MyPerformance }) {
  const [isPublic, setIsPublic] = useState(performance.isPublic);
  const [saving, setSaving] = useState(false);

  const pct =
    performance.totalDialogues > 0
      ? Math.round((performance.recordedDialogues / performance.totalDialogues) * 100)
      : 0;
  const video = performance.render?.videoUrl ?? null;

  async function togglePublic() {
    const next = !isPublic;
    setSaving(true);
    try {
      const response = await fetch(`/api/performances/${performance.id}`, {
        method: 'PATCH',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ isPublic: next })
      });
      if (response.ok) setIsPublic(next);
    } finally {
      setSaving(false);
    }
  }

  return (
    <article className="flex flex-col gap-4 rounded-2xl border border-line bg-card p-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="text-lg font-black text-ink">{performance.episode.title}</h3>
          <p className="text-sm text-muted">{performance.title}</p>
        </div>
        <span className="shrink-0 rounded-full border border-line px-2.5 py-1 text-xs font-black text-muted">
          {STATUS_LABEL[performance.status] ?? performance.status}
        </span>
      </div>

      {/* 녹음 진행률 */}
      <div>
        <div className="mb-1.5 flex justify-between text-xs font-black text-muted">
          <span>녹음 진행</span>
          <span>
            {performance.recordedDialogues}/{performance.totalDialogues} · {pct}%
          </span>
        </div>
        <div className="h-2 overflow-hidden rounded-full bg-cream">
          <i className="block h-full bg-gradient-to-r from-coral to-gold" style={{ width: `${pct}%` }} />
        </div>
      </div>

      {/* 생성된 영상 */}
      {video ? (
        <video src={video} controls playsInline className="w-full rounded-xl bg-ink" />
      ) : (
        <div className="rounded-xl border border-dashed border-line bg-cream px-4 py-6 text-center text-sm font-bold text-muted">
          {performance.render
            ? `영상 ${RENDER_LABEL[performance.render.status] ?? performance.render.status}`
            : '아직 생성된 영상이 없습니다'}
        </div>
      )}

      {/* 액션 */}
      <div className="flex flex-wrap items-center gap-2">
        <Link
          href={`/episodes/${performance.episode.slug}`}
          className="rounded-lg bg-ink px-4 py-2 text-sm font-black text-paper"
        >
          {pct >= 100 ? '다시 녹음' : '이어하기'}
        </Link>
        {video && (
          <a
            href={video}
            download={`webtoon-${performance.episode.slug}.mp4`}
            className="rounded-lg border border-line px-4 py-2 text-sm font-black text-ink"
          >
            다운로드
          </a>
        )}
        <button
          type="button"
          onClick={togglePublic}
          disabled={saving}
          className={`ml-auto rounded-lg border px-4 py-2 text-sm font-black disabled:opacity-50 ${
            isPublic ? 'border-teal text-teal' : 'border-line text-muted'
          }`}
          aria-pressed={isPublic}
        >
          {saving ? '저장 중...' : isPublic ? '공개됨' : '비공개'}
        </button>
      </div>
    </article>
  );
}
