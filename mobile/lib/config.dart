import 'package:flutter/material.dart';

/// Supabase 연결 설정 (publishable 키는 클라이언트 공개용 — 안전)
class Env {
  static const supabaseUrl = 'https://brnjzvtvudkyjoxswuln.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_vqxNd4NX6GSb_MYFEPyOXg_88oe8PlP';

  // Storage 버킷 (웹과 공용)
  static const bucketRecordings = 'recordings';
  static const bucketVideos = 'rendered-videos';
}

/// 더빙고 브랜드 컬러 (웹과 동일 팔레트)
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
