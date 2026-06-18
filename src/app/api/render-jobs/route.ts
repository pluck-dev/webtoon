import { NextResponse } from 'next/server';
import { z } from 'zod';

import { getRequiredDbUser } from '@/lib/clerk-user';
import { prisma } from '@/lib/prisma';
import { buildHyperlapseTimeline } from '@/lib/timeline';

const schema = z.object({
  performanceId: z.string().min(1)
});

export async function POST(request: Request) {
  const user = await getRequiredDbUser();
  if (!user) {
    return NextResponse.json({ error: 'Login required' }, { status: 401 });
  }

  const parsed = schema.safeParse(await request.json());
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const performance = await prisma.performance.findUnique({
    where: { id: parsed.data.performanceId },
    include: {
      episode: {
        include: {
          cuts: {
            orderBy: { order: 'asc' },
            include: {
              dialogues: {
                include: {
                  recordings: {
                    where: { performanceId: parsed.data.performanceId },
                    orderBy: { createdAt: 'desc' },
                    take: 1
                  }
                }
              }
            }
          }
        }
      }
    }
  });

  if (!performance) {
    return NextResponse.json({ error: 'Performance not found' }, { status: 404 });
  }

  if (performance.userId !== user.id) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  const timeline = buildHyperlapseTimeline(performance.episode.cuts, performance.episode.maxSeconds);
  const job = await prisma.renderJob.create({
    data: {
      performanceId: performance.id,
      timeline
    }
  });

  await prisma.performance.update({
    where: { id: performance.id },
    data: { status: 'READY' }
  });

  return NextResponse.json({ job, timeline });
}
