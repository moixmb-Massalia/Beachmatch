import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';
import 'package:beachmatch_mobile/services/bracket_generator_service.dart';
import 'package:beachmatch_mobile/services/tournament_pdf_service.dart';

void main() {
  group('Single Pool Palmares Resolution Tests', () {
    test('Poule Unique (4 pairs) correctly resolves Winner and Runner-up from standings', () {
      const pair1 = TournamentPair(
        id: 'p1',
        player1Name: 'CHAZAL Margaux',
        player2Name: 'GAUTIER Sophie',
        seed: 1,
      );
      const pair2 = TournamentPair(
        id: 'p2',
        player1Name: 'MOREAU Julie',
        player2Name: 'PETIT Laura',
        seed: 2,
      );
      const pair3 = TournamentPair(
        id: 'p3',
        player1Name: 'DURAND Claire',
        player2Name: 'LEROY Camille',
      );
      const pair4 = TournamentPair(
        id: 'p4',
        player1Name: 'ROUX Lea',
        player2Name: 'BONNET Emma',
      );

      final bracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: 'tournoi_test_dd',
        category: 'DD',
        pouleAPairs: [pair1, pair2, pair3, pair4],
        pouleBPairs: const [], // Poule Unique !
        finalPhaseType: 'direct_finals',
        numCourts: 2,
      );

      expect(bracket.pools.length, equals(1));
      expect(bracket.mainMatches.isEmpty, isTrue);

      final pool = bracket.pools.first;
      // Mark matches as completed:
      // Pair1 wins all matches 6-0
      final updatedMatches = pool.matches.map((m) {
        if (m.pair1?.id == 'p1' || m.pair2?.id == 'p1') {
          final isP1Slot1 = m.pair1?.id == 'p1';
          return m.copyWith(
            status: 'completed',
            score: isP1Slot1 ? '6-0' : '0-6',
            winnerId: 'p1',
          );
        } else if (m.pair1?.id == 'p2' || m.pair2?.id == 'p2') {
          final isP2Slot1 = m.pair1?.id == 'p2';
          return m.copyWith(
            status: 'completed',
            score: isP2Slot1 ? '6-2' : '2-6',
            winnerId: 'p2',
          );
        } else {
          return m.copyWith(
            status: 'completed',
            score: '6-4',
            winnerId: m.pair1?.id,
          );
        }
      }).toList();

      final completedBracket = bracket.copyWith(
        pools: [pool.copyWith(matches: updatedMatches)],
      );

      final (winner, runnerUp, third) = TournamentPdfService.resolvePalmares(completedBracket);

      expect(winner, isNotNull);
      expect(winner!.id, equals('p1'));
      expect(runnerUp, isNotNull);
      expect(runnerUp!.id, equals('p2'));
      expect(third, isNotNull);

      // Verify text summary contains the winner and runner-up names instead of "En cours..."
      final tournament = TournamentModel(
        id: 'tournoi_test_dd',
        name: 'BT 25 Dames FFT',
        category: 'BT 25',
        club: 'Beach Club Test',
        location: 'Marseille',
        dateString: '18/10/2026',
        distance: 0.0,
        referee: 'Christelle Dugols',
      );

      final fullSummary = TournamentPdfService.generateFullTournamentTextSummary(
        tournament: tournament,
        brackets: [completedBracket],
      );

      expect(fullSummary.contains("CHAZAL"), isTrue);
      expect(fullSummary.contains("MOREAU"), isTrue);
      expect(fullSummary.contains("En cours..."), isFalse);
    });
  });
}
