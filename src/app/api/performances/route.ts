import { NextResponse } from 'next/server';
import { z } from 'zod';

import { getRequiredDbUser } from '@/lib/clerk-user';
import { prisma } from '@/lib/prisma';

const schema = z.object({
  episodeId: z.string().min(1)
});

export async function GET(request: Request) {
  const user = await getRequiredDbUser();
  if (!user) {
    return NextResponse.json({ error: 'Login required' }, { status: 401 });
  }

  const { searchParams } = new URL(request.url);
  const episodeId = searchParams.get('episodeId');
  if (!episodeId) {
    return NextResponse.json({ error: 'episodeId is required' }, { status: 400 });
  }

  const performance = await prisma.performance.findFirst({
    where: { episodeId, userId: user.id },
    orderBy: { updatedAt: 'desc' },
    include: {
      recordings: { orderBy: { createdAt: 'desc' } }
    }
  });

  if (!performance) {
    return NextResponse.json({ performance: null, recordings: [] });
  }

  const latestByDialogue = new Map<string, (typeof performance.recordings)[number]>();
  for (const recording of performance.recordings) {
    if (!latestByDialogue.has(recording.dialogueId)) latestByDialogue.set(recording.dialogueId, recording);
  }

  return NextResponse.json({
    performance,
    recordings: Array.from(latestByDialogue.values())
  });
}

export async function POST(request: Request) {
  const user = await getRequiredDbUser();
  if (!user) {
    return NextResponse.json({ error: 'Login required' }, { status: 401 });
  }

  const parsed = schema.safeParse(await request.json());
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const existing = await prisma.performance.findFirst({
    where: {
      episodeId: parsed.data.episodeId,
      userId: user.id
    },
    orderBy: { updatedAt: 'desc' }
  });

  if (existing) {
    return NextResponse.json({ user, performance: existing });
  }

  const performance = await prisma.performance.create({
    data: {
      episodeId: parsed.data.episodeId,
      userId: user.id,
      title: `${user.displayName} voice version`
    }
  });

  return NextResponse.json({ user, performance });
}
