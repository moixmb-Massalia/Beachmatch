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
    required List<TournamentPair> registeredPairs,
    int numCourts = 4,
  }) {
    if (registeredPairs.isEmpty) {
      return TournamentBracket(
        tournamentId: tournamentId,
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
    // - TS1 en BAS (Dernier match, Slot 2)
    // - TS2 en HAUT (Premier match, Slot 1)
    // - TS3 et TS4 réparties
    // - Injection des BYE (exempts)
    final r0Slots = List<TournamentPair?>.filled(bracketSize, null);

    // Dictionnaire des seeds
    final seedMap = <int, TournamentPair>{};
    final unseeded = <TournamentPair>[];
    for (final p in seededPairs) {
      if (p.seed != null) {
        seedMap[p.seed!] = p;
      } else {
        unseeded.add(p);
      }
    }

    // Positions clés FFT :
    // Haut : index 0 (Match 0 Slot 1) = TS2
    // Bas : index bracketSize - 1 (Dernier match Slot 2) = TS1
    if (seedMap.containsKey(2)) r0Slots[0] = seedMap[2];
    if (seedMap.containsKey(1)) r0Slots[bracketSize - 1] = seedMap[1];

    if (bracketSize >= 8) {
      // TS3 et TS4
      if (seedMap.containsKey(3) || seedMap.containsKey(4)) {
        final posQuartHaut = (bracketSize ~/ 2) - 1; // Bas de la moitié haute
        final posQuartBas = bracketSize ~/ 2;        // Haut de la moitié basse
        
        // Tirage ou placement équilibré
        final ts3 = seedMap[3];
        final ts4 = seedMap[4];
        if (ts3 != null) r0Slots[posQuartBas] = ts3;
        if (ts4 != null) r0Slots[posQuartHaut] = ts4;
      }
    }

    if (bracketSize == 32) {
      // TS5 à TS8
      if (seedMap.containsKey(5)) r0Slots[7] = seedMap[5];
      if (seedMap.containsKey(6)) r0Slots[8] = seedMap[6];
      if (seedMap.containsKey(7)) r0Slots[23] = seedMap[7];
      if (seedMap.containsKey(8)) r0Slots[24] = seedMap[8];
    }

    // Placement des BYE en face des têtes de série prioritaires
    int numByes = bracketSize - seededPairs.length;
    final byePairs = <TournamentPair>[];
    for (int b = 0; b < numByes; b++) {
      byePairs.add(TournamentPair(
        id: "bye_$b",
        player1Name: "EXEMPT",
        player2Name: "BYE",
        isBye: true,
      ));
    }

    // Les BYE affrontent d'abord TS1, TS2, TS3, TS4...
    final byePrioritySlots = [
      bracketSize - 2, // Opposant de TS1 (Bas)
      1,                // Opposant de TS2 (Haut)
      if (bracketSize >= 8) (bracketSize ~/ 2) + 1, // Opposant TS3
      if (bracketSize >= 8) (bracketSize ~/ 2) - 2, // Opposant TS4
      // Autres positions si beaucoup de byes
      3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31
    ];

    int byeIdx = 0;
    for (final slot in byePrioritySlots) {
      if (byeIdx >= byePairs.length) break;
      if (slot < bracketSize && r0Slots[slot] == null) {
        r0Slots[slot] = byePairs[byeIdx++];
      }
    }

    // Remplir les slots restants avec les équipes non têtes de série
    int unseededIdx = 0;
    for (int s = 0; s < bracketSize; s++) {
      if (r0Slots[s] == null) {
        if (unseededIdx < unseeded.length) {
          r0Slots[s] = unseeded[unseededIdx++];
        } else if (byeIdx < byePairs.length) {
          r0Slots[s] = byePairs[byeIdx++];
        }
      }
    }

    // Injecter les slots dans les matches du round 0
    final updatedMainMatches = <BracketMatch>[];
    for (final m in mainMatches) {
      if (m.roundIndex == 0) {
        final p1 = r0Slots[m.matchIndex * 2];
        final p2 = r0Slots[m.matchIndex * 2 + 1];

        // Vérifier si un des deux est un BYE -> Qualification directe
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

    // 3. Construction de l'arbre de Consolante (si applicable)
    final consolationMatches = <BracketMatch>[];
    if (bracketSize >= 8) {
      final consoSize = bracketSize ~/ 2; // ex: 16 -> 8
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
    }

    return TournamentBracket(
      tournamentId: tournamentId,
      numCourts: numCourts,
      status: 'in_progress',
      pairs: seededPairs,
      mainMatches: updatedMainMatches,
      consolationMatches: consolationMatches,
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

    // 2. Si c'est le 1er tour du tableau principal, basculement du perdant en consolante
    List<BracketMatch> updatedConso = List<BracketMatch>.from(bracket.consolationMatches);
    if (isMain && match.roundIndex == 0 && match.consolationMatchId != null) {
      final loser = updatedMatch.loser;
      if (loser != null && !loser.isBye) {
        final consoIdx = updatedConso.indexWhere((m) => m.id == match.consolationMatchId);
        if (consoIdx != -1) {
          final cm = updatedConso[consoIdx];
          updatedConso[consoIdx] = cm.copyWith(
            pair1: match.consolationSlot == 1 ? loser : cm.pair1,
            pair2: match.consolationSlot == 2 ? loser : cm.pair2,
          );
        }
      }
    }

    // Vérifier si la finale principale est terminée pour passer en 'finished'
    final mainFinal = (isMain ? targetList : bracket.mainMatches).lastWhere(
      (m) => m.nextMatchId == null,
      orElse: () => updatedMatch,
    );
    final isFinished = mainFinal.isCompleted;

    return bracket.copyWith(
      mainMatches: isMain ? targetList : bracket.mainMatches,
      consolationMatches: isMain ? updatedConso : targetList,
      status: isFinished ? 'finished' : 'in_progress',
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
