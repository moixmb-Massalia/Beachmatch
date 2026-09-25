import 'dart:math';
import '../models/tournament_bracket_model.dart';

class BracketGeneratorService {
  /// Calcule la puissance de 2 immédiatement supérieure ou égale (min 4, max 32)
  static int getBracketSize(int teamCount) {
    if (teamCount <= 4) return 4;
    if (teamCount <= 8) return 8;
    if (teamCount <= 16) return 16;
    return 32;
  }

  /// Détermine le nombre de têtes de série officiel selon la taille du tableau
  static int getSeedCount(int bracketSize, int teamCount) {
    if (bracketSize == 4) return min(2, teamCount);
    if (bracketSize == 8) return min(2, teamCount);
    if (bracketSize == 16) return min(4, teamCount);
    return min(8, teamCount);
  }

  /// Assigne les têtes de série (TS1, TS2...) après tri par poids croissant
  static List<TournamentPair> assignSeeds(List<TournamentPair> inputPairs) {
    final pairs = List<TournamentPair>.from(inputPairs);
    // Tri par poids croissant (plus petit = plus fort)
    pairs.sort((a, b) {
      if (a.weight != b.weight) {
        return a.weight.compareTo(b.weight);
      }
      final minA = min(a.player1Rank, a.player2Rank);
      final minB = min(b.player1Rank, b.player2Rank);
      return minA.compareTo(minB);
    });

    final bracketSize = getBracketSize(pairs.length);
    final seedCount = getSeedCount(bracketSize, pairs.length);

    final result = <TournamentPair>[];
    for (int i = 0; i < pairs.length; i++) {
      final seed = i < seedCount ? i + 1 : null;
      result.add(pairs[i].copyWith(seed: seed));
    }
    return result;
  }

