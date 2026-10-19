import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';
import 'package:beachmatch_mobile/services/bracket_generator_service.dart';

void main() {
  group('BracketGeneratorService.swapPairs Tests', () {
    test('Swapping two unseeded pairs in Round 0 swaps them cleanly', () {
      final pairs = List.generate(
        8,
        (i) => TournamentPair(
          id: 'p_$i',
          player1Name: 'P1_$i',
          player2Name: 'P2_$i',
          player1Rank: 100 + i,
          player2Rank: 100 + i,
        ),
      );

      final bracket = BracketGeneratorService.generateBracket(
        tournamentId: 't1',
        registeredPairs: pairs,
      );

      final m0 = bracket.mainMatches.firstWhere((m) => m.id == 'main_0_0');
      final m1 = bracket.mainMatches.firstWhere((m) => m.id == 'main_0_1');

      final initialPairM0S1 = m0.pair1!;
      final initialPairM1S2 = m1.pair2!;

      final swapped = BracketGeneratorService.swapPairs(
        bracket: bracket,
        matchIdA: m0.id,
        slotA: 1,
        matchIdB: m1.id,
        slotB: 2,
      );

      final updatedM0 = swapped.mainMatches.firstWhere((m) => m.id == 'main_0_0');
      final updatedM1 = swapped.mainMatches.firstWhere((m) => m.id == 'main_0_1');

      expect(updatedM0.pair1?.id, initialPairM1S2.id);
      expect(updatedM1.pair2?.id, initialPairM0S1.id);
    });

    test('Swapping within the same match inverts slot 1 and slot 2', () {
      final pairs = List.generate(
        8,
        (i) => TournamentPair(
          id: 'p_$i',
          player1Name: 'P1_$i',
          player2Name: 'P2_$i',
          player1Rank: 100 + i,
          player2Rank: 100 + i,
        ),
      );

      final bracket = BracketGeneratorService.generateBracket(
        tournamentId: 't1',
        registeredPairs: pairs,
      );

      final m0 = bracket.mainMatches.firstWhere((m) => m.id == 'main_0_0');
      final p1 = m0.pair1!;
      final p2 = m0.pair2!;

      final swapped = BracketGeneratorService.swapPairs(
        bracket: bracket,
        matchIdA: m0.id,
        slotA: 1,
        matchIdB: m0.id,
        slotB: 2,
      );

      final updatedM0 = swapped.mainMatches.firstWhere((m) => m.id == 'main_0_0');
      expect(updatedM0.pair1?.id, p2.id);
      expect(updatedM0.pair2?.id, p1.id);
    });

    test('Swapping with a BYE updates winner progression to next round', () {
      // 12 pairs in a 16-draw means 4 BYEs
      final pairs = List.generate(
        12,
        (i) => TournamentPair(
          id: 'p_$i',
          player1Name: 'P1_$i',
          player2Name: 'P2_$i',
          player1Rank: 10 + i,
          player2Rank: 10 + i,
        ),
      );

      final bracket = BracketGeneratorService.generateBracket(
        tournamentId: 't1',
        registeredPairs: pairs,
      );

      // Find a match with a BYE in round 0
      final byeMatch = bracket.mainMatches.firstWhere((m) => m.roundIndex == 0 && m.isBye);
      final regularMatch = bracket.mainMatches.firstWhere((m) => m.roundIndex == 0 && !m.isBye);

      final nonByePair = byeMatch.pair1?.isBye == true ? byeMatch.pair2! : byeMatch.pair1!;
      final regularPair = regularMatch.pair1!;

      // Swap regularPair into the BYE match slot of nonByePair
      final slotInByeMatch = byeMatch.pair1?.id == nonByePair.id ? 1 : 2;

      final swapped = BracketGeneratorService.swapPairs(
        bracket: bracket,
        matchIdA: byeMatch.id,
        slotA: slotInByeMatch,
        matchIdB: regularMatch.id,
        slotB: 1,
      );

      final updatedByeMatch = swapped.mainMatches.firstWhere((m) => m.id == byeMatch.id);
      final updatedRegularMatch = swapped.mainMatches.firstWhere((m) => m.id == regularMatch.id);

      // The byeMatch should now have regularPair as winner because it plays the BYE
      expect(updatedByeMatch.isBye, true);
      expect(updatedByeMatch.winnerId, regularPair.id);

      // And in next round, the regularPair should now be propagated
      final nextMatch = swapped.mainMatches.firstWhere((m) => m.id == updatedByeMatch.nextMatchId);
      final propagatedPair = updatedByeMatch.nextMatchSlot == 1 ? nextMatch.pair1 : nextMatch.pair2;
      expect(propagatedPair?.id, regularPair.id);

      // And updatedRegularMatch should now have nonByePair
      expect(updatedRegularMatch.pair1?.id, nonByePair.id);
    });
  });
}
