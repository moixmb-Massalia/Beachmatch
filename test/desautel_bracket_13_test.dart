import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';
import 'package:beachmatch_mobile/services/bracket_generator_service.dart';

void main() {
  test('Test 13 pairs Desautel Mixte bracket generation', () {
    final pairs = [
      const TournamentPair(id: 'p1', player1Name: 'PIVOT Sebastien', player1Rank: 184, player2Name: 'CLAUDEL lena', player2Rank: 168),
      const TournamentPair(id: 'p2', player1Name: 'MEYTRAS Frédéric', player1Rank: 164, player2Name: 'PLANTEVIN Marion', player2Rank: 203),
      const TournamentPair(id: 'p3', player1Name: 'RAGETLY Mathieu', player1Rank: 264, player2Name: 'PREVOT Delphine', player2Rank: 277),
      const TournamentPair(id: 'p4', player1Name: 'LEBRETON Frederic', player1Rank: 58, player2Name: 'DELEPLACE Julie', player2Rank: 529),
      const TournamentPair(id: 'p5', player1Name: 'LEDRU Benjamin', player1Rank: 573, player2Name: 'LEW-MAN-MEW soonya', player2Rank: 146),
      const TournamentPair(id: 'p6', player1Name: 'MINASSIAN Djivan', player1Rank: 503, player2Name: 'LHUISSIER Zoe', player2Rank: 284),
      const TournamentPair(id: 'p7', player1Name: 'ROUYER Hugo', player1Rank: 474, player2Name: 'RIPERT elisabeth', player2Rank: 343),
      const TournamentPair(id: 'p8', player1Name: 'ARGAUD JEAN-MICHEL', player1Rank: 275, player2Name: 'ARGAUD VICTORIA', player2Rank: 547),
      const TournamentPair(id: 'p9', player1Name: 'HAMMADACHE Mohamed-Amine', player1Rank: 441, player2Name: 'OURLIAC Ophélie', player2Rank: 418),
      const TournamentPair(id: 'p10', player1Name: 'APPY GUILLAUME', player1Rank: 601, player2Name: 'ALCANTARA Angelica', player2Rank: 383),
      const TournamentPair(id: 'p11', player1Name: 'FABRE Claude', player1Rank: 608, player2Name: 'Dubus Florence', player2Rank: 607),
      const TournamentPair(id: 'p12', player1Name: 'CLAUDEL david', player1Rank: 557, player2Name: 'DESMONTS LUDIVINE', player2Rank: 781),
      const TournamentPair(id: 'p13', player1Name: 'ENDEL Benjamin', player1Rank: 1899, player2Name: 'ENDEL Christine', player2Rank: 86),
    ];

    final bracket = BracketGeneratorService.generateBracket(
      tournamentId: 'FED_82676940',
      category: 'double_mixtes',
      registeredPairs: pairs,
      numCourts: 4,
    );

    expect(bracket.pairs.length, equals(13));
    expect(bracket.pairs[0].seed, equals(1)); // PIVOT / CLAUDEL (352)
    expect(bracket.pairs[1].seed, equals(2)); // MEYTRAS / PLANTEVIN (367)
    expect(bracket.pairs[2].seed, equals(3)); // RAGETLY / PREVOT (541)
    expect(bracket.pairs[3].seed, equals(4)); // LEBRETON / DELEPLACE (587)

    // Check round 0 matches (8 matches in a 16-draw)
    final r0Matches = bracket.mainMatches.where((m) => m.roundIndex == 0).toList();
    expect(r0Matches.length, equals(8));

    // Check round 1 matches (Quarts de finale)
    final r1Matches = bracket.mainMatches.where((m) => m.roundIndex == 1).toList();
    expect(r1Matches.length, equals(4));
  });
}