  /// Génère l'ensemble du tableau officiel FFT (Principal + Consolante)
  static TournamentBracket generateBracket({
    required String tournamentId,
    String category = 'double_mixtes',
    required List<TournamentPair> registeredPairs,
    int numCourts = 4,
  }) {
    if (registeredPairs.isEmpty) {
      return TournamentBracket(
        tournamentId: tournamentId,
        category: category,
        format: 'elimination',
        numCourts: numCourts,
        updatedAt: DateTime.now(),
      );
    }

    final seededPairs = assignSeeds(registeredPairs);
    final bracketSize = getBracketSize(seededPairs.length);
    final roundsCount = (log(bracketSize) / ln2).round();

    // 1. Initialisation des matches du tableau principal
    final mainMatches = <BracketMatch>[];
    for (int r = 0; r < roundsCount; r++) {
      final matchesInRound = bracketSize ~/ pow(2, r + 1);
      final roundName = _getRoundName(roundsCount - 1 - r);

      for (int m = 0; m < matchesInRound; m++) {
        final matchId = "main_${r}_$m";
        final nextMatchId = r < roundsCount - 1 ? "main_${r + 1}_${m ~/ 2}" : null;
        final nextSlot = r < roundsCount - 1 ? (m % 2 == 0 ? 1 : 2) : null;

        // Consolante pour les matches du 1er tour (si le tableau fait au moins 8)
        String? consoId;
        int? consoSlot;
        if (r == 0 && bracketSize >= 8) {
          consoId = "conso_0_${m ~/ 2}";
          consoSlot = m % 2 == 0 ? 1 : 2;
        }

        mainMatches.add(BracketMatch(
          id: matchId,
          roundIndex: r,
          roundName: roundName,
          matchIndex: m,
          nextMatchId: nextMatchId,
          nextMatchSlot: nextSlot,
          consolationMatchId: consoId,
          consolationSlot: consoSlot,
        ));
      }
    }

    // 2. Placement FFT réglementaire des paires au 1er tour (Round 0)
    final r0Slots = List<TournamentPair?>.filled(bracketSize, null);
    final seedMap = <int, TournamentPair>{};
    final unseeded = <TournamentPair>[];
    for (final p in seededPairs) {
      if (p.seed != null) {
        seedMap[p.seed!] = p;
      } else {
        unseeded.add(p);
      }
    }

    // Cas spécial Tableau de 16 avec 4 BYE (ex: 12 équipes mixte Toulon)
    if (bracketSize == 16 && seededPairs.length == 12) {
      // Haut: TS2 en Slot 0 (Match 0 Slot 1), BYE en Slot 1 (Match 0 Slot 2)
      if (seedMap.containsKey(2)) r0Slots[0] = seedMap[2];
      r0Slots[1] = const TournamentPair(id: "bye_ts2", player1Name: "EXEMPT", player2Name: "BYE", isBye: true);

      // Haut: BYE en Slot 6 (Match 3 Slot 1), TS3 en Slot 7 (Match 3 Slot 2)
      r0Slots[6] = const TournamentPair(id: "bye_ts3", player1Name: "EXEMPT", player2Name: "BYE", isBye: true);
      if (seedMap.containsKey(3)) r0Slots[7] = seedMap[3];

      // Bas: TS4 en Slot 8 (Match 4 Slot 1), BYE en Slot 9 (Match 4 Slot 2)
      if (seedMap.containsKey(4)) r0Slots[8] = seedMap[4];
      r0Slots[9] = const TournamentPair(id: "bye_ts4", player1Name: "EXEMPT", player2Name: "BYE", isBye: true);

      // Bas: BYE en Slot 14 (Match 7 Slot 1), TS1 en Slot 15 (Match 7 Slot 2)
      r0Slots[14] = const TournamentPair(id: "bye_ts1", player1Name: "EXEMPT", player2Name: "BYE", isBye: true);
      if (seedMap.containsKey(1)) r0Slots[15] = seedMap[1];

      // Remplissage des 8 slots restants (Matches 1, 2, 5, 6) avec les 8 paires non têtes de série
      final remainingSlots = [2, 3, 4, 5, 10, 11, 12, 13];
      for (int i = 0; i < remainingSlots.length && i < unseeded.length; i++) {
        r0Slots[remainingSlots[i]] = unseeded[i];
      }
    } else {
      // Placement générique FFT
      if (seedMap.containsKey(2)) r0Slots[0] = seedMap[2];
      if (seedMap.containsKey(1)) r0Slots[bracketSize - 1] = seedMap[1];

      if (bracketSize >= 8) {
        final posQuartHaut = (bracketSize ~/ 2) - 1;
        final posQuartBas = bracketSize ~/ 2;
        if (seedMap.containsKey(4)) r0Slots[posQuartHaut] = seedMap[4];
        if (seedMap.containsKey(3)) r0Slots[posQuartBas] = seedMap[3];
      }

      int numByes = bracketSize - seededPairs.length;
      final byePrioritySlots = [
        bracketSize - 2, // Opposant TS1
        1,               // Opposant TS2
        if (bracketSize >= 8) (bracketSize ~/ 2) + 1, // Opposant TS3
        if (bracketSize >= 8) (bracketSize ~/ 2) - 2, // Opposant TS4
        3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31
      ];

      int byeIdx = 0;
      for (final slot in byePrioritySlots) {
        if (byeIdx >= numByes) break;
        if (slot < bracketSize && r0Slots[slot] == null) {
          r0Slots[slot] = TournamentPair(
            id: "bye_$byeIdx",
            player1Name: "EXEMPT",
            player2Name: "BYE",
            isBye: true,
          );
          byeIdx++;
        }
      }

      int unseededIdx = 0;
      for (int s = 0; s < bracketSize; s++) {
        if (r0Slots[s] == null) {
          if (unseededIdx < unseeded.length) {
            r0Slots[s] = unseeded[unseededIdx++];
          } else if (byeIdx < numByes) {
            r0Slots[s] = TournamentPair(
              id: "bye_$byeIdx",
              player1Name: "EXEMPT",
              player2Name: "BYE",
              isBye: true,
            );
            byeIdx++;
          }
        }
      }
    }

    // Injecter les paires dans les matches du round 0
    final updatedMainMatches = <BracketMatch>[];
    for (final m in mainMatches) {
      if (m.roundIndex == 0) {
        final p1 = r0Slots[m.matchIndex * 2];
        final p2 = r0Slots[m.matchIndex * 2 + 1];

        final hasBye = (p1?.isBye == true) || (p2?.isBye == true);
        String? winnerId;
        String status = 'pending';
        String? score;

        if (hasBye) {
          status = 'completed';
          score = 'EXEMPT';
          if (p1 != null && !p1.isBye) winnerId = p1.id;
          if (p2 != null && !p2.isBye) winnerId = p2.id;
        }

        updatedMainMatches.add(m.copyWith(
          pair1: p1,
          pair2: p2,
          isBye: hasBye,
          status: status,
          score: score,
          winnerId: winnerId,
        ));
      } else {
        updatedMainMatches.add(m);
      }
    }

    // Propager immédiatement les gagnants de BYE au Round 1
    for (final m in updatedMainMatches.where((x) => x.roundIndex == 0 && x.isBye && x.winnerId != null).toList()) {
      _applyWinnerProgression(updatedMainMatches, m);
    }

    // 3. Construction de l'arbre de Consolante
    final consolationMatches = <BracketMatch>[];
    if (bracketSize >= 8) {
      final nonByeRound0Matches = updatedMainMatches.where((m) => m.roundIndex == 0 && !m.isBye).length;
      final consoSize = getBracketSize(max(2, nonByeRound0Matches));
      final consoRounds = (log(consoSize) / ln2).round();

      for (int r = 0; r < consoRounds; r++) {
        final matchesInRound = consoSize ~/ pow(2, r + 1);
        final roundName = "Consolante ${_getRoundName(consoRounds - 1 - r)}";

        for (int m = 0; m < matchesInRound; m++) {
          final matchId = "conso_${r}_$m";
          final nextMatchId = r < consoRounds - 1 ? "conso_${r + 1}_${m ~/ 2}" : null;
          final nextSlot = r < consoRounds - 1 ? (m % 2 == 0 ? 1 : 2) : null;

          consolationMatches.add(BracketMatch(
            id: matchId,
            roundIndex: r,
            roundName: roundName,
            matchIndex: m,
            nextMatchId: nextMatchId,
            nextMatchSlot: nextSlot,
          ));
        }
      }

      // Re-lier les consolations du tour 0
      int nonByeIdx = 0;
      for (int i = 0; i < updatedMainMatches.length; i++) {
        final m = updatedMainMatches[i];
        if (m.roundIndex == 0 && !m.isBye) {
          final consoTargetMatch = nonByeIdx ~/ 2;
          final consoTargetSlot = nonByeIdx % 2 == 0 ? 1 : 2;
          if (consoTargetMatch < (consoSize ~/ 2)) {
            updatedMainMatches[i] = m.copyWith(
              consolationMatchId: "conso_0_$consoTargetMatch",
              consolationSlot: consoTargetSlot,
            );
          }
          nonByeIdx++;
        }
      }
    }

    return TournamentBracket(
      tournamentId: tournamentId,
      category: category,
      format: 'elimination',
      numCourts: numCourts,
      status: 'in_progress',
      pairs: seededPairs,
      mainMatches: updatedMainMatches,
      consolationMatches: consolationMatches,
      updatedAt: DateTime.now(),
    );
  }

