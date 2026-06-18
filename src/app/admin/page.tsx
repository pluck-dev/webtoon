import Link from 'next/link';

import AdminImageGenerator from '@/components/AdminImageGenerator';

export default function AdminPage() {
  return (
    <main className="shell">
      <nav className="topbar">
        <Link href="/" className="brand">
          <span className="brand-mark">WV</span>
          <span>
            <strong>관리자 콘솔</strong>
            <small>웹툰 컷 생성, 에피소드 원본 관리</small>
          </span>
        </Link>
      </nav>

      <section className="workspace single">
        <section className="panel">
          <div className="panel-head">
            <h1>CLI 이미지 생성</h1>
            <span>god-tibo-imagen private-codex</span>
          </div>
          <div className="panel-content">
            <p className="muted">
              관리자는 여기서 컷 PNG를 생성하고, 생성된 URL을 에피소드 컷 이미지로 등록합니다.
              같은 에피소드의 다음 컷은 이전 컷을 reference image로 넣어 일관성을 유지하는 방식으로 확장하면 됩니다.
            </p>
            <AdminImageGenerator />
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <h2>관리자 운영 모델</h2>
          </div>
          <div className="panel-content flow-list">
            <div><strong>1. 이미지 생성</strong><span>AI로 9:16 웹툰 컷을 생성하고 캐릭터 일관성을 확인합니다.</span></div>
            <div><strong>2. 에피소드 발행</strong><span>컷 이미지, 말풍선 대사, 캐릭터 보이스 가이드를 등록합니다.</span></div>
            <div><strong>3. 사용자 참여</strong><span>사용자는 원본을 바꾸지 않고 자기 녹음 버전만 만듭니다.</span></div>
            <div><strong>4. 렌더링</strong><span>RenderJob이 컷 이미지와 녹음을 합쳐 숏츠 타임라인을 만듭니다.</span></div>
          </div>
        </section>
      </section>
    </main>
  );
}
