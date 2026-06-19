/**
 * 모든 밈 에피소드를 순차로 생성+seed 한다 (한 편 실패해도 계속).
 * 각 에피소드는 seed-meme-episode.ts를 별도 프로세스로 실행 → 인자 분리 안전.
 *
 * 실행: npx tsx scripts/batch-all.ts
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

type Ep = { slug: string };
const eps: Ep[] = JSON.parse(fs.readFileSync('./prisma/data/meme-episodes.json', 'utf8'));
const slugs = eps.map((e) => e.slug);

let ok = 0;
const failed: string[] = [];

for (let i = 0; i < slugs.length; i++) {
  const slug = slugs[i];
  console.log(`\n=== [${i + 1}/${slugs.length}] ${slug} ===`);
  try {
    execFileSync('npx', ['tsx', '--env-file=.env', 'scripts/seed-meme-episode.ts', slug], {
      stdio: 'inherit'
    });
    ok++;
  } catch {
    console.log(`!!! FAILED: ${slug}`);
    failed.push(slug);
  }
}

console.log(`\n=== BATCH DONE: 성공 ${ok}/${slugs.length}, 실패 ${failed.length} ${failed.length ? `(${failed.join(', ')})` : ''} ===`);
