import fs from 'node:fs/promises';
import path from 'node:path';
import { NextResponse } from 'next/server';
import { z } from 'zod';

import { generateWebtoonImage } from '@/lib/imagegen';

const schema = z.object({
  prompt: z.string().min(20),
  slug: z.string().min(2).regex(/^[a-z0-9-]+$/),
  referenceImages: z.array(z.string()).optional()
});

export async function POST(request: Request) {
  const parsed = schema.safeParse(await request.json());
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const generatedDir = path.join(process.cwd(), 'public', 'generated');
  await fs.mkdir(generatedDir, { recursive: true });

  const fileName = `${parsed.data.slug}-${Date.now()}.png`;
  const outputPath = path.join(generatedDir, fileName);
  await generateWebtoonImage({
    prompt: parsed.data.prompt,
    outputPath,
    referenceImages: parsed.data.referenceImages
  });

  return NextResponse.json({
    imageUrl: `/generated/${fileName}`,
    fileName
  });
}
