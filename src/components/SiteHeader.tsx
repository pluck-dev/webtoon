import Link from 'next/link';

import AuthNav from '@/components/AuthNav';

const navLinkClass =
  'inline-flex min-h-[38px] items-center rounded-full border border-line bg-paper/70 px-3.5 text-[13px] font-extrabold text-ink transition-colors hover:bg-ink/5';

export default function SiteHeader() {
  return (
    <header className="sticky top-0 z-10 grid min-h-16 grid-cols-[1fr_auto] items-center gap-4 border-b border-line bg-cream/85 backdrop-blur-md md:grid-cols-[minmax(160px,1fr)_auto_minmax(160px,1fr)]">
      <Link href="/" className="inline-flex items-center gap-2.5 text-xl font-black text-ink">
        <span className="grid h-[30px] w-[30px] place-items-center rounded-[9px] bg-ink text-base font-black text-gold">
          W
        </span>
        <span className="whitespace-nowrap">Webtoon Voice Studio</span>
      </Link>
      <nav
        className="order-3 col-span-2 flex items-center gap-1.5 overflow-x-auto md:order-none md:col-span-1 md:justify-center"
        aria-label="Main navigation"
      >
        <Link href="/" className={navLinkClass}>
          Episodes
        </Link>
        <a href="/#collection" className={navLinkClass}>
          Collection
        </a>
        <Link href="/mypage" className={navLinkClass}>
          마이페이지
        </Link>
        <Link href="/admin" className={navLinkClass}>
          Admin
        </Link>
      </nav>
      <div className="flex items-center justify-end">
        <AuthNav />
      </div>
    </header>
  );
}
