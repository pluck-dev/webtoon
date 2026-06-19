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
  const stylePrefix = ep.cuts[0].imgPrompt.split(' — ')[0];
  const names = ep.characters.map((c) => c.name);

  // 1) 캐릭터별 "단독" 레퍼런스 — 한 장에 한 캐릭터만(다른 캐릭터 섞지 않음) → 정체성 고정
  console.log('  · 캐릭터별 단독 레퍼런스 생성 중...');
  const charRef = new Map<string, string>(); // name -> dataUrl
  // Storage 키는 ASCII만 허용 → 캐릭터 인덱스 사용 (한글 이름 키 금지)
  for (const [i, c] of ep.characters.entries()) {
    const tmp = path.join(os.tmpdir(), `${ep.slug}-ref-${i}.png`);
    await provider.generateImage({
      prompt: `${stylePrefix} — single-character reference of ONE character ONLY: ${c.name}. ${c.description} Front-facing face plus upper body, plain neutral background, no other characters in frame, locked consistent design (face, hairstyle, outfit, colors).`,
      model: config.defaultModel,
      outputPath: tmp,
      size: '1024x1536'
    });
    charRef.set(c.name, toDataUrl(tmp));
    await uploadToBucket({ bucket: BUCKET_IMAGES, key: `${ep.slug}/_ref-${i}.png`, body: fs.readFileSync(tmp), contentType: 'image/png' });
    fs.unlinkSync(tmp);
    console.log(`    ✓ ref: ${c.name}`);
  }

  // 컷에 실제 등장하는 캐릭터 = 그 컷 대사 화자 + 캡션에 이름이 언급된 캐릭터 (없으면 주인공)
  const protagonist = names[0];
  function charsInCut(cut: Cut): string[] {
    // 대사 화자가 가장 신뢰도 높은 신호 → 우선. (캡션의 일반명사 오인 방지)
    const speakers = [...new Set(cut.dialogues.map((d) => d.speaker).filter((s) => names.includes(s)))];
    if (speakers.length) return speakers;
    // 화자 없는 나레이션 컷이면 캡션에 이름 언급된 캐릭터, 그것도 없으면 주인공
    const inCaption = names.filter((n) => cut.caption.includes(n));
    return inCaption.length ? inCaption : [protagonist];
  }

  // 2) 각 컷 — 등장 캐릭터의 단독 레퍼런스만 전달 + 정체성 명시 (동시 3개)
  const cutUrls = await pool(ep.cuts, CONCURRENCY, async (cut) => {
    const present = charsInCut(cut);
    const refs = present.map((n) => charRef.get(n)).filter(Boolean) as string[];
    const idLine = present.map((n, i) => `reference image ${i + 1} = the character "${n}"`).join('; ');
    // generic 일관성 규칙은 provider(CONSISTENCY_DIRECTIVE)에서 항시 적용됨.
    // 여기서는 이 컷에 등장하는 캐릭터 매핑만 명시한다.
    const lock = `Characters in THIS panel: ${idLine}. Draw ONLY the listed character(s) and match each one's reference image exactly. `;
    const tmp = path.join(os.tmpdir(), `${ep.slug}-${cut.order}.png`);
    const t = Date.now();
    await provider.generateImage({
      prompt: lock + cut.imgPrompt,
      model: config.defaultModel,
      outputPath: tmp,
      size: '1024x1536',
      images: refs
    });
    const buffer = fs.readFileSync(tmp);
    const { publicUrl } = await uploadToBucket({
      bucket: BUCKET_IMAGES,
      key: `${ep.slug}/cut-${String(cut.order).padStart(2, '0')}.png`,
      body: buffer,
      contentType: 'image/png'
    });
    fs.unlinkSync(tmp);
    console.log(`  ✓ CUT ${cut.order} [${present.join(',')}] (${((Date.now() - t) / 1000).toFixed(0)}s)`);
    return { order: cut.order, url: publicUrl };
  });
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
