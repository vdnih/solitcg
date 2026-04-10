import 'package:flutter/material.dart';
import '../theme/game_theme.dart';

/// ゲーム終了時の演出オーバーレイ。
///
/// [isWin] が true のとき勝利演出（金色タイトル + スケールイン）、
/// false のとき敗北演出（赤系タイトル + フェードイン）を表示する。
class GameOverOverlay extends StatefulWidget {
  final bool isWin;

  const GameOverOverlay({super.key, required this.isWin});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withOpacity(0.82),
        child: Center(
          child: ScaleTransition(
            scale: widget.isWin ? _scale : _fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTitle(),
                const SizedBox(height: 16),
                _buildSubtext(),
                const SizedBox(height: 48),
                _buildMenuButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    if (widget.isWin) {
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFF176), Color(0xFFFFD700)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(bounds),
        child: const Text(
          '勝利！',
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 4,
            shadows: [
              Shadow(
                color: Color(0xFFFFD700),
                blurRadius: 24,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      );
    } else {
      return const Text(
        '敗北...',
        style: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: Color(0xFFEF4444),
          letterSpacing: 4,
          shadows: [
            Shadow(
              color: Color(0xFF7F1D1D),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSubtext() {
    return Text(
      widget.isWin ? 'コンボを制した！' : 'またの挑戦を待っている',
      style: TextStyle(
        fontSize: 18,
        color: widget.isWin
            ? const Color(0xFFFEF9C3)
            : const Color(0xFF94A3B8),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.isWin
            ? GameTheme.selectionGlow
            : const Color(0xFF94A3B8),
        side: BorderSide(
          color: widget.isWin
              ? GameTheme.selectionGlow
              : const Color(0xFF475569),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'メニューに戻る',
        style: TextStyle(fontSize: 16, letterSpacing: 1),
      ),
    );
  }
}
