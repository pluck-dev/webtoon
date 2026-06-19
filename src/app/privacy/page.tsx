import Link from 'next/link';

import SiteHeader from '@/components/SiteHeader';

export const metadata = {
  title: '개인정보처리방침 | Webtoon Voice Studio',
  description: 'Webtoon Voice Studio 개인정보처리방침'
};

export default function PrivacyPage() {
  return (
    <main className="market-shell">
      <SiteHeader />
      <div className="mx-auto w-full max-w-[1760px] px-4 py-4 sm:px-6 lg:px-10">

        <article className="legal-article">
        <p className="legal-eyebrow">법적 고지</p>
        <h1>개인정보처리방침</h1>
        <p className="legal-updated">시행일: 2026년 6월 19일</p>

        <section>
          <p>
            플럭(Pluck, 이하 &ldquo;회사&rdquo;)은 「개인정보 보호법」 등 관련 법령을 준수하며, 이용자의 개인정보를
            보호하기 위해 다음과 같이 개인정보처리방침을 수립·공개합니다.
          </p>
        </section>

        <section>
          <h2>제1조 (수집하는 개인정보 항목)</h2>
          <ol>
            <li>회원가입 및 인증: 이메일 주소, 이름(또는 닉네임), 소셜 로그인 식별자</li>
            <li>서비스 이용 과정에서 생성: 음성 녹음 파일, 더빙 버전 등 회원이 제작한 콘텐츠</li>
            <li>자동 수집 항목: 접속 IP, 쿠키, 서비스 이용 기록, 기기·브라우저 정보</li>
          </ol>
        </section>

        <section>
          <h2>제2조 (개인정보의 수집 및 이용 목적)</h2>
          <ol>
            <li>회원 식별 및 가입 의사 확인, 본인 인증</li>
            <li>음성 녹음·더빙 버전 제작 및 저장 등 서비스 제공</li>
            <li>서비스 운영, 부정 이용 방지, 문의 응대</li>
            <li>서비스 개선 및 신규 기능 개발을 위한 통계 분석</li>
          </ol>
        </section>

        <section>
          <h2>제3조 (개인정보의 보유 및 이용 기간)</h2>
          <ol>
            <li>회사는 원칙적으로 회원 탈퇴 시 지체 없이 개인정보를 파기합니다.</li>
            <li>다만 관련 법령에 따라 보존이 필요한 경우 해당 기간 동안 보관합니다.</li>
            <li>회원이 작성한 콘텐츠는 회원의 삭제 요청 또는 탈퇴 시까지 보관됩니다.</li>
          </ol>
        </section>

        <section>
          <h2>제4조 (개인정보의 제3자 제공 및 처리위탁)</h2>
          <ol>
            <li>회사는 이용자의 동의 없이 개인정보를 외부에 제공하지 않습니다.</li>
            <li>
              회사는 안정적인 서비스 제공을 위해 인증·인프라 등 일부 업무를 외부 전문업체(예: 인증 서비스 제공자,
              클라우드 인프라 제공자)에 위탁할 수 있으며, 위탁 시 관련 법령에 따라 개인정보가 안전하게 관리되도록 합니다.
            </li>
          </ol>
        </section>

        <section>
          <h2>제5조 (이용자의 권리와 행사 방법)</h2>
          <ol>
            <li>이용자는 언제든지 자신의 개인정보를 조회·수정하거나 삭제, 처리정지를 요청할 수 있습니다.</li>
            <li>권리 행사는 이메일(admin@pluck.co.kr)을 통해 요청할 수 있으며, 회사는 지체 없이 조치합니다.</li>
          </ol>
        </section>

        <section>
          <h2>제6조 (개인정보의 파기)</h2>
          <p>
            회사는 개인정보 보유 기간의 경과, 처리 목적 달성 등 개인정보가 불필요하게 되었을 때 지체 없이 해당 정보를
            파기합니다. 전자적 파일은 복구 불가능한 방법으로 영구 삭제합니다.
          </p>
        </section>

        <section>
          <h2>제7조 (개인정보의 안전성 확보 조치)</h2>
          <p>
            회사는 개인정보의 안전한 처리를 위해 접근 권한 관리, 전송 구간 암호화, 접근 기록 보관 등 기술적·관리적
            보호조치를 시행합니다.
          </p>
        </section>

        <section>
          <h2>제8조 (개인정보 보호책임자)</h2>
          <p>회사는 개인정보 처리에 관한 업무를 총괄하는 개인정보 보호책임자를 다음과 같이 지정합니다.</p>
          <ul>
            <li>개인정보 보호책임자: 심재형</li>
            <li>이메일: <a href="mailto:admin@pluck.co.kr">admin@pluck.co.kr</a></li>
          </ul>
        </section>

        <section className="legal-contact">
          <h2>사업자 정보</h2>
          <p>상호: 플럭 (Pluck)</p>
          <p>대표: 심재형</p>
          <p>사업자등록번호: 709-19-02368</p>
          <p>이메일: <a href="mailto:admin@pluck.co.kr">admin@pluck.co.kr</a></p>
        </section>

        <p className="legal-back">
          <Link href="/">← 홈으로 돌아가기</Link>
        </p>
        </article>
      </div>
    </main>
  );
}
