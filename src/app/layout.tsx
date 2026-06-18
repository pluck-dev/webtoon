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
  title: 'Webtoon Voice Studio',
  description: 'Create actor versions of admin-made AI webtoon shorts',
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
