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

    // Attribution automatique intelligente des terrains
    final smartMainMatches = _assignSmartCourtsToBracketMatches(
      matches: updatedMainMatches,
      roundsCount: roundsCount,
      numCourts: numCourts,
    );

    final smartConsoMatches = _assignSmartCourtsToConsoMatches(
      matches: consolationMatches,
      numCourts: numCourts,
    );

    return TournamentBracket(
      tournamentId: tournamentId,
      category: category,
      format: 'elimination',
      numCourts: numCourts,
      status: 'in_progress',
      pairs: seededPairs,
      mainMatches: smartMainMatches,
      consolationMatches: smartConsoMatches,
      updatedAt: DateTime.now(),
    );
  }

  /// Génère les matches d'une poule de 2, 3 ou 4 paires (Round Robin)
  static List<BracketMatch> _generatePoolMatches({
    required String poolId,
    required String poolName,
    required String matchPrefix,
    required List<TournamentPair> pairs,
  }) {
    final matches = <BracketMatch>[];
    final poolCode = poolId == 'poule_a' ? 'PA' : 'PB';

    if (pairs.length == 3) {
      // 3 paires -> 3 matches
      matches.add(BracketMatch(
        id: "${matchPrefix}_0",
        roundIndex: 0,
        roundName: "$poolName - Match 1",
        matchIndex: 0,
        poolId: poolId,
        matchCode: "${poolCode}_1",
        pair1: pairs[0],
        pair2: pairs[1],
      ));
      matches.add(BracketMatch(
        id: "${matchPrefix}_1",
        roundIndex: 0,
        roundName: "$poolName - Match 2",
        matchIndex: 1,
        poolId: poolId,
        matchCode: "${poolCode}_2",
        pair1: pairs[0],
        pair2: pairs[2],
      ));
      matches.add(BracketMatch(
        id: "${matchPrefix}_2",
        roundIndex: 0,
        roundName: "$poolName - Match 3",
        matchIndex: 2,
        poolId: poolId,
        matchCode: "${poolCode}_3",
        pair1: pairs[1],
        pair2: pairs[2],
      ));
    } else if (pairs.length == 4) {
      // 4 paires -> 6 matches (Round Robin FFT)
      // Tour 1 : 0 vs 1 & 2 vs 3
      // Tour 2 : 0 vs 2 & 1 vs 3
      // Tour 3 : 0 vs 3 & 1 vs 2
      final schedule = [
        [0, 1],
        [2, 3],
        [0, 2],
        [1, 3],
        [0, 3],
        [1, 2],
      ];
      for (int i = 0; i < schedule.length; i++) {
        final pairAIdx = schedule[i][0];
        final pairBIdx = schedule[i][1];
        matches.add(BracketMatch(
          id: "${matchPrefix}_$i",
          roundIndex: 0,
          roundName: "$poolName - Match ${i + 1}",
          matchIndex: i,
          poolId: poolId,
          matchCode: "${poolCode}_${i + 1}",
          pair1: pairs[pairAIdx],
          pair2: pairs[pairBIdx],
        ));
      }
    } else if (pairs.length >= 5) {
      // 5 paires -> 10 matches (Table de Berger FFT, 5 rotations de 2 matches, 1 exempt par tour)
      // Tour 1 : 0 vs 4 & 1 vs 3 (Exempt: 2)
      // Tour 2 : 0 vs 3 & 2 vs 1 (Exempt: 4)
      // Tour 3 : 0 vs 2 & 3 vs 4 (Exempt: 1)
      // Tour 4 : 0 vs 1 & 4 vs 2 (Exempt: 3 - Choc TS1 vs TS2 !)
      // Tour 5 : 1 vs 4 & 2 vs 3 (Exempt: 0)
      final schedule = [
        [0, 4],
        [1, 3],
        [0, 3],
        [2, 1],
        [0, 2],
        [3, 4],
        [0, 1],
        [4, 2],
        [1, 4],
        [2, 3],
      ];
      for (int i = 0; i < schedule.length; i++) {
        final pairAIdx = schedule[i][0];
        final pairBIdx = schedule[i][1];
        final tourNumber = (i ~/ 2) + 1;
        final matchInTour = (i % 2) + 1;
        matches.add(BracketMatch(
          id: "${matchPrefix}_$i",
          roundIndex: i ~/ 2,
          roundName: "$poolName - Tour $tourNumber (M$matchInTour)",
          matchIndex: i,
          poolId: poolId,
          matchCode: "${poolCode}_${i + 1}",
          pair1: pairs[pairAIdx],
          pair2: pairs[pairBIdx],
        ));
      }
    } else if (pairs.length == 2) {
      // 2 paires -> 1 match
      matches.add(BracketMatch(
        id: "${matchPrefix}_0",
        roundIndex: 0,
        roundName: "$poolName - Match 1",
        matchIndex: 0,
        poolId: poolId,
        matchCode: "${poolCode}_1",
        pair1: pairs[0],
        pair2: pairs[1],
      ));
    }

    return matches;
  }

  /// Génère un tournoi au format Poules + Phase Finale (ex: Double Hommes & Dames Toulon ou Poule Unique)
  static TournamentBracket generatePoolsAndBracket({
    required String tournamentId,
    required String category,
    required List<TournamentPair> pouleAPairs,
    required List<TournamentPair> pouleBPairs,
    String finalPhaseType = 'direct_finals',
    int numCourts = 4,
  }) {
    // 1. Matches de la Poule A (3 paires = 3 matches, 4 paires = 6 matches, 5 paires = 10 matches)
    final matchesA = _generatePoolMatches(
      poolId: "poule_a",
      poolName: pouleBPairs.isEmpty ? "Poule Unique" : "Poule A",
      matchPrefix: "pa",
      pairs: pouleAPairs,
    );

    // Cas d'une Poule Unique (ex: 5 paires DD BT 25)
    if (pouleBPairs.isEmpty) {
      final smartMatches = _assignSmartCourtsToPoolMatches(
        matches: matchesA,
        isPoolA: true,
        numCourts: numCourts,
      );
      final singlePool = TournamentPool(
        id: "poule_a",
        name: "Poule Unique",
        pairs: pouleAPairs,
        matches: smartMatches,
      );
      return TournamentBracket(
        tournamentId: tournamentId,
        category: category,
        format: 'pools_and_bracket',
        finalPhaseType: 'direct_finals',
        numCourts: numCourts,
        status: 'draft',
        pairs: pouleAPairs,
        pools: [singlePool],
        mainMatches: const [],
        consolationMatches: const [],
        updatedAt: DateTime.now(),
      );
    }

    // 2. Matches de la Poule B (si 2 poules)
    final matchesB = _generatePoolMatches(
      poolId: "poule_b",
      poolName: "Poule B",
      matchPrefix: "pb",
      pairs: pouleBPairs,
    );

    // Attribution automatique intelligente des terrains sur les poules
    final smartMatchesA = _assignSmartCourtsToPoolMatches(
      matches: matchesA,
      isPoolA: true,
      numCourts: numCourts,
    );
    final smartMatchesB = _assignSmartCourtsToPoolMatches(
      matches: matchesB,
      isPoolA: false,
      numCourts: numCourts,
    );

    final pools = [
      TournamentPool(
        id: "poule_a",
        name: "Poule A",
        pairs: pouleAPairs,
        matches: smartMatchesA,
      ),
      TournamentPool(
        id: "poule_b",
        name: "Poule B",
        pairs: pouleBPairs,
        matches: smartMatchesB,
      ),
    ];

    // 3. Phase Finale : Directe (FFT 1 jour) ou Demi-Finales Croisées (2 jours / Championnat)
    final finalMatches = <BracketMatch>[];

    if (finalPhaseType == 'crossover_semis') {
      // Formule avec Demi-finales croisées (1A vs 2B, 1B vs 2A)
      finalMatches.add(const BracketMatch(
        id: "final_df1",
        roundIndex: 0,
        roundName: "Demi-finale 1 (1A vs 2B)",
        matchIndex: 0,
        matchCode: "DF1",
        nextMatchId: "final_fin",
        nextMatchSlot: 1,
        consolationMatchId: "final_p34",
        consolationSlot: 1,
      ));
      finalMatches.add(const BracketMatch(
        id: "final_df2",
        roundIndex: 0,
        roundName: "Demi-finale 2 (1B vs 2A)",
        matchIndex: 1,
        matchCode: "DF2",
        nextMatchId: "final_fin",
        nextMatchSlot: 2,
        consolationMatchId: "final_p34",
        consolationSlot: 2,
      ));
      finalMatches.add(const BracketMatch(
        id: "final_fin",
        roundIndex: 1,
        roundName: "Grande Finale (Places 1 & 2)",
        matchIndex: 0,
        matchCode: "FINALE",
      ));
      finalMatches.add(const BracketMatch(
        id: "final_p34",
        roundIndex: 1,
        roundName: "Petite Finale (Places 3 & 4)",
        matchIndex: 1,
        matchCode: "PLACE_3_4",
      ));
      finalMatches.add(const BracketMatch(
        id: "final_p56",
        roundIndex: 0,
        roundName: "Match Places 5 & 6",
        matchIndex: 2,
        matchCode: "PLACE_5_6",
      ));
      if (pouleAPairs.length >= 4 && pouleBPairs.length >= 4) {
        finalMatches.add(const BracketMatch(
          id: "final_p78",
          roundIndex: 0,
          roundName: "Match Places 7 & 8",
          matchIndex: 3,
          matchCode: "PLACE_7_8",
        ));
      }
    } else {
      // Formule FFT Directe (1er vs 1er, 2e vs 2e, 3e vs 3e...)
      finalMatches.add(const BracketMatch(
        id: "final_fin",
        roundIndex: 0,
        roundName: "Grande Finale (Places 1 & 2)",
        matchIndex: 0,
        matchCode: "FINALE",
      ));
      finalMatches.add(const BracketMatch(
        id: "final_p34",
        roundIndex: 0,
        roundName: "Petite Finale (Places 3 & 4)",
        matchIndex: 1,
        matchCode: "PLACE_3_4",
      ));
      finalMatches.add(const BracketMatch(
        id: "final_p56",
        roundIndex: 0,
        roundName: "Match Places 5 & 6",
        matchIndex: 2,
        matchCode: "PLACE_5_6",
      ));
      if (pouleAPairs.length >= 4 && pouleBPairs.length >= 4) {
        finalMatches.add(const BracketMatch(
          id: "final_p78",
          roundIndex: 0,
          roundName: "Match Places 7 & 8",
          matchIndex: 3,
          matchCode: "PLACE_7_8",
        ));
      }
    }

    final smartFinalMatches = _assignSmartCourtsToFinalMatches(
      matches: finalMatches,
      numCourts: numCourts,
    );

    final allPairs = [...pouleAPairs, ...pouleBPairs];

    return TournamentBracket(
      tournamentId: tournamentId,
      category: category,
      format: 'pools_and_bracket',
      finalPhaseType: finalPhaseType,
      numCourts: numCourts,
      status: 'in_progress',
      pairs: allPairs,
      mainMatches: smartFinalMatches,
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

    if (allACompleted && allBCompleted && standingsA.length >= 2 && standingsB.length >= 2) {
      final isSemis = bracket.finalPhaseType == 'crossover_semis';
      for (int i = 0; i < updatedFinalMatches.length; i++) {
        final m = updatedFinalMatches[i];
        if (isSemis) {
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
          }
        } else {
          if (m.id == "final_fin") {
            updatedFinalMatches[i] = m.copyWith(
              pair1: standingsA[0].pair, // 1er Poule A
              pair2: standingsB[0].pair, // 1er Poule B
            );
          } else if (m.id == "final_p34") {
            updatedFinalMatches[i] = m.copyWith(
              pair1: standingsA[1].pair, // 2ème Poule A
              pair2: standingsB[1].pair, // 2ème Poule B
            );
          }
        }

        // Places 5 & 6 et Places 7 & 8
        if (m.id == "final_p56" && standingsA.length >= 3 && standingsB.length >= 3) {
          updatedFinalMatches[i] = m.copyWith(
            pair1: standingsA[2].pair, // 3ème Poule A
            pair2: standingsB[2].pair, // 3ème Poule B
          );
        } else if (m.id == "final_p78" && standingsA.length >= 4 && standingsB.length >= 4) {
          updatedFinalMatches[i] = m.copyWith(
            pair1: standingsA[3].pair, // 4ème Poule A
            pair2: standingsB[3].pair, // 4ème Poule B
          );
        }
      }

      // Remplir automatiquement la Poule de Classement (Places 5 à 7) si présente
      final pool57Idx = updatedPools.indexWhere((p) => p.id == "poule_5_7");
      if (pool57Idx != -1) {
        TournamentPair? p3A = standingsA.length >= 3 ? standingsA[2].pair : null;
        TournamentPair? p4A = standingsA.length >= 4 ? standingsA[3].pair : null;
        TournamentPair? p3B = standingsB.length >= 3 ? standingsB[2].pair : null;
        final nonQualPairs = [p3A, p4A, p3B].whereType<TournamentPair>().toList();
        if (nonQualPairs.length >= 3) {
          final pool57 = updatedPools[pool57Idx];
          final p57Matches = List<BracketMatch>.from(pool57.matches);
          if (p57Matches.length >= 3) {
            p57Matches[0] = p57Matches[0].copyWith(pair1: p3A, pair2: p3B);
            p57Matches[1] = p57Matches[1].copyWith(pair1: p4A, pair2: p3B);
            p57Matches[2] = p57Matches[2].copyWith(pair1: p3A, pair2: p4A);
          }
          updatedPools[pool57Idx] = pool57.copyWith(
            pairs: nonQualPairs,
            matches: p57Matches,
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

  /// Modification en direct d'une paire par le JAT (joueur 1, joueur 2, classements, TS, etc.).
  /// Propage instantanément la modification dans la liste des paires, dans les poules et dans tous les matches
  /// (en préservant strictement les scores et les matches déjà joués).
  static TournamentBracket updatePair({
    required TournamentBracket bracket,
    required TournamentPair updatedPair,
  }) {
    // 1. Mettre à jour dans la liste globale des paires
    final updatedPairs = bracket.pairs.map((p) {
      return p.id == updatedPair.id ? updatedPair : p;
    }).toList();

    // 2. Mettre à jour dans les poules (paires de la poule + matches de poule)
    final updatedPools = bracket.pools.map((pool) {
      final poolPairs = pool.pairs.map((p) => p.id == updatedPair.id ? updatedPair : p).toList();
      final poolMatches = pool.matches.map((m) {
        return m.copyWith(
          pair1: m.pair1?.id == updatedPair.id ? updatedPair : m.pair1,
          pair2: m.pair2?.id == updatedPair.id ? updatedPair : m.pair2,
        );
      }).toList();
      return pool.copyWith(pairs: poolPairs, matches: poolMatches);
    }).toList();

    // 3. Mettre à jour dans le tableau principal
    final updatedMain = bracket.mainMatches.map((m) {
      return m.copyWith(
        pair1: m.pair1?.id == updatedPair.id ? updatedPair : m.pair1,
        pair2: m.pair2?.id == updatedPair.id ? updatedPair : m.pair2,
      );
    }).toList();

    // 4. Mettre à jour dans la consolante
    final updatedConso = bracket.consolationMatches.map((m) {
      return m.copyWith(
        pair1: m.pair1?.id == updatedPair.id ? updatedPair : m.pair1,
        pair2: m.pair2?.id == updatedPair.id ? updatedPair : m.pair2,
      );
    }).toList();

    return bracket.copyWith(
      pairs: updatedPairs,
      pools: updatedPools,
      mainMatches: updatedMain,
      consolationMatches: updatedConso,
      updatedAt: DateTime.now(),
    );
  }

  /// Suppression d'une paire par le JAT.
  /// Retire la paire de la liste des paires, des poules et vide les slots correspondants dans les matches non joués
  static TournamentBracket deletePair({
    required TournamentBracket bracket,
    required String pairId,
  }) {
    // 1. Retirer de la liste globale des paires
    final updatedPairs = bracket.pairs.where((p) => p.id != pairId).toList();

    // 2. Retirer des poules (paires de la poule + matches de poule)
    final updatedPools = bracket.pools.map((pool) {
      final poolPairs = pool.pairs.where((p) => p.id != pairId).toList();
      final poolMatches = pool.matches.map((m) {
        return m.copyWith(
          pair1: m.pair1?.id == pairId ? null : m.pair1,
          pair2: m.pair2?.id == pairId ? null : m.pair2,
        );
      }).toList();
      return pool.copyWith(pairs: poolPairs, matches: poolMatches);
    }).toList();

    // 3. Mettre à jour dans le tableau principal
    final updatedMain = bracket.mainMatches.map((m) {
      return m.copyWith(
        pair1: m.pair1?.id == pairId ? null : m.pair1,
        pair2: m.pair2?.id == pairId ? null : m.pair2,
      );
    }).toList();

    // 4. Mettre à jour dans la consolante
    final updatedConso = bracket.consolationMatches.map((m) {
      return m.copyWith(
        pair1: m.pair1?.id == pairId ? null : m.pair1,
        pair2: m.pair2?.id == pairId ? null : m.pair2,
      );
    }).toList();

    return bracket.copyWith(
      pairs: updatedPairs,
      pools: updatedPools,
      mainMatches: updatedMain,
      consolationMatches: updatedConso,
      updatedAt: DateTime.now(),
    );
  }

  /// Permutation manuelle de 2 paires par le JAT (Drag & Drop ou Clic & Swap).
  /// Échange la paire du slot A (matchIdA, slotA: 1 ou 2) avec la paire du slot B (matchIdB, slotB: 1 ou 2).
  /// Gère automatiquement :
  /// - L'inversion des paires dans le ou les matches ciblés
  /// - La réévaluation des BYEs (si l'une des paires est un EXEMPT / BYE)
  /// - La propagation / réinitialisation immédiate du gagnant vers le tour suivant si un BYE est déplacé
  /// - Le support complet pour le Tableau Principal, la Consolante et les Poules.
  static TournamentBracket swapPairs({
    required TournamentBracket bracket,
    required String matchIdA,
    required int slotA, // 1 or 2
    required String matchIdB,
    required int slotB, // 1 or 2
    String? poolIdA,
    String? poolIdB,
  }) {
    // 1. Cas des Poules
    if (poolIdA != null && poolIdB != null) {
      final poolAIdx = bracket.pools.indexWhere((p) => p.id == poolIdA);
      final poolBIdx = bracket.pools.indexWhere((p) => p.id == poolIdB);
      if (poolAIdx == -1 || poolBIdx == -1) return bracket;

      final poolA = bracket.pools[poolAIdx];
      final poolB = bracket.pools[poolBIdx];

      final mAIdx = poolA.matches.indexWhere((m) => m.id == matchIdA);
      final mBIdx = poolB.matches.indexWhere((m) => m.id == matchIdB);
      if (mAIdx == -1 || mBIdx == -1) return bracket;

      final pairA = slotA == 1 ? poolA.matches[mAIdx].pair1 : poolA.matches[mAIdx].pair2;
      final pairB = slotB == 1 ? poolB.matches[mBIdx].pair1 : poolB.matches[mBIdx].pair2;
      if (pairA == null && pairB == null) return bracket;
      if (pairA?.id == pairB?.id && pairA != null) return bracket;

      final updatedPools = List<TournamentPool>.from(bracket.pools);

      if (poolIdA == poolIdB) {
        // Permutation au sein de la même poule
        final updatedPairs = poolA.pairs.map((p) {
          if (pairA != null && p.id == pairA.id) return pairB ?? p;
          if (pairB != null && p.id == pairB.id) return pairA ?? p;
          return p;
        }).toList();

        final updatedMatches = poolA.matches.map((m) {
          TournamentPair? p1 = m.pair1;
          TournamentPair? p2 = m.pair2;
          bool changed = false;
          if (pairA != null && p1?.id == pairA.id) {
            p1 = pairB;
            changed = true;
          } else if (pairB != null && p1?.id == pairB.id) {
            p1 = pairA;
            changed = true;
          }
          if (pairA != null && p2?.id == pairA.id) {
            p2 = pairB;
            changed = true;
          } else if (pairB != null && p2?.id == pairB.id) {
            p2 = pairA;
            changed = true;
          }
          if (changed) {
            return m.copyWith(
              pair1: p1,
              pair2: p2,
              clearPair1: p1 == null,
              clearPair2: p2 == null,
              clearScore: true,
              clearWinner: true,
              status: 'pending',
            );
          }
          return m;
        }).toList();

        updatedPools[poolAIdx] = poolA.copyWith(pairs: updatedPairs, matches: updatedMatches);
      } else {
        // Permutation entre deux poules différentes
        final pairsA = poolA.pairs.map((p) => (pairA != null && p.id == pairA.id && pairB != null) ? pairB : p).toList();
        final pairsB = poolB.pairs.map((p) => (pairB != null && p.id == pairB.id && pairA != null) ? pairA : p).toList();

        final matchesA = poolA.matches.map((m) {
          TournamentPair? p1 = (pairA != null && m.pair1?.id == pairA.id) ? pairB : m.pair1;
          TournamentPair? p2 = (pairA != null && m.pair2?.id == pairA.id) ? pairB : m.pair2;
          if (p1 != m.pair1 || p2 != m.pair2) {
            return m.copyWith(pair1: p1, pair2: p2, clearScore: true, clearWinner: true, status: 'pending');
          }
          return m;
        }).toList();

        final matchesB = poolB.matches.map((m) {
          TournamentPair? p1 = (pairB != null && m.pair1?.id == pairB.id) ? pairA : m.pair1;
          TournamentPair? p2 = (pairB != null && m.pair2?.id == pairB.id) ? pairA : m.pair2;
          if (p1 != m.pair1 || p2 != m.pair2) {
            return m.copyWith(pair1: p1, pair2: p2, clearScore: true, clearWinner: true, status: 'pending');
          }
          return m;
        }).toList();

        updatedPools[poolAIdx] = poolA.copyWith(pairs: pairsA, matches: matchesA);
        updatedPools[poolBIdx] = poolB.copyWith(pairs: pairsB, matches: matchesB);
      }

      return bracket.copyWith(pools: updatedPools, updatedAt: DateTime.now());
    }

    // 2. Cas de l'Arbre (Tableau Principal et/ou Consolante)
    final listMain = List<BracketMatch>.from(bracket.mainMatches);
    final listConso = List<BracketMatch>.from(bracket.consolationMatches);

    final isMainA = listMain.any((m) => m.id == matchIdA);
    final isMainB = listMain.any((m) => m.id == matchIdB);

    final targetListA = isMainA ? listMain : listConso;
    final targetListB = isMainB ? listMain : listConso;

    final idxA = targetListA.indexWhere((m) => m.id == matchIdA);
    final idxB = targetListB.indexWhere((m) => m.id == matchIdB);
    if (idxA == -1 || idxB == -1) return bracket;

    if (matchIdA == matchIdB && slotA == slotB) return bracket;

    final matchA = targetListA[idxA];
    final matchB = targetListB[idxB];

    final pairA = slotA == 1 ? matchA.pair1 : matchA.pair2;
    final pairB = slotB == 1 ? matchB.pair1 : matchB.pair2;

    if (matchIdA == matchIdB) {
      // Inversion slot 1 et slot 2 dans le même match
      final newPair1 = matchA.pair2;
      final newPair2 = matchA.pair1;
      final hasBye = (newPair1?.isBye == true) || (newPair2?.isBye == true);
      String status = matchA.status;
      String? score = matchA.score;
      String? winnerId = matchA.winnerId;

      if (hasBye) {
        status = 'completed';
        score = 'EXEMPT';
        if (newPair1 != null && !newPair1.isBye) winnerId = newPair1.id;
        if (newPair2 != null && !newPair2.isBye) winnerId = newPair2.id;
      } else if (matchA.isBye || matchA.isCompleted) {
        status = 'pending';
        score = null;
        winnerId = null;
      }

      final updatedMatch = matchA.copyWith(
        pair1: newPair1,
        pair2: newPair2,
        clearPair1: newPair1 == null,
        clearPair2: newPair2 == null,
        isBye: hasBye,
        status: status,
        score: score,
        winnerId: winnerId,
        clearScore: score == null,
        clearWinner: winnerId == null,
      );

      targetListA[idxA] = updatedMatch;
      if (updatedMatch.nextMatchId != null) {
        _updateProgressionAfterSwap(targetListA, updatedMatch);
      }
    } else {
      // Échange entre deux matches distincts
      final newPair1A = slotA == 1 ? pairB : matchA.pair1;
      final newPair2A = slotA == 2 ? pairB : matchA.pair2;
      final hasByeA = (newPair1A?.isBye == true) || (newPair2A?.isBye == true);
      String statusA = matchA.status;
      String? scoreA = matchA.score;
      String? winnerIdA = matchA.winnerId;

      if (hasByeA) {
        statusA = 'completed';
        scoreA = 'EXEMPT';
        if (newPair1A != null && !newPair1A.isBye) winnerIdA = newPair1A.id;
        if (newPair2A != null && !newPair2A.isBye) winnerIdA = newPair2A.id;
      } else if (matchA.isBye || matchA.isCompleted) {
        statusA = 'pending';
        scoreA = null;
        winnerIdA = null;
      }

      final updatedMatchA = matchA.copyWith(
        pair1: newPair1A,
        pair2: newPair2A,
        clearPair1: newPair1A == null,
        clearPair2: newPair2A == null,
        isBye: hasByeA,
        status: statusA,
        score: scoreA,
        winnerId: winnerIdA,
        clearScore: scoreA == null,
        clearWinner: winnerIdA == null,
      );
      targetListA[idxA] = updatedMatchA;

      final newPair1B = slotB == 1 ? pairA : matchB.pair1;
      final newPair2B = slotB == 2 ? pairA : matchB.pair2;
      final hasByeB = (newPair1B?.isBye == true) || (newPair2B?.isBye == true);
      String statusB = matchB.status;
      String? scoreB = matchB.score;
      String? winnerIdB = matchB.winnerId;

      if (hasByeB) {
        statusB = 'completed';
        scoreB = 'EXEMPT';
        if (newPair1B != null && !newPair1B.isBye) winnerIdB = newPair1B.id;
        if (newPair2B != null && !newPair2B.isBye) winnerIdB = newPair2B.id;
      } else if (matchB.isBye || matchB.isCompleted) {
        statusB = 'pending';
        scoreB = null;
        winnerIdB = null;
      }

      final updatedMatchB = matchB.copyWith(
        pair1: newPair1B,
        pair2: newPair2B,
        clearPair1: newPair1B == null,
        clearPair2: newPair2B == null,
        isBye: hasByeB,
        status: statusB,
        score: scoreB,
        winnerId: winnerIdB,
        clearScore: scoreB == null,
        clearWinner: winnerIdB == null,
      );
      targetListB[idxB] = updatedMatchB;

      if (updatedMatchA.nextMatchId != null) {
        _updateProgressionAfterSwap(targetListA, updatedMatchA);
      }
      if (updatedMatchB.nextMatchId != null) {
        _updateProgressionAfterSwap(targetListB, updatedMatchB);
      }
    }

    // Mise à jour de la liste ordonnée des paires du tournoi si deux paires réelles
    List<TournamentPair> updatedPairs = List<TournamentPair>.from(bracket.pairs);
    if (pairA != null && pairB != null && !pairA.isBye && !pairB.isBye) {
      final pAIdx = updatedPairs.indexWhere((p) => p.id == pairA.id);
      final pBIdx = updatedPairs.indexWhere((p) => p.id == pairB.id);
      if (pAIdx != -1 && pBIdx != -1) {
        final temp = updatedPairs[pAIdx];
        updatedPairs[pAIdx] = updatedPairs[pBIdx];
        updatedPairs[pBIdx] = temp;
      }
    }

    return bracket.copyWith(
      pairs: updatedPairs,
      mainMatches: listMain,
      consolationMatches: listConso,
      updatedAt: DateTime.now(),
    );
  }

  static void _updateProgressionAfterSwap(List<BracketMatch> matches, BracketMatch match) {
    if (match.nextMatchId == null) return;
    final nextIdx = matches.indexWhere((m) => m.id == match.nextMatchId);
    if (nextIdx == -1) return;

    final nextMatch = matches[nextIdx];
    final winner = match.winner;
    final isSlot1 = match.nextMatchSlot == 1;

    matches[nextIdx] = nextMatch.copyWith(
      pair1: isSlot1 ? winner : nextMatch.pair1,
      pair2: !isSlot1 ? winner : nextMatch.pair2,
      clearPair1: isSlot1 && winner == null,
      clearPair2: !isSlot1 && winner == null,
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

  /// Réinitialise le score d'un match (remise à zéro / non joué)
  /// Efface le vainqueur, remet le statut à 'scheduled', et retire les qualifications automatiques induites
  static TournamentBracket resetMatchScore({
    required TournamentBracket bracket,
    required String matchId,
    String? poolId,
  }) {
    if (poolId != null) {
      // 1. Réinitialisation dans une Poule
      final updatedPools = <TournamentPool>[];
      for (final pool in bracket.pools) {
        if (pool.id == poolId) {
          final updatedMatches = pool.matches.map((m) {
            if (m.id == matchId) {
              return m.copyWith(
                clearScore: true,
                clearWinner: true,
                status: 'scheduled',
              );
            }
            return m;
          }).toList();
          updatedPools.add(pool.copyWith(matches: updatedMatches));
        } else {
          updatedPools.add(pool);
        }
      }

      // Si les poules ne sont plus toutes deux complètes, nettoyer les paires qualifiées dans la phase finale
      List<BracketMatch> updatedFinalMatches = List<BracketMatch>.from(bracket.mainMatches);
      final poolA = updatedPools.firstWhere((p) => p.id == "poule_a", orElse: () => updatedPools.first);
      final poolB = updatedPools.firstWhere((p) => p.id == "poule_b", orElse: () => updatedPools.last);
      final allACompleted = poolA.matches.every((m) => m.isCompleted);
      final allBCompleted = poolB.matches.every((m) => m.isCompleted);

      if (!allACompleted || !allBCompleted) {
        for (int i = 0; i < updatedFinalMatches.length; i++) {
          final m = updatedFinalMatches[i];
          if (m.id == "final_df1" ||
              m.id == "final_df2" ||
              m.id == "final_fin" ||
              m.id == "final_p34" ||
              m.id == "final_p56" ||
              m.id == "final_p78") {
            updatedFinalMatches[i] = m.copyWith(
              clearPair1: true,
              clearPair2: true,
              clearWinner: true,
              clearScore: true,
              status: 'pending',
            );
          }
        }
      }

      return bracket.copyWith(
        pools: updatedPools,
        mainMatches: updatedFinalMatches,
        updatedAt: DateTime.now(),
      );
    } else {
      // 2. Réinitialisation dans un Tableau Éliminatoire (Principal ou Consolante)
      final isMain = bracket.mainMatches.any((m) => m.id == matchId);
      final targetList = isMain
          ? List<BracketMatch>.from(bracket.mainMatches)
          : List<BracketMatch>.from(bracket.consolationMatches);
      final matchIndex = targetList.indexWhere((m) => m.id == matchId);
      if (matchIndex == -1) return bracket;

      final match = targetList[matchIndex];
      final resetMatch = match.copyWith(
        clearScore: true,
        clearWinner: true,
        status: 'scheduled',
      );
      targetList[matchIndex] = resetMatch;

      // Retirer le vainqueur du match suivant (nextMatch)
      if (match.nextMatchId != null) {
        final nextIdx = targetList.indexWhere((m) => m.id == match.nextMatchId);
        if (nextIdx != -1) {
          final nextMatch = targetList[nextIdx];
          targetList[nextIdx] = nextMatch.copyWith(
            clearPair1: match.nextMatchSlot == 1,
            clearPair2: match.nextMatchSlot == 2,
            clearWinner: true,
            clearScore: true,
            status: 'pending',
          );
        }
      }

      // Si consolationMatchId existe, retirer le perdant de la consolante
      List<BracketMatch> updatedConso = List<BracketMatch>.from(bracket.consolationMatches);
      if (match.consolationMatchId != null) {
        if (bracket.format == 'pools_and_bracket') {
          final cIdx = targetList.indexWhere((m) => m.id == match.consolationMatchId);
          if (cIdx != -1) {
            final cm = targetList[cIdx];
            targetList[cIdx] = cm.copyWith(
              clearPair1: match.consolationSlot == 1,
              clearPair2: match.consolationSlot == 2,
              clearWinner: true,
              clearScore: true,
              status: 'pending',
            );
          }
        } else {
          final cIdx = updatedConso.indexWhere((m) => m.id == match.consolationMatchId);
          if (cIdx != -1) {
            final cm = updatedConso[cIdx];
            updatedConso[cIdx] = cm.copyWith(
              clearPair1: match.consolationSlot == 1,
              clearPair2: match.consolationSlot == 2,
              clearWinner: true,
              clearScore: true,
              status: 'pending',
            );
          }
        }
      }

      return bracket.copyWith(
        mainMatches: isMain ? targetList : bracket.mainMatches,
        consolationMatches: isMain ? (match.consolationMatchId != null ? updatedConso : bracket.consolationMatches) : targetList,
        updatedAt: DateTime.now(),
      );
    }
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

  /// Assigne intelligemment les terrains pour les matches de poules :
  /// Priorité Terrain 1 pour TS1 (Poule A), Terrain 2 pour TS2 (Poule B)
  /// Terrains 3, 4, ... N pour les autres matches de chaque rotation
  static List<BracketMatch> _assignSmartCourtsToPoolMatches({
    required List<BracketMatch> matches,
    required bool isPoolA,
    required int numCourts,
  }) {
    if (matches.isEmpty) return matches;
    final primaryCourt = isPoolA ? 1 : min(2, numCourts);
    final secondaryCourt = isPoolA
        ? (numCourts >= 3 ? 3 : 1)
        : (numCourts >= 4 ? 4 : min(2, numCourts));

    final result = <BracketMatch>[];

    if (matches.length <= 3) {
      // Poule de 3 paires : 3 matches (1 seul match par rotation)
      // Tour 1: match 0 -> primaryCourt (avec tête de série)
      // Tour 2: match 1 -> primaryCourt (avec tête de série)
      // Tour 3: match 2 -> primaryCourt
      for (int i = 0; i < matches.length; i++) {
        result.add(matches[i].copyWith(court: primaryCourt));
      }
    } else if (matches.length == 10) {
      // Poule de 5 paires : 10 matches (2 matches par rotation)
      // Alternance intelligente entre Terrain 1 et Terrain 2 pour chaque rotation
      final court1 = isPoolA ? 1 : min(2, numCourts);
      final court2 = isPoolA ? (numCourts >= 2 ? 2 : 1) : min(numCourts, 3);
      for (int i = 0; i < matches.length; i++) {
        final assignedCourt = (i % 2 == 0) ? court1 : court2;
        result.add(matches[i].copyWith(court: assignedCourt));
      }
    } else {
      // Poule de 4 paires : 6 matches (2 matches par rotation)
      // Matches 0, 2, 4 contiennent la paire 0 (Tête de Série)
      for (int i = 0; i < matches.length; i++) {
        final isTopSeedMatch = (i % 2 == 0);
        final assignedCourt = isTopSeedMatch ? primaryCourt : secondaryCourt;
        result.add(matches[i].copyWith(court: assignedCourt));
      }
    }
    return result;
  }

  /// Assigne intelligemment les terrains pour la phase finale :
  /// Grande Finale -> Court 1 (Court Central)
  /// Demi-finale 1 (avec TS1) -> Court 1
  /// Demi-finale 2 (avec TS2) -> Court 2
  /// Petite Finale -> Court 2
  /// Matches de classement -> Court 3, 4...
  static List<BracketMatch> _assignSmartCourtsToFinalMatches({
    required List<BracketMatch> matches,
    required int numCourts,
  }) {
    return matches.map((m) {
      int court = 1;
      if (m.matchCode == 'FINALE') {
        court = 1;
      } else if (m.matchCode == 'DF1') {
        court = 1;
      } else if (m.matchCode == 'DF2') {
        court = min(2, numCourts);
      } else if (m.matchCode == 'PLACE_3_4') {
        court = min(2, numCourts);
      } else if (m.matchCode == 'PLACE_5_6') {
        court = min(3, numCourts);
      } else if (m.matchCode == 'PLACE_7_8') {
        court = min(4, numCourts);
      } else {
        court = (m.matchIndex % numCourts) + 1;
      }
      return m.copyWith(court: court);
    }).toList();
  }

  /// Assigne intelligemment les terrains pour un tableau à élimination directe :
  /// - Matches avec TS1 -> Court 1
  /// - Matches avec TS2 -> Court 2
  /// - Demi-finales -> Court 1 et Court 2
  /// - Grande Finale -> Court 1
  /// - Autres matches -> ventilés sur Court 3, 4... jusqu'à numCourts
  static List<BracketMatch> _assignSmartCourtsToBracketMatches({
    required List<BracketMatch> matches,
    required int roundsCount,
    required int numCourts,
  }) {
    final result = <BracketMatch>[];

    for (final m in matches) {
      if (m.isBye) {
        result.add(m);
        continue;
      }

      int assignedCourt;

      if (m.roundIndex == roundsCount - 1) {
        // Grande Finale
        assignedCourt = 1;
      } else if (m.roundIndex == roundsCount - 2) {
        // Demi-finales
        assignedCourt = (m.matchIndex == 0) ? 1 : min(2, numCourts);
      } else {
        // Round 0 ou tours intermédiaires (1/8, Quarts)
        final p1Seed = m.pair1?.seed;
        final p2Seed = m.pair2?.seed;
        final hasTs1 = p1Seed == 1 || p2Seed == 1;
        final hasTs2 = p1Seed == 2 || p2Seed == 2;

        if (hasTs1) {
          assignedCourt = 1;
        } else if (hasTs2) {
          assignedCourt = min(2, numCourts);
        } else {
          // Ventiler sur les terrains restants (Court 3, 4... puis rotation)
          if (numCourts <= 2) {
            assignedCourt = (m.matchIndex % 2) + 1;
          } else {
            final offset = m.matchIndex % (numCourts - 2);
            assignedCourt = 3 + offset;
          }
        }
      }

      result.add(m.copyWith(court: assignedCourt));
    }

    return result;
  }

  /// Assigne les terrains de la consolante
  static List<BracketMatch> _assignSmartCourtsToConsoMatches({
    required List<BracketMatch> matches,
    required int numCourts,
  }) {
    return matches.map((m) {
      if (m.isBye) return m;
      final court = numCourts > 2
          ? 3 + (m.matchIndex % (numCourts - 2))
          : min(2, numCourts);
      return m.copyWith(court: court);
    }).toList();
  }
}
