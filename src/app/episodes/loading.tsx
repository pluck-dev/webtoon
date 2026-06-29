import SiteHeader from '@/components/SiteHeader';

export default function EpisodesLoading() {
  return (
    <main className="market-shell">
      <SiteHeader />
      <div className="mx-auto w-full max-w-[1760px] px-4 py-10 sm:px-6 lg:px-10">
        <section className="pb-8 pt-10">
          <div className="h-9 w-44 animate-pulse rounded-full bg-line-soft" />
          <div className="mt-6 h-20 max-w-3xl animate-pulse rounded-2xl bg-line-soft" />
          <div className="mt-5 h-6 max-w-xl animate-pulse rounded-full bg-line-soft" />
        </section>
        <section className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4" aria-label="작품 목록 로딩 중">
          {Array.from({ length: 8 }).map((_, index) => (
            <div key={index} className="overflow-hidden rounded-2xl border border-line bg-card">
              <div className="aspect-[4/5] animate-pulse bg-line-soft" />
              <div className="space-y-3 p-4">
                <div className="h-4 w-20 animate-pulse rounded-full bg-line-soft" />
                <div className="h-7 w-3/4 animate-pulse rounded-full bg-line-soft" />
                <div className="h-4 w-full animate-pulse rounded-full bg-line-soft" />
              </div>
            </div>
          ))}
        </section>
      </div>
    </main>
  );
}
