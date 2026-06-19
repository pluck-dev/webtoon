import { NextResponse } from 'next/server';

import { getRequiredDbUser } from '@/lib/clerk-user';
import { prisma } from '@/lib/prisma';
import { BUCKET_RECORDINGS, uploadToBucket } from '@/lib/supabase';

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

  const takeNumber = await prisma.recording.count({
    where: { performanceId, dialogueId, userId: user.id }
  });

  // 녹음 음성을 비공개 Supabase Storage 버킷에 업로드한다.
  // 버킷이 private이므로 공개 URL은 저장하지 않고, storageKey(경로)만 저장한다.
  // 실제 재생 URL은 조회 시 본인 확인 후 서명 URL로 발급한다.
  const fileName = `${performanceId}-${dialogueId}-${Date.now()}.webm`;
  // Supabase Storage 버킷은 코덱 파라미터가 붙은 MIME(예: audio/webm;codecs=opus)을
  // 거부하므로 기본 타입만 추출해 전달한다 (파일 바이트는 그대로라 재생 영향 없음).
  const baseContentType = (audio.type || 'audio/webm').split(';')[0].trim() || 'audio/webm';
  const { storageKey } = await uploadToBucket({
    bucket: BUCKET_RECORDINGS,
    key: `${performanceId}/${fileName}`,
    body: await audio.arrayBuffer(),
    contentType: baseContentType
  });

  const recording = await prisma.recording.create({
    data: {
      performanceId,
      dialogueId,
      userId: user.id,
      durationMs,
      // audioUrl에는 직접 재생 가능한 URL 대신 storage 경로를 보관한다
      audioUrl: storageKey,
      storageKey,
      takeNumber: takeNumber + 1
    }
  });

  return NextResponse.json({ recording });
}
