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
    default: 'Webtoon Voice Studio — AI 웹툰 보이스 마켓플레이스',
    template: '%s · Webtoon Voice Studio'
  },
  description: '관리자가 만든 AI 웹툰 에피소드에 내 목소리를 입혀 나만의 더빙 숏폼을 만드세요.',
  keywords: ['웹툰', '더빙', 'AI 웹툰', '보이스', '숏폼', 'voice acting'],
  openGraph: {
    type: 'website',
    siteName: 'Webtoon Voice Studio',
    title: 'Webtoon Voice Studio — AI 웹툰 보이스 마켓플레이스',
    description: '하나의 원작 웹툰, 무한한 배우 버전. 모든 말풍선을 내 목소리로 녹음하세요.',
    images: ['/sample/interview-cut-01.png']
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Webtoon Voice Studio',
    description: '하나의 원작 웹툰, 무한한 배우 버전.',
    images: ['/sample/interview-cut-01.png']
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
