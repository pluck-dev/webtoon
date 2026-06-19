import Link from 'next/link';

const businessInfo: { label: string; value: string; href?: string }[] = [
  { label: '상호', value: '플럭 (Pluck)' },
  { label: '대표', value: '심재형' },
  { label: '사업자등록번호', value: '709-19-02368' },
  { label: '이메일', value: 'admin@pluck.co.kr', href: 'mailto:admin@pluck.co.kr' }
];

export default function SiteFooter() {
  return (
    <footer className="mt-14 grid gap-6 rounded-2xl border border-line bg-card px-7 py-8">
      <div className="flex flex-wrap items-center justify-between gap-x-6 gap-y-4">
        <Link href="/" className="flex items-center gap-3">
          <span className="grid h-8 w-8 place-items-center rounded-[10px] bg-ink text-base font-black text-gold">
            W
          </span>
          <span className="grid">
            <strong className="text-base">Webtoon Voice Studio</strong>
            <span className="text-[13px] text-muted">One original webtoon, endless actor versions.</span>
          </span>
        </Link>
        <nav className="flex flex-wrap justify-end gap-2" aria-label="Footer navigation">
          <a
            href="/#collection"
            className="rounded-full border border-line px-3.5 py-2 text-[13px] font-extrabold transition-colors hover:bg-ink/5"
          >
            Episodes
          </a>
          <Link
            href="/admin"
            className="rounded-full border border-line px-3.5 py-2 text-[13px] font-extrabold transition-colors hover:bg-ink/5"
          >
            Admin
          </Link>
          <Link
            href="/terms"
            className="rounded-full border border-line px-3.5 py-2 text-[13px] font-extrabold transition-colors hover:bg-ink/5"
          >
            이용약관
          </Link>
          <Link
            href="/privacy"
            className="rounded-full border border-ink px-3.5 py-2 text-[13px] font-extrabold transition-colors hover:bg-ink/5"
          >
            개인정보처리방침
          </Link>
        </nav>
      </div>

      {/* 사업자 정보 (전자상거래법 표시) */}
      <dl className="grid grid-cols-[repeat(auto-fit,minmax(180px,1fr))] gap-x-7 gap-y-3.5 border-y border-line-soft py-5">
        {businessInfo.map((item) => (
          <div className="grid gap-1" key={item.label}>
            <dt className="text-[11px] font-black uppercase tracking-wider text-faint">{item.label}</dt>
            <dd className="text-sm font-bold text-ink-soft">
              {item.href ? (
                <a className="border-b border-transparent transition-colors hover:border-ink-soft" href={item.href}>
                  {item.value}
                </a>
              ) : (
                item.value
              )}
            </dd>
          </div>
        ))}
      </dl>

      <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-2.5">
        <p className="text-xs font-bold text-faint">© 2026 플럭 (Pluck). All rights reserved.</p>
        <nav className="inline-flex items-center gap-2.5 text-[13px] text-faint" aria-label="Legal">
          <Link className="font-extrabold text-ink-soft transition-colors hover:text-ink" href="/terms">
            이용약관
          </Link>
          <span aria-hidden="true">·</span>
          <Link className="font-extrabold text-ink-soft transition-colors hover:text-ink" href="/privacy">
            개인정보처리방침
          </Link>
        </nav>
      </div>
    </footer>
  );
}