  /// Génère un tournoi au format Poules + Phase Finale (ex: Double Hommes & Dames Toulon)
  static TournamentBracket generatePoolsAndBracket({
    required String tournamentId,
    required String category,
    required List<TournamentPair> pouleAPairs,
    required List<TournamentPair> pouleBPairs,
    int numCourts = 4,
  }) {
    // 1. Matches de la Poule A (3 équipes -> 3 matches)
    final matchesA = <BracketMatch>[];
    if (pouleAPairs.length >= 3) {
      matchesA.add(BracketMatch(
        id: "pa_0",
        roundIndex: 0,
        roundName: "Poule A - Match 1",
        matchIndex: 0,
        poolId: "poule_a",
        matchCode: "PA_1",
        pair1: pouleAPairs[0],
        pair2: pouleAPairs[1],
      ));
      matchesA.add(BracketMatch(
        id: "pa_1",
        roundIndex: 0,
        roundName: "Poule A - Match 2",
        matchIndex: 1,
        poolId: "poule_a",
        matchCode: "PA_2",
        pair1: pouleAPairs[0],
        pair2: pouleAPairs[2],
      ));
      matchesA.add(BracketMatch(
        id: "pa_2",
        roundIndex: 0,
        roundName: "Poule A - Match 3",
        matchIndex: 2,
        poolId: "poule_a",
        matchCode: "PA_3",
        pair1: pouleAPairs[1],
        pair2: pouleAPairs[2],
      ));
    }

    // 2. Matches de la Poule B (3 équipes -> 3 matches)
    final matchesB = <BracketMatch>[];
    if (pouleBPairs.length >= 3) {
      matchesB.add(BracketMatch(
        id: "pb_0",
        roundIndex: 0,
        roundName: "Poule B - Match 1",
        matchIndex: 0,
        poolId: "poule_b",
        matchCode: "PB_1",
        pair1: pouleBPairs[0],
        pair2: pouleBPairs[1],
      ));
      matchesB.add(BracketMatch(
        id: "pb_1",
        roundIndex: 0,
        roundName: "Poule B - Match 2",
        matchIndex: 1,
        poolId: "poule_b",
        matchCode: "PB_2",
        pair1: pouleBPairs[0],
        pair2: pouleBPairs[2],
      ));
      matchesB.add(BracketMatch(
        id: "pb_2",
        roundIndex: 0,
        roundName: "Poule B - Match 3",
        matchIndex: 2,
        poolId: "poule_b",
        matchCode: "PB_3",
        pair1: pouleBPairs[1],
        pair2: pouleBPairs[2],
      ));
    }

    final pools = [
      TournamentPool(
        id: "poule_a",
        name: "Poule A",
        pairs: pouleAPairs,
        matches: matchesA,
      ),
      TournamentPool(
        id: "poule_b",
        name: "Poule B",
        pairs: pouleBPairs,
        matches: matchesB,
      ),
    ];

    // 3. Phase Finale (Demis, Finale, 3e/4e, 5e/6e)
    final finalMatches = <BracketMatch>[
      // Demi-finale 1 : 1er Poule A vs 2ème Poule B
      const BracketMatch(
        id: "final_df1",
        roundIndex: 0,
        roundName: "Demi-finale 1",
        matchIndex: 0,
        matchCode: "DF1",
        nextMatchId: "final_fin",
        nextMatchSlot: 1,
        consolationMatchId: "final_p34",
        consolationSlot: 1,
      ),
      // Demi-finale 2 : 1er Poule B vs 2ème Poule A
      const BracketMatch(
        id: "final_df2",
        roundIndex: 0,
        roundName: "Demi-finale 2",
        matchIndex: 1,
        matchCode: "DF2",
        nextMatchId: "final_fin",
        nextMatchSlot: 2,
        consolationMatchId: "final_p34",
        consolationSlot: 2,
      ),
      // Finale : Vainqueur DF1 vs Vainqueur DF2
      const BracketMatch(
        id: "final_fin",
        roundIndex: 1,
        roundName: "Grande Finale",
        matchIndex: 0,
        matchCode: "FINALE",
      ),
      // Petite Finale : Perdant DF1 vs Perdant DF2 (Place 3 & 4)
      const BracketMatch(
        id: "final_p34",
        roundIndex: 1,
        roundName: "Match Place 3 / 4",
        matchIndex: 1,
        matchCode: "PLACE_3_4",
      ),
      // Match de Classement : 3ème Poule A vs 3ème Poule B (Place 5 & 6)
      const BracketMatch(
        id: "final_p56",
        roundIndex: 1,
        roundName: "Match Place 5 / 6",
        matchIndex: 2,
        matchCode: "PLACE_5_6",
      ),
    ];

    final allPairs = [...pouleAPairs, ...pouleBPairs];

    return TournamentBracket(
      tournamentId: tournamentId,
      category: category,
      format: 'pools_and_bracket',
      numCourts: numCourts,
      status: 'in_progress',
      pairs: allPairs,
      mainMatches: finalMatches,
      pools: pools,
      updatedAt: DateTime.now(),
    );
  }

