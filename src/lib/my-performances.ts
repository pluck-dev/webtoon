import { prisma } from './prisma';
import { BUCKET_VIDEOS, createSignedUrl } from './supabase';

export type MyPerformance = {
  id: string;
  title: string;
  status: string;
  isPublic: boolean;
  episode: { slug: string; title: string; thumbnailUrl: string | null };
  totalDialogues: number;
  recordedDialogues: number;
  render: { status: string; videoUrl: string | null; durationMs: number | null } | null;
};

/**
 * 로그인 사용자의 공연 목록을 마이페이지용으로 만든다.
 * 에피소드별 녹음 진행률 + 최신 렌더 잡 상태 + (완료 시) 서명된 영상 URL 포함.
 */
export async function getMyPerformances(userId: string): Promise<MyPerformance[]> {
  const performances = await prisma.performance.findMany({
    where: { userId },
    orderBy: { updatedAt: 'desc' },
    include: {
      episode: {
        select: {
          slug: true,
          title: true,
          thumbnailUrl: true,
          cuts: { select: { _count: { select: { dialogues: true } } } }
        }
      },
      recordings: { select: { dialogueId: true } },
      renderJobs: { orderBy: { createdAt: 'desc' }, take: 1, include: { video: true } }
    }
  });

  const result: MyPerformance[] = [];
  for (const performance of performances) {
    const totalDialogues = performance.episode.cuts.reduce((sum, cut) => sum + cut._count.dialogues, 0);
    // 같은 대사를 여러 번 녹음(takes)해도 1개로 센다
    const recordedDialogues = new Set(performance.recordings.map((recording) => recording.dialogueId)).size;

    const job = performance.renderJobs[0] ?? null;
    let render: MyPerformance['render'] = null;
    if (job) {
      render = {
        status: job.status,
        videoUrl: job.video ? await createSignedUrl(BUCKET_VIDEOS, job.video.videoUrl, 60 * 60) : null,
        durationMs: job.video?.durationMs ?? null
      };
    }

    result.push({
      id: performance.id,
      title: performance.title,
      status: performance.status,
      isPublic: performance.isPublic,
      episode: {
        slug: performance.episode.slug,
        title: performance.episode.title,
        thumbnailUrl: performance.episode.thumbnailUrl
      },
      totalDialogues,
      recordedDialogues,
      render
    });
  }

  return result;
}
