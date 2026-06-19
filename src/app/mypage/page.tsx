import type { Metadata } from 'next';
import Link from 'next/link';
import { SignInButton } from '@clerk/nextjs';

import MyPerformanceCard from '@/components/MyPerformanceCard';
import SiteHeader from '@/components/SiteHeader';
import { getRequiredDbUser } from '@/lib/clerk-user';
import { getMyPerformances } from '@/lib/my-performances';

export const metadata: Metadata = {
  title: '마이페이지 · Webtoon Voice Studio'
};

export default async function MyPage() {
  const user = await getRequiredDbUser();
  const performances = user ? await getMyPerformances(user.id) : [];

  return (
    <main className="market-shell">
      <SiteHeader />
      <div className="mx-auto w-full max-w-[1760px] px-4 py-4 sm:px-6 lg:px-10">

        <section className="py-10">
        <h1 className="text-3xl font-black text-ink">마이페이지</h1>
        <p className="mt-2 text-muted">
          {user
            ? `${user.displayName} 님의 녹음 공연과 생성한 영상입니다.`
            : '로그인하면 내 녹음 공연과 생성한 영상을 모아볼 수 있습니다.'}
        </p>
      </section>

      {!user ? (
        <section className="rounded-2xl border border-line bg-card p-10 text-center">
          <p className="mb-4 font-bold text-ink">로그인이 필요합니다.</p>
          <SignInButton mode="modal">
            <button type="button" className="rounded-lg bg-ink px-5 py-2.5 font-black text-paper">
              로그인
            </button>
          </SignInButton>
        </section>
      ) : performances.length === 0 ? (
        <section className="rounded-2xl border border-dashed border-line bg-card p-10 text-center">
          <p className="mb-2 text-lg font-black text-ink">아직 녹음한 공연이 없습니다.</p>
          <p className="mb-5 text-muted">에피소드를 골라 첫 녹음을 시작해보세요.</p>
          <Link href="/" className="inline-block rounded-lg bg-ink px-5 py-2.5 font-black text-paper">
            에피소드 보러가기
          </Link>
        </section>
      ) : (
        <section className="grid gap-5 pb-16 sm:grid-cols-2">
          {performances.map((performance) => (
            <MyPerformanceCard key={performance.id} performance={performance} />
          ))}
        </section>
      )}
      </div>
    </main>
  );
}
