import 'package:cloud_firestore/cloud_firestore.dart';

class LiveMatchModel {
  final String id;
  final String tournamentId;
  final String courtName; // "Court Central", "Court 1", etc.
  final String category; // "Double Messieurs", "Double Dames", "Double Mixte"
  final String round; // "Finale 🏆", "1/2 Finale", "1/4 Finale", "Poules"
  final String team1;
  final String team2;
  final int set1Team1;
  final int set1Team2;
  final int set2Team1;
  final int set2Team2;
  final int? set3Team1;
  final int? set3Team2;
  final int currentSet; // 1, 2, 3
  final int servingTeam; // 1 or 2
  final String status; // 'LIVE', 'FINISHED', 'PAUSED'
  final int? winner; // 1 or 2
  final String? refereeName;
  final DateTime? updatedAt;

  LiveMatchModel({
    required this.id,
    required this.tournamentId,
    this.courtName = 'Court Central',
    this.category = 'Double',
    this.round = 'Finale 🏆',
    required this.team1,
    required this.team2,
    this.set1Team1 = 0,
    this.set1Team2 = 0,
    this.set2Team1 = 0,
    this.set2Team2 = 0,
    this.set3Team1,
    this.set3Team2,
    this.currentSet = 1,
    this.servingTeam = 1,
    this.status = 'LIVE',
    this.winner,
    this.refereeName,
    this.updatedAt,
  });

  factory LiveMatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LiveMatchModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      courtName: data['courtName'] ?? 'Court Central',
      category: data['category'] ?? 'Double',
      round: data['round'] ?? 'Match en direct',
      team1: data['team1'] ?? 'Paire A',
      team2: data['team2'] ?? 'Paire B',
      set1Team1: data['set1Team1'] ?? 0,
      set1Team2: data['set1Team2'] ?? 0,
      set2Team1: data['set2Team1'] ?? 0,
      set2Team2: data['set2Team2'] ?? 0,
      set3Team1: data['set3Team1'],
      set3Team2: data['set3Team2'],
      currentSet: data['currentSet'] ?? 1,
      servingTeam: data['servingTeam'] ?? 1,
      status: data['status'] ?? 'LIVE',
      winner: data['winner'],
      refereeName: data['refereeName'],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'courtName': courtName,
      'category': category,
      'round': round,
      'team1': team1,
      'team2': team2,
      'set1Team1': set1Team1,
      'set1Team2': set1Team2,
      'set2Team1': set2Team1,
      'set2Team2': set2Team2,
      'set3Team1': set3Team1,
      'set3Team2': set3Team2,
      'currentSet': currentSet,
      'servingTeam': servingTeam,
      'status': status,
      'winner': winner,
      if (refereeName != null) 'refereeName': refereeName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
