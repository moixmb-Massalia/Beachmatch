import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';
import 'package:beachmatch_mobile/services/bracket_generator_service.dart';

void main() {
  group('Smart Court Assignment Tests', () {
    test('generatePoolsAndBracket assigns Court 1 to TS1 and Court 2 to TS2', () {
      final pouleAPairs = [
        const TournamentPair(id: 'ts1', player1Name: 'P1', player2Name: 'P2', player1Rank: 1, player2Rank: 1, seed: 1),
        const TournamentPair(id: 'pa2', player1Name: 'P3', player2Name: 'P4', player1Rank: 10, player2Rank: 10),
        const TournamentPair(id: 'pa3', player1Name: 'P5', player2Name: 'P6', player1Rank: 20, player2Rank: 20),
        const TournamentPair(id: 'pa4', player1Name: 'P7', player2Name: 'P8', player1Rank: 30, player2Rank: 30),
      ];

      final pouleBPairs = [
        const TournamentPair(id: 'ts2', player1Name: 'P9', player2Name: 'P10', player1Rank: 2, player2Rank: 2, seed: 2),
        const TournamentPair(id: 'pb2', player1Name: 'P11', player2Name: 'P12', player1Rank: 11, player2Rank: 11),
        const TournamentPair(id: 'pb3', player1Name: 'P13', player2Name: 'P14', player1Rank: 21, player2Rank: 21),
        const TournamentPair(id: 'pb4', player1Name: 'P15', player2Name: 'P16', player1Rank: 31, player2Rank: 31),
      ];

      final bracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: 'tourney_test',
        category: 'double_messieurs',
        pouleAPairs: pouleAPairs,
        pouleBPairs: pouleBPairs,
        finalPhaseType: 'crossover_semis',
        numCourts: 4,
      );

      expect(bracket.numCourts, equals(4));

      final poolA = bracket.pools.firstWhere((p) => p.id == 'poule_a');
      final poolB = bracket.pools.firstWhere((p) => p.id == 'poule_b');

      // Poule A matches containing TS1 (matches 0, 2, 4) should be on Court 1
      expect(poolA.matches[0].court, equals(1));
      expect(poolA.matches[2].court, equals(1));
      expect(poolA.matches[4].court, equals(1));

      // Poule A other matches (matches 1, 3, 5) should be on Court 3
      expect(poolA.matches[1].court, equals(3));
      expect(poolA.matches[3].court, equals(3));
      expect(poolA.matches[5].court, equals(3));

      // Poule B matches containing TS2 (matches 0, 2, 4) should be on Court 2
      expect(poolB.matches[0].court, equals(2));
      expect(poolB.matches[2].court, equals(2));
      expect(poolB.matches[4].court, equals(2));

      // Poule B other matches (matches 1, 3, 5) should be on Court 4
      expect(poolB.matches[1].court, equals(4));
      expect(poolB.matches[3].court, equals(4));
      expect(poolB.matches[5].court, equals(4));

      // Final matches
      final finale = bracket.mainMatches.firstWhere((m) => m.matchCode == 'FINALE');
      expect(finale.court, equals(1)); // Court Central

      final df1 = bracket.mainMatches.firstWhere((m) => m.matchCode == 'DF1');
      expect(df1.court, equals(1));

      final df2 = bracket.mainMatches.firstWhere((m) => m.matchCode == 'DF2');
      expect(df2.court, equals(2));

      final p34 = bracket.mainMatches.firstWhere((m) => m.matchCode == 'PLACE_3_4');
      expect(p34.court, equals(2));
    });

    test('generatePoolsAndBracket with 2 courts wraps around cleanly', () {
      final pouleAPairs = [
        const TournamentPair(id: 'ts1', player1Name: 'P1', player2Name: 'P2', player1Rank: 1, player2Rank: 1, seed: 1),
        const TournamentPair(id: 'pa2', player1Name: 'P3', player2Name: 'P4', player1Rank: 10, player2Rank: 10),
      ];

      final pouleBPairs = [
        const TournamentPair(id: 'ts2', player1Name: 'P9', player2Name: 'P10', player1Rank: 2, player2Rank: 2, seed: 2),
        const TournamentPair(id: 'pb2', player1Name: 'P11', player2Name: 'P12', player1Rank: 11, player2Rank: 11),
      ];

      final bracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: 'tourney_test_2courts',
        category: 'double_messieurs',
        pouleAPairs: pouleAPairs,
        pouleBPairs: pouleBPairs,
        finalPhaseType: 'direct_finals',
        numCourts: 2,
      );

      final poolA = bracket.pools.firstWhere((p) => p.id == 'poule_a');
      final poolB = bracket.pools.firstWhere((p) => p.id == 'poule_b');

      expect(poolA.matches[0].court, equals(1));
      expect(poolB.matches[0].court, equals(2));

      final finale = bracket.mainMatches.firstWhere((m) => m.matchCode == 'FINALE');
      expect(finale.court, equals(1));
    });

    test('generateBracket (Elimination) assigns Court 1 to TS1, Court 2 to TS2, and Court 1 to Finale', () {
      final pairs = [
        const TournamentPair(id: 'pair_1', player1Name: 'Alice', player2Name: 'Bob', player1Rank: 1, player2Rank: 2),
        const TournamentPair(id: 'pair_2', player1Name: 'Charlie', player2Name: 'Dave', player1Rank: 5, player2Rank: 6),
        const TournamentPair(id: 'pair_3', player1Name: 'Eve', player2Name: 'Frank', player1Rank: 10, player2Rank: 12),
        const TournamentPair(id: 'pair_4', player1Name: 'Grace', player2Name: 'Heidi', player1Rank: 20, player2Rank: 25),
        const TournamentPair(id: 'pair_5', player1Name: 'Ivan', player2Name: 'Judy', player1Rank: 30, player2Rank: 35),
        const TournamentPair(id: 'pair_6', player1Name: 'Mallory', player2Name: 'Niaj', player1Rank: 40, player2Rank: 45),
        const TournamentPair(id: 'pair_7', player1Name: 'Oscar', player2Name: 'Peggy', player1Rank: 50, player2Rank: 55),
        const TournamentPair(id: 'pair_8', player1Name: 'Sybil', player2Name: 'Trent', player1Rank: 60, player2Rank: 65),
      ];

      final bracket = BracketGeneratorService.generateBracket(
        tournamentId: 'bracket_test',
        category: 'double_mixtes',
        registeredPairs: pairs,
        numCourts: 4,
      );

      final round0Matches = bracket.mainMatches.where((m) => m.roundIndex == 0).toList();

      // TS1 match must be on Court 1
      final ts1Match = round0Matches.firstWhere((m) => m.pair1?.seed == 1 || m.pair2?.seed == 1);
      expect(ts1Match.court, equals(1));

      // TS2 match must be on Court 2
      final ts2Match = round0Matches.firstWhere((m) => m.pair1?.seed == 2 || m.pair2?.seed == 2);
      expect(ts2Match.court, equals(2));

      // Grande Finale must be on Court 1
      final finale = bracket.mainMatches.last;
      expect(finale.court, equals(1));
    });
  });
}
