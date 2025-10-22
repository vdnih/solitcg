import '../../core/game_state.dart';
import '../models/game_result.dart';

/// カード効果の基本となる抽象クラス（コマンドパターン）。
///
/// すべての具体的なカード効果（ドロー、ダメージなど）は、このクラスを継承し、
/// `execute` メソッドを実装する必要があります。
/// これにより、効果のロジックをオブジェクトとしてカプセル化し、
/// 再利用性、組み合わせの容易さ、テストのしやすさを向上させます。
abstract class CardEffectCommand {
  /// コマンドを実行し、ゲーム状態を変更します。
  ///
  /// [state] 現在のゲーム状態。
  /// 戻り値として、処理の成功・失敗とログを含む [GameResult] を返します。
  GameResult execute(GameState state);
}
