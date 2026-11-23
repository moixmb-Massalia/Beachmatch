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

    final team1Name = (data['team1'] ?? 'Paire A').toString();
    final team2Name = (data['team2'] ?? 'Paire B').toString();

    // Résolution robuste et ultra-tolérante du vainqueur (entier, texte ou nom d'équipe)
    int? parsedWinner;
    final rawWinner = data['winner'];
    if (rawWinner is num) {
      parsedWinner = rawWinner.toInt();
    } else if (rawWinner is String && rawWinner.trim().isNotEmpty) {
      final asInt = int.tryParse(rawWinner.trim());
      if (asInt != null) {
        parsedWinner = asInt;
      } else if (rawWinner.trim() == team1Name.trim()) {
        parsedWinner = 1;
      } else if (rawWinner.trim() == team2Name.trim()) {
        parsedWinner = 2;
      }
    }

    int parseNum(dynamic val, [int fallback = 0]) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    int? parseOptionalNum(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    return LiveMatchModel(
      id: doc.id,
      tournamentId: (data['tournamentId'] ?? '').toString(),
      courtName: (data['courtName'] ?? 'Court Central').toString(),
      category: (data['category'] ?? 'Double').toString(),
      round: (data['round'] ?? 'Match en direct').toString(),
      team1: team1Name,
      team2: team2Name,
      set1Team1: parseNum(data['set1Team1'], 0),
      set1Team2: parseNum(data['set1Team2'], 0),
      set2Team1: parseNum(data['set2Team1'], 0),
      set2Team2: parseNum(data['set2Team2'], 0),
      set3Team1: parseOptionalNum(data['set3Team1']),
      set3Team2: parseOptionalNum(data['set3Team2']),
      currentSet: parseNum(data['currentSet'], 1),
      servingTeam: parseNum(data['servingTeam'], 1),
      status: (data['status'] ?? 'LIVE').toString(),
      winner: parsedWinner,
      refereeName: data['refereeName']?.toString(),
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
