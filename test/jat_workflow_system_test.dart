import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';

void main() {
  group('JAT Official 5-Step Workflow & Regulatory Checkpoint Tests', () {
    test('Step 0 (Inscriptions) is active when pairs < 4', () {
      final bracket = TournamentBracket(
        tournamentId: 'tournoi_test',
        pairs: [
          const TournamentPair(id: 'p1', player1Name: 'A', player2Name: 'B', seed: 1),
          const TournamentPair(id: 'p2', player1Name: 'C', player2Name: 'D', seed: 2),
        ],
        updatedAt: DateTime.now(),
      );

      final pairCount = bracket.pairs.length;
      final step1Complete = pairCount >= 4;
      final step2Complete = bracket.mainMatches.isNotEmpty || bracket.pools.isNotEmpty;

      expect(pairCount, 2);
      expect(step1Complete, isFalse);
      expect(step2Complete, isFalse);
    });

    test('Step 1 (Tirage) is unlocked when pairs >= 4 and matches are empty', () {
      final bracket = TournamentBracket(
        tournamentId: 'tournoi_test',
        pairs: [
          const TournamentPair(id: 'p1', player1Name: 'A', player2Name: 'B', seed: 1),
          const TournamentPair(id: 'p2', player1Name: 'C', player2Name: 'D', seed: 2),
          const TournamentPair(id: 'p3', player1Name: 'E', player2Name: 'F'),
          const TournamentPair(id: 'p4', player1Name: 'G', player2Name: 'H'),
        ],
        updatedAt: DateTime.now(),
      );

      final pairCount = bracket.pairs.length;
      final step1Complete = pairCount >= 4;
      final step2Complete = bracket.mainMatches.isNotEmpty || bracket.pools.isNotEmpty;

      expect(step1Complete, isTrue);
      expect(step2Complete, isFalse);
    });

    test('Step 3 (Scores) tracks completed vs total matches accurately', () {
      const p1 = TournamentPair(id: 'p1', player1Name: 'A', player2Name: 'B');
      const p2 = TournamentPair(id: 'p2', player1Name: 'C', player2Name: 'D');

      final bracket = TournamentBracket(
        tournamentId: 'tournoi_test',
        pairs: [p1, p2],
        mainMatches: [
          const BracketMatch(
            id: 'm1',
            roundIndex: 0,
            roundName: 'Demi-Finale 1',
            matchIndex: 0,
            pair1: p1,
            pair2: p2,
            score: '6/2 6/4',
            winnerId: 'p1',
            court: 1,
            status: 'completed',
          ),
          const BracketMatch(
            id: 'm2',
            roundIndex: 0,
            roundName: 'Demi-Finale 2',
            matchIndex: 1,
            court: 2,
            status: 'in_progress',
          ),
        ],
        updatedAt: DateTime.now(),
      );

      int totalMatches = bracket.mainMatches.length;
      int completedMatches = bracket.mainMatches.where((m) => m.isCompleted).length;
      int inProgressMatches = bracket.mainMatches.where((m) => m.isInProgress).length;

      expect(totalMatches, 2);
      expect(completedMatches, 1);
      expect(inProgressMatches, 1);
      expect(completedMatches == totalMatches, isFalse);
    });

    test('Step 4 & 5 (Clôture & Homologation) complete when 100% matches finished', () {
      const p1 = TournamentPair(id: 'p1', player1Name: 'A', player2Name: 'B');
      const p2 = TournamentPair(id: 'p2', player1Name: 'C', player2Name: 'D');

      final bracket = TournamentBracket(
        tournamentId: 'tournoi_test',
        pairs: [p1, p2],
        status: 'finished',
        mainMatches: [
          const BracketMatch(
            id: 'm1',
            roundIndex: 0,
            roundName: 'Finale',
            matchIndex: 0,
            pair1: p1,
            pair2: p2,
            score: '6/4 6/3',
            winnerId: 'p1',
            court: 1,
            status: 'completed',
          ),
        ],
        updatedAt: DateTime.now(),
      );

      int totalMatches = bracket.mainMatches.length;
      int completedMatches = bracket.mainMatches.where((m) => m.isCompleted).length;
      final step4Complete = totalMatches > 0 && completedMatches == totalMatches;
      final step5Complete = step4Complete && bracket.status == 'finished';

      expect(step4Complete, isTrue);
      expect(step5Complete, isTrue);
    });
  });
}
