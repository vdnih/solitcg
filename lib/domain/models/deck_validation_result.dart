/// デッキバリデーション結果
class DeckValidationResult {
  final bool isValid;
  final List<String> errors;
  
  DeckValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}
