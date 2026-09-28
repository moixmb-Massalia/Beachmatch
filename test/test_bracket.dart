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
      expect(bracket.mainMatches.length, 3); // Finale (1-2), P3_4 (3-4), P5_6 (5-6)

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

      // Play all matches in Poule B
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_b",
        matchId: "pb_0",
        score: "6/3 6/3",
        winnerId: "hb1",
      );
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_b",
        matchId: "pb_1",
        score: "6/2 6/2",
        winnerId: "hb1",
      );
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_b",
        matchId: "pb_2",
        score: "6/4 6/4",
        winnerId: "hb2",
      );

      // Verify Direct Finals FFT placement (1A vs 1B, 2A vs 2B, 3A vs 3B)
      final finale = bracket.mainMatches.firstWhere((m) => m.id == "final_fin");
      final p34 = bracket.mainMatches.firstWhere((m) => m.id == "final_p34");
      final p56 = bracket.mainMatches.firstWhere((m) => m.id == "final_p56");

      expect(finale.pair1?.id, "ha1"); // 1er Poule A
      expect(finale.pair2?.id, "hb1"); // 1er Poule B
      expect(p34.pair1?.id, "ha2");    // 2e Poule A
      expect(p34.pair2?.id, "hb2");    // 2e Poule B
      expect(p56.pair1?.id, "ha3");    // 3e Poule A
      expect(p56.pair2?.id, "hb3");    // 3e Poule B

      // Test live updatePair propagation
      final updatedHa1 = standingsA[0].pair.copyWith(
        player1Name: "Argaud Modifié",
        player1Rank: 100,
      );
      bracket = BracketGeneratorService.updatePair(
        bracket: bracket,
        updatedPair: updatedHa1,
      );

      // Verify propagation in global pairs, pools, and final matches
      expect(bracket.pairs.firstWhere((p) => p.id == "ha1").player1Name, "Argaud Modifié");
      expect(bracket.pools[0].pairs.firstWhere((p) => p.id == "ha1").player1Name, "Argaud Modifié");
      expect(bracket.pools[0].matches.first.pair1?.player1Name, "Argaud Modifié");
      expect(bracket.mainMatches.firstWhere((m) => m.id == "final_fin").pair1?.player1Name, "Argaud Modifié");
      // And score remains intact
      expect(bracket.pools[0].matches.first.score, "6/4 6/2");

      // Test manual free editing (Saisie libre JAT)
      final overridden = BracketGeneratorService.manualUpdateMatchPair(
        bracket: bracket,
        matchId: "final_fin",
        slot: 1,
        pair: pouleA[1], // Force ha2 instead of ha1
      );
      final fin = overridden.mainMatches.firstWhere((m) => m.id == "final_fin");
      expect(fin.pair1?.id, "ha2");
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

    test('8-pair Pool Tournament (Pools of 4 with 6 matches each & 4 Final Matches)', () {
      final pouleA = [
        const TournamentPair(id: "a1", player1Name: "A1", player1Rank: 100, player2Name: "A1b", player2Rank: 100, seed: 1),
        const TournamentPair(id: "a2", player1Name: "A2", player1Rank: 200, player2Name: "A2b", player2Rank: 200),
        const TournamentPair(id: "a3", player1Name: "A3", player1Rank: 300, player2Name: "A3b", player2Rank: 300),
        const TournamentPair(id: "a4", player1Name: "A4", player1Rank: 400, player2Name: "A4b", player2Rank: 400),
      ];

      final pouleB = [
        const TournamentPair(id: "b1", player1Name: "B1", player1Rank: 150, player2Name: "B1b", player2Rank: 150, seed: 2),
        const TournamentPair(id: "b2", player1Name: "B2", player1Rank: 250, player2Name: "B2b", player2Rank: 250),
        const TournamentPair(id: "b3", player1Name: "B3", player1Rank: 350, player2Name: "B3b", player2Rank: 350),
        const TournamentPair(id: "b4", player1Name: "B4", player1Rank: 450, player2Name: "B4b", player2Rank: 450),
      ];

      final bracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: "test_pool_8",
        category: "double_messieurs",
        pouleAPairs: pouleA,
        pouleBPairs: pouleB,
        numCourts: 4,
      );

      // Verify that each pool of 4 has 6 matches
      expect(bracket.pools[0].matches.length, 6);
      expect(bracket.pools[1].matches.length, 6);

      // Verify that final matches include Places 1-2, 3-4, 5-6, and 7-8
      expect(bracket.mainMatches.length, 4);
      expect(bracket.mainMatches.any((m) => m.id == "final_fin"), true);
      expect(bracket.mainMatches.any((m) => m.id == "final_p34"), true);
      expect(bracket.mainMatches.any((m) => m.id == "final_p56"), true);
      expect(bracket.mainMatches.any((m) => m.id == "final_p78"), true);
    });

    test('Pool Tournament with Crossover Semifinals (Demi-finales croisées 1A vs 2B & 1B vs 2A)', () {
      final pouleA = [
        const TournamentPair(id: "a1", player1Name: "A1", player1Rank: 100, player2Name: "A1b", player2Rank: 100, seed: 1),
        const TournamentPair(id: "a2", player1Name: "A2", player1Rank: 200, player2Name: "A2b", player2Rank: 200),
        const TournamentPair(id: "a3", player1Name: "A3", player1Rank: 300, player2Name: "A3b", player2Rank: 300),
      ];

      final pouleB = [
        const TournamentPair(id: "b1", player1Name: "B1", player1Rank: 150, player2Name: "B1b", player2Rank: 150, seed: 2),
        const TournamentPair(id: "b2", player1Name: "B2", player1Rank: 250, player2Name: "B2b", player2Rank: 250),
        const TournamentPair(id: "b3", player1Name: "B3", player1Rank: 350, player2Name: "B3b", player2Rank: 350),
      ];

      var bracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: "test_crossover",
        category: "double_messieurs",
        pouleAPairs: pouleA,
        pouleBPairs: pouleB,
        finalPhaseType: 'crossover_semis',
        numCourts: 4,
      );

      // Verify matches generated: DF1, DF2, Finale, P3_4, P5_6
      expect(bracket.mainMatches.length, 5);
      expect(bracket.mainMatches.any((m) => m.id == "final_df1"), true);
      expect(bracket.mainMatches.any((m) => m.id == "final_df2"), true);
      expect(bracket.mainMatches.any((m) => m.id == "final_fin"), true);
      expect(bracket.mainMatches.any((m) => m.id == "final_p34"), true);
      expect(bracket.mainMatches.any((m) => m.id == "final_p56"), true);

      // Play Poule A: a1 wins both -> 1st, a2 wins one -> 2nd, a3 -> 3rd
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_a",
        matchId: "pa_0",
        score: "6/4 6/2",
        winnerId: "a1",
      );
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_a",
        matchId: "pa_1",
        score: "6/1 6/1",
        winnerId: "a1",
      );
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_a",
        matchId: "pa_2",
        score: "7/5 6/3",
        winnerId: "a2",
      );

      // Play Poule B: b1 wins both -> 1st, b2 wins one -> 2nd, b3 -> 3rd
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_b",
        matchId: "pb_0",
        score: "6/3 6/3",
        winnerId: "b1",
      );
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_b",
        matchId: "pb_1",
        score: "6/2 6/2",
        winnerId: "b1",
      );
      bracket = BracketGeneratorService.recordPoolMatchScore(
        bracket: bracket,
        poolId: "poule_b",
        matchId: "pb_2",
        score: "6/4 6/4",
        winnerId: "b2",
      );

      // Verify Crossover Demis assignment:
      // DF1: 1A (a1) vs 2B (b2)
      // DF2: 1B (b1) vs 2A (a2)
      // P56: 3A (a3) vs 3B (b3)
      final df1 = bracket.mainMatches.firstWhere((m) => m.id == "final_df1");
      final df2 = bracket.mainMatches.firstWhere((m) => m.id == "final_df2");
      final p56 = bracket.mainMatches.firstWhere((m) => m.id == "final_p56");

      expect(df1.pair1?.id, "a1");
      expect(df1.pair2?.id, "b2");
      expect(df2.pair1?.id, "b1");
      expect(df2.pair2?.id, "a2");
      expect(p56.pair1?.id, "a3");
      expect(p56.pair2?.id, "b3");

      // Play DF1: a1 beats b2 -> a1 goes to Finale slot 1, b2 goes to Petite Finale slot 1
      bracket = BracketGeneratorService.recordMatchScore(
        bracket: bracket,
        matchId: "final_df1",
        score: "6/2 6/3",
        winnerId: "a1",
      );

      // Play DF2: b1 beats a2 -> b1 goes to Finale slot 2, a2 goes to Petite Finale slot 2
      bracket = BracketGeneratorService.recordMatchScore(
        bracket: bracket,
        matchId: "final_df2",
        score: "6/4 7/5",
        winnerId: "b1",
      );

      final finale = bracket.mainMatches.firstWhere((m) => m.id == "final_fin");
      final p34 = bracket.mainMatches.firstWhere((m) => m.id == "final_p34");

      expect(finale.pair1?.id, "a1");
      expect(finale.pair2?.id, "b1");
      expect(p34.pair1?.id, "b2");
      expect(p34.pair2?.id, "a2");

      // Play the Grand Finale: a1 wins!
      bracket = BracketGeneratorService.recordMatchScore(
        bracket: bracket,
        matchId: "final_fin",
        score: "6/4 4/6 10/8",
        winnerId: "a1",
      );
      final finishedFinale = bracket.mainMatches.firstWhere((m) => m.id == "final_fin");
      expect(finishedFinale.winnerId, "a1");
      expect(finishedFinale.status, "completed");
    });
  });
}
