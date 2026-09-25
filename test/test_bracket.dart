import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';
import 'package:beachmatch_mobile/services/bracket_generator_service.dart';

void main() {
  test('Bracket Generator FFT tests', () {
    final pairs = [
      const TournamentPair(id: "p1", player1Name: "Moretto", player1Rank: 10, player2Name: "Goudin", player2Rank: 12), // weight 22 -> TS1
      const TournamentPair(id: "p2", player1Name: "Dupont", player1Rank: 25, player2Name: "Martin", player2Rank: 30),  // weight 55 -> TS2
      const TournamentPair(id: "p3", player1Name: "Leroi", player1Rank: 40, player2Name: "Blanc", player2Rank: 45),    // weight 85 -> TS3
      const TournamentPair(id: "p4", player1Name: "Petit", player1Rank: 50, player2Name: "Grand", player2Rank: 60),    // weight 110 -> TS4
      const TournamentPair(id: "p5", player1Name: "Roux", player1Rank: 100, player2Name: "Brun", player2Rank: 110),
      const TournamentPair(id: "p6", player1Name: "Faure", player1Rank: 120, player2Name: "Perez", player2Rank: 130),
      const TournamentPair(id: "p7", player1Name: "Simon", player1Rank: 150, player2Name: "Michel", player2Rank: 160),
      const TournamentPair(id: "p8", player1Name: "Garcia", player1Rank: 200, player2Name: "David", player2Rank: 210),
    ];

    final bracket = BracketGeneratorService.generateBracket(
      tournamentId: "toulon_2026",
      registeredPairs: pairs,
      numCourts: 4,
    );

    expect(bracket.mainMatches.length, 7); // 4 QF + 2 SF + 1 Final

    // Check TS1 and TS2 positions
    final mFirst = bracket.mainMatches.firstWhere((m) => m.roundIndex == 0 && m.matchIndex == 0);
    final mLast = bracket.mainMatches.lastWhere((m) => m.roundIndex == 0);

    // Verify TS2 on top, TS1 on bottom
    expect(mFirst.pair1?.seed, 2); // TS2 on top (FFT rule)
    expect(mLast.pair2?.seed, 1);  // TS1 on bottom (FFT rule)

    // Test recording a score
    final updated = BracketGeneratorService.recordMatchScore(
      bracket: bracket,
      matchId: mFirst.id,
      score: "6/4 6/3",
      winnerId: mFirst.pair1!.id,
    );

    final nextMatch = updated.mainMatches.firstWhere((m) => m.id == mFirst.nextMatchId);
    expect(nextMatch.pair1?.id, mFirst.pair1!.id);
  });
}
