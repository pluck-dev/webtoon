/* eslint-disable @next/next/no-img-element */
import Link from 'next/link';

import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

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
    <main className="shell">
      <nav className="topbar">
        <Link href="/" className="brand">
          <span className="brand-mark">WV</span>
          <span>
            <strong>Webtoon Voice Studio</strong>
            <small>같은 웹툰을 각자 다른 연기로 만드는 숏츠 SaaS</small>
          </span>
        </Link>
        <div className="nav-actions">
          <Link className="button" href="/admin">관리자</Link>
        </div>
      </nav>

      <section className="hero">
        <div>
          <p className="eyebrow">Admin creates. Actors perform. Shorts render.</p>
          <h1>관리자가 만든 웹툰에 사람들이 자기 목소리 버전을 올립니다.</h1>
          <p>
            원본 컷과 말풍선 대사는 고정됩니다. 사용자는 컷별로 직접 녹음하고, 서비스는
            녹음 길이에 맞춰 1분 미만 하이퍼랩스 숏츠 타임라인을 만듭니다.
          </p>
        </div>
        <div className="metric-grid">
          <div className="metric"><strong>8컷</strong><span>권장 숏츠 템플릿</span></div>
          <div className="metric"><strong>1분 미만</strong><span>자동 타임라인 스케일링</span></div>
          <div className="metric"><strong>N개</strong><span>사용자별 더빙 버전</span></div>
        </div>
      </section>

      <section className="episode-grid">
        {episodes.map((episode) => (
          <Link className="episode-card" href={`/episodes/${episode.slug}`} key={episode.id}>
            <img src={episode.thumbnailUrl ?? '/sample/interview-cut-01.png'} alt="" />
            <div className="episode-card-body">
              <h2>{episode.title}</h2>
              <p>{episode.logline}</p>
              <div className="pill-row">
                <span>{episode._count.cuts}컷</span>
                <span>{episode._count.performances}개 버전</span>
                <span>{episode.maxSeconds}초 이하</span>
              </div>
            </div>
          </Link>
        ))}
      </section>
    </main>
  );
}
