import { ClerkProvider } from '@clerk/nextjs';
import type { Metadata } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL('https://webtoon-voice-studio.vercel.app'),
  title: {
    default: '더빙고 — 짧은 상황을 내 목소리로 연기하는 더빙 놀이터',
    template: '%s · 더빙고'
  },
  description: '짧은 상황극에 내 목소리를 입혀 더빙 숏폼을 만드세요. 웹툰체·상황극·애니 화풍 컷에 누구나 성우가 됩니다.',
  keywords: ['더빙', '더빙고', '상황극', '성우', '보이스', '숏폼', 'voice acting', 'dubbing'],
  openGraph: {
    type: 'website',
    siteName: '더빙고',
    title: '더빙고 — 짧은 상황을 내 목소리로',
    description: '짧은 상황극을 내 목소리로 연기하는 더빙 놀이터. 누구나 성우가 됩니다.'
  },
  twitter: {
    card: 'summary_large_image',
    title: '더빙고',
    description: '짧은 상황을 내 목소리로 연기하는 더빙 놀이터.'
  }
};

const clerkAppearance = {
  variables: {
    colorPrimary: '#171512',
    colorText: '#171512',
    colorTextSecondary: '#675f54',
    colorBackground: '#fffcf5',
    colorInputBackground: '#fffcf5',
    colorInputText: '#171512',
    colorDanger: '#ef6f5e',
    borderRadius: '8px',
    fontFamily: 'Inter, Pretendard, "Segoe UI", Arial, sans-serif'
  },
  elements: {
    modalBackdrop: 'clerk-modal-backdrop',
    cardBox: 'clerk-card-box',
    card: 'clerk-card',
    headerTitle: 'clerk-title',
    headerSubtitle: 'clerk-subtitle',
    socialButtonsBlockButton: 'clerk-social-button',
    formButtonPrimary: 'clerk-primary-button',
    formFieldInput: 'clerk-input',
    footer: 'clerk-footer',
    footerActionLink: 'clerk-footer-link'
  }
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ko" className={`${geistSans.variable} ${geistMono.variable}`} suppressHydrationWarning>
      <body suppressHydrationWarning>
        <ClerkProvider appearance={clerkAppearance}>
          {children}
        </ClerkProvider>
      </body>
    </html>
  );
}
