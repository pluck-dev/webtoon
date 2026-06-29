# 쩌렁쩌렁 수익화 / 인앱 구독 등록 스펙

> 모델: **월 AI 크레딧 중심 Pro 구독** (컷 수 패키지 아님). 결정 근거·정책은 프로젝트 메모리 `monetization-model` 참조.

## 1. 티어

| 항목 | Free | Pro |
|---|---|---|
| AI 월 생성 | 50회 (`Env.aiFreeLimit` / 서버 `AI_FREE_LIMIT`) | **500회** (`Env.aiProLimit` / 서버 `AI_PRO_LIMIT`) |
| AI 스토리보드 컷 | 5컷 (`Env.storyboardFreeCuts`) | **20컷** (`Env.storyboardProCuts`) |
| 영상 워터마크 | 있음 | **제거** |
| 생성 속도 | 일반 | 우선 |
| 우선 지원 | — | O |

가격(표시용, `Env.proMonthlyPriceText`/`proYearlyPriceText` — 실제는 스토어 가격이 우선):
- **월간 ₩4,900 / 월**
- **연간 ₩39,000 / 년** (월 환산 ₩3,250, 약 34% 절약)

## 2. 인앱 상품 (App Store / Google Play 등록)

| 구분 | 상품 ID | 유형 | 가격 |
|---|---|---|---|
| 월간 | `kr.co.pluck.dubbingo.pro.monthly` | 자동 갱신 구독 | ₩4,900 / 월 |
| 연간 | `kr.co.pluck.dubbingo.pro.yearly` | 자동 갱신 구독 | ₩39,000 / 년 |

- 구독 그룹: `dubbingo_pro` (두 상품을 같은 그룹에 두어 사용자가 월↔연 전환 가능)
- (선택) 7일 무료 체험 — 스토어 introductory offer로 설정

### App Store Connect
1. 기능 → 구독 → 구독 그룹 `dubbingo_pro` 생성
2. 위 두 상품 ID로 자동 갱신 구독 추가, 가격(KRW) 설정
3. 현지화(한국어): 표시 이름 "쩌렁쩌렁 Pro (월간/연간)", 설명
4. 심사용: 스크린샷, 검토 정보. **"구매 복원" 동작 필수** (앱 페이월에 복원 버튼 있음)

### Google Play Console
1. 수익 창출 → 구독 → 위 상품 ID로 기본 요금제(월/연) 생성, 가격 설정
2. 구독 혜택 설명 입력

## 3. RevenueCat (권장 — 크로스플랫폼 구독 관리)
1. 프로젝트 생성, iOS/Android 앱 추가
2. **Entitlement**: `pro`
3. **Products**: 위 두 상품 ID 등록 → entitlement `pro`에 연결
4. **Offering**: `default` → 월/연 패키지 구성
5. 공개 SDK 키를 앱 `Env.revenueCatKeyIos` / `Env.revenueCatKeyAndroid`에 입력

## 4. 앱 코드 연동 지점
- `lib/config.dart` `Env` — 상품 ID, entitlement, 가격 표시, 한도 상수, RevenueCat 키
- `lib/subscription.dart` `Subscription` — Pro 상태 추상화. **현재 stub(항상 무료)**. 키 입력 후 `init()`/`_purchase()`/`restore()`의 `TODO(RevenueCat)` 지점에 `purchases_flutter` 연결:
  - `pubspec.yaml`에 `purchases_flutter` 추가
  - `init()`: `Purchases.configure(...)` + `addCustomerInfoUpdateListener` → `isProListenable` 갱신
  - 구매/복원: `Purchases.purchaseStoreProduct` / `restorePurchases` → entitlement `pro` 활성 반영
- `lib/widgets/paywall.dart` — 플랜 선택·가격·혜택·구매·복원 UI (Subscription 호출)
- 한도 적용: `Subscription.instance.aiLimit`(프로필 표시), `storyboardMaxCuts`(스토리보드 컷 수)

## 5. 서버 (Supabase Edge Function)
- `generate-image` / 한도 RPC: 현재 무료 한도(`AI_FREE_LIMIT=50`)만 적용.
  Pro 한도 차등은 구독 검증(RevenueCat webhook → User에 pro 플래그)을 붙인 뒤,
  `check_ai_credit` / `consume_ai_credit` 호출 시 사용자 플래그에 따라 한도를 분기.
- `suggest-cuts`: maxCuts 2~20 clamp (Pro 20컷 허용). 클라가 `Subscription.storyboardMaxCuts`를 전달.

## 6. 출시 체크리스트
- [ ] 스토어 상품 등록(월/연) + 가격
- [ ] RevenueCat entitlement `pro` + products + offering
- [ ] `Env`에 RevenueCat 키 입력
- [ ] `subscription.dart`의 `TODO(RevenueCat)` 구현 + `purchases_flutter` 의존성
- [ ] 서버 Pro 한도 차등(webhook + RPC 분기)
- [ ] 구매/복원/업그레이드 실기기 테스트(샌드박스)
