import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';
import 'package:beachmatch_mobile/services/bracket_generator_service.dart';

void main() {
  group('Tournament Bracket Tests', () {
    test('12-pair Mixte Bracket FFT Seeding and 4 BYEs', () {
      final pairs = [
        const TournamentPair(id: "p1", player1Name: "Bernard", player1Rank: 434, player2Name: "Gloaguen", player2Rank: 341), // 775 -> TS1
        const TournamentPair(id: "p2", player1Name: "Hammadache", player1Rank: 453, player2Name: "Bellahsene", player2Rank: 369), // 822 -> TS2
        const TournamentPair(id: "p3", player1Name: "Argaud JM", player1Rank: 274, player2Name: "Argaud V", player2Rank: 630), // 904 -> TS3
        const TournamentPair(id: "p4", player1Name: "Aillaud", player1Rank: 287, player2Name: "Desmonts", player2Rank: 993), // 1280 -> TS4
        const TournamentPair(id: "p5", player1Name: "Boissonnade", player1Rank: 600, player2Name: "Cuadrado", player2Rank: 800),
        const TournamentPair(id: "p6", player1Name: "Ducarne", player1Rank: 1337, player2Name: "Mangirci", player2Rank: 657),
        const TournamentPair(id: "p7", player1Name: "Mateos H", player1Rank: 1858, player2Name: "Mateos S", player2Rank: 622),
        const TournamentPair(id: "p8", player1Name: "Baichere T", player1Rank: 1471, player2Name: "Baichere E", player2Rank: 1064),
        const TournamentPair(id: "p9", player1Name: "Pinlet", player1Rank: 1471, player2Name: "Barnabas", player2Rank: 1127),
        const TournamentPair(id: "p10", player1Name: "Cuvillier", player1Rank: 1858, player2Name: "Filomar", player2Rank: 1308),
        const TournamentPair(id: "p11", player1Name: "Pepino", player1Rank: 1858, player2Name: "Estampe", player2Rank: 1308),
        const TournamentPair(id: "p12", player1Name: "Simon", player1Rank: 1858, player2Name: "Guillot", player2Rank: 1308),
      ];

      final bracket = BracketGeneratorService.generateBracket(
        tournamentId: "toulon_mixte",
        category: "double_mixtes",
        registeredPairs: pairs,
        numCourts: 4,
      );

      expect(bracket.mainMatches.length, 15); // 8 R16 + 4 QF + 2 SF + 1 Final

      // Check R0 matches
      final m0 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 0 && m.matchIndex == 0);
      final m3 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 0 && m.matchIndex == 3);
      final m4 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 0 && m.matchIndex == 4);
      final m7 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 0 && m.matchIndex == 7);

      // Verify exact seed positions: TS2 & TS3 in top half, TS4 & TS1 in bottom half
      expect(m0.pair1?.seed, 2); // TS2 on top (Match 0 Slot 1)
      expect(m0.pair2?.isBye, true); // BYE opposite TS2
      expect(m0.winnerId, m0.pair1?.id); // Auto-advanced

      expect(m3.pair2?.seed, 3); // TS3 on top half (Match 3 Slot 2)
      expect(m3.pair1?.isBye, true); // BYE opposite TS3
      expect(m3.winnerId, m3.pair2?.id); // Auto-advanced

      expect(m4.pair1?.seed, 4); // TS4 on bottom half (Match 4 Slot 1)
      expect(m4.pair2?.isBye, true); // BYE opposite TS4
      expect(m4.winnerId, m4.pair1?.id); // Auto-advanced

      expect(m7.pair2?.seed, 1); // TS1 on bottom (Match 7 Slot 2)
      expect(m7.pair1?.isBye, true); // BYE opposite TS1
      expect(m7.winnerId, m7.pair2?.id); // Auto-advanced

      // Check Quarter-finals (Round 1) progression
      final qf0 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 1 && m.matchIndex == 0);
      final qf1 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 1 && m.matchIndex == 1);
      final qf2 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 1 && m.matchIndex == 2);
      final qf3 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 1 && m.matchIndex == 3);

      expect(qf0.pair1?.id, m0.pair1?.id); // TS2 already in QF
      expect(qf1.pair2?.id, m3.pair2?.id); // TS3 already in QF
      expect(qf2.pair1?.id, m4.pair1?.id); // TS4 already in QF
      expect(qf3.pair2?.id, m7.pair2?.id); // TS1 already in QF

      // Test playing Match 1 (between two non-seeded pairs)
      final m1 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 0 && m.matchIndex == 1);
      expect(m1.isBye, false);
      expect(m1.pair1 != null, true);
      expect(m1.pair2 != null, true);

      final updated = BracketGeneratorService.recordMatchScore(
        bracket: bracket,
        matchId: m1.id,
        score: "6/3 6/4",
        winnerId: m1.pair1!.id,
      );

      // Winner advances to QF against TS2
      final updatedQf0 = updated.mainMatches.firstWhere((m) => m.roundIndex == 1 && m.matchIndex == 0);
      expect(updatedQf0.pair2?.id, m1.pair1!.id);

      // Loser goes to consolation
      final conso0 = updated.consolationMatches.firstWhere((m) => m.id == m1.consolationMatchId);
      expect(conso0.pair1?.id, m1.pair2!.id);
    });

    test('6-pair Pool Tournament Generator & Standings', () {
      final pouleA = [
        const TournamentPair(id: "ha1", player1Name: "Argaud JM", player1Rank: 274, player2Name: "Bernard F", player2Rank: 434, seed: 1),
        const TournamentPair(id: "ha2", player1Name: "Pepino Q", player1Rank: 1858, player2Name: "Hammadache A", player2Rank: 453),
        const TournamentPair(id: "ha3", player1Name: "Baichere T", player1Rank: 1471, player2Name: "Cuvillier C", player2Rank: 1858),
      ];

      final pouleB = [
        const TournamentPair(id: "hb1", player1Name: "Nguyen-Khac D", player1Rank: 665, player2Name: "Mateos P", player2Rank: 397, seed: 2),
        const TournamentPair(id: "hb2", player1Name: "Aillaud G", player1Rank: 287, player2Name: "Faucon T", player2Rank: 840),
        const TournamentPair(id: "hb3", player1Name: "Pinlet R", player1Rank: 1471, player2Name: "Ducarne N", player2Rank: 1337),
      ];

      var bracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: "toulon_hommes",
        category: "double_messieurs",
        pouleAPairs: pouleA,
        pouleBPairs: pouleB,
        numCourts: 4,
      );

      expect(bracket.format, "pools_and_bracket");
      expect(bracket.pools.length, 2);
      expect(bracket.pools[0].matches.length, 3);
      expect(bracket.pools[1].matches.length, 3);
      expect(bracket.mainMatches.length, 5); // DF1, DF2, Finale, P3_4, P5_6

      // Play all matches in Poule A
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_a",
        matchId: "pa_0",
        score: "6/4 6/2",
        winnerId: "ha1",
      );
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_a",
        matchId: "pa_1",
        score: "6/1 6/1",
        winnerId: "ha1",
      );
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_a",
        matchId: "pa_2",
        score: "7/5 6/3",
        winnerId: "ha2",
      );

      final standingsA = bracket.pools[0].calculateStandings();
      expect(standingsA[0].pair.id, "ha1"); // 2 wins -> 1st
      expect(standingsA[1].pair.id, "ha2"); // 1 win -> 2nd
      expect(standingsA[2].pair.id, "ha3"); // 0 win -> 3rd

      // Test manual free editing (Saisie libre JAT)
      final overridden = BracketGeneratorService.manualUpdateMatchPair(
        bracket: bracket,
        matchId: "final_df1",
        slot: 1,
        pair: pouleA[1], // Force ha2 instead of ha1
      );
      final df1 = overridden.mainMatches.firstWhere((m) => m.id == "final_df1");
      expect(df1.pair1?.id, "ha2");
    });

    test('Reset Match Score (Remise à zéro / non joué)', () {
      final pairs = [
        const TournamentPair(id: "p1", player1Name: "P1", player1Rank: 100, player2Name: "P1b", player2Rank: 100),
        const TournamentPair(id: "p2", player1Name: "P2", player1Rank: 200, player2Name: "P2b", player2Rank: 200),
      ];

      var bracket = BracketGeneratorService.generateBracket(
        tournamentId: "test_reset",
        category: "double_mixtes",
        registeredPairs: pairs,
        numCourts: 1,
      );

      final m1 = bracket.mainMatches.firstWhere((m) => m.roundIndex == 0 && m.matchIndex == 1);
      final scored = BracketGeneratorService.recordMatchScore(
        bracket: bracket,
        matchId: m1.id,
        score: "6/4 6/4",
        winnerId: m1.pair1!.id,
      );

      final scoredM1 = scored.mainMatches.firstWhere((m) => m.id == m1.id);
      expect(scoredM1.isCompleted, true);
      expect(scoredM1.score, "6/4 6/4");

      // Reset the match
      final reset = BracketGeneratorService.resetMatchScore(
        bracket: scored,
        matchId: m1.id,
      );

      final resetM1 = reset.mainMatches.firstWhere((m) => m.id == m1.id);
      expect(resetM1.isCompleted, false);
      expect(resetM1.score, null);
      expect(resetM1.winnerId, null);
      expect(resetM1.status, 'scheduled');

      // Next match slot should be cleared
      final nextMatch = reset.mainMatches.firstWhere((m) => m.id == m1.nextMatchId);
      expect(nextMatch.pair2, null);
    });
  });
}
