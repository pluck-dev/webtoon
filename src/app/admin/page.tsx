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
          <span className="grid h-11 w-11 place-items-center rounded-lg border-2 border-[#f0bd62] font-black text-[#f0bd62]">더</span>
          <span>
            <strong className="block text-[#f5f0e8]">관리자 콘솔</strong>
            <small className="mt-[3px] block text-[#aeb8bf]">컷 이미지를 생성하고 원작 에피소드를 관리합니다</small>
          </span>
        </Link>
        <div className="flex flex-wrap gap-2">
          {user ? <UserButton /> : (
            <SignInButton mode="modal">
              <button
                className="min-h-[40px] rounded-lg border border-[#34404a] bg-[#141a20] px-[13px] text-sm font-bold text-[#f5f0e8]"
                type="button"
              >
                로그인
              </button>
            </SignInButton>
          )}
        </div>
      </nav>

      {(!user || user.role !== 'ADMIN') && (
        <section className="rounded-lg border border-[#34404a] bg-[rgba(23,29,35,0.95)]">
          <div className="flex min-h-[58px] items-center justify-between gap-3 border-b border-[#34404a] px-4">
            <h1 className="text-[18px] text-[#f5f0e8]">관리자 권한이 필요합니다</h1>
            <span className="text-[12px] font-black text-[#aeb8bf]">{user ? user.email : '로그아웃 상태'}</span>
          </div>
          <div className="p-4">
            <p className="text-[#aeb8bf] leading-[1.6]">
              일반 회원은 에피소드를 녹음할 수 있어요. 관리자 계정은 원작 에피소드를 만들고,
              컷 이미지를 생성하고, 작품을 공개합니다.
            </p>
          </div>
        </section>
      )}

      {user?.role === 'ADMIN' && <section className="grid grid-cols-1">
        <section className="rounded-lg border border-[#34404a] bg-[rgba(23,29,35,0.95)]">
          <div className="flex min-h-[58px] items-center justify-between gap-3 border-b border-[#34404a] px-4">
            <h1 className="text-[18px] text-[#f5f0e8]">내장 이미지 생성</h1>
            <span className="text-[12px] font-black text-[#aeb8bf]">private-codex 런타임</span>
          </div>
          <div className="p-4">
            <p className="text-[#aeb8bf] leading-[1.6]">
              자체 이미지 생성 런타임이 내장돼 있습니다. 생성된 이미지는 Supabase Storage에 저장돼
              에피소드 컷에 연결할 수 있습니다.
            </p>
            <AdminImageGenerator />
          </div>
        </section>

        <section className="rounded-lg border border-[#34404a] bg-[rgba(23,29,35,0.95)]">
          <div className="flex min-h-[58px] items-center justify-between gap-3 border-b border-[#34404a] px-4">
            <h2 className="text-[18px] text-[#f5f0e8]">관리자 워크플로</h2>
          </div>
          <div className="grid gap-3 p-4">
            <div className="rounded-lg border border-[#303943] bg-[#202832] p-[14px]"><strong className="mb-[6px] block text-[#f0bd62]">1. 컷 생성</strong><span className="text-[#d0d7d3] leading-[1.5]">9:16 세로 컷을 생성하고 캐릭터 일관성을 확인합니다.</span></div>
            <div className="rounded-lg border border-[#303943] bg-[#202832] p-[14px]"><strong className="mb-[6px] block text-[#f0bd62]">2. 에피소드 공개</strong><span className="text-[#d0d7d3] leading-[1.5]">컷 이미지·대사·캐릭터·보이스 가이드를 등록합니다.</span></div>
            <div className="rounded-lg border border-[#303943] bg-[#202832] p-[14px]"><strong className="mb-[6px] block text-[#f0bd62]">3. 참여 오픈</strong><span className="text-[#d0d7d3] leading-[1.5]">참여자는 원작을 그대로 두고 자기 목소리 버전을 만듭니다.</span></div>
            <div className="rounded-lg border border-[#303943] bg-[#202832] p-[14px]"><strong className="mb-[6px] block text-[#f0bd62]">4. 숏폼 렌더</strong><span className="text-[#d0d7d3] leading-[1.5]">컷 이미지·자막·녹음을 세로 타임라인 영상으로 합칩니다.</span></div>
          </div>
        </section>
      </section>}
    </main>
  );
}
