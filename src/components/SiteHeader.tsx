'use client';

import Link from 'next/link';
import { useState } from 'react';

import AuthNav from '@/components/AuthNav';

const navLinks: { href: string; label: string; external?: boolean }[] = [
  { href: '/', label: '작품' },
  { href: '/#collection', label: '컬렉션', external: true },
  { href: '/mypage', label: '마이페이지' },
  { href: '/admin', label: '관리자' }
];

const navLinkClass =
  'inline-flex min-h-[38px] items-center rounded-full border border-line bg-paper/70 px-3.5 text-[13px] font-extrabold text-ink transition-colors hover:bg-ink/5';

export default function SiteHeader() {
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-20 border-b border-line bg-cream/85 backdrop-blur-md">
      <div className="mx-auto w-full max-w-[1760px] px-4 sm:px-6 lg:px-10">
      <div className="flex min-h-16 items-center justify-between gap-4">
        <Link href="/" className="inline-flex items-center gap-2.5 text-xl font-black text-ink">
          <span className="grid h-[30px] w-[30px] place-items-center rounded-[9px] bg-ink text-base font-black text-gold">
            더
          </span>
          <span className="whitespace-nowrap">더빙고</span>
        </Link>

        {/* 데스크톱 내비 */}
        <nav className="hidden items-center gap-1.5 md:flex" aria-label="Main navigation">
          {navLinks.map((link) =>
            link.external ? (
              <a key={link.label} href={link.href} className={navLinkClass}>
                {link.label}
              </a>
            ) : (
              <Link key={link.label} href={link.href} className={navLinkClass}>
                {link.label}
              </Link>
            )
          )}
        </nav>

        <div className="flex items-center gap-2">
          <div className="hidden md:block">
            <AuthNav />
          </div>
          {/* 모바일 햄버거 */}
          <button
            type="button"
            onClick={() => setOpen((value) => !value)}
            aria-label={open ? '메뉴 닫기' : '메뉴 열기'}
            aria-expanded={open}
            className="grid h-10 w-10 shrink-0 place-items-center rounded-lg border border-line bg-card text-ink transition-colors hover:bg-ink/5 md:hidden"
          >
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true">
              {open ? (
                <path d="M4 4l10 10M14 4L4 14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              ) : (
                <path d="M3 5h12M3 9h12M3 13h12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              )}
            </svg>
          </button>
        </div>
      </div>

      {/* 모바일 드롭다운 메뉴 */}
      {open && (
        <nav
          className="flex flex-col gap-1 border-t border-line-soft py-3 md:hidden"
          aria-label="Mobile navigation"
          onClick={() => setOpen(false)}
        >
          <div className="mb-1 border-b border-line-soft pb-2">
            <AuthNav />
          </div>
          {navLinks.map((link) =>
            link.external ? (
              <a
                key={link.label}
                href={link.href}
                className="rounded-lg px-3 py-2.5 text-sm font-extrabold text-ink transition-colors hover:bg-ink/5"
              >
                {link.label}
              </a>
            ) : (
              <Link
                key={link.label}
                href={link.href}
                className="rounded-lg px-3 py-2.5 text-sm font-extrabold text-ink transition-colors hover:bg-ink/5"
              >
                {link.label}
              </Link>
            )
          )}
        </nav>
      )}
      </div>
    </header>
  );
}
