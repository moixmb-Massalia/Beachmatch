import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';
import 'package:beachmatch_mobile/services/bracket_generator_service.dart';

void main() {
  group('Custom Court Schedule Tailor-made Test', () {
    test('Schedules real pairs dynamically across selected courts without mock data', () {
      final tournament = TournamentModel(
        id: 'TOURNOI_TEST_REEL_001',
        name: 'Open Beach Tennis Cap d\'Agde',
        club: 'Cap d\'Agde Tennis Club',
        location: 'Cap d\'Agde',
        dateString: '24 Octobre 2026',
        distance: 0,
        category: 'BT 250',
        formats: ['DH', 'DD'],
        referee: 'Gilles Martin (JAT2)',
      );

      // Real Double Dames: 5 pairs (Poule Unique)
      final ddPairs = [
        const TournamentPair(id: 'dd1', player1Name: 'Julie Deleplace', player2Name: 'Katia Estampe'),
        const TournamentPair(id: 'dd2', player1Name: 'Satine Mateos', player2Name: 'Loane Roussel'),
        const TournamentPair(id: 'dd3', player1Name: 'Luce Moreno', player2Name: 'Margaret Debono'),
        const TournamentPair(id: 'dd4', player1Name: 'Lucie Eliasz', player2Name: 'Elyse Appy'),
        const TournamentPair(id: 'dd5', player1Name: 'Sarah Madi', player2Name: 'Marie Viret'),
      ];

      final ddBracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: tournament.id,
        category: 'double_dames',
        pouleAPairs: ddPairs,
        pouleBPairs: const [],
        numCourts: 3,
      );

      // Verify real pairs in DD bracket
      expect(ddBracket.pools.length, equals(1));
      expect(ddBracket.pools.first.pairs.length, equals(5));
      expect(ddBracket.pools.first.matches.length, equals(10));

      // Check that all matches contain ONLY real players
      for (final m in ddBracket.pools.first.matches) {
        expect(m.pair1, isNotNull);
        expect(m.pair2, isNotNull);
        expect(m.pair1!.displayName, isNot(contains('COLIN')));
        expect(m.pair1!.displayName, isNot(contains('VIDAL')));
        expect(m.pair2!.displayName, isNot(contains('BERTRAND')));
      }

      // Real Double Messieurs: 6 pairs (2 Poules de 3)
      final dhPairs = [
        const TournamentPair(id: 'dh1', player1Name: 'Thomas Ripert', player2Name: 'Maxime Meytras'),
        const TournamentPair(id: 'dh2', player1Name: 'Alex Rovira', player2Name: 'Paul Simon'),
        const TournamentPair(id: 'dh3', player1Name: 'Lucas Raoult', player2Name: 'Marc Leclerc'),
        const TournamentPair(id: 'dh4', player1Name: 'Cyril Girard', player2Name: 'Luc Claudel'),
        const TournamentPair(id: 'dh5', player1Name: 'Romain Garnier', player2Name: 'Yann Faure'),
        const TournamentPair(id: 'dh6', player1Name: 'Hugo Blanc', player2Name: 'Adrien Denis'),
      ];

      final dhBracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: tournament.id,
        category: 'double_messieurs',
        pouleAPairs: dhPairs.take(3).toList(),
        pouleBPairs: dhPairs.skip(3).toList(),
        numCourts: 3,
      );

      expect(dhBracket.pools.length, equals(2));
      expect(dhBracket.pools[0].matches.length, equals(3));
      expect(dhBracket.pools[1].matches.length, equals(3));
      expect(dhBracket.mainMatches.length, equals(3)); // Finale + Place 3/4 + Place 5/6

      // Total matches across both categories
      final totalMatches = ddBracket.pools.first.matches.length +
          dhBracket.pools[0].matches.length +
          dhBracket.pools[1].matches.length +
          dhBracket.mainMatches.length;

      expect(totalMatches, equals(19));
    });
  });
}
