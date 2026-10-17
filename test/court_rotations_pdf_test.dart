import 'package:flutter_test/flutter_test.dart';
import 'package:beachmatch_mobile/models/tournament.dart';
import 'package:beachmatch_mobile/services/tournament_pdf_service.dart';

void main() {
  test('buildCourtRotationsPdfBytes completes without type errors', () async {
    final tournament = TournamentModel(
      id: 'TOURNOI_TEST_001',
      name: 'Open Beach Tennis Cap d\'Agde',
      club: 'Cap d\'Agde Tennis Club',
      location: 'Cap d\'Agde',
      dateString: '24 Octobre 2026',
      distance: 0,
      category: 'BT 250',
      formats: ['DH', 'DD'],
      referee: 'Gilles Martin (JAT2)',
    );

    final dummyRotations = [
      {
        'id': 0,
        'time': '09:00 - 10:15',
        'title': 'ROTATION 1 (09:00) · 5 COURTS',
        'desc': 'Double Hommes & Double Dames',
        'courts': [
          {
            'court': 1,
            'matchId': 'm1',
            'type': 'DH',
            'cat': 'DH',
            'tour': '1/8 Finale',
            'p1': 'DUPONT / MARTIN',
            'p2': 'DURAND / LEROY',
            'status': 'A venir',
            'score': '',
            'next': 'Tour suivant',
          },
          {
            'court': 2,
            'matchId': 'm2',
            'type': 'Disponible',
            'cat': '',
            'tour': '',
            'p1': 'Court disponible',
            'p2': '',
            'status': '',
            'score': '',
            'next': '',
          },
          // Courts 3, 4, 5 are intentionally missing to trigger where(...).firstOrNull == null
        ],
      },
      {
        'id': 1,
        'time': '10:15 - 11:30',
        'title': 'ROTATION 2 (10:15) · 5 COURTS',
        'desc': 'Double Hommes & Double Dames',
        'courts': [
          {
            'court': 3,
            'matchId': 'm3',
            'type': 'DD',
            'cat': 'DD',
            'tour': 'Poule A',
            'p1': 'DELEPLACE / ESTAMPE',
            'p2': 'MATEOS / ROUSSEL',
            'status': 'A venir',
            'score': '',
            'next': 'Tour suivant',
          },
        ],
      },
    ];

    final pdfBytes = await TournamentPdfService.buildCourtRotationsPdfBytes(
      tournament: tournament,
      rotations: dummyRotations,
      numCourts: 5,
      categories: {'DH', 'DD'},
    );

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(1000));
    print("PDF bytes generated cleanly: ${pdfBytes.length} bytes");
  });
}
