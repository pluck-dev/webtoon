import { NextResponse } from 'next/server';

import { prisma } from '@/lib/prisma';

export async function GET(_: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const performance = await prisma.performance.findUnique({
    where: { id },
    include: {
      user: true,
      recordings: {
        orderBy: { createdAt: 'desc' }
      }
    }
  });

  if (!performance) {
    return NextResponse.json({ error: 'Performance not found' }, { status: 404 });
  }

  const latestByDialogue = new Map<string, (typeof performance.recordings)[number]>();
  for (const recording of performance.recordings) {
    if (!latestByDialogue.has(recording.dialogueId)) {
      latestByDialogue.set(recording.dialogueId, recording);
    }
  }

  return NextResponse.json({
    performance,
    user: performance.user,
    recordings: Array.from(latestByDialogue.values())
  });
}
