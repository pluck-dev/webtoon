import { NextResponse } from 'next/server';
import { z } from 'zod';

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

const patchSchema = z.object({
  isPublic: z.boolean()
});

// 공연 공개/비공개 토글 (본인 소유만)
export async function PATCH(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getRequiredDbUser();
  if (!user) {
    return NextResponse.json({ error: 'Login required' }, { status: 401 });
  }

  const parsed = patchSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: 'isPublic(boolean)가 필요합니다' }, { status: 400 });
  }

  const { id } = await params;
  const performance = await prisma.performance.findUnique({ where: { id } });
  if (!performance || performance.userId !== user.id) {
    return NextResponse.json({ error: 'Performance not found' }, { status: 404 });
  }

  const updated = await prisma.performance.update({
    where: { id },
    data: { isPublic: parsed.data.isPublic }
  });

  return NextResponse.json({ performance: { id: updated.id, isPublic: updated.isPublic } });
}
