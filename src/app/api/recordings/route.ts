import fs from 'node:fs/promises';
import path from 'node:path';
import { NextResponse } from 'next/server';

import { prisma } from '@/lib/prisma';

export async function POST(request: Request) {
  const formData = await request.formData();
  const performanceId = String(formData.get('performanceId') ?? '');
  const dialogueId = String(formData.get('dialogueId') ?? '');
  const userId = String(formData.get('userId') ?? '');
  const durationMs = Number(formData.get('durationMs') ?? 0);
  const audio = formData.get('audio');

  if (!performanceId || !dialogueId || !userId || !durationMs || !(audio instanceof File)) {
    return NextResponse.json({ error: 'Missing recording fields' }, { status: 400 });
  }

  const dir = path.join(process.cwd(), 'public', 'recordings');
  await fs.mkdir(dir, { recursive: true });
  const fileName = `${performanceId}-${dialogueId}-${Date.now()}.webm`;
  const filePath = path.join(dir, fileName);
  await fs.writeFile(filePath, Buffer.from(await audio.arrayBuffer()));

  const takeNumber = await prisma.recording.count({
    where: { performanceId, dialogueId, userId }
  });

  const recording = await prisma.recording.create({
    data: {
      performanceId,
      dialogueId,
      userId,
      durationMs,
      audioUrl: `/recordings/${fileName}`,
      storageKey: fileName,
      takeNumber: takeNumber + 1
    }
  });

  return NextResponse.json({ recording });
}
