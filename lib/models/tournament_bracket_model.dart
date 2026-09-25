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
  final String? poolId; // e.g. 'poule_a', 'poule_b'
  final String? matchCode; // e.g. 'DF1', 'DF2', 'FINALE', 'PLACE_3_4', 'PLACE_5_6'

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
    this.poolId,
    this.matchCode,
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
    String? poolId,
    String? matchCode,
    bool clearPair1 = false,
    bool clearPair2 = false,
    bool clearWinner = false,
    bool clearCourt = false,
    bool clearScore = false,
  }) {
    return BracketMatch(
      id: id ?? this.id,
      roundIndex: roundIndex ?? this.roundIndex,
      roundName: roundName ?? this.roundName,
      matchIndex: matchIndex ?? this.matchIndex,
      pair1: clearPair1 ? null : (pair1 ?? this.pair1),
      pair2: clearPair2 ? null : (pair2 ?? this.pair2),
      score: clearScore ? null : (score ?? this.score),
      winnerId: clearWinner ? null : (winnerId ?? this.winnerId),
      court: clearCourt ? null : (court ?? this.court),
      status: status ?? this.status,
      nextMatchId: nextMatchId ?? this.nextMatchId,
      nextMatchSlot: nextMatchSlot ?? this.nextMatchSlot,
      consolationMatchId: consolationMatchId ?? this.consolationMatchId,
      consolationSlot: consolationSlot ?? this.consolationSlot,
      isBye: isBye ?? this.isBye,
      poolId: poolId ?? this.poolId,
      matchCode: matchCode ?? this.matchCode,
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
      'poolId': poolId,
      'matchCode': matchCode,
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
      poolId: map['poolId'],
      matchCode: map['matchCode'],
    );
  }
}

class PoolStanding {
  final TournamentPair pair;
  final int played;
  final int won;
  final int lost;
  final int setsWon;
  final int setsLost;
  final int gamesWon;
  final int gamesLost;
  final int points;

  const PoolStanding({
    required this.pair,
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.setsWon = 0,
    this.setsLost = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.points = 0,
  });

  int get diffSets => setsWon - setsLost;
  int get diffGames => gamesWon - gamesLost;

  PoolStanding copyWith({
    TournamentPair? pair,
    int? played,
    int? won,
    int? lost,
    int? setsWon,
    int? setsLost,
    int? gamesWon,
    int? gamesLost,
    int? points,
  }) {
    return PoolStanding(
      pair: pair ?? this.pair,
      played: played ?? this.played,
      won: won ?? this.won,
      lost: lost ?? this.lost,
      setsWon: setsWon ?? this.setsWon,
      setsLost: setsLost ?? this.setsLost,
      gamesWon: gamesWon ?? this.gamesWon,
      gamesLost: gamesLost ?? this.gamesLost,
      points: points ?? this.points,
    );
  }
}

class TournamentPool {
  final String id;
  final String name; // 'Poule A', 'Poule B'
  final List<TournamentPair> pairs;
  final List<BracketMatch> matches;

  const TournamentPool({
    required this.id,
    required this.name,
    this.pairs = const [],
    this.matches = const [],
  });

  List<PoolStanding> calculateStandings() {
    final map = <String, PoolStanding>{};
    for (final p in pairs) {
      map[p.id] = PoolStanding(pair: p);
    }

    for (final m in matches) {
      if (!m.isCompleted || m.pair1 == null || m.pair2 == null) continue;
      final p1 = map[m.pair1!.id] ?? PoolStanding(pair: m.pair1!);
      final p2 = map[m.pair2!.id] ?? PoolStanding(pair: m.pair2!);

      final isP1Winner = m.winnerId == m.pair1!.id;
      final isP2Winner = m.winnerId == m.pair2!.id;

      // Parse score (e.g. "6/4 6/3" or "9/4")
      int p1Sets = 0;
      int p2Sets = 0;
      int p1Games = 0;
      int p2Games = 0;

      if (m.score != null && m.score!.isNotEmpty) {
        final setTokens = m.score!.trim().split(RegExp(r'\s+'));
        for (final tok in setTokens) {
          final parts = tok.split('/');
          if (parts.length == 2) {
            final g1 = int.tryParse(parts[0]) ?? 0;
            final g2 = int.tryParse(parts[1]) ?? 0;
            p1Games += g1;
            p2Games += g2;
            if (g1 > g2) p1Sets++;
            if (g2 > g1) p2Sets++;
          }
        }
      }

      if (p1Sets == 0 && p2Sets == 0) {
        if (isP1Winner) p1Sets = 1;
        if (isP2Winner) p2Sets = 1;
      }

      map[m.pair1!.id] = p1.copyWith(
        played: p1.played + 1,
        won: p1.won + (isP1Winner ? 1 : 0),
        lost: p1.lost + (isP1Winner ? 0 : 1),
        points: p1.points + (isP1Winner ? 2 : 1),
        setsWon: p1.setsWon + p1Sets,
        setsLost: p1.setsLost + p2Sets,
        gamesWon: p1.gamesWon + p1Games,
        gamesLost: p1.gamesLost + p2Games,
      );

      map[m.pair2!.id] = p2.copyWith(
        played: p2.played + 1,
        won: p2.won + (isP2Winner ? 1 : 0),
        lost: p2.lost + (isP2Winner ? 0 : 1),
        points: p2.points + (isP2Winner ? 2 : 1),
        setsWon: p2.setsWon + p2Sets,
        setsLost: p2.setsLost + p1Sets,
        gamesWon: p2.gamesWon + p2Games,
        gamesLost: p2.gamesLost + p1Games,
      );
    }

    final list = map.values.toList();
    list.sort((a, b) {
      if (a.points != b.points) return b.points.compareTo(a.points);
      if (a.diffSets != b.diffSets) return b.diffSets.compareTo(a.diffSets);
      if (a.diffGames != b.diffGames) return b.diffGames.compareTo(a.diffGames);
      return a.pair.weight.compareTo(b.pair.weight);
    });
    return list;
  }

