import 'package:flutter/material.dart';
import '../../domain/models/card_data.dart';

/// ゲーム画面全体で使用するビジュアル定数。
/// すべての色・グラデーション・タイポグラフィはここで一元管理する。
class GameTheme {
  GameTheme._();

  // ─── ボード背景 ───────────────────────────────────────────
  static const Color boardBg = Color(0xFF0D1117);
  static const Color zoneBg = Color(0xFF161B22);
  static const Color zoneBorder = Color(0xFF30363D);

  // ─── ゾーン背景 ───────────────────────────────────────────
  static const Color handZoneBg = Color(0xFF0F2014);
  static const Color boardZoneBg = Color(0xFF0F0F2A);
  static const Color domainZoneBg = Color(0xFF1A1020);
  static const Color graveZoneBg = Color(0xFF1A1010);

  // ─── HUD ─────────────────────────────────────────────────
  static const Color hudBg = Color(0xCC0D1117);
  static const Color hudLifeColor = Color(0xFF22C55E);
  static const Color hudTextColor = Color(0xFFE2E8F0);
  static const Color hudDimColor = Color(0xFF64748B);

  // ─── 選択グロー ───────────────────────────────────────────
  static const Color selectionGlow = Color(0xFFFFD700);
  static const Color selectionBorder = Color(0xFFFFD700);

  // ─── ログパネル ───────────────────────────────────────────
  static const Color logPanelBg = Color(0xCC0D1117);
  static const Color logTextRecent = Color(0xFFE2E8F0);
  static const Color logTextOld = Color(0xFF64748B);

  // ─── カード種別グラデーション (dark, light) ──────────────
  static List<Color> cardGradient(CardType type) {
    switch (type) {
      case CardType.monster:
        return [const Color(0xFF5C3317), const Color(0xFF9B6B3A)];
      case CardType.ritual:
        return [const Color(0xFF3B1F5E), const Color(0xFF7C4DA0)];
      case CardType.spell:
        return [const Color(0xFF1A4731), const Color(0xFF2E8B57)];
      case CardType.arcane:
        return [const Color(0xFF0F3D3D), const Color(0xFF1F7A7A)];
      case CardType.artifact:
        return [const Color(0xFF5C3D00), const Color(0xFFB07D20)];
      case CardType.relic:
        return [const Color(0xFF5C2200), const Color(0xFFB04820)];
      case CardType.equip:
        return [const Color(0xFF4A4A00), const Color(0xFF9A9A00)];
      case CardType.domain:
        return [const Color(0xFF0F2A5C), const Color(0xFF1F5CA0)];
    }
  }

  /// カード種別の表示名（日本語）
  static String cardTypeName(CardType type) {
    switch (type) {
      case CardType.monster:
        return 'モンスター';
      case CardType.ritual:
        return 'リチュアル';
      case CardType.spell:
        return 'スペル';
      case CardType.arcane:
        return 'アルカナ';
      case CardType.artifact:
        return 'アーティファクト';
      case CardType.relic:
        return 'レリック';
      case CardType.equip:
        return '装備';
      case CardType.domain:
        return 'ドメイン';
    }
  }

  /// カード種別のアクセントカラー（バッジ・ラベル用）
  static Color cardAccentColor(CardType type) {
    switch (type) {
      case CardType.monster:
        return const Color(0xFFB07D40);
      case CardType.ritual:
        return const Color(0xFF9B6BBF);
      case CardType.spell:
        return const Color(0xFF3DBF7A);
      case CardType.arcane:
        return const Color(0xFF3DBFBF);
      case CardType.artifact:
        return const Color(0xFFCFA040);
      case CardType.relic:
        return const Color(0xFFCF6040);
      case CardType.equip:
        return const Color(0xFFCFCF40);
      case CardType.domain:
        return const Color(0xFF4080CF);
    }
  }
}