  /// Valide le score d'un match de poule et met à jour le classement et la phase finale
  static TournamentBracket recordPoolMatchScore({
    required TournamentBracket bracket,
    required String poolId,
    required String matchId,
    required String score,
    required String winnerId,
  }) {
    final updatedPools = <TournamentPool>[];
    for (final pool in bracket.pools) {
      if (pool.id == poolId) {
        final updatedMatches = pool.matches.map((m) {
          if (m.id == matchId) {
            return m.copyWith(
              score: score,
              winnerId: winnerId,
              status: 'completed',
            );
          }
          return m;
        }).toList();
        updatedPools.add(pool.copyWith(matches: updatedMatches));
      } else {
        updatedPools.add(pool);
      }
    }

    // Vérifier si les deux poules ont terminé pour pré-remplir la phase finale
    List<BracketMatch> updatedFinalMatches = List<BracketMatch>.from(bracket.mainMatches);
    final poolA = updatedPools.firstWhere((p) => p.id == "poule_a", orElse: () => updatedPools.first);
    final poolB = updatedPools.firstWhere((p) => p.id == "poule_b", orElse: () => updatedPools.last);

    final standingsA = poolA.calculateStandings();
    final standingsB = poolB.calculateStandings();

    final allACompleted = poolA.matches.every((m) => m.isCompleted);
    final allBCompleted = poolB.matches.every((m) => m.isCompleted);

    if (allACompleted && allBCompleted && standingsA.length >= 3 && standingsB.length >= 3) {
      for (int i = 0; i < updatedFinalMatches.length; i++) {
        final m = updatedFinalMatches[i];
        if (m.id == "final_df1") {
          updatedFinalMatches[i] = m.copyWith(
            pair1: standingsA[0].pair, // 1er Poule A
            pair2: standingsB[1].pair, // 2ème Poule B
          );
        } else if (m.id == "final_df2") {
          updatedFinalMatches[i] = m.copyWith(
            pair1: standingsB[0].pair, // 1er Poule B
            pair2: standingsA[1].pair, // 2ème Poule A
          );
        } else if (m.id == "final_p56") {
          updatedFinalMatches[i] = m.copyWith(
            pair1: standingsA[2].pair, // 3ème Poule A
            pair2: standingsB[2].pair, // 3ème Poule B
          );
        }
      }
    }

    return bracket.copyWith(
      pools: updatedPools,
      mainMatches: updatedFinalMatches,
      updatedAt: DateTime.now(),
    );
  }

