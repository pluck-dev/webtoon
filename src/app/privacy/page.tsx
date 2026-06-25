import Link from 'next/link';

import SiteHeader from '@/components/SiteHeader';

export const metadata = {
  title: '개인정보처리방침 | 쩌렁쩌렁',
  description: '쩌렁쩌렁 개인정보처리방침'
};

export default function PrivacyPage() {
  return (
    <main className="market-shell">
      <SiteHeader />
      <div className="mx-auto w-full max-w-[1760px] px-4 py-4 sm:px-6 lg:px-10">

        <article className="legal-article">
        <p className="legal-eyebrow">법적 고지</p>
        <h1>개인정보처리방침</h1>
        <p className="legal-updated">시행일: 2026년 6월 25일</p>

        <section>
          <p>
            플럭(Pluck, 이하 &ldquo;회사&rdquo;)은 쩌렁쩌렁(이하 &ldquo;서비스&rdquo;) 제공과 관련하여 「개인정보 보호법」 등
            관련 법령을 준수하며, 이용자의 개인정보를 보호하기 위해 다음과 같이 개인정보처리방침을 수립·공개합니다.
          </p>
        </section>

        <section>
          <h2>제1조 (수집하는 개인정보 항목)</h2>
          <ol>
            <li>회원가입 및 인증: 이메일 주소, 이름(또는 닉네임), 소셜 로그인 식별자</li>
            <li>서비스 이용 과정에서 생성·입력되는 콘텐츠:
              <ul>
                <li>음성 녹음 파일, 더빙 영상</li>
                <li>AI 이미지 생성을 위해 회원이 입력한 텍스트(프롬프트)·키워드</li>
                <li>회원이 업로드한 사진·이미지(컷 사진, 캐릭터·포즈 참조 이미지 등) 및 AI가 생성한 이미지</li>
              </ul>
            </li>
            <li>AI 사용 기록: AI 생성 횟수 및 이용 한도 관리를 위한 사용량 정보</li>
            <li>결제 관련: 구독 등 유료 서비스 이용 시, 결제는 앱마켓(App Store, Google Play)을 통해 처리되며 회사는
              결제 수단의 카드번호 등 민감 결제정보를 직접 저장하지 않습니다(구매 사실·구독 상태 등 최소 정보만 처리).</li>
            <li>자동 수집 항목: 접속 IP, 쿠키, 서비스 이용 기록, 기기·앱·브라우저 정보</li>
          </ol>
          <p>회원이 사진 등 입력물에 제3자의 개인정보(얼굴 등)를 포함하는 경우, 해당 정보 제공에 대한 적법한 권한 확보 책임은 회원에게 있습니다.</p>
        </section>

        <section>
          <h2>제2조 (개인정보의 수집 및 이용 목적)</h2>
          <ol>
            <li>회원 식별 및 가입 의사 확인, 본인 인증</li>
            <li>만화 제작, AI 이미지 생성, 음성 녹음·더빙 영상 제작 및 저장 등 서비스 제공</li>
            <li>AI 생성 이용 한도 관리 및 유료(구독) 혜택 적용</li>
            <li>서비스 운영, 부정 이용·권리 침해 방지, 신고 처리, 문의 응대</li>
            <li>서비스 개선 및 신규 기능 개발을 위한 통계 분석</li>
          </ol>
        </section>

        <section>
          <h2>제3조 (개인정보의 보유 및 이용 기간)</h2>
          <ol>
            <li>회사는 원칙적으로 회원 탈퇴 시 지체 없이 개인정보 및 회원이 만든 콘텐츠를 파기합니다.</li>
            <li>회원이 작성·생성한 콘텐츠는 회원의 삭제 요청 또는 탈퇴 시까지 보관됩니다.</li>
            <li>다만 관련 법령에 따라 보존이 필요한 경우 해당 기간 동안 보관합니다.</li>
          </ol>
        </section>

        <section>
          <h2>제4조 (개인정보 처리의 위탁 및 국외 이전)</h2>
          <p>회사는 안정적인 서비스 제공을 위해 아래와 같이 개인정보 처리를 위탁하며, 일부 수탁자의 서버가 국외에 위치하여 개인정보가 국외로 이전될 수 있습니다.</p>
          <ul>
            <li>
              <strong>Supabase Inc.</strong> — 회원 인증, 데이터베이스, 파일(이미지·음성·영상) 저장 및 클라우드 인프라 운영.
              이전 항목: 본 방침에 따라 수집·생성되는 개인정보 및 콘텐츠. 이전 국가: 미국 등(클라우드 리전). 보유: 위탁 목적 달성 시 또는 탈퇴 시까지.
            </li>
            <li>
              <strong>Google LLC</strong> — AI 이미지·콘티 생성 기능(Gemini API) 제공. 회원이 AI 생성을 요청할 때 입력한
              프롬프트·키워드 및 참조 이미지가 처리 목적 범위에서 전송·처리됩니다. 이전 국가: 미국 등.
            </li>
          </ul>
          <p>회사는 위탁 시 관련 법령에 따라 개인정보가 안전하게 관리되도록 필요한 조치를 합니다. 수탁자·이전 항목은 변경될 수 있으며 변경 시 본 방침을 통해 공지합니다.</p>
          <p>회사는 위 위탁의 경우를 제외하고 이용자의 동의 없이 개인정보를 외부에 제공하지 않습니다.</p>
        </section>

        <section>
          <h2>제5조 (이용자 및 법정대리인의 권리)</h2>
          <ol>
            <li>이용자는 언제든지 자신의 개인정보를 조회·수정하거나 삭제, 처리정지를 요청할 수 있습니다.</li>
            <li>이용자는 서비스 내 <strong>계정 삭제</strong> 기능 또는 이메일(admin@pluck.co.kr)을 통해 탈퇴·삭제를 요청할 수 있으며, 회사는 지체 없이 조치합니다.</li>
            <li>만 14세 미만 아동의 개인정보는 법정대리인의 동의가 있는 경우에 한해 처리하며, 법정대리인은 아동의 개인정보에 대한 권리를 행사할 수 있습니다.</li>
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
