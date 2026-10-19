import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament_bracket_model.dart';
import 'package:beachmatch_mobile/models/court_call_model.dart';

class FakeFirestoreTimestamp {
  final DateTime _dateTime;
  FakeFirestoreTimestamp(this._dateTime);
  DateTime toDate() => _dateTime;
}

void main() {
  group('TournamentBracket.fromMap Robustness Tests', () {
    test('handles FakeFirestoreTimestamp for updatedAt without crashing', () {
      final fakeTimestamp = FakeFirestoreTimestamp(DateTime(2026, 10, 17, 10, 0));
      final map = {
        'tournamentId': 'FED_82684691',
        'category': 'double_dames',
        'format': 'pools_and_bracket',
        'finalPhaseType': 'direct_finals',
        'numCourts': 4,
        'status': 'draft',
        'pairs': [],
        'pools': [],
        'mainMatches': [],
        'consolationMatches': [],
        'updatedAt': fakeTimestamp,
      };

      final bracket = TournamentBracket.fromMap(map, 'FED_82684691');
      expect(bracket.tournamentId, equals('FED_82684691'));
      expect(bracket.category, equals('double_dames'));
      expect(bracket.updatedAt, equals(DateTime(2026, 10, 17, 10, 0)));
      expect(bracket.pairs, isEmpty);
      expect(bracket.pools, isEmpty);
    });

    test('handles ISO-8601 String for updatedAt', () {
      final map = {
        'category': 'double_dames',
        'updatedAt': '2026-10-01T22:20:08.269227Z',
      };

      final bracket = TournamentBracket.fromMap(map, 'FED_82684691');
      expect(bracket.category, equals('double_dames'));
      expect(bracket.updatedAt.year, equals(2026));
      expect(bracket.updatedAt.month, equals(10));
    });

    test('handles null updatedAt gracefully', () {
      final map = <String, dynamic>{
        'category': 'double_dames',
        'updatedAt': null,
      };

      final bracket = TournamentBracket.fromMap(map, 'FED_82684691');
      expect(bracket.updatedAt, isNotNull);
    });

    test('handles empty map gracefully', () {
      final bracket = TournamentBracket.fromMap({}, 'FED_82684691');
      expect(bracket.tournamentId, equals('FED_82684691'));
      expect(bracket.category, equals('double_messieurs'));
      expect(bracket.format, equals('elimination'));
      expect(bracket.numCourts, equals(4));
    });

    test('CourtCallModel handles FakeFirestoreTimestamp without crashing', () {
      final fakeTimestamp = FakeFirestoreTimestamp(DateTime(2026, 10, 17, 14, 30));
      final map = {
        'tournamentId': 'FED_82684691',
        'category': 'double_dames',
        'court': '2',
        'roundName': 'Poule A',
        'pair1Name': 'Paire 1',
        'pair2Name': 'Paire 2',
        'calledAt': fakeTimestamp,
        'isActive': true,
      };

      final call = CourtCallModel.fromMap(map, 'call_123');
      expect(call.court, equals(2));
      expect(call.calledAt, equals(DateTime(2026, 10, 17, 14, 30)));
    });
  });
}
