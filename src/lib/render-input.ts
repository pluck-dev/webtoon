import { prisma } from './prisma';
import { BUCKET_RECORDINGS, createSignedUrl } from './supabase';
import { buildHyperlapseTimeline } from './timeline';
import { RENDER_FPS, RENDER_HEIGHT, RENDER_WIDTH, type RenderCut, type RenderInput } from '@/remotion/types';

// 컷 이미지가 상대경로(/generated/..)면 앱 베이스 URL을 붙여 절대 URL로 만든다.
// (Remotion 서버 렌더는 절대 URL이 필요하다)
const APP_URL = process.env.APP_URL ?? 'http://localhost:3000';
function toAbsolute(url: string) {
  return url.startsWith('http://') || url.startsWith('https://') ? url : `${APP_URL}${url}`;
}

const msToFrames = (ms: number) => Math.max(1, Math.round((ms / 1000) * RENDER_FPS));

/**
 * 공연(performanceId)을 Remotion 렌더 입력으로 변환한다.
 * 컷 길이는 buildHyperlapseTimeline(maxSeconds 스케일)을 따르고,
 * 음성은 private 버킷의 서명 URL로 변환해 컷 안에서 순차 배치한다.
 */
export async function buildRenderInput(performanceId: string): Promise<RenderInput> {
  const performance = await prisma.performance.findUnique({
    where: { id: performanceId },
    include: {
      episode: {
        include: {
          cuts: {
            orderBy: { order: 'asc' },
            include: {
              dialogues: {
                orderBy: { order: 'asc' },
                include: {
                  character: true,
                  recordings: {
                    where: { performanceId },
                    orderBy: { createdAt: 'desc' },
                    take: 1
                  }
                }
              }
            }
          }
        }
      }
    }
  });

  if (!performance) {
    throw new Error(`Performance not found: ${performanceId}`);
  }

  const timeline = buildHyperlapseTimeline(performance.episode.cuts, performance.episode.maxSeconds);
  const durationByCut = new Map(timeline.map((item) => [item.cutId, item]));

  const cuts: RenderCut[] = [];
  for (const cut of performance.episode.cuts) {
    const timed = durationByCut.get(cut.id);

    let cursor = 0;
    const audios: RenderCut['audios'] = [];
    const bubbles: RenderCut['bubbles'] = [];

    for (const dialogue of cut.dialogues) {
      bubbles.push({
        speaker: dialogue.character?.name ?? '',
        text: dialogue.text,
        color: dialogue.character?.color ?? '#7c5cff'
      });

      const recording = dialogue.recordings[0];
      if (recording) {
        const durationInFrames = msToFrames(recording.durationMs);
        // 2시간 유효한 서명 URL (렌더 시간 여유)
        const src = await createSignedUrl(BUCKET_RECORDINGS, recording.storageKey, 60 * 60 * 2);
        audios.push({ src, startInFrames: cursor, durationInFrames });
        cursor += durationInFrames;
      }
    }

    // 컷 길이는 timeline(maxSeconds로 축소될 수 있음)을 따르되,
    // 그 컷의 음성 총합보다는 절대 짧지 않게 보장한다 → 녹음이 잘리지 않음.
    // (cursor = 이 컷 음성들의 끝 프레임 합. 끝에 짧은 여유 6프레임 추가)
    const timelineFrames = msToFrames(timed?.durationMs ?? 1800);
    const audioFloorFrames = cursor > 0 ? cursor + 6 : 0;

    cuts.push({
      imageUrl: toAbsolute(cut.imageUrl),
      durationInFrames: Math.max(timelineFrames, audioFloorFrames),
      transition: timed?.transition ?? 'hold',
      bubbles,
      audios
    });
  }

  return { fps: RENDER_FPS, width: RENDER_WIDTH, height: RENDER_HEIGHT, cuts };
}