  TournamentPool copyWith({
    String? id,
    String? name,
    List<TournamentPair>? pairs,
    List<BracketMatch>? matches,
  }) {
    return TournamentPool(
      id: id ?? this.id,
      name: name ?? this.name,
      pairs: pairs ?? this.pairs,
      matches: matches ?? this.matches,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pairs': pairs.map((p) => p.toMap()).toList(),
      'matches': matches.map((m) => m.toMap()).toList(),
    };
  }

  factory TournamentPool.fromMap(Map<String, dynamic> map) {
    return TournamentPool(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      pairs: (map['pairs'] as List<dynamic>?)
              ?.map((p) => TournamentPair.fromMap(Map<String, dynamic>.from(p)))
              .toList() ??
          [],
      matches: (map['matches'] as List<dynamic>?)
              ?.map((m) => BracketMatch.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
    );
  }
}

class TournamentBracket {
  final String tournamentId;
  final String category; // 'double_messieurs', 'double_dames', 'double_mixtes'
  final String format; // 'elimination' or 'pools_and_bracket'
  final int numCourts;
  final String status; // 'draft', 'in_progress', 'finished'
  final List<TournamentPair> pairs;
  final List<BracketMatch> mainMatches;
  final List<BracketMatch> consolationMatches;
  final List<TournamentPool> pools;
  final DateTime updatedAt;

  const TournamentBracket({
    required this.tournamentId,
    this.category = 'double_messieurs',
    this.format = 'elimination',
    this.numCourts = 4,
    this.status = 'draft',
    this.pairs = const [],
    this.mainMatches = const [],
    this.consolationMatches = const [],
    this.pools = const [],
    required this.updatedAt,
  });

  TournamentBracket copyWith({
    String? tournamentId,
    String? category,
    String? format,
    int? numCourts,
    String? status,
    List<TournamentPair>? pairs,
    List<BracketMatch>? mainMatches,
    List<BracketMatch>? consolationMatches,
    List<TournamentPool>? pools,
    DateTime? updatedAt,
  }) {
    return TournamentBracket(
      tournamentId: tournamentId ?? this.tournamentId,
      category: category ?? this.category,
      format: format ?? this.format,
      numCourts: numCourts ?? this.numCourts,
      status: status ?? this.status,
      pairs: pairs ?? this.pairs,
      mainMatches: mainMatches ?? this.mainMatches,
      consolationMatches: consolationMatches ?? this.consolationMatches,
      pools: pools ?? this.pools,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'category': category,
      'format': format,
      'numCourts': numCourts,
      'status': status,
      'pairs': pairs.map((p) => p.toMap()).toList(),
      'mainMatches': mainMatches.map((m) => m.toMap()).toList(),
      'consolationMatches': consolationMatches.map((m) => m.toMap()).toList(),
      'pools': pools.map((p) => p.toMap()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TournamentBracket.fromMap(Map<String, dynamic> map, String tournamentId) {
    return TournamentBracket(
      tournamentId: tournamentId,
      category: map['category'] ?? 'double_messieurs',
      format: map['format'] ?? (map['pools'] != null && (map['pools'] as List).isNotEmpty ? 'pools_and_bracket' : 'elimination'),
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
      pools: (map['pools'] as List<dynamic>?)
              ?.map((p) => TournamentPool.fromMap(Map<String, dynamic>.from(p)))
              .toList() ??
          [],
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
