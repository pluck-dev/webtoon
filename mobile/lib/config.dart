import 'package:flutter/material.dart';

/// Supabase 연결 설정 (publishable 키는 클라이언트 공개용 — 안전)
class Env {
  static const supabaseUrl = 'https://brnjzvtvudkyjoxswuln.supabase.co';
  static const supabaseAnonKey =
      'sb_publishable_vqxNd4NX6GSb_MYFEPyOXg_88oe8PlP';

  // Storage 버킷 (웹과 공용)
  static const bucketRecordings = 'recordings';
  static const bucketVideos = 'rendered-videos';
  static const bucketImages = 'webtoon-images'; // 작가가 올린 컷 이미지

  // 무료 월 AI 생성 한도 — generate-image Edge Function의 AI_FREE_LIMIT(기본 50)과 맞출 것.
  static const aiFreeLimit = 50;
  static const aiProLimit = 500; // Pro 월 한도 (구독 연동 시 서버 AI_PRO_LIMIT도 동일하게)
  static const storyboardFreeCuts = 5; // 무료 스토리보드 컷 수
  static const storyboardProCuts = 20; // Pro 스토리보드 컷 수

  // ── Pro 구독(인앱결제) ──────────────────────────────────────
  // 스토어(App Store Connect·Play Console)와 RevenueCat에 동일하게 등록할 식별자.
  static const proEntitlement = 'pro'; // RevenueCat entitlement
  static const proMonthlyId = 'kr.co.pluck.dubbingo.pro.monthly';
  static const proYearlyId = 'kr.co.pluck.dubbingo.pro.yearly';
  static const proMonthlyPriceText = '₩4,900'; // 표시용(실가격은 스토어 연동 시 대체)
  static const proYearlyPriceText = '₩39,000';
  // RevenueCat 공개 SDK 키 — 설정 후 채우면 구독 활성화. 비어 있으면 전원 무료.
  static const revenueCatKeyIos = '';
  static const revenueCatKeyAndroid = '';

  /// 공개 버킷의 storage key → public URL
  static String publicImageUrl(String key) =>
      '$supabaseUrl/storage/v1/object/public/$bucketImages/$key';

  /// 초대 더빙 공유 링크(웹 랜딩 → 앱 유도). 앱 딥링크 스킴은 별도.
  static String collabLink(String code) => '$siteBaseUrl/c/$code';
  static const collabScheme = 'kr.co.pluck.dubbingo';

  // 구글 로그인 — Google Cloud OAuth 클라이언트 ID
  //  - googleWebClientId: "웹 애플리케이션" 클라이언트 ID (Supabase에도 동일하게 등록)
  //  - googleIosClientId: iOS 클라이언트 ID (iOS 빌드 시 필요, 안드로이드는 비워도 됨)
  // 비어 있으면 구글 버튼이 안내 메시지를 띄운다.
  static const googleWebClientId = '';
  static const googleIosClientId = '';

  // 외부 링크 (프로필 화면)
  static const siteBaseUrl = 'https://webtoon-flax.vercel.app';
  static const termsUrl = '$siteBaseUrl/terms';
  static const privacyUrl = '$siteBaseUrl/privacy';
  static const guidelinesUrl = '$siteBaseUrl/guidelines';
  static const supportEmail = 'admin@pluck.co.kr';
}

/// 쩌렁쩌렁 브랜드 컬러 (웹과 동일 팔레트)
class AppColors {
  static const cream = Color(0xFFF3F0E8);
  static const card = Color(0xFFFFFCF5);
  static const paper = Color(0xFFFFFAF0);
  static const ink = Color(0xFF171512);
  static const inkSoft = Color(0xFF4D463E);
  static const muted = Color(0xFF7A6F61);
  static const faint = Color(0xFF978B7D);
  static const line = Color(0xFFD6D0C4);
  static const lineSoft = Color(0xFFE1DBD1);
  static const coral = Color(0xFFEF6F5E);
  static const teal = Color(0xFF5CC8BA);
  static const gold = Color(0xFFF0BD62);

  // 다크(스튜디오/퍼포머) 톤
  static const deviceDark = Color(0xFF080B0D);
  static const panelDark = Color(0xFF171512);
}

/// StyleSeed 그림자 토큰 — 절제된(미세한) 엘리베이션
/// card: 0 1px 3px /.04 · elevated: 0 4px 12px /.08 · modal: 0 8px 24px /.12
class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const elevated = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const modal = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

/// StyleSeed 모션 토큰 — fast 100 / normal 200 / slow 350
class AppMotion {
  static const fast = Duration(milliseconds: 100);
  static const normal = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 350);
  // 스프링(장난스러운 마이크로 인터랙션)
  static const spring = Cubic(0.34, 1.56, 0.64, 1);
  static const easeOutToken = Cubic(0, 0, 0.2, 1);
}
