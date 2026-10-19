import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';
import 'package:beachmatch_mobile/services/bracket_generator_service.dart';

void main() {
  group('Bracket Generator for all pair counts (8 to 16+)', () {
    for (int count = 4; count <= 20; count++) {
      test('Generates cleanly for $count pairs', () {
        final pairs = List.generate(
          count,
          (i) => TournamentPair(
            id: 'pair_$i',
            player1Name: 'Joueur A$i',
            player2Name: 'Joueur B$i',
            player1Rank: (i + 1) * 10,
            player2Rank: (i + 1) * 10,
          ),
        );

        final bracket = BracketGeneratorService.generateBracket(
          tournamentId: 'test_tourn_$count',
          category: 'double_hommes',
          registeredPairs: pairs,
          numCourts: 4,
        );

        expect(bracket.mainMatches.isNotEmpty, isTrue);
        expect(bracket.pairs.length, equals(count));

        // Verify all non-bye matches have valid structure
        for (final m in bracket.mainMatches) {
          expect(m.roundIndex, greaterThanOrEqualTo(0));
          expect(m.roundName.isNotEmpty, isTrue);
        }

        // Verify that round 0 has the expected number of matches
        final r0Matches = bracket.mainMatches.where((m) => m.roundIndex == 0).toList();
        final expectedR0 = BracketGeneratorService.getBracketSize(bracket.pairs.length) ~/ 2;
        expect(r0Matches.length, equals(expectedR0));
      });
    }

    test('Pools generation works for 8 pairs (2 pools of 4)', () {
      final pA = List.generate(4, (i) => TournamentPair(id: 'pa_$i', player1Name: 'A$i', player2Name: 'A$i'));
      final pB = List.generate(4, (i) => TournamentPair(id: 'pb_$i', player1Name: 'B$i', player2Name: 'B$i'));

      final bracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: 'test_pools_8',
        category: 'double_dames',
        pouleAPairs: pA,
        pouleBPairs: pB,
      );

      expect(bracket.pools.length, equals(2));
      expect(bracket.pools[0].matches.length, equals(6)); // 4 teams = 6 matches
      expect(bracket.pools[1].matches.length, equals(6));
      expect(bracket.mainMatches.isNotEmpty, isTrue);
    });

    test('Single pool generation works for 5 pairs (Poule Unique BT 25)', () {
      final pairs5 = List.generate(
        5,
        (i) => TournamentPair(
          id: "p_$i",
          player1Name: "J1_$i",
          player2Name: "J2_$i",
        ),
      );

      final bracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: "FED_82691000",
        category: "double_dames",
        pouleAPairs: pairs5,
        pouleBPairs: const [],
      );

      expect(bracket.pools.length, equals(1));
      expect(bracket.pools[0].name, equals("Poule Unique"));
      expect(bracket.pools[0].pairs.length, equals(5));
      expect(bracket.pools[0].matches.length, equals(10)); // 5*4/2 = 10 matches!
    });
  });
}
