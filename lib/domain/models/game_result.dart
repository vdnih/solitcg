
/// 効果解決や処理の結果を表す。
class GameResult {
  final bool success;
  final String? error;
  final List<String> logs;

  const GameResult({required this.success, this.error, this.logs = const []});

  factory GameResult.success({List<String> logs = const []}) {
    return GameResult(success: true, logs: logs);
  }

  factory GameResult.failure(String error, {List<String> logs = const []}) {
    return GameResult(success: false, error: error, logs: logs);
  }
}
