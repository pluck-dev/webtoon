/**
 * 모든 public 테이블에 RLS(Row Level Security)를 활성화한다.
 *
 * 배경:
 *  - Supabase advisor가 9개 테이블 RLS 비활성화를 critical 경고로 보고했다.
 *  - 이 앱은 DB 접근을 전부 Prisma(테이블 소유자 = postgres 역할)로만 한다.
 *    테이블 소유자는 자기 테이블 RLS의 적용을 받지 않으므로(FORCE 미설정),
 *    RLS를 켜도 앱 동작은 그대로다.
 *  - 정책을 추가하지 않으면 anon / authenticated 역할(= supabase 공개 키)은
 *    모든 행 접근이 차단된다. 이게 우리가 원하는 보안 상태다.
 *
 * 실행: npx tsx --env-file=.env scripts/setup-rls.ts
 */
import { PrismaClient } from '@prisma/client';

const TABLES = [
  'User',
  'Episode',
  'Character',
  'Cut',
  'Dialogue',
  'Performance',
  'Recording',
  'RenderJob',
  'RenderedVideo'
];

const prisma = new PrismaClient({
  // 마이그레이션/DDL은 풀러(6543)가 아닌 직접 연결(5432)을 사용한다
  datasourceUrl: process.env.DIRECT_URL ?? process.env.DATABASE_URL
});

async function main() {
  for (const table of TABLES) {
    await prisma.$executeRawUnsafe(
      `ALTER TABLE public."${table}" ENABLE ROW LEVEL SECURITY;`
    );
    console.log(`✓ RLS 활성화: public.${table}`);
  }
  console.log('완료: 모든 테이블 RLS 활성화 (anon/authenticated 직접 접근 차단, Prisma 접근 유지)');
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
