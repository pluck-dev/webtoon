import Link from 'next/link';

import SiteHeader from '@/components/SiteHeader';

export default function NotFound() {
  return (
    <main className="market-shell">
      <SiteHeader />
      <div className="mx-auto w-full max-w-[1760px] px-4 py-4 sm:px-6 lg:px-10">

        <section className="grid min-h-[60vh] place-items-center py-16 text-center">
          <div className="max-w-md">
            <p className="mb-3 text-xs font-black uppercase tracking-wider text-coral">404</p>
            <h1 className="text-[clamp(36px,6vw,64px)] font-black leading-none tracking-tight text-ink">
              페이지를 찾을 수 없어요
            </h1>
            <p className="mt-5 leading-relaxed text-ink-soft">
              주소가 바뀌었거나 삭제된 에피소드일 수 있어요. 홈에서 다른 웹툰을 둘러보세요.
            </p>
            <div className="mt-8 flex flex-wrap justify-center gap-2.5">
              <Link
                href="/"
                className="inline-flex min-h-12 items-center rounded-full bg-ink px-6 text-[15px] font-black text-paper transition-transform hover:-translate-y-0.5"
              >
                홈으로 가기
              </Link>
              <Link
                href="/#collection"
                className="inline-flex min-h-12 items-center rounded-full border border-ink px-6 text-[15px] font-black text-ink transition-colors hover:bg-ink/5"
              >
                에피소드 보기
              </Link>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
