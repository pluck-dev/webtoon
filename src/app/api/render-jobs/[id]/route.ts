import { NextResponse } from 'next/server';

import { getRequiredDbUser } from '@/lib/clerk-user';
import { prisma } from '@/lib/prisma';
import { BUCKET_VIDEOS, createSignedUrl } from '@/lib/supabase';

// 렌더 잡 상태 조회 — 클라이언트가 폴링한다. DONE이면 서명된 영상 URL을 함께 준다.
export async function GET(_: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getRequiredDbUser();
  if (!user) {
    return NextResponse.json({ error: 'Login required' }, { status: 401 });
  }

  const { id } = await params;
  const job = await prisma.renderJob.findUnique({
    where: { id },
    include: { performance: true, video: true }
  });

  // 본인 공연의 잡만 조회 가능
  if (!job || job.performance.userId !== user.id) {
    return NextResponse.json({ error: 'Render job not found' }, { status: 404 });
  }

  const videoUrl = job.video
    ? await createSignedUrl(BUCKET_VIDEOS, job.video.videoUrl, 60 * 60)
    : null;

  return NextResponse.json({
    status: job.status,
    error: job.error,
    video: job.video ? { url: videoUrl, durationMs: job.video.durationMs } : null
  });
}
