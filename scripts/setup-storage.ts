/**
 * Supabase Storage 버킷을 생성한다 (멱등).
 * MCP가 read-only라 버킷 생성은 secret key로 직접 호출한다.
 *
 * 실행: npx tsx --env-file=.env scripts/setup-storage.ts
 */
import { createClient } from '@supabase/supabase-js';

import { BUCKET_IMAGES, BUCKET_RECORDINGS, BUCKET_VIDEOS } from '../src/lib/supabase';

const url = process.env.SUPABASE_URL;
const secret = process.env.SUPABASE_SECRET_KEY;

if (!url || !secret) {
  throw new Error('SUPABASE_URL / SUPABASE_SECRET_KEY 가 필요합니다 (.env 확인)');
}

const supabase = createClient(url, secret, {
  auth: { persistSession: false, autoRefreshToken: false }
});

const BUCKETS = [
  // 웹툰 컷 이미지: 공개 읽기, 이미지 타입만 허용
  {
    id: BUCKET_IMAGES,
    public: true,
    allowedMimeTypes: ['image/png', 'image/jpeg', 'image/webp', 'image/gif'],
    fileSizeLimit: '10MB'
  },
  // 녹음 음성: 비공개(본인만 듣기) — 재생은 서버 발급 서명 URL로만 가능
  {
    id: BUCKET_RECORDINGS,
    public: false,
    allowedMimeTypes: ['audio/webm', 'audio/mpeg', 'audio/mp4', 'audio/ogg', 'audio/wav'],
    fileSizeLimit: '25MB'
  },
  // 렌더된 영상: 비공개(음성 포함) — 재생/다운로드는 서명 URL로만
  {
    id: BUCKET_VIDEOS,
    public: false,
    allowedMimeTypes: ['video/mp4'],
    // 프로젝트 글로벌 Storage 한도(50MB)에 맞춘다. 1분 세로 영상은 충분히 들어감.
    fileSizeLimit: '50MB'
  }
] as const;

async function main() {
  for (const cfg of BUCKETS) {
    const { error } = await supabase.storage.createBucket(cfg.id, {
      public: cfg.public,
      allowedMimeTypes: [...cfg.allowedMimeTypes],
      fileSizeLimit: cfg.fileSizeLimit
    });

    if (error) {
      // 이미 존재하면 설정만 갱신한다
      if (error.message.toLowerCase().includes('already exists')) {
        await supabase.storage.updateBucket(cfg.id, {
          public: cfg.public,
          allowedMimeTypes: [...cfg.allowedMimeTypes],
          fileSizeLimit: cfg.fileSizeLimit
        });
        console.log(`✓ 버킷 갱신: ${cfg.id}`);
      } else {
        throw new Error(`버킷 생성 실패 (${cfg.id}): ${error.message}`);
      }
    } else {
      console.log(`✓ 버킷 생성: ${cfg.id}`);
    }
  }

  const { data } = await supabase.storage.listBuckets();
  console.log('현재 버킷:', data?.map((b) => `${b.name}(public=${b.public})`).join(', '));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
