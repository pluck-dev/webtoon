import { NextResponse } from 'next/server';
import { z } from 'zod';

import { prisma } from '@/lib/prisma';

const schema = z.object({
  episodeId: z.string().min(1),
  handle: z.string().min(2).regex(/^[a-zA-Z0-9_-]+$/),
  displayName: z.string().min(1)
});

export async function POST(request: Request) {
  const parsed = schema.safeParse(await request.json());
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const user = await prisma.user.upsert({
    where: { handle: parsed.data.handle },
    update: { displayName: parsed.data.displayName },
    create: {
      handle: parsed.data.handle,
      displayName: parsed.data.displayName
    }
  });

  const performance = await prisma.performance.create({
    data: {
      episodeId: parsed.data.episodeId,
      userId: user.id,
      title: `${parsed.data.displayName}님의 더빙 버전`
    }
  });

  return NextResponse.json({ user, performance });
}
