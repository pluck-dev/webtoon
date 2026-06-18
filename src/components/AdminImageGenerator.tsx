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
      if (!response.ok) throw new Error(body.error ? JSON.stringify(body.error) : 'generation failed');
      setImageUrl(body.imageUrl);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'unknown error');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="admin-generator">
      <label>
        파일 슬러그
        <input value={slug} onChange={(event) => setSlug(event.target.value)} />
      </label>
      <label>
        이미지 프롬프트
        <textarea rows={9} value={prompt} onChange={(event) => setPrompt(event.target.value)} />
      </label>
      <button className="primary" type="button" onClick={generate} disabled={busy}>
        {busy ? '생성 중...' : 'CLI로 PNG 생성'}
      </button>
      {error ? <p className="error">{error}</p> : null}
      {imageUrl ? (
        <div className="generated-result">
          <img src={imageUrl} alt="generated webtoon cut" />
          <code>{imageUrl}</code>
        </div>
      ) : null}
    </div>
  );
}