  /// Saisie libre par le JAT : force ou remplace une paire dans un match
  static TournamentBracket manualUpdateMatchPair({
    required TournamentBracket bracket,
    required String matchId,
    required int slot, // 1 or 2
    required TournamentPair? pair,
  }) {
    // Vérifie si le match est dans les poules
    bool foundInPool = false;
    final updatedPools = bracket.pools.map((pool) {
      final mIdx = pool.matches.indexWhere((m) => m.id == matchId);
      if (mIdx != -1) {
        foundInPool = true;
        final m = pool.matches[mIdx];
        final updatedMatches = List<BracketMatch>.from(pool.matches);
        updatedMatches[mIdx] = m.copyWith(
          pair1: slot == 1 ? pair : m.pair1,
          pair2: slot == 2 ? pair : m.pair2,
          clearPair1: slot == 1 && pair == null,
          clearPair2: slot == 2 && pair == null,
        );
        return pool.copyWith(matches: updatedMatches);
      }
      return pool;
    }).toList();

    if (foundInPool) {
      return bracket.copyWith(pools: updatedPools, updatedAt: DateTime.now());
    }

    // Sinon vérifie dans mainMatches ou consolationMatches
    final isMain = bracket.mainMatches.any((m) => m.id == matchId);
    final targetList = isMain ? List<BracketMatch>.from(bracket.mainMatches) : List<BracketMatch>.from(bracket.consolationMatches);
    final mIdx = targetList.indexWhere((m) => m.id == matchId);
    if (mIdx == -1) return bracket;

    final m = targetList[mIdx];
    targetList[mIdx] = m.copyWith(
      pair1: slot == 1 ? pair : m.pair1,
      pair2: slot == 2 ? pair : m.pair2,
      clearPair1: slot == 1 && pair == null,
      clearPair2: slot == 2 && pair == null,
    );

    return bracket.copyWith(
      mainMatches: isMain ? targetList : bracket.mainMatches,
      consolationMatches: isMain ? bracket.consolationMatches : targetList,
      updatedAt: DateTime.now(),
    );
  }

