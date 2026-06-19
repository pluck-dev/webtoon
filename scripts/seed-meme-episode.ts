/**
 * 밈 에피소드 1편을 풀 파이프라인으로 처리한다:
 * 컷 이미지 생성(private-codex) → Supabase Storage 업로드 → DB seed.
 *
 * 실행: npx tsx --env-file=.env scripts/seed-meme-episode.ts [slug] [--draft]
 *   slug 생략 시 meme-episodes.json 첫 에피소드.
 *   --draft 주면 DRAFT(홈 비노출), 기본은 PUBLISHED.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { PrismaClient } from '@prisma/client';

import { resolveConfig } from '../src/server/imagegen/config.js';
import { createPrivateCodexProvider } from '../src/server/imagegen/providers/privateCodexProvider.js';
import { BUCKET_IMAGES, uploadToBucket } from '../src/lib/supabase';

const prisma = new PrismaClient({ datasourceUrl: process.env.DIRECT_URL ?? process.env.DATABASE_URL });

const CONCURRENCY = 3;

type Cut = { order: number; caption: string; imgPrompt: string; dialogues: { speaker: string; text: string; direction: string }[] };
type Episode = {
  slug: string; title: string; category: string; genre: string; logline: string; maxSeconds: number;
  characters: { name: string; description: string; voiceGuide: string; color: string }[];
  cuts: Cut[];
};

async function pool<T, R>(items: T[], limit: number, fn: (item: T, i: number) => Promise<R>): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let cursor = 0;
  async function worker() {
    for (;;) {
      const i = cursor++;
      if (i >= items.length) return;
      results[i] = await fn(items[i], i);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

async function main() {
  const args = process.argv.slice(2);
  const draft = args.includes('--draft');
  const slugArg = args.find((a) => !a.startsWith('--'));

  const episodes: Episode[] = JSON.parse(fs.readFileSync('./prisma/data/meme-episodes.json', 'utf8'));
  const ep = slugArg ? episodes.find((e) => e.slug === slugArg) : episodes[0];
  if (!ep) throw new Error(`에피소드 못 찾음: ${slugArg}`);

  console.log(`▶ ${ep.title} (${ep.slug}) — ${ep.cuts.length}컷 이미지 생성 시작`);
  const config = resolveConfig({ provider: 'private-codex' });
  const provider = createPrivateCodexProvider(config);

  const toDataUrl = (p: string) => `data:image/png;base64,${fs.readFileSync(p).toString('base64')}`;

  // 화풍 프리픽스 추출(컷 프롬프트는 "<style> — <scene>" 형식)
  const stylePrefix = ep.cuts[0].imgPrompt.split(' — ')[0];
  const charLine = ep.characters.map((c) => `${c.name} (${c.description.split('.')[0]})`).join('; ');

  // 1) 캐릭터/화풍 앵커 1장 — 이후 모든 컷의 일관성 기준
  console.log('  · 캐릭터/화풍 앵커 생성 중...');
  const anchorTmp = path.join(os.tmpdir(), `${ep.slug}-anchor.png`);
  await provider.generateImage({
    prompt: `${stylePrefix} — character reference sheet / model sheet, full body and face close-up of ${ep.characters.length} distinct Korean characters: ${charLine}. neutral poses and expressions, clean plain background, locked consistent character design (faces, hairstyles, outfits, colors)`,
    model: config.defaultModel,
    outputPath: anchorTmp,
    size: '1024x1536'
  });
  const anchorDataUrl = toDataUrl(anchorTmp);
  // 앵커도 Storage에 보관(레퍼런스/재생성용)
  await uploadToBucket({ bucket: BUCKET_IMAGES, key: `${ep.slug}/_anchor.png`, body: fs.readFileSync(anchorTmp), contentType: 'image/png' });
  console.log('  ✓ 앵커 완료 — 이제 모든 컷을 이 캐릭터/화풍으로 고정');

  const CONSISTENCY = 'CRITICAL: keep the EXACT same art style and the SAME character designs (same faces, hairstyles, outfits, colors, proportions) as the reference image across every panel. Do not redesign the characters. ';

  // 2) 각 컷 — 앵커를 레퍼런스로 참조해 일관성 유지하며 생성 (동시 3개)
  const cutUrls = await pool(ep.cuts, CONCURRENCY, async (cut) => {
    const tmp = path.join(os.tmpdir(), `${ep.slug}-${cut.order}.png`);
    const t = Date.now();
    await provider.generateImage({
      prompt: CONSISTENCY + cut.imgPrompt,
      model: config.defaultModel,
      outputPath: tmp,
      size: '1024x1536',
      images: [anchorDataUrl]
    });
    const buffer = fs.readFileSync(tmp);
    const { publicUrl } = await uploadToBucket({
      bucket: BUCKET_IMAGES,
      key: `${ep.slug}/cut-${String(cut.order).padStart(2, '0')}.png`,
      body: buffer,
      contentType: 'image/png'
    });
    fs.unlinkSync(tmp);
    console.log(`  ✓ CUT ${cut.order} (${((Date.now() - t) / 1000).toFixed(0)}s)`);
    return { order: cut.order, url: publicUrl };
  });
  fs.unlinkSync(anchorTmp);
  const urlByOrder = new Map(cutUrls.map((c) => [c.order, c.url]));

  // 재실행 가능하게 기존 동일 slug 삭제(cascade)
  await prisma.episode.deleteMany({ where: { slug: ep.slug } });

  // seed
  const created = await prisma.episode.create({
    data: {
      slug: ep.slug,
      title: ep.title,
      logline: ep.logline,
      status: draft ? 'DRAFT' : 'PUBLISHED',
      category: ep.category as 'WEBTOON' | 'ROLEPLAY' | 'ANIMATION',
      maxSeconds: ep.maxSeconds ?? 55,
      thumbnailUrl: urlByOrder.get(ep.cuts[0].order) ?? null,
      characters: {
        create: ep.characters.map((c) => ({
          name: c.name, description: c.description, voiceGuide: c.voiceGuide, color: c.color
        }))
      }
    },
    include: { characters: true }
  });

  const charIdByName = new Map(created.characters.map((c) => [c.name, c.id]));

  for (const cut of ep.cuts) {
    await prisma.cut.create({
      data: {
        episodeId: created.id,
        order: cut.order,
        imageUrl: urlByOrder.get(cut.order)!,
        caption: cut.caption,
        imagePrompt: cut.imgPrompt,
        dialogues: {
          create: cut.dialogues.map((d, i) => ({
            order: i + 1,
            text: d.text,
            direction: d.direction,
            characterId: charIdByName.get(d.speaker) ?? null
          }))
        }
      }
    });
  }

  console.log(`✓ seed 완료: ${ep.title} (${draft ? 'DRAFT' : 'PUBLISHED'}) — /episodes/${ep.slug}`);
}

main()
  .catch((err) => {
    console.error('실패:', err?.message || err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
