// Pro 구독 상태 (RevenueCat 연동 지점)
//
// 현재는 stub — 인앱결제(RevenueCat)가 아직 연결되지 않아 항상 무료(isPro=false).
// 스토어 상품(Env.proMonthlyId/proYearlyId) + RevenueCat 키(Env.revenueCatKeyIos/Android)를
// 등록한 뒤, 아래 TODO(RevenueCat) 지점에 purchases_flutter SDK를 연결하면 동작한다.
//
// 사용처:
//  - 앱 시작: await Subscription.instance.init();  (main.dart)
//  - Pro 여부: Subscription.instance.isPro / isProListenable(ValueListenable)
//  - 구매/복원: purchaseMonthly() / purchaseYearly() / restore()

import 'package:flutter/foundation.dart';

import 'config.dart';

class Subscription {
  Subscription._();
  static final Subscription instance = Subscription._();

  /// Pro entitlement 활성 여부. RevenueCat 미연동 시 항상 false.
  final ValueNotifier<bool> isProListenable = ValueNotifier<bool>(false);
  bool get isPro => isProListenable.value;

  /// RevenueCat 키가 설정돼 실제 구독이 가능한 상태인지.
  bool get isConfigured =>
      Env.revenueCatKeyIos.isNotEmpty || Env.revenueCatKeyAndroid.isNotEmpty;

  /// 이번 달 AI 생성 한도 (Pro면 상향).
  int get aiLimit => isPro ? Env.aiProLimit : Env.aiFreeLimit;

  /// 스토리보드 최대 컷 수 (Pro면 상향).
  int get storyboardMaxCuts =>
      isPro ? Env.storyboardProCuts : Env.storyboardFreeCuts;

  /// 앱 시작 시 1회 — RevenueCat 초기화 + 현재 상태 로드. 미설정이면 no-op.
  Future<void> init() async {
    if (!isConfigured) return;
    // TODO(RevenueCat): purchases_flutter 연결
    //   await Purchases.configure(PurchasesConfiguration(<platform key>));
    //   Purchases.addCustomerInfoUpdateListener(_apply);
    //   _apply(await Purchases.getCustomerInfo());
  }

  /// 월간 구독 구매. 성공 시 true. 미연동이면 false(호출부가 안내).
  Future<bool> purchaseMonthly() => _purchase(Env.proMonthlyId);

  /// 연간 구독 구매. 성공 시 true.
  Future<bool> purchaseYearly() => _purchase(Env.proYearlyId);

  Future<bool> _purchase(String productId) async {
    if (!isConfigured) return false;
    // TODO(RevenueCat): Purchases.purchaseStoreProduct(...) → _apply(customerInfo)
    return false;
  }

  /// 구매 복원(Apple 심사 필수). 성공 시 true. 미연동이면 false.
  Future<bool> restore() async {
    if (!isConfigured) return false;
    // TODO(RevenueCat): final info = await Purchases.restorePurchases(); _apply(info);
    return isPro;
  }

  // RevenueCat CustomerInfo → Pro 여부 반영 (연동 시 사용)
  // void _apply(CustomerInfo info) {
  //   isProListenable.value =
  //       info.entitlements.active.containsKey(Env.proEntitlement);
  // }
}
