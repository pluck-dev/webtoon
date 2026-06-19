'use client';

import { Show, SignInButton, SignUpButton, UserButton } from '@clerk/nextjs';

export default function AuthNav() {
  return (
    <div className="flex items-center justify-end gap-2">
      <Show when="signed-out">
        <SignInButton mode="modal">
          <button
            className="min-h-[40px] rounded-lg border border-line bg-card px-[13px] text-sm font-bold text-ink transition-colors hover:bg-ink/5"
            type="button"
          >
            로그인
          </button>
        </SignInButton>
        <SignUpButton mode="modal">
          <button className="min-h-[40px] rounded-lg border-0 bg-[#ef6f5e] px-[13px] font-black text-[#190b09]" type="button">회원가입</button>
        </SignUpButton>
      </Show>
      <Show when="signed-in">
        <UserButton />
      </Show>
    </div>
  );
}
