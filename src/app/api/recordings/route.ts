import fs from 'node:fs/promises';
import path from 'node:path';
import { NextResponse } from 'next/server';

import { getRequiredDbUser } from '@/lib/clerk-user';
import { prisma } from '@/lib/prisma';

export async function POST(request: Request) {
  const user = await getRequiredDbUser();
  if (!user) {
    return NextResponse.json({ error: 'Login required' }, { status: 401 });
  }

  const formData = await request.formData();
  const performanceId = String(formData.get('performanceId') ?? '');
  const dialogueId = String(formData.get('dialogueId') ?? '');
  const durationMs = Number(formData.get('durationMs') ?? 0);
  const audio = formData.get('audio');

  if (!performanceId || !dialogueId || !durationMs || !(audio instanceof File)) {
    return NextResponse.json({ error: 'Missing recording fields' }, { status: 400 });
  }

  const performance = await prisma.performance.findFirst({
    where: { id: performanceId, userId: user.id }
  });

  if (!performance) {
    return NextResponse.json({ error: 'Performance not found' }, { status: 404 });
  }

  const dir = path.join(process.cwd(), 'public', 'recordings');
  await fs.mkdir(dir, { recursive: true });
  const fileName = `${performanceId}-${dialogueId}-${Date.now()}.webm`;
  const filePath = path.join(dir, fileName);
  await fs.writeFile(filePath, Buffer.from(await audio.arrayBuffer()));

  const takeNumber = await prisma.recording.count({
    where: { performanceId, dialogueId, userId: user.id }
  });

  const recording = await prisma.recording.create({
    data: {
      performanceId,
      dialogueId,
      userId: user.id,
      durationMs,
      audioUrl: `/recordings/${fileName}`,
      storageKey: fileName,
      takeNumber: takeNumber + 1
    }
  });

  return NextResponse.json({ recording });
}
