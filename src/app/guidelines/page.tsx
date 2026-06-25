import Link from 'next/link';

import SiteHeader from '@/components/SiteHeader';

export const metadata = {
  title: '커뮤니티 가이드라인 | 쩌렁쩌렁',
  description: '쩌렁쩌렁 커뮤니티 가이드라인'
};

export default function GuidelinesPage() {
  return (
    <main className="market-shell">
      <SiteHeader />
      <div className="mx-auto w-full max-w-[1760px] px-4 py-4 sm:px-6 lg:px-10">

        <article className="legal-article">
        <p className="legal-eyebrow">법적 고지</p>
        <h1>커뮤니티 가이드라인</h1>
        <p className="legal-updated">시행일: 2026년 6월 25일</p>

        <section>
          <p>
            쩌렁쩌렁은 누구나 안전하고 즐겁게 만화를 만들고 더빙하며 공유하는 공간을 지향합니다. 모든 회원은 본 가이드라인을
            준수해야 하며, 이를 위반하는 콘텐츠는 사전 통지 없이 제한될 수 있습니다. 본 가이드라인은
            <Link href="/terms"> 이용약관</Link>의 일부를 이룹니다.
          </p>
        </section>

        <section>
          <h2>1. 금지되는 콘텐츠</h2>
          <p>다음에 해당하는 콘텐츠는 제작·생성·게시·공유할 수 없습니다.</p>
          <ol>
            <li><strong>성적·선정적 콘텐츠</strong>: 음란물, 노골적 성적 묘사, 미성년자를 성적으로 대상화하는 일체의 콘텐츠</li>
            <li><strong>폭력·혐오</strong>: 잔혹한 폭력, 자해·자살 조장, 특정 집단에 대한 차별·혐오·비하</li>
            <li><strong>지식재산권 침해</strong>: 타인의 저작물·캐릭터·상표를 무단으로 복제하거나 AI로 생성하는 행위
              (예: 타사 만화·애니·게임의 캐릭터 무단 생성)</li>
            <li><strong>실존 인물·유명인 무단 이용</strong>: 연예인 등 실존 인물의 사진·얼굴·목소리를 동의 없이 사용하거나
              닮은 이미지를 생성하여 초상권·퍼블리시티권을 침해하는 행위</li>
            <li><strong>사칭·기만</strong>: 타인을 사칭하거나, 특정인이 만들거나 참여한 것처럼 오인하게 하는 행위(딥페이크 등)</li>
            <li><strong>타인의 개인정보</strong>: 동의 없이 타인의 사진·개인정보를 업로드하거나 노출하는 행위</li>
            <li><strong>괴롭힘·명예훼손</strong>: 특정인을 향한 모욕, 협박, 괴롭힘, 허위사실 유포</li>
            <li><strong>불법·스팸</strong>: 불법행위 조장, 사기, 도배·광고성 스팸, 악성코드 유포</li>
          </ol>
        </section>

        <section>
          <h2>2. AI 생성에 대한 책임</h2>
          <ol>
            <li>AI로 생성한 콘텐츠라도 위 금지 사항이 동일하게 적용됩니다.</li>
            <li>회원이 AI 생성을 위해 입력하는 텍스트·사진·참조 이미지의 적법성에 대한 책임은 회원에게 있습니다.</li>
            <li>AI 생성물은 의도와 다르거나 부정확할 수 있으며, 결과물의 이용·공유에 따른 책임은 회원에게 있습니다.</li>
          </ol>
        </section>

        <section>
          <h2>3. 신고 및 차단</h2>
          <ol>
            <li>회원은 가이드라인을 위반하는 콘텐츠나 권리 침해를 발견한 경우 서비스 내 신고 기능 또는 이메일로 신고할 수 있습니다.</li>
            <li>권리자(저작권자·초상권자 등)는 자신의 권리를 침해하는 콘텐츠에 대해 삭제를 요청할 수 있습니다.</li>
            <li>회원은 원치 않는 상대의 콘텐츠를 차단할 수 있습니다.</li>
          </ol>
        </section>

        <section>
          <h2>4. 제재</h2>
          <p>회사는 위반의 경중에 따라 다음 조치를 취할 수 있습니다.</p>
          <ol>
            <li>해당 콘텐츠의 비공개 또는 삭제</li>
            <li>경고 및 일시적 이용 제한</li>
            <li>중대하거나 반복되는 위반의 경우 계정의 영구 이용정지</li>
          </ol>
        </section>

        <section className="legal-contact">
          <h2>신고·문의</h2>
          <p>이메일: <a href="mailto:admin@pluck.co.kr">admin@pluck.co.kr</a></p>
          <p>상호: 플럭 (Pluck) · 대표: 심재형</p>
        </section>

        <p className="legal-back">
          <Link href="/">← 홈으로 돌아가기</Link>
        </p>
        </article>
      </div>
    </main>
  );
}
