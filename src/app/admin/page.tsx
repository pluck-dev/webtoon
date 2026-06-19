import Link from 'next/link';
import { SignInButton, UserButton } from '@clerk/nextjs';

import AdminImageGenerator from '@/components/AdminImageGenerator';
import { getRequiredDbUser } from '@/lib/clerk-user';

export default async function AdminPage() {
  const user = await getRequiredDbUser();

  return (
    <main className="min-h-screen bg-[#101317] p-[26px]">
      <nav className="mb-7 flex items-center justify-between gap-4">
        <Link href="/" className="flex items-center gap-3">
          <span className="grid h-11 w-11 place-items-center rounded-lg border-2 border-[#f0bd62] font-black text-[#f0bd62]">WV</span>
          <span>
            <strong className="block text-[#f5f0e8]">Admin Console</strong>
            <small className="mt-[3px] block text-[#aeb8bf]">Create webtoon cuts and manage episode originals</small>
          </span>
        </Link>
        <div className="flex flex-wrap gap-2">
          {user ? <UserButton /> : (
            <SignInButton mode="modal">
              <button type="button">Sign in</button>
            </SignInButton>
          )}
        </div>
      </nav>

      {(!user || user.role !== 'ADMIN') && (
        <section className="rounded-lg border border-[#34404a] bg-[rgba(23,29,35,0.95)]">
          <div className="flex min-h-[58px] items-center justify-between gap-3 border-b border-[#34404a] px-4">
            <h1 className="text-[18px] text-[#f5f0e8]">Admin access required</h1>
            <span className="text-[12px] font-black text-[#aeb8bf]">{user ? user.email : 'Signed out'}</span>
          </div>
          <div className="p-4">
            <p className="text-[#aeb8bf] leading-[1.6]">
              Members can record webtoon episodes. Admin accounts create original episodes,
              generate cut images, and publish the source webtoon.
            </p>
          </div>
        </section>
      )}

      {user?.role === 'ADMIN' && <section className="grid grid-cols-1">
        <section className="rounded-lg border border-[#34404a] bg-[rgba(23,29,35,0.95)]">
          <div className="flex min-h-[58px] items-center justify-between gap-3 border-b border-[#34404a] px-4">
            <h1 className="text-[18px] text-[#f5f0e8]">Built-in Image Generation</h1>
            <span className="text-[12px] font-black text-[#aeb8bf]">private-codex runtime</span>
          </div>
          <div className="p-4">
            <p className="text-[#aeb8bf] leading-[1.6]">
              This project now contains its own image generation runtime. It does not depend
              on another local project path. Generated PNG files are saved into
              public/generated and can be attached to episode cuts.
            </p>
            <AdminImageGenerator />
          </div>
        </section>

        <section className="rounded-lg border border-[#34404a] bg-[rgba(23,29,35,0.95)]">
          <div className="flex min-h-[58px] items-center justify-between gap-3 border-b border-[#34404a] px-4">
            <h2 className="text-[18px] text-[#f5f0e8]">Admin Workflow</h2>
          </div>
          <div className="grid gap-3 p-4">
            <div className="rounded-lg border border-[#303943] bg-[#202832] p-[14px]"><strong className="mb-[6px] block text-[#f0bd62]">1. Generate cuts</strong><span className="text-[#d0d7d3] leading-[1.5]">Create 9:16 webtoon panels and check character consistency.</span></div>
            <div className="rounded-lg border border-[#303943] bg-[#202832] p-[14px]"><strong className="mb-[6px] block text-[#f0bd62]">2. Publish episode</strong><span className="text-[#d0d7d3] leading-[1.5]">Register cut images, speech bubbles, characters, and voice guides.</span></div>
            <div className="rounded-lg border border-[#303943] bg-[#202832] p-[14px]"><strong className="mb-[6px] block text-[#f0bd62]">3. Open participation</strong><span className="text-[#d0d7d3] leading-[1.5]">Actors keep the original webtoon fixed and create their own voice version.</span></div>
            <div className="rounded-lg border border-[#303943] bg-[#202832] p-[14px]"><strong className="mb-[6px] block text-[#f0bd62]">4. Render shorts</strong><span className="text-[#d0d7d3] leading-[1.5]">RenderJob combines cut images, bubble text, and recordings into a vertical timeline.</span></div>
          </div>
        </section>
      </section>}
    </main>
  );
}
