
/// 効果解決や処理の結果を表す。
class GameResult {
  final bool success;
  final bool awaitingChoice;
  final String? error;
  final List<String> logs;

  const GameResult({
    required this.success,
    this.awaitingChoice = false,
    this.error,
    this.logs = const [],
  });

  factory GameResult.success({List<String> logs = const []}) {
    return GameResult(success: true, logs: logs);
  }

  factory GameResult.failure(String error, {List<String> logs = const []}) {
    return GameResult(success: false, error: error, logs: logs);
  }

  /// プレイヤーのカード選択を待っている状態。トリガー解決は一時停止。
  factory GameResult.pending({List<String> logs = const []}) {
    return GameResult(success: true, awaitingChoice: true, logs: logs);
  }
}
