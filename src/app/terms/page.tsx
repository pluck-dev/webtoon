import Link from 'next/link';

export const metadata = {
  title: '이용약관 | Webtoon Voice Studio',
  description: 'Webtoon Voice Studio 서비스 이용약관'
};

export default function TermsPage() {
  return (
    <main className="market-shell">
      <header className="market-nav">
        <Link href="/" className="market-brand">
          <span className="market-brand-mark">W</span>
          <span>Webtoon Voice Studio</span>
        </Link>
        <nav className="market-links" aria-label="Main navigation">
          <Link href="/">Episodes</Link>
          <Link href="/terms" className="footer-link-strong">이용약관</Link>
          <Link href="/privacy">개인정보처리방침</Link>
        </nav>
      </header>

      <article className="legal-article">
        <p className="legal-eyebrow">Legal</p>
        <h1>이용약관</h1>
        <p className="legal-updated">시행일: 2026년 6월 19일</p>

        <section>
          <h2>제1조 (목적)</h2>
          <p>
            본 약관은 플럭(Pluck, 이하 &ldquo;회사&rdquo;)이 제공하는 Webtoon Voice Studio(이하 &ldquo;서비스&rdquo;)의
            이용과 관련하여 회사와 회원 간의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.
          </p>
        </section>

        <section>
          <h2>제2조 (정의)</h2>
          <ol>
            <li>&ldquo;서비스&rdquo;란 회사가 게시한 웹툰 에피소드에 회원이 음성을 녹음하여 자신만의 버전을 제작·공유할 수 있도록 제공하는 일체의 서비스를 의미합니다.</li>
            <li>&ldquo;회원&rdquo;이란 본 약관에 동의하고 서비스에 가입하여 이용하는 자를 말합니다.</li>
            <li>&ldquo;에피소드&rdquo;란 회사 또는 운영자가 게시한 컷 이미지, 대사, 배역 가이드로 구성된 원본 웹툰 콘텐츠를 말합니다.</li>
            <li>&ldquo;콘텐츠&rdquo;란 회원이 서비스를 이용하며 생성한 음성 녹음, 더빙 버전 등 일체의 결과물을 말합니다.</li>
          </ol>
        </section>

        <section>
          <h2>제3조 (약관의 효력 및 변경)</h2>
          <ol>
            <li>본 약관은 서비스 화면에 게시하거나 기타의 방법으로 회원에게 공지함으로써 효력이 발생합니다.</li>
            <li>회사는 관련 법령을 위배하지 않는 범위에서 본 약관을 개정할 수 있으며, 개정 시 적용일자 및 사유를 명시하여 사전 공지합니다.</li>
          </ol>
        </section>

        <section>
          <h2>제4조 (회원가입 및 이용계약)</h2>
          <ol>
            <li>이용계약은 회원이 약관에 동의하고 가입 절차를 완료한 후 회사가 이를 승낙함으로써 성립합니다.</li>
            <li>회원은 가입 시 정확한 정보를 제공해야 하며, 타인의 정보를 도용해서는 안 됩니다.</li>
          </ol>
        </section>

        <section>
          <h2>제5조 (콘텐츠의 권리와 책임)</h2>
          <ol>
            <li>에피소드 등 원본 콘텐츠에 대한 저작권은 회사 또는 정당한 권리자에게 귀속됩니다.</li>
            <li>회원이 생성한 음성 녹음 등 콘텐츠의 권리는 회원에게 있으며, 회원은 서비스 운영·홍보를 위해 회사가 해당 콘텐츠를 사용하는 것에 동의합니다.</li>
            <li>회원은 제3자의 권리를 침해하거나 법령에 위반되는 콘텐츠를 게시해서는 안 됩니다.</li>
          </ol>
        </section>

        <section>
          <h2>제6조 (금지행위)</h2>
          <p>회원은 다음 각 호의 행위를 하여서는 안 됩니다.</p>
          <ol>
            <li>타인의 권리나 명예를 침해하는 행위</li>
            <li>음란·폭력적이거나 공서양속에 반하는 콘텐츠를 게시하는 행위</li>
            <li>서비스의 정상적인 운영을 방해하는 행위</li>
            <li>회사의 사전 동의 없이 서비스를 영리 목적으로 이용하는 행위</li>
          </ol>
        </section>

        <section>
          <h2>제7조 (서비스의 중단)</h2>
          <p>
            회사는 시스템 점검, 천재지변 등 불가피한 사유가 있는 경우 서비스의 전부 또는 일부를 일시적으로 중단할 수 있으며,
            이 경우 사전에 공지하되 부득이한 경우 사후에 공지할 수 있습니다.
          </p>
        </section>

        <section>
          <h2>제8조 (책임의 제한)</h2>
          <p>
            회사는 천재지변, 회원의 귀책사유 등 회사의 통제 범위를 벗어난 사유로 발생한 손해에 대하여 책임을 지지 않습니다.
          </p>
        </section>

        <section>
          <h2>제9조 (준거법 및 관할)</h2>
          <p>
            본 약관은 대한민국 법령에 따라 해석되며, 서비스 이용과 관련한 분쟁에 대해서는 민사소송법상의 관할 법원을 제1심 관할 법원으로 합니다.
          </p>
        </section>

        <section className="legal-contact">
          <h2>문의</h2>
          <p>상호: 플럭 (Pluck)</p>
          <p>대표: 심재형</p>
          <p>사업자등록번호: 709-19-02368</p>
          <p>이메일: <a href="mailto:hello@pluck.co.kr">hello@pluck.co.kr</a></p>
        </section>

        <p className="legal-back">
          <Link href="/">← 홈으로 돌아가기</Link>
        </p>
      </article>
    </main>
  );
}
