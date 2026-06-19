import { ImageResponse } from 'next/og';

// 빌드 시 정적 프리렌더하지 않고 요청 시 생성한다(폰트 fetch가 빌드 프리렌더에서 실패하므로).
export const dynamic = 'force-dynamic';

// 홈 링크 공유 시(카톡 등) 뜨는 브랜드 OG 카드
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';
export const alt = '더빙고 — 짧은 상황을 내 목소리로 연기하는 더빙 놀이터';

export default async function OpengraphImage() {
  // 한글 렌더용 폰트 (satori 기본 폰트는 한글 미지원 → 임베드 필수)
  const pretendard = await fetch(new URL('./Pretendard-Bold.otf', import.meta.url)).then((res) =>
    res.arrayBuffer()
  );

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          padding: '90px',
          background: '#171512',
          color: '#fffaf0',
          fontFamily: 'Pretendard'
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '28px', marginBottom: '40px' }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: '108px',
              height: '108px',
              borderRadius: '28px',
              background: '#f0bd62',
              color: '#171512',
              fontSize: '64px'
            }}
          >
            더
          </div>
          <div style={{ fontSize: '96px', color: '#f0bd62' }}>더빙고</div>
        </div>
        <div style={{ fontSize: '52px', lineHeight: 1.3 }}>짧은 상황을 내 목소리로 연기하는</div>
        <div style={{ fontSize: '52px', color: '#ef6f5e' }}>더빙 놀이터</div>
        <div style={{ marginTop: '44px', fontSize: '30px', color: '#aeb8bf' }}>
          웹툰체 · 상황극 · 애니 — 누구나 성우가 됩니다
        </div>
      </div>
    ),
    {
      ...size,
      fonts: [{ name: 'Pretendard', data: pretendard, weight: 800, style: 'normal' }]
    }
  );
}
