/* eslint-disable @next/next/no-img-element */
'use client';

import { useState } from 'react';

const defaultPrompt = `Vertical 9:16 semi-realistic Korean webtoon panel.
Modern Seoul office interview room.
Same episode characters: Seo-yoon, Korean woman age 27, black bob haircut, coral knit jacket; Do-ha, Korean man age 29, dark brown hair, navy shirt.
Cinematic lighting, expressive faces, crisp webtoon line art.
Leave empty space for speech bubbles.
No readable text, no logo, no watermark.`;

export default function AdminImageGenerator() {
  const [slug, setSlug] = useState('episode-cut');
  const [prompt, setPrompt] = useState(defaultPrompt);
  const [busy, setBusy] = useState(false);
  const [imageUrl, setImageUrl] = useState('');
  const [error, setError] = useState('');

  async function generate() {
    setBusy(true);
    setError('');
    setImageUrl('');
    try {
      const response = await fetch('/api/admin/generate-image', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ slug, prompt })
      });
      const body = await response.json();
      if (!response.ok) throw new Error(body.error ? JSON.stringify(body.error) : '생성 실패');
      setImageUrl(body.imageUrl);
    } catch (err) {
      setError(err instanceof Error ? err.message : '알 수 없는 오류');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-3 grid gap-3">
      <label className="grid gap-[7px] font-extrabold text-[#d9e0dd]">
        파일 슬러그
        <input
          className="w-full rounded-lg border border-[#34404a] bg-[#11161c] px-3 py-2.5 text-[#f5f0e8]"
          value={slug}
          onChange={(event) => setSlug(event.target.value)}
        />
      </label>
      <label className="grid gap-[7px] font-extrabold text-[#d9e0dd]">
        이미지 프롬프트
        <textarea
          className="w-full resize-y rounded-lg border border-[#34404a] bg-[#11161c] px-3 py-2.5 leading-relaxed text-[#f5f0e8]"
          rows={9}
          value={prompt}
          onChange={(event) => setPrompt(event.target.value)}
        />
      </label>
      <button
        className="min-h-[40px] rounded-lg border-0 bg-[#ef6f5e] px-[13px] font-black text-[#190b09] disabled:cursor-not-allowed disabled:opacity-55"
        type="button"
        onClick={generate}
        disabled={busy}
      >
        {busy ? '생성 중...' : '이미지 생성'}
      </button>
      {error ? <p className="text-[#ff8b7b]">{error}</p> : null}
      {imageUrl ? (
        <div className="grid gap-2">
          <img src={imageUrl} alt="생성된 컷" className="w-full max-w-[260px] rounded-lg border border-[#34404a]" />
          <code className="text-[#5cc8ba]">{imageUrl}</code>
        </div>
      ) : null}
    </div>
  );
}
