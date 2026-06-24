# 체크포인트 — 2026-06-24 · AI 이미지 생성 (배포 완료 ✅)

> 세션 재시작용 컨텍스트. 새 세션에서 이 파일 + git 로그 보면 바로 따라잡을 수 있음.

## ✅ 완료 — Edge Function 배포 + E2E 검증 (2026-06-24)
**`generate-image` Edge Function 배포 성공 (status ACTIVE, version 1, verify_jwt=true).**

- Supabase MCP OAuth 인증 후 `deploy_edge_function`으로 배포.
- 스모크 테스트 통과: JWT없음→401, anon키→`unauthorized`(함수본문 실행 확인), OPTIONS→200.
- **해피패스 E2E 통과**: tester@dubbingo.app 로그인 → 함수 호출 → stub PNG + `remaining:4`(쿼터 1 차감) + `stub:true`. `AiUsage.count`=1 영속 확인 후 **0으로 원복**(테스트 흔적 제거).
- 결론: JWT검증→User.id해석→`consume_ai_credit`→이미지반환 전 구간 동작. **stub 모드**(GEMINI_API_KEY 미설정).

### 🔴 남은 일 (선택)
1. **실제 AI 생성**: 사장님이 **Gemini API 키**(aistudio.google.com, 무료) 발급 →
   `mcp__supabase__` secrets 또는 대시보드 Edge Functions secrets에 `GEMINI_API_KEY` 설정.
   모델 기본값 `gemini-2.5-flash-image-preview`. (`AI_FREE_LIMIT`로 한도 조정 가능)
2. **기기 UI 검증**: 작가 에디터 → 사진 추가 → "✨ AI로 생성" → 프롬프트 → 컷 적용.
   (키 없어도 stub PNG로 버튼→로딩→컷적용 흐름 검증 가능)

## ✅ 완성된 것 (전부 git 커밋·푸시됨, origin/main)

- **기본 앱**: 더빙(녹음→온디바이스 영상), 홈/피드/보관함/프로필, 로그인(비번+구글), 완성 푸시
- **작가 에디터**: 컷별 사진+대사로 발행, 사진 여러 장→컷 자동, 컷추가 버튼 가려짐 수정
- **커뮤니티**: 공개 피드, 좋아요, 댓글, 작가 프로필, 자동 새로고침(RouteObserver)
- **초대 더빙**(실기기 검증): TEAM(같이 한 영상) + REMIX(각자 버전 A+B/A+C) 둘 다.
  딥링크(`kr.co.pluck.dubbingo://collab/{code}`)·캐스팅·참여·배역한정 녹음·합본 렌더.
  - 이번에 잡은 버그: **Row의 비-flex 자식으로 Material 버튼(FilledButton 등) 쓰면 화면 silent 블랭크** → Pressable+Container 알약으로 교체. (앞으로도 Row 안엔 Material 버튼 X)

## 🔨 AI 이미지 생성 — 코드 상태 (배포만 남음)

- **`supabase/functions/generate-image/index.ts`** (Deno Edge Function):
  JWT검증 → User.id 해석(supabaseUserId) → `consume_ai_credit`(월 한도, 기본 5회) →
  GEMINI_API_KEY 있으면 Gemini 생성, 없으면 stub PNG → base64 반환. CORS 처리. verify_jwt=true로 배포.
- **DB(이미 적용됨)**: `AiUsage`(userId,periodStart,count) + `consume_ai_credit(p_user,p_limit)` 원자적 증가/한도.
- **Flutter `Cloud.generateAiImage(prompt)`**: functions.invoke → base64→임시파일→컷 imagePath.
  `AiQuotaException`(used/limit). 402면 구독 안내.
- **에디터**: 사진 시트에 "✨ AI로 생성" → 프롬프트 다이얼로그 → 풀스크린 로딩 → 컷 적용 토스트(남은 횟수/stub 안내).

## ⏭️ 그 다음 후보 (AI 생성 동작 후)
- **Phase 3b**: RevenueCat 구독 → 구독자는 월 한도 상향(consume_ai_credit의 p_limit를 RevenueCat entitlement로 분기). RevenueCat/Play 구독상품/시크릿 = 사장님 외부 셋업.
- **출시 준비**: 서명 release 빌드, 스토어 등록, UGC 신고/숨김(모더레이션), 약관/개인정보.
- **초대 더빙 마무리**: 2계정 실음성 합본 E2E, 공개 캐스팅 피드, FCM 푸시 넛지.

## 환경 메모
- 기기: 삼성 SM-F966N. **USB(R3CY70H0JLW)가 무선(192.168.0.11:5555)보다 안정적** — 무선은 자주 끊기고 PIN 잠금 자주 걸림.
- adb 스크린샷은 1080x2520 → `sips -Z 1400`로 줄여서 봄.
- DB 직접 점검: `.env`의 DIRECT_URL로 psql. Storage API는 SUPABASE_SECRET_KEY.
- 핫 리로드(`flutter run`)는 무선 VM Service 불안정으로 포기 → 빌드+설치 방식 사용 중.
- 테스트 데이터(콜라보 세션, u- 에피소드, 검증 시드)는 매번 정리함. 현재 CollabSession 0개.

## 마지막 커밋
`f613494 Phase 3a: AI 컷 이미지 생성 (무료 쿼터, 구독 전 단계)`