  /// Valide le score d'un match et fait monter la paire gagnante au tour suivant (et perdant en consolante)
  static TournamentBracket recordMatchScore({
    required TournamentBracket bracket,
    required String matchId,
    required String score,
    required String winnerId,
  }) {
    final isMain = bracket.mainMatches.any((m) => m.id == matchId);
    final targetList = isMain ? List<BracketMatch>.from(bracket.mainMatches) : List<BracketMatch>.from(bracket.consolationMatches);
    final matchIndex = targetList.indexWhere((m) => m.id == matchId);
    if (matchIndex == -1) return bracket;

    final match = targetList[matchIndex];
    final updatedMatch = match.copyWith(
      score: score,
      winnerId: winnerId,
      status: 'completed',
    );
    targetList[matchIndex] = updatedMatch;

    // 1. Progression du vainqueur au tour suivant
    _applyWinnerProgression(targetList, updatedMatch);

    // 2. Si match de phase finale avec consolante (ex: Petite Finale 3e/4e)
    if (match.consolationMatchId != null) {
      final loser = updatedMatch.loser;
      if (loser != null && !loser.isBye) {
        if (bracket.format == 'pools_and_bracket') {
          // Dans pools_and_bracket, la consolante est le match de place 3/4 dans mainMatches
          final cIdx = targetList.indexWhere((m) => m.id == match.consolationMatchId);
          if (cIdx != -1) {
            final cm = targetList[cIdx];
            targetList[cIdx] = cm.copyWith(
              pair1: match.consolationSlot == 1 ? loser : cm.pair1,
              pair2: match.consolationSlot == 2 ? loser : cm.pair2,
            );
          }
        } else {
          // Dans elimination, bascule dans consolationMatches
          List<BracketMatch> updatedConso = List<BracketMatch>.from(bracket.consolationMatches);
          final consoIdx = updatedConso.indexWhere((m) => m.id == match.consolationMatchId);
          if (consoIdx != -1) {
            final cm = updatedConso[consoIdx];
            updatedConso[consoIdx] = cm.copyWith(
              pair1: match.consolationSlot == 1 ? loser : cm.pair1,
              pair2: match.consolationSlot == 2 ? loser : cm.pair2,
            );
            return bracket.copyWith(
              mainMatches: targetList,
              consolationMatches: updatedConso,
              updatedAt: DateTime.now(),
            );
          }
        }
      }
    }

    return bracket.copyWith(
      mainMatches: isMain ? targetList : bracket.mainMatches,
      consolationMatches: isMain ? bracket.consolationMatches : targetList,
      updatedAt: DateTime.now(),
    );
  }

  /// Assigne un terrain à un match
  static TournamentBracket assignCourt({
    required TournamentBracket bracket,
    required String matchId,
    required int court,
    bool startMatch = true,
  }) {
    // Vérifie si le match est dans une poule
    bool foundInPool = false;
    final updatedPools = bracket.pools.map((pool) {
      final mIdx = pool.matches.indexWhere((m) => m.id == matchId);
      if (mIdx != -1) {
        foundInPool = true;
        final m = pool.matches[mIdx];
        final updatedMatches = List<BracketMatch>.from(pool.matches);
        updatedMatches[mIdx] = m.copyWith(
          court: court,
          status: startMatch ? 'in_progress' : m.status,
        );
        return pool.copyWith(matches: updatedMatches);
      }
      return pool;
    }).toList();

    if (foundInPool) {
      return bracket.copyWith(pools: updatedPools, updatedAt: DateTime.now());
    }

    final isMain = bracket.mainMatches.any((m) => m.id == matchId);
    final targetList = isMain ? List<BracketMatch>.from(bracket.mainMatches) : List<BracketMatch>.from(bracket.consolationMatches);
    final matchIndex = targetList.indexWhere((m) => m.id == matchId);
    if (matchIndex == -1) return bracket;

    final match = targetList[matchIndex];
    targetList[matchIndex] = match.copyWith(
      court: court,
      status: startMatch ? 'in_progress' : match.status,
    );

    return bracket.copyWith(
      mainMatches: isMain ? targetList : bracket.mainMatches,
      consolationMatches: isMain ? bracket.consolationMatches : targetList,
      updatedAt: DateTime.now(),
    );
  }

  static void _applyWinnerProgression(List<BracketMatch> matches, BracketMatch completedMatch) {
    if (completedMatch.nextMatchId == null) return;
    final winner = completedMatch.winner;
    if (winner == null) return;

    final nextIdx = matches.indexWhere((m) => m.id == completedMatch.nextMatchId);
    if (nextIdx == -1) return;

    final nextMatch = matches[nextIdx];
    matches[nextIdx] = nextMatch.copyWith(
      pair1: completedMatch.nextMatchSlot == 1 ? winner : nextMatch.pair1,
      pair2: completedMatch.nextMatchSlot == 2 ? winner : nextMatch.pair2,
    );
  }

  static String _getRoundName(int roundsFromFinal) {
    switch (roundsFromFinal) {
      case 0:
        return "Finale";
      case 1:
        return "Demi-finales";
      case 2:
        return "Quarts de finale";
      case 3:
        return "1/8 de finale";
      case 4:
        return "1/16 de finale";
      default:
        return "Tour ${roundsFromFinal + 1}";
    }
  }
}
