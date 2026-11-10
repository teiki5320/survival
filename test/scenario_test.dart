import 'package:flutter_test/flutter_test.dart';
import 'package:train_cosy/data/cards_data.dart';
import 'package:train_cosy/models/reigns_engine.dart';

void main() {
  test('le scénario compte 14 gares, chacune avec au moins une carte', () {
    expect(trainCosyScenario.length, 14);
    for (final segment in trainCosyScenario) {
      expect(segment.gareCards(<String>{}), isNotEmpty);
    }
  });

  test('les cartes de gare ont un identifiant unique et deux choix libellés', () {
    final ids = <String>{};
    for (final segment in trainCosyScenario) {
      for (final carte in segment.gareCards(<String>{})) {
        expect(ids.add(carte.id), isTrue, reason: 'identifiant en double : ${carte.id}');
        expect(carte.left.label, isNotEmpty);
        expect(carte.right.label, isNotEmpty);
      }
    }
  });

  test('chaque fin possible a un titre et un texte', () {
    final fin = resolveTrainCosyEnding({for (final s in Stat.values) s: 50}, <String>{});
    expect(endings.containsKey(fin), isTrue);
    expect(endings[fin]!.title, isNotEmpty);
    expect(endings[fin]!.body, isNotEmpty);
  });
}
