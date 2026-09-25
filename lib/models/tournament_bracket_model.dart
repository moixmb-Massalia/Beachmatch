class TournamentPair {
  final String id;
  final String player1Name;
  final int player1Rank;
  final String player2Name;
  final int player2Rank;
  final int? seed; // 1 = TS1, 2 = TS2, etc.
  final bool isBye;

  const TournamentPair({
    required this.id,
    required this.player1Name,
    this.player1Rank = 9999,
    required this.player2Name,
    this.player2Rank = 9999,
    this.seed,
    this.isBye = false,
  });

  int get weight => player1Rank + player2Rank;

  String get displayName {
    if (isBye) return "EXEMPT (BYE)";
    return "$player1Name / $player2Name";
  }

  TournamentPair copyWith({
    String? id,
    String? player1Name,
    int? player1Rank,
    String? player2Name,
    int? player2Rank,
    int? seed,
    bool? isBye,
  }) {
    return TournamentPair(
      id: id ?? this.id,
      player1Name: player1Name ?? this.player1Name,
      player1Rank: player1Rank ?? this.player1Rank,
      player2Name: player2Name ?? this.player2Name,
      player2Rank: player2Rank ?? this.player2Rank,
      seed: seed ?? this.seed,
      isBye: isBye ?? this.isBye,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'player1Name': player1Name,
      'player1Rank': player1Rank,
      'player2Name': player2Name,
      'player2Rank': player2Rank,
      'seed': seed,
      'isBye': isBye,
    };
  }

  factory TournamentPair.fromMap(Map<String, dynamic> map) {
    return TournamentPair(
      id: map['id'] ?? '',
      player1Name: map['player1Name'] ?? '',
      player1Rank: (map['player1Rank'] is num) ? (map['player1Rank'] as num).toInt() : 9999,
      player2Name: map['player2Name'] ?? '',
      player2Rank: (map['player2Rank'] is num) ? (map['player2Rank'] as num).toInt() : 9999,
      seed: map['seed'] != null ? (map['seed'] as num).toInt() : null,
      isBye: map['isBye'] == true,
    );
  }
}

class BracketMatch {
  final String id;
  final int roundIndex;
  final String roundName;
  final int matchIndex;
  final TournamentPair? pair1;
  final TournamentPair? pair2;
  final String? score;
  final String? winnerId;
  final int? court;
  final String status; // 'pending', 'in_progress', 'completed'
  final String? nextMatchId;
  final int? nextMatchSlot; // 1 or 2
  final String? consolationMatchId;
  final int? consolationSlot; // 1 or 2
  final bool isBye;

  const BracketMatch({
    required this.id,
    required this.roundIndex,
    required this.roundName,
    required this.matchIndex,
    this.pair1,
    this.pair2,
    this.score,
    this.winnerId,
    this.court,
    this.status = 'pending',
    this.nextMatchId,
    this.nextMatchSlot,
    this.consolationMatchId,
    this.consolationSlot,
    this.isBye = false,
  });

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isReady => pair1 != null && pair2 != null && !isBye;

  TournamentPair? get winner {
    if (winnerId == null) return null;
    if (pair1?.id == winnerId) return pair1;
    if (pair2?.id == winnerId) return pair2;
    return null;
  }

  TournamentPair? get loser {
    if (winnerId == null) return null;
    if (pair1?.id == winnerId) return pair2;
    if (pair2?.id == winnerId) return pair1;
    return null;
  }

