import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { NextResponse } from 'next/server';
import { z } from 'zod';

import { getRequiredDbUser } from '@/lib/clerk-user';
import { generateWebtoonImage } from '@/lib/imagegen';
import { BUCKET_IMAGES, uploadToBucket } from '@/lib/supabase';

const schema = z.object({
  prompt: z.string().min(20),
  slug: z.string().min(2).regex(/^[a-z0-9-]+$/),
  referenceImages: z.array(z.string()).optional()
});

export async function POST(request: Request) {
  const user = await getRequiredDbUser();
  if (!user) {
    return NextResponse.json({ error: 'Login required' }, { status: 401 });
  }
  if (user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Admin only' }, { status: 403 });
  }

  const parsed = schema.safeParse(await request.json());
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  // 이미지 생성기는 디스크 경로로 출력하므로 임시 디렉터리에 먼저 쓴 뒤 Storage로 업로드한다
  const fileName = `${parsed.data.slug}-${Date.now()}.png`;
  const tmpPath = path.join(os.tmpdir(), fileName);

  try {
    await generateWebtoonImage({
      prompt: parsed.data.prompt,
      outputPath: tmpPath,
      referenceImages: parsed.data.referenceImages
    });

    const buffer = await fs.readFile(tmpPath);
    const { publicUrl, storageKey } = await uploadToBucket({
      bucket: BUCKET_IMAGES,
      key: `${parsed.data.slug}/${fileName}`,
      body: buffer,
      contentType: 'image/png'
    });

    return NextResponse.json({ imageUrl: publicUrl, fileName, storageKey });
  } finally {
    // 임시 파일 정리 (실패해도 무시)
    await fs.unlink(tmpPath).catch(() => {});
  }
}
