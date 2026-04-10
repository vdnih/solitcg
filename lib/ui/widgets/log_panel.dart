import 'package:flutter/material.dart';
import '../theme/game_theme.dart';

/// ゲームログを表示する Flutter ウィジェット。
///
/// Flame キャンバスではなく Flutter レイヤーで描画することで、
/// カードや手札ゾーンとの重なりを防ぐ。
class LogPanel extends StatelessWidget {
  final List<String> logs;

  const LogPanel({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.6;
    final recentLogs = logs.length > 9 ? logs.sublist(logs.length - 9) : logs;

    return Container(
      width: panelWidth,
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GameTheme.logPanelBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < recentLogs.length; i++)
            Text(
              recentLogs[i],
              style: TextStyle(
                color: i == recentLogs.length - 1
                    ? GameTheme.logTextRecent
                    : GameTheme.logTextOld,
                fontSize: 11,
                height: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
