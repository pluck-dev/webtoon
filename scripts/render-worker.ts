/**
 * 렌더 워커 — QUEUED 렌더 잡을 집어 Remotion으로 MP4를 만들고 Storage에 올린다.
 *
 * Supabase(Postgres) 네이티브 큐:
 *  - claim_render_job() (FOR UPDATE SKIP LOCKED)로 잡을 원자적으로 획득한다.
 *  - 워커를 여러 개 띄우면 동시 렌더 처리량이 그만큼 늘어난다(중복 없이).
 *
 * 무겁고 오래 걸리는 작업이라 Next.js(서버리스) 밖에서 독립 프로세스로 돌린다.
 * 실행: npx tsx --env-file=.env scripts/render-worker.ts
 */
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import { bundle } from '@remotion/bundler';
import { renderMedia, selectComposition } from '@remotion/renderer';
import { PrismaClient, type RenderJob } from '@prisma/client';

import { buildRenderInput } from '../src/lib/render-input';
import { BUCKET_VIDEOS, uploadToBucket } from '../src/lib/supabase';

const prisma = new PrismaClient({
  datasourceUrl: process.env.DIRECT_URL ?? process.env.DATABASE_URL
});

const POLL_MS = 3000;

// 컴포지션 번들은 한 번만 만들고 재사용한다
let cachedServeUrl: string | undefined;
async function getServeUrl() {
  if (!cachedServeUrl) {
    console.log('컴포지션 번들링...');
    cachedServeUrl = await bundle({
      entryPoint: path.join(process.cwd(), 'src', 'remotion', 'index.ts'),
      webpackOverride: (config) => config
    });
  }
  return cachedServeUrl;
}

async function claimJob(): Promise<RenderJob | null> {
  const rows = await prisma.$queryRawUnsafe<RenderJob[]>('SELECT * FROM claim_render_job();');
  return rows[0] ?? null;
}

async function processJob(job: RenderJob) {
  console.log(`▶ 렌더 시작: job=${job.id} performance=${job.performanceId}`);
  await prisma.performance
    .update({ where: { id: job.performanceId }, data: { status: 'RENDERING' } })
    .catch(() => {});

  const outputPath = path.join(os.tmpdir(), `render-${job.id}.mp4`);
  try {
    const inputProps = await buildRenderInput(job.performanceId);
    const serveUrl = await getServeUrl();
    const composition = await selectComposition({ serveUrl, id: 'WebtoonShort', inputProps });

    await renderMedia({
      composition,
      serveUrl,
      codec: 'h264',
      outputLocation: outputPath,
      inputProps
    });

    const buffer = await fs.readFile(outputPath);
    const { storageKey } = await uploadToBucket({
      bucket: BUCKET_VIDEOS,
      key: `${job.performanceId}/${job.id}.mp4`,
      body: buffer,
      contentType: 'video/mp4'
    });

    const durationMs = Math.round((composition.durationInFrames / composition.fps) * 1000);
    await prisma.renderedVideo.create({
      data: {
        performanceId: job.performanceId,
        renderJobId: job.id,
        // private 버킷 경로 저장 — 재생은 서명 URL로
        videoUrl: storageKey,
        durationMs,
        width: composition.width,
        height: composition.height
      }
    });
    await prisma.renderJob.update({ where: { id: job.id }, data: { status: 'DONE' } });
    await prisma.performance
      .update({ where: { id: job.performanceId }, data: { status: 'RENDERED' } })
      .catch(() => {});

    console.log(`✓ 완료: job=${job.id} (${(durationMs / 1000).toFixed(1)}초)`);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await prisma.renderJob.update({ where: { id: job.id }, data: { status: 'FAILED', error: message } });
    await prisma.performance
      .update({ where: { id: job.performanceId }, data: { status: 'FAILED' } })
      .catch(() => {});
    console.error(`✗ 실패: job=${job.id}: ${message}`);
  } finally {
    await fs.unlink(outputPath).catch(() => {});
  }
}

async function loop() {
  console.log('렌더 워커 시작 — QUEUED 잡 폴링 중...');
  for (;;) {
    const job = await claimJob();
    if (!job) {
      await new Promise((resolve) => setTimeout(resolve, POLL_MS));
      continue;
    }
    await processJob(job);
  }
}

loop().catch((err) => {
  console.error(err);
  process.exit(1);
});
