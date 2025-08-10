import 'package:flutter_test/flutter_test.dart';
import 'package:solitcg/engine/loader.dart';
import 'package:solitcg/engine/types.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CardLoader loads cards from YAML files', () async {
    // Force load assets from bundle
    await _loadAssets();
    
    // Load all cards
    final cards = await CardLoader.loadAllCards();
    
    // Verify cards were loaded
    expect(cards, isNotEmpty);
    
    // Check specific card content
    final fieldCard = cards.firstWhere((c) => c.id == 'fld_x01');
    expect(fieldCard.name, '残響の講堂');
    expect(fieldCard.type, CardType.field);
    expect(fieldCard.abilities.length, 2);
    
    // Check ability details
    final playAbility = fieldCard.abilities.firstWhere((a) => a.when == TriggerWhen.onPlay);
    expect(playAbility.effects.length, 1);
    expect(playAbility.effects.first.op, 'draw');
    expect(playAbility.effects.first.params['count'], 2);
  });
}

Future<void> _loadAssets() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // This is a hack to preload assets in a test environment
  try {
    await rootBundle.loadString('assets/cards/index.yaml');
    await rootBundle.loadString('assets/cards/fld_x01.yaml');
    await rootBundle.loadString('assets/cards/fld_x02.yaml');
    await rootBundle.loadString('assets/cards/spl_x07.yaml');
  } catch (e) {
    print('Error loading assets: $e');
  }
}