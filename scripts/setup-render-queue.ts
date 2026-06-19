/**
 * 렌더 큐용 Postgres 함수 claim_render_job() 을 생성한다.
 *
 * Supabase(Postgres) 네이티브 큐 패턴:
 *  - FOR UPDATE SKIP LOCKED 로 QUEUED 잡 1건을 원자적으로 잠그고 RUNNING으로 바꾼다.
 *  - 워커가 여러 대여도 같은 잡을 두 번 집지 않는다(중복 렌더 방지).
 *
 * 실행: npx tsx --env-file=.env scripts/setup-render-queue.ts
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient({
  datasourceUrl: process.env.DIRECT_URL ?? process.env.DATABASE_URL
});

const SQL = `
CREATE OR REPLACE FUNCTION claim_render_job()
RETURNS SETOF "RenderJob"
LANGUAGE sql
AS $$
  UPDATE "RenderJob"
  SET status = 'RUNNING', "updatedAt" = now()
  WHERE id = (
    SELECT id FROM "RenderJob"
    WHERE status = 'QUEUED'
    ORDER BY "createdAt" ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  )
  RETURNING *;
$$;
`;

async function main() {
  await prisma.$executeRawUnsafe(SQL);
  console.log('✓ claim_render_job() 생성 완료 (FOR UPDATE SKIP LOCKED 큐)');
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
