'use client';

import { Show, SignInButton, SignUpButton, UserButton } from '@clerk/nextjs';

export default function AuthNav() {
  return (
    <div className="auth-nav">
      <Show when="signed-out">
        <SignInButton mode="modal">
          <button type="button">Sign in</button>
        </SignInButton>
        <SignUpButton mode="modal">
          <button className="primary" type="button">Sign up</button>
        </SignUpButton>
      </Show>
      <Show when="signed-in">
        <UserButton />
      </Show>
    </div>
  );
}
