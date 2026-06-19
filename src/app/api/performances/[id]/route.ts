import { NextResponse } from 'next/server';

import { getRequiredDbUser } from '@/lib/clerk-user';
import { prisma } from '@/lib/prisma';
import { BUCKET_RECORDINGS, createSignedUrl } from '@/lib/supabase';

export async function GET(_: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getRequiredDbUser();
  if (!user) {
    return NextResponse.json({ error: 'Login required' }, { status: 401 });
  }

  const { id } = await params;
  const performance = await prisma.performance.findUnique({
    where: { id, userId: user.id },
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

  // 본인(userId) 소유 공연만 조회되므로, 비공개 녹음을 임시 서명 URL로 발급한다
  const recordings = await Promise.all(
    Array.from(latestByDialogue.values()).map(async (recording) => ({
      ...recording,
      audioUrl: await createSignedUrl(BUCKET_RECORDINGS, recording.storageKey)
    }))
  );

  return NextResponse.json({
    performance,
    user: performance.user,
    recordings
  });
}
