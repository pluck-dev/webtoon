import { NextResponse } from 'next/server';

import { getRequiredDbUser } from '@/lib/clerk-user';
import { getMyPerformances } from '@/lib/my-performances';

// 마이페이지 데이터 — 본인 공연 목록 + 진행률 + 렌더 상태/영상
export async function GET() {
  const user = await getRequiredDbUser();
  if (!user) {
    return NextResponse.json({ error: 'Login required' }, { status: 401 });
  }

  const performances = await getMyPerformances(user.id);
  return NextResponse.json({ performances });
}
