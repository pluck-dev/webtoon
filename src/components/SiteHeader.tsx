'use client';

import Link from 'next/link';
import { useState } from 'react';

const navLinks = [
  { href: '/', label: '소개' },
  { href: '/episodes', label: '갤러리' },
  { href: '/guidelines', label: '사용법' }
] as const;

const navLinkClass =
  'rounded-full px-4 py-2 text-sm font-extrabold text-ink-soft transition-colors hover:bg-ink/5 hover:text-ink';

export default function SiteHeader() {
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-3 z-30 px-3 sm:px-5 lg:px-8">
      <div className="mx-auto w-full max-w-[1180px]">
        <div className="flex min-h-[58px] items-center justify-between gap-3 rounded-full border border-line/70 bg-paper/78 px-3.5 shadow-[0_14px_44px_rgba(23,21,18,.10)] backdrop-blur-xl sm:px-5">
          <Link href="/" className="inline-flex min-w-0 items-center gap-2.5 text-ink" aria-label="더빙고 홈">
            <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-ink text-sm font-black text-gold shadow-[inset_0_0_0_1px_rgba(255,255,255,.12)]">
              더
            </span>
            <span className="grid min-w-0 leading-none">
              <strong className="text-[17px] font-black tracking-[-0.02em]">더빙고</strong>
              <span className="mt-1 hidden text-[10px] font-black uppercase tracking-[0.16em] text-muted sm:block">
                Voice Webtoon
              </span>
            </span>
          </Link>

          <nav className="hidden items-center rounded-full bg-cream/65 p-1 md:flex" aria-label="Main navigation">
            {navLinks.map((link) => (
              <Link key={link.href} href={link.href} className={navLinkClass}>
                {link.label}
              </Link>
            ))}
          </nav>

          <div className="flex items-center gap-2">
            <Link
              href="/#download"
              className="hidden min-h-10 items-center rounded-full bg-ink px-4 text-sm font-black text-paper transition-transform hover:-translate-y-0.5 sm:inline-flex"
            >
              앱 설치
            </Link>
            <button
              type="button"
              onClick={() => setOpen((value) => !value)}
              aria-label={open ? '메뉴 닫기' : '메뉴 열기'}
              aria-expanded={open}
              className="grid h-10 w-10 shrink-0 place-items-center rounded-full border border-line bg-card text-ink transition-colors hover:bg-ink/5 md:hidden"
            >
              <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true">
                {open ? (
                  <path d="M4 4l10 10M14 4L4 14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                ) : (
                  <path d="M3.5 5.25h11M3.5 9h11M3.5 12.75h11" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                )}
              </svg>
            </button>
          </div>
        </div>

        {open && (
          <nav
            className="mt-2 grid gap-1 rounded-3xl border border-line bg-paper/95 p-2 shadow-[0_18px_54px_rgba(23,21,18,.14)] backdrop-blur-xl md:hidden"
            aria-label="Mobile navigation"
            onClick={() => setOpen(false)}
          >
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="rounded-2xl px-4 py-3 text-sm font-black text-ink transition-colors hover:bg-ink/5"
              >
                {link.label}
              </Link>
            ))}
            <Link
              href="/#download"
              className="mt-1 rounded-2xl bg-ink px-4 py-3 text-center text-sm font-black text-paper"
            >
              앱 설치 준비중
            </Link>
          </nav>
        )}
      </div>
    </header>
  );
}
