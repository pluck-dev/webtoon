import fs from 'node:fs/promises';
import path from 'node:path';

import { resolveConfig } from '@/server/imagegen/config.js';
import { createPrivateCodexProvider } from '@/server/imagegen/providers/privateCodexProvider.js';

type GenerateImageInput = {
  prompt: string;
  outputPath: string;
  referenceImages?: string[];
};

const EXT_TO_MIME: Record<string, string> = {
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  gif: 'image/gif',
  webp: 'image/webp'
};

export async function generateWebtoonImage({ prompt, outputPath, referenceImages = [] }: GenerateImageInput) {
  const config = resolveConfig({
    provider: 'private-codex'
  });
  const provider = createPrivateCodexProvider(config);
  const images = referenceImages.length > 0
    ? await Promise.all(referenceImages.map((imagePath) => readImageAsDataUrl(imagePath)))
    : undefined;

  return provider.generateImage({
    prompt,
    model: config.defaultModel,
    outputPath,
    debug: true,
    debugDir: path.join(process.cwd(), '.imagegen-debug'),
    images,
    size: '1024x1536'
  });
}

async function readImageAsDataUrl(imagePath: string) {
  const resolved = path.resolve(imagePath);
  const ext = path.extname(resolved).toLowerCase().replace(/^\./, '');
  const mime = EXT_TO_MIME[ext];
  if (!mime) {
    throw new Error(`Unsupported reference image type: ${ext}`);
  }

  const buffer = await fs.readFile(resolved);
  return `data:${mime};base64,${buffer.toString('base64')}`;
}