  BracketMatch copyWith({
    String? id,
    int? roundIndex,
    String? roundName,
    int? matchIndex,
    TournamentPair? pair1,
    TournamentPair? pair2,
    String? score,
    String? winnerId,
    int? court,
    String? status,
    String? nextMatchId,
    int? nextMatchSlot,
    String? consolationMatchId,
    int? consolationSlot,
    bool? isBye,
    bool clearPair1 = false,
    bool clearPair2 = false,
    bool clearWinner = false,
    bool clearCourt = false,
  }) {
    return BracketMatch(
      id: id ?? this.id,
      roundIndex: roundIndex ?? this.roundIndex,
      roundName: roundName ?? this.roundName,
      matchIndex: matchIndex ?? this.matchIndex,
      pair1: clearPair1 ? null : (pair1 ?? this.pair1),
      pair2: clearPair2 ? null : (pair2 ?? this.pair2),
      score: score ?? this.score,
      winnerId: clearWinner ? null : (winnerId ?? this.winnerId),
      court: clearCourt ? null : (court ?? this.court),
      status: status ?? this.status,
      nextMatchId: nextMatchId ?? this.nextMatchId,
      nextMatchSlot: nextMatchSlot ?? this.nextMatchSlot,
      consolationMatchId: consolationMatchId ?? this.consolationMatchId,
      consolationSlot: consolationSlot ?? this.consolationSlot,
      isBye: isBye ?? this.isBye,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roundIndex': roundIndex,
      'roundName': roundName,
      'matchIndex': matchIndex,
      'pair1': pair1?.toMap(),
      'pair2': pair2?.toMap(),
      'score': score,
      'winnerId': winnerId,
      'court': court,
      'status': status,
      'nextMatchId': nextMatchId,
      'nextMatchSlot': nextMatchSlot,
      'consolationMatchId': consolationMatchId,
      'consolationSlot': consolationSlot,
      'isBye': isBye,
    };
  }

  factory BracketMatch.fromMap(Map<String, dynamic> map) {
    return BracketMatch(
      id: map['id'] ?? '',
      roundIndex: (map['roundIndex'] is num) ? (map['roundIndex'] as num).toInt() : 0,
      roundName: map['roundName'] ?? '',
      matchIndex: (map['matchIndex'] is num) ? (map['matchIndex'] as num).toInt() : 0,
      pair1: map['pair1'] != null ? TournamentPair.fromMap(Map<String, dynamic>.from(map['pair1'])) : null,
      pair2: map['pair2'] != null ? TournamentPair.fromMap(Map<String, dynamic>.from(map['pair2'])) : null,
      score: map['score'],
      winnerId: map['winnerId'],
      court: map['court'] != null ? (map['court'] as num).toInt() : null,
      status: map['status'] ?? 'pending',
      nextMatchId: map['nextMatchId'],
      nextMatchSlot: map['nextMatchSlot'] != null ? (map['nextMatchSlot'] as num).toInt() : null,
      consolationMatchId: map['consolationMatchId'],
      consolationSlot: map['consolationSlot'] != null ? (map['consolationSlot'] as num).toInt() : null,
      isBye: map['isBye'] == true,
    );
  }
}

class TournamentBracket {
  final String tournamentId;
  final int numCourts;
  final String status; // 'draft', 'in_progress', 'finished'
  final List<TournamentPair> pairs;
  final List<BracketMatch> mainMatches;
  final List<BracketMatch> consolationMatches;
  final DateTime updatedAt;

  const TournamentBracket({
    required this.tournamentId,
    this.numCourts = 4,
    this.status = 'draft',
    this.pairs = const [],
    this.mainMatches = const [],
    this.consolationMatches = const [],
    required this.updatedAt,
  });

  TournamentBracket copyWith({
    String? tournamentId,
    int? numCourts,
    String? status,
    List<TournamentPair>? pairs,
    List<BracketMatch>? mainMatches,
    List<BracketMatch>? consolationMatches,
    DateTime? updatedAt,
  }) {
    return TournamentBracket(
      tournamentId: tournamentId ?? this.tournamentId,
      numCourts: numCourts ?? this.numCourts,
      status: status ?? this.status,
      pairs: pairs ?? this.pairs,
      mainMatches: mainMatches ?? this.mainMatches,
      consolationMatches: consolationMatches ?? this.consolationMatches,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'numCourts': numCourts,
      'status': status,
      'pairs': pairs.map((p) => p.toMap()).toList(),
      'mainMatches': mainMatches.map((m) => m.toMap()).toList(),
      'consolationMatches': consolationMatches.map((m) => m.toMap()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TournamentBracket.fromMap(Map<String, dynamic> map, String tournamentId) {
    return TournamentBracket(
      tournamentId: tournamentId,
      numCourts: (map['numCourts'] is num) ? (map['numCourts'] as num).toInt() : 4,
      status: map['status'] ?? 'draft',
      pairs: (map['pairs'] as List<dynamic>?)
              ?.map((p) => TournamentPair.fromMap(Map<String, dynamic>.from(p)))
              .toList() ??
          [],
      mainMatches: (map['mainMatches'] as List<dynamic>?)
              ?.map((m) => BracketMatch.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
      consolationMatches: (map['consolationMatches'] as List<dynamic>?)
              ?.map((m) => BracketMatch.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
