import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/tournament.dart';
import '../models/tournament_bracket_model.dart';
import 'bracket_generator_service.dart';
import 'web_file_downloader.dart';

class PdfPairRanking {
  final int rank;
  final TournamentPair pair;
  final String stage;
  final String? score;

  const PdfPairRanking({
    required this.rank,
    required this.pair,
    required this.stage,
    this.score,
  });
}

class TournamentPdfService {
  /// Exporte ou télécharge le document PDF de manière fiable sur Web et Mobile
  static Future<void> exportOrDownloadPdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    // 1. Sur Web : Téléchargement natif direct immédiat dans le dossier Téléchargements du navigateur
    if (kIsWeb) {
      final downloaded = await WebFileDownloader.download(bytes, filename);
      if (downloaded) return;
    }

    // 2. Tenter le téléchargement direct via Printing.sharePdf
    // Sur Web fallback : crée un Blob URL et déclenche le téléchargement immédiat dans le navigateur.
    // Sur Mobile : ouvre la feuille de partage native (Enregistrer dans Fichiers, Imprimer, WhatsApp, etc.).
    try {
      final shared = await Printing.sharePdf(bytes: bytes, filename: filename);
      if (shared) return;
    } catch (e) {
      debugPrint("Printing.sharePdf notice: $e");
    }

    // 3. En dernier recours, Printing.layoutPdf (ouvre la boîte d'impression native)
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: filename,
      );
      return;
    } catch (e) {
      debugPrint("Printing.layoutPdf notice: $e");
    }
  }

  /// Label complet officiel pour une épreuve
  static String getCategoryFullLabel(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('dame') || cat == 'dd') return "DOUBLE DAMES (DD)";
    if (cat.contains('messieur') || cat == 'dh') return "DOUBLE MESSIEURS (DH)";
    if (cat.contains('mixte') || cat == 'dx') return "DOUBLE MIXTE (DX)";
    return category.toUpperCase();
  }

  /// Résout de façon sûre la paire gagnante d'un match (que winnerId ou pair1/pair2 soit utilisé)
  static TournamentPair? _resolveWinner(BracketMatch? m) {
    if (m == null) return null;
    if (m.winner != null) return m.winner;
    if (m.winnerId != null && m.winnerId!.isNotEmpty) {
      if (m.pair1 != null && m.pair1!.id == m.winnerId) return m.pair1;
      if (m.pair2 != null && m.pair2!.id == m.winnerId) return m.pair2;
    }
    return null;
  }

  /// Résout de façon sûre la paire perdante d'un match
  static TournamentPair? _resolveLoser(BracketMatch? m) {
    if (m == null) return null;
    if (m.loser != null) return m.loser;
    final w = _resolveWinner(m);
    if (w != null) {
      if (m.pair1 != null && m.pair1!.id == w.id) return m.pair2;
      if (m.pair2 != null && m.pair2!.id == w.id) return m.pair1;
    }
    return null;
  }

  /// 🏆 Calcule le classement complet et sans doublon de toutes les paires engagées
  static List<PdfPairRanking> computeCompleteRankings(TournamentBracket bracket) {
    final List<PdfPairRanking> rankings = [];
    final Set<String> placedIds = {'pair_bye', 'bye', 'exempt'};

    // CAS 1 : POULE UNIQUE
    if (bracket.pools.length == 1) {
      final pool = bracket.pools.first;
      final standings = pool.calculateStandings();
      for (int i = 0; i < standings.length; i++) {
        final st = standings[i];
        if (placedIds.contains(st.pair.id)) continue;
        placedIds.add(st.pair.id);

        String stage;
        if (i == 0) {
          stage = "1ère Place (Vainqueur)";
        } else if (i == 1) {
          stage = "2ème Place (Finaliste)";
        } else if (i == 2) {
          stage = "3ème Place";
        } else {
          stage = "${i + 1}ème Place";
        }

        final scoreDesc = st.played > 0
            ? "${st.won}V - ${st.lost}D (${st.points} pts, ${st.diffGames >= 0 ? '+' : ''}${st.diffGames})"
            : "À jouer";
        rankings.add(PdfPairRanking(
          rank: i + 1,
          pair: st.pair,
          stage: stage,
          score: scoreDesc,
        ));
      }
    } else {
      // CAS 2 : POULES MULTIPLES OU ARBRE ÉLIMINATION DIRECTE
      BracketMatch? finalMatch;
      BracketMatch? p34Match;
      BracketMatch? p56Match;
      BracketMatch? p78Match;
      BracketMatch? p910Match;
      BracketMatch? p1112Match;
      BracketMatch? p1314Match;
      final List<BracketMatch> semiMatches = [];

      for (final m in bracket.mainMatches) {
        final code = m.matchCode ?? '';
        final id = m.id.toLowerCase();
        final name = m.roundName.toLowerCase();
        if (code == 'FINALE' || id == 'final_fin' || (name.contains('finale') && !name.contains('demi') && !name.contains('1/4') && !name.contains('1/8') && !name.contains('consolante') && !name.contains('3') && !name.contains('5') && !name.contains('7'))) {
          finalMatch = m;
        } else if (code == 'PLACE_3_4' || id == 'final_p34' || name.contains('place 3') || name.contains('3/4') || name.contains('3e') || name.contains('petite finale')) {
          p34Match = m;
        } else if (code == 'PLACE_5_6' || id == 'final_p56' || name.contains('place 5') || name.contains('5/6') || name.contains('5e')) {
          p56Match = m;
        } else if (code == 'PLACE_7_8' || id == 'final_p78' || name.contains('place 7') || name.contains('7/8') || name.contains('7e')) {
          p78Match = m;
        } else if (code.startsWith('DF') || id.contains('df') || name.contains('demi') || name.contains('1/2')) {
          semiMatches.add(m);
        }
      }

      for (final m in bracket.consolationMatches) {
        final code = m.matchCode ?? '';
        final id = m.id.toLowerCase();
        final name = m.roundName.toLowerCase();
        if (code == 'PLACE_5_6' || id == 'conso_1_0' || name.contains('place 5') || name.contains('5/6') || name.contains('5e')) {
          p56Match ??= m;
        } else if (code == 'PLACE_7_8' || id == 'conso_place_7_8' || name.contains('place 7') || name.contains('7/8') || name.contains('7e')) {
          p78Match ??= m;
        } else if (code == 'PLACE_9_10' || id == 'conso_2_0' || id == 'final_p910' || (name.contains('finale') && !name.contains('demi') && !name.contains('quart') && !name.contains('1/4') && !name.contains('1/8') && !name.contains('11') && !name.contains('13'))) {
          p910Match = m;
        } else if (code == 'PLACE_11_12' || id == 'conso_place_11_12' || id == 'final_p1112' || name.contains('11 & 12') || name.contains('11/12') || name.contains('11e')) {
          p1112Match = m;
        } else if (code == 'PLACE_13_14' || id == 'conso_place_13_14' || id == 'final_p1314' || name.contains('13 & 14') || name.contains('13/14') || name.contains('13e')) {
          p1314Match = m;
        }
      }

      // 1. FINALE (1er et 2e)
      TournamentPair? wFin = _resolveWinner(finalMatch);
      TournamentPair? lFin = _resolveLoser(finalMatch);
      final finScore = finalMatch?.score?.trim();
      if (wFin == null && finalMatch != null && (finalMatch.isCompleted || (finScore != null && finScore.isNotEmpty))) {
        wFin = finalMatch.pair1;
        lFin = finalMatch.pair2;
      }
      if (wFin != null) {
        placedIds.add(wFin.id);
        rankings.add(PdfPairRanking(
          rank: 1,
          pair: wFin,
          stage: "Vainqueur (Champion)",
          score: (finScore != null && finScore.isNotEmpty)
              ? "Finale : $finScore"
              : "Champion",
        ));
        if (lFin != null) {
          placedIds.add(lFin.id);
          rankings.add(PdfPairRanking(
            rank: 2,
            pair: lFin,
            stage: "Finaliste",
            score: (finScore != null && finScore.isNotEmpty)
                ? "Finale : $finScore"
                : "Finaliste",
          ));
        }
      } else if (finalMatch != null) {
        if (finalMatch.pair1 != null && !placedIds.contains(finalMatch.pair1!.id)) {
          placedIds.add(finalMatch.pair1!.id);
          rankings.add(PdfPairRanking(
            rank: 1,
            pair: finalMatch.pair1!,
            stage: "Qualifié Finale",
            score: "Finale à disputer",
          ));
        }
        if (finalMatch.pair2 != null && !placedIds.contains(finalMatch.pair2!.id)) {
          placedIds.add(finalMatch.pair2!.id);
          rankings.add(PdfPairRanking(
            rank: 2,
            pair: finalMatch.pair2!,
            stage: "Qualifié Finale",
            score: "Finale à disputer",
          ));
        }
      }

      // 2. PETITE FINALE (3e et 4e)
      TournamentPair? w34 = _resolveWinner(p34Match);
      TournamentPair? l34 = _resolveLoser(p34Match);
      final p34Score = p34Match?.score?.trim();
      if (w34 == null && p34Match != null && (p34Match.isCompleted || (p34Score != null && p34Score.isNotEmpty))) {
        w34 = p34Match.pair1;
        l34 = p34Match.pair2;
      }
      if (w34 != null && !placedIds.contains(w34.id)) {
        placedIds.add(w34.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: w34,
          stage: "3ème Place (Podium)",
          score: (p34Score != null && p34Score.isNotEmpty)
              ? "Petite Finale : $p34Score"
              : "3e Place",
        ));
      }
      if (l34 != null && !placedIds.contains(l34.id)) {
        placedIds.add(l34.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: l34,
          stage: "4ème Place",
          score: (p34Score != null && p34Score.isNotEmpty)
              ? "Petite Finale : $p34Score"
              : "4e Place",
        ));
      }

      // Si pas de match 3/4 : regarder les perdants des demi-finales
      if (p34Match == null || (w34 == null && l34 == null)) {
        for (final sm in semiMatches) {
          final sLoser = _resolveLoser(sm) ?? (sm.winner != null && sm.pair1 != null && sm.pair2 != null ? (sm.pair1!.id == sm.winner!.id ? sm.pair2 : sm.pair1) : null);
          if (sLoser != null && !placedIds.contains(sLoser.id)) {
            placedIds.add(sLoser.id);
            rankings.add(PdfPairRanking(
              rank: rankings.length + 1,
              pair: sLoser,
              stage: "1/2 Finaliste",
              score: (sm.score != null && sm.score!.trim().isNotEmpty)
                  ? "1/2 Finale : ${sm.score!.trim()}"
                  : "Demi-finale",
            ));
          }
        }
      }

      // 3. PLACES 5 & 6
      TournamentPair? w56 = _resolveWinner(p56Match);
      TournamentPair? l56 = _resolveLoser(p56Match);
      final p56Score = p56Match?.score?.trim();
      if (w56 == null && p56Match != null && (p56Match.isCompleted || (p56Score != null && p56Score.isNotEmpty))) {
        w56 = p56Match.pair1;
        l56 = p56Match.pair2;
      }
      if (w56 != null && !placedIds.contains(w56.id)) {
        placedIds.add(w56.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: w56,
          stage: "5ème Place",
          score: (p56Score != null && p56Score.isNotEmpty)
              ? "Match 5/6 : $p56Score"
              : "5e Place",
        ));
      }
      if (l56 != null && !placedIds.contains(l56.id)) {
        placedIds.add(l56.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: l56,
          stage: "6ème Place",
          score: (p56Score != null && p56Score.isNotEmpty)
              ? "Match 5/6 : $p56Score"
              : "6e Place",
        ));
      }

      // 4. PLACES 7 & 8
      TournamentPair? w78 = _resolveWinner(p78Match);
      TournamentPair? l78 = _resolveLoser(p78Match);
      final p78Score = p78Match?.score?.trim();
      if (w78 == null && p78Match != null && (p78Match.isCompleted || (p78Score != null && p78Score.isNotEmpty))) {
        w78 = p78Match.pair1;
        l78 = p78Match.pair2;
      }
      if (w78 != null && !placedIds.contains(w78.id)) {
        placedIds.add(w78.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: w78,
          stage: "7ème Place",
          score: (p78Score != null && p78Score.isNotEmpty)
              ? "Match 7/8 : $p78Score"
              : "7e Place",
        ));
      }
      if (l78 != null && !placedIds.contains(l78.id)) {
        placedIds.add(l78.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: l78,
          stage: "8ème Place",
          score: (p78Score != null && p78Score.isNotEmpty)
              ? "Match 7/8 : $p78Score"
              : "8e Place",
        ));
      }

      // 5. RESTANT DES POULES (si poules)
      if (bracket.pools.isNotEmpty) {
        final remainingPoolPairs = <({TournamentPair pair, String poolName, int poolRank, int points, int diffGames})>[];
        for (final pool in bracket.pools) {
          final standings = pool.calculateStandings();
          for (int i = 0; i < standings.length; i++) {
            final st = standings[i];
            if (!placedIds.contains(st.pair.id)) {
              remainingPoolPairs.add((
                pair: st.pair,
                poolName: pool.name,
                poolRank: i + 1,
                points: st.points,
                diffGames: st.diffGames,
              ));
            }
          }
        }
        remainingPoolPairs.sort((a, b) {
          if (a.poolRank != b.poolRank) return a.poolRank.compareTo(b.poolRank);
          if (a.points != b.points) return b.points.compareTo(a.points);
          return b.diffGames.compareTo(a.diffGames);
        });

        for (final item in remainingPoolPairs) {
          if (!placedIds.contains(item.pair.id)) {
            placedIds.add(item.pair.id);
            rankings.add(PdfPairRanking(
              rank: rankings.length + 1,
              pair: item.pair,
              stage: "${item.poolName} (${item.poolRank}e)",
              score: "${item.points} pts (${item.diffGames >= 0 ? '+' : ''}${item.diffGames})",
            ));
          }
        }
      }

      // 5. PLACES 9 & 10 (Finale Consolante)
      TournamentPair? w910 = _resolveWinner(p910Match);
      TournamentPair? l910 = _resolveLoser(p910Match);
      final p910Score = p910Match?.score?.trim();
      if (w910 == null && p910Match != null && (p910Match.isCompleted || (p910Score != null && p910Score.isNotEmpty))) {
        w910 = p910Match.pair1;
        l910 = p910Match.pair2;
      }
      if (w910 != null && !placedIds.contains(w910.id)) {
        placedIds.add(w910.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: w910,
          stage: "9ème Place (Vainqueur Consolante)",
          score: (p910Score != null && p910Score.isNotEmpty) ? "Finale Conso : $p910Score" : "9e Place",
        ));
      }
      if (l910 != null && !placedIds.contains(l910.id)) {
        placedIds.add(l910.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: l910,
          stage: "10ème Place (Finaliste Consolante)",
          score: (p910Score != null && p910Score.isNotEmpty) ? "Finale Conso : $p910Score" : "10e Place",
        ));
      }

      // 6. PLACES 11 & 12
      TournamentPair? w1112 = _resolveWinner(p1112Match);
      TournamentPair? l1112 = _resolveLoser(p1112Match);
      final p1112Score = p1112Match?.score?.trim();
      if (w1112 == null && p1112Match != null && (p1112Match.isCompleted || (p1112Score != null && p1112Score.isNotEmpty))) {
        w1112 = p1112Match.pair1;
        l1112 = p1112Match.pair2;
      }
      if (w1112 != null && !placedIds.contains(w1112.id)) {
        placedIds.add(w1112.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: w1112,
          stage: "11ème Place",
          score: (p1112Score != null && p1112Score.isNotEmpty) ? "Match 11/12 : $p1112Score" : "11e Place",
        ));
      }
      if (l1112 != null && !placedIds.contains(l1112.id)) {
        placedIds.add(l1112.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: l1112,
          stage: "12ème Place",
          score: (p1112Score != null && p1112Score.isNotEmpty) ? "Match 11/12 : $p1112Score" : "12e Place",
        ));
      }

      // 7. PLACES 13 & 14
      TournamentPair? w1314 = _resolveWinner(p1314Match);
      TournamentPair? l1314 = _resolveLoser(p1314Match);
      final p1314Score = p1314Match?.score?.trim();
      if (w1314 == null && p1314Match != null && (p1314Match.isCompleted || (p1314Score != null && p1314Score.isNotEmpty))) {
        w1314 = p1314Match.pair1;
        l1314 = p1314Match.pair2;
      }
      if (w1314 != null && !placedIds.contains(w1314.id)) {
        placedIds.add(w1314.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: w1314,
          stage: "13ème Place",
          score: (p1314Score != null && p1314Score.isNotEmpty) ? "Match 13/14 : $p1314Score" : "13e Place",
        ));
      }
      if (l1314 != null && !placedIds.contains(l1314.id)) {
        placedIds.add(l1314.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: l1314,
          stage: "14ème Place",
          score: (p1314Score != null && p1314Score.isNotEmpty) ? "Match 13/14 : $p1314Score" : "14e Place",
        ));
      }

      // 8. AUTRES MATCHES DE CONSOLANTE (exclusion stricte des BYE / EXEMPT)
      for (final cm in bracket.consolationMatches) {
        final cw = _resolveWinner(cm);
        final cl = _resolveLoser(cm);
        if (cw != null && !cw.isBye && cw.id != 'pair_bye' && !placedIds.contains(cw.id)) {
          placedIds.add(cw.id);
          rankings.add(PdfPairRanking(
            rank: rankings.length + 1,
            pair: cw,
            stage: "Consolante (${cm.roundName})",
            score: cm.score ?? "NC",
          ));
        }
        if (cl != null && !cl.isBye && cl.id != 'pair_bye' && !placedIds.contains(cl.id)) {
          placedIds.add(cl.id);
          rankings.add(PdfPairRanking(
            rank: rankings.length + 1,
            pair: cl,
            stage: "Consolante",
            score: cm.score ?? "NC",
          ));
        }
      }
    }

    // 7. FILET DE SÉCURITÉ : toute paire inscrite non encore classée (exclusion stricte des BYE)
    for (final p in bracket.pairs) {
      if (!placedIds.contains(p.id) && !p.isBye && p.id != 'pair_bye') {
        placedIds.add(p.id);
        rankings.add(PdfPairRanking(
          rank: rankings.length + 1,
          pair: p,
          stage: "Tour préliminaire",
          score: "-",
        ));
      }
    }

    // Nettoyage absolu : exclure toute éventuelle entrée BYE / EXEMPT
    final cleanRankings = rankings.where((r) {
      if (r.pair.isBye || r.pair.id == 'pair_bye') return false;
      final name = r.pair.displayName.toUpperCase();
      if (name.contains('BYE') || name.contains('EXEMPT')) return false;
      return true;
    }).toList();

    // Ré-indexation séquentielle stricte de 1 à N (exactement 14 équipes réelles)
    for (int i = 0; i < cleanRankings.length; i++) {
      cleanRankings[i] = PdfPairRanking(
        rank: i + 1,
        pair: cleanRankings[i].pair,
        stage: cleanRankings[i].stage,
        score: cleanRankings[i].score,
      );
    }

    return cleanRankings;
  }

  /// Génère et ouvre la boîte de dialogue d'impression / export PDF officiel FFT
  static Future<void> generateAndExportPdf({
    required TournamentModel tournament,
    required TournamentBracket bracket,
  }) async {
    final pdf = pw.Document();

    final categoryLabel = getCategoryFullLabel(bracket.category);
    final shortCategory = _getCategoryLabel(bracket.category);
    final rankings = computeCompleteRankings(bracket);

    // Couleurs officielles prestigieuses
    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFB8860B);
    const darkGray = PdfColor.fromInt(0xFF334155);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        header: (context) => _buildOfficialHeader(tournament, categoryLabel, shortCategory, navyColor, goldColor),
        footer: (context) => _buildFooter(context, darkGray),
        build: (context) => [
          pw.SizedBox(height: 6),

          // 1. Classement Officiel Unifié du 1er au dernier (1er en grand prestige or, 2e argent, 3e bronze, 4e à Ne continu)
          _buildUnifiedRankingsSection(rankings, navyColor, goldColor),
          pw.SizedBox(height: 10),

          // 2. Récapitulatif officiel exhaustif avec TOUS les scores des phases finales et des poules
          _buildCleanScoresRecap(bracket, navyColor, darkGray),
          pw.SizedBox(height: 10),

          // 3. Cadre d'homologation officielle et visa JAT
          _buildJatSignatureBox(navyColor, darkGray, tournament: tournament, categoryLabel: categoryLabel),
        ],
      ),
    );

    final bytes = await pdf.save();
    final filename = 'FFT_Resultats_${tournament.id}_$shortCategory.pdf';
    await exportOrDownloadPdf(bytes: bytes, filename: filename);
  }

  /// Génère le Dossier Officiel Homologué A4 Paysage (Widescreen Landscape)
  static Future<void> generateAndExportLandscapePdf({
    required TournamentModel tournament,
    required TournamentBracket bracket,
  }) async {
    final pdf = pw.Document();

    final categoryLabel = getCategoryFullLabel(bracket.category);
    final shortCategory = _getCategoryLabel(bracket.category);
    final rankings = computeCompleteRankings(bracket);

    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFB8860B);
    const darkGray = PdfColor.fromInt(0xFF334155);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        header: (context) => _buildOfficialHeader(tournament, "$categoryLabel (Homologation Paysage)", shortCategory, navyColor, goldColor),
        footer: (context) => _buildFooter(context, darkGray),
        build: (context) => [
          pw.SizedBox(height: 6),
          _buildUnifiedRankingsSection(rankings, navyColor, goldColor),
          pw.SizedBox(height: 8),
          _buildCleanScoresRecap(bracket, navyColor, darkGray),
          pw.SizedBox(height: 8),
          _buildJatSignatureBox(navyColor, darkGray, tournament: tournament, categoryLabel: categoryLabel),
        ],
      ),
    );

    final bytes = await pdf.save();
    final filename = 'FFT_Dossier_Paysage_${tournament.id}_$shortCategory.pdf';
    await exportOrDownloadPdf(bytes: bytes, filename: filename);
  }

  /// Génère le Dossier Officiel Complet du Tournoi (Toutes les épreuves réunies : DH + DD + DX)
  static Future<void> generateAndExportFullTournamentPdf({
    required TournamentModel tournament,
    required List<TournamentBracket> brackets,
  }) async {
    final pdf = pw.Document();

    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFB8860B);
    const darkGray = PdfColor.fromInt(0xFF334155);
    const lightGray = PdfColor.fromInt(0xFFF1F5F9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildFullHeader(tournament, navyColor, goldColor),
        footer: (context) => _buildFooter(context, darkGray),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildMasterPodiumSummary(brackets, navyColor, goldColor),
          pw.SizedBox(height: 14),

          for (final b in brackets) ...[
            _buildCategorySectionHeader(b, navyColor, goldColor),
            pw.SizedBox(height: 8),
            if (b.format == 'pools_and_bracket') ...[
              for (final pool in b.pools) ...[
                _buildPoolSection(pool, navyColor, lightGray),
                pw.SizedBox(height: 8),
              ],
              _buildFinalPhaseSection(b, navyColor, lightGray),
            ] else ...[
              _buildEliminationSection(b, navyColor, lightGray),
            ],
            pw.SizedBox(height: 14),
          ],

          pw.SizedBox(height: 10),
          _buildJatSignatureBox(navyColor, darkGray),
        ],
      ),
    );

    final bytes = await pdf.save();
    final filename = 'FFT_Dossier_Complet_${tournament.id}.pdf';
    await exportOrDownloadPdf(bytes: bytes, filename: filename);
  }

  /// 🥇 Résolution infaillible du palmarès (Vainqueur, Finaliste, 3e place)
  /// Gère automatiquement les poules uniques (DD, DH, DX) et les tableaux à élimination
  static (TournamentPair?, TournamentPair?, TournamentPair?) resolvePalmares(TournamentBracket bracket) {
    BracketMatch? finalMatch;
    BracketMatch? p34Match;

    for (final m in bracket.mainMatches) {
      if (m.matchCode == 'FINALE' || (bracket.format == 'elimination' && m.roundName.toLowerCase().contains('finale'))) {
        finalMatch = m;
      }
      if (m.matchCode == 'PLACE_3_4') {
        p34Match = m;
      }
    }

    TournamentPair? winner = finalMatch?.winner;
    TournamentPair? runnerUp = finalMatch?.loser;
    TournamentPair? third = p34Match?.winner;

    // 🏆 POULE UNIQUE : Si pas de finale directe et qu'il y a une seule poule
    if (winner == null && bracket.pools.length == 1) {
      final pool = bracket.pools.first;
      final standings = pool.calculateStandings();
      final hasCompleted = pool.matches.any((m) => m.isCompleted);
      if (standings.isNotEmpty && hasCompleted) {
        winner = standings[0].pair;
        if (standings.length > 1) runnerUp = standings[1].pair;
        if (standings.length > 2) third = standings[2].pair;
      }
    }

    return (winner, runnerUp, third);
  }

  /// Génère un texte récapitulatif global pour toutes les épreuves du tournoi (WhatsApp / MOJA)
  static String generateFullTournamentTextSummary({
    required TournamentModel tournament,
    required List<TournamentBracket> brackets,
  }) {
    final buf = StringBuffer();
    buf.writeln("=================================================");
    buf.writeln("🏆 FÉDÉRATION FRANÇAISE DE TENNIS · BEACH TENNIS");
    buf.writeln("BILAN OFFICIEL DU TOURNOI · TOUTES ÉPREUVES");
    buf.writeln("Tournoi : ${tournament.name} (${tournament.category})");
    buf.writeln("Club organisateur : ${tournament.club}");
    buf.writeln("Lieu : ${tournament.location.isNotEmpty ? tournament.location : tournament.club}");
    buf.writeln("Dates : ${tournament.dateString}");
    if (tournament.referee != null && tournament.referee!.isNotEmpty) {
      buf.writeln("JAT Responsable : ${tournament.referee}");
    }
    buf.writeln("=================================================\n");

    buf.writeln("🥇 PALMARÈS GÉNÉRAL DU TOURNOI :");
    for (final bracket in brackets) {
      final label = _getCategoryLabel(bracket.category);
      final (winner, runnerUp, third) = resolvePalmares(bracket);

      buf.writeln("🏆 *$label*");
      buf.writeln("   • 🥇 Vainqueurs : ${winner?.displayName ?? 'En cours...'}");
      buf.writeln("   • 🥈 Finalistes : ${runnerUp?.displayName ?? 'En cours...'}");
      if (third != null) {
        buf.writeln("   • 🥉 3ème Place : ${third.displayName}");
      }
      buf.writeln("");
    }

    buf.writeln("-------------------------------------------------");
    buf.writeln("DÉTAIL DES RÉSULTATS PAR TABLEAU :");
    for (final bracket in brackets) {
      final label = _getCategoryLabel(bracket.category);
      buf.writeln("\n▶️ $label :");
      if (bracket.format == 'pools_and_bracket') {
        for (final p in bracket.pools) {
          buf.writeln("  [${p.name}]");
          for (final m in p.matches.where((x) => x.isCompleted && x.winner != null)) {
            buf.writeln("   • ${m.winner!.displayName} bat ${m.loser?.displayName ?? 'Adversaire'} (${m.score ?? 'Joué'})");
          }
        }
        for (final m in bracket.mainMatches.where((x) => x.isCompleted && x.winner != null)) {
          buf.writeln("   • ${m.roundName} : ${m.winner!.displayName} bat ${m.loser?.displayName ?? 'Adversaire'} (${m.score ?? 'Joué'})");
        }
      } else {
        for (final m in bracket.mainMatches.where((x) => x.isCompleted && x.winner != null)) {
          buf.writeln("   • ${m.roundName} : ${m.winner!.displayName} bat ${m.loser?.displayName ?? 'Adversaire'} (${m.score ?? 'Joué'})");
        }
      }
    }

    buf.writeln("\n📄 Tous les tableaux et live scores sont disponibles sur BeachMatch.");
    buf.writeln("Félicitations à tous les participants ! 🏖️🔥");

    return buf.toString();
  }

  /// Génère un texte structuré récapitulant les résultats officiels du tournoi pour le JAT
  static String generateTextSummary({
    required TournamentModel tournament,
    required TournamentBracket bracket,
  }) {
    final isPoolFormat = bracket.format == 'pools_and_bracket';
    final categoryLabel = bracket.category == 'double_messieurs' || bracket.category == 'DH'
        ? 'DH'
        : (bracket.category == 'double_dames' || bracket.category == 'DD' ? 'DD' : 'DX');

    final (winner, runnerUp, third) = resolvePalmares(bracket);

    final buf = StringBuffer();
    buf.writeln("=================================================");
    buf.writeln("🏆 FÉDÉRATION FRANÇAISE DE TENNIS · BEACH TENNIS");
    buf.writeln("Tournoi : ${tournament.name}");
    buf.writeln("Épreuve : $categoryLabel");
    buf.writeln("Homologation : ${tournament.id}");
    buf.writeln("Lieu : ${tournament.location.isNotEmpty ? tournament.location : tournament.club}");
    buf.writeln("Dates : ${tournament.dateString}");
    buf.writeln("=================================================\n");

    buf.writeln("🥇 PALMARÈS :");
    buf.writeln("• 1ère Place (Vainqueurs) 🥇 : ${winner?.displayName ?? 'En cours...'}");
    buf.writeln("• 2ème Place (Finalistes) 🥈 : ${runnerUp?.displayName ?? 'En cours...'}");
    if (third != null) {
      buf.writeln("• 3ème Place 🥉 : ${third.displayName}");
    }
    buf.writeln("");

    if (isPoolFormat) {
      buf.writeln("📊 RÉSULTATS DES POULES :");
      for (final pool in bracket.pools) {
        buf.writeln("\n[${pool.name.toUpperCase()}]");
        final standings = pool.calculateStandings();
        for (int i = 0; i < standings.length; i++) {
          final s = standings[i];
          final qualif = i < 2 ? "-> Qualifié Demies" : "";
          final diffS = s.diffSets > 0 ? "+${s.diffSets}" : "${s.diffSets}";
          final diffG = s.diffGames > 0 ? "+${s.diffGames}" : "${s.diffGames}";
          buf.writeln("${i + 1}. ${s.pair.displayName} (${s.won}V - ${s.lost}D | Diff Sets: $diffS | Diff Jeux: $diffG | ${s.points} pts) $qualif");
        }
        buf.writeln("Scores :");
        for (final m in pool.matches) {
          final scoreStr = m.isCompleted ? (m.score ?? 'Joué') : 'Non joué';
          if (m.isCompleted && m.winner != null) {
            buf.writeln("• ${m.winner!.displayName} bat ${m.loser?.displayName ?? 'Adversaire'} : $scoreStr");
          } else {
            buf.writeln("• ${m.pair1?.displayName ?? 'TBD'} vs ${m.pair2?.displayName ?? 'TBD'} : $scoreStr");
          }
        }
      }

      buf.writeln("\n⚔️ PHASE FINALE :");
      for (final m in bracket.mainMatches) {
        final scoreStr = m.isCompleted ? (m.score ?? 'NC') : 'À venir';
        if (m.isCompleted && m.winner != null) {
          buf.writeln("• ${m.roundName} : ${m.winner!.displayName} bat ${m.loser?.displayName ?? 'Adversaire'} ($scoreStr)");
        } else {
          buf.writeln("• ${m.roundName} : ${m.pair1?.displayName ?? 'TBD'} vs ${m.pair2?.displayName ?? 'TBD'} ($scoreStr)");
        }
      }
    } else {
      buf.writeln("⚔️ TABLEAU PRINCIPAL :");
      for (final m in bracket.mainMatches) {
        final scoreStr = m.isCompleted ? (m.score ?? 'NC') : (m.isBye ? 'BYE' : 'À venir');
        if (m.isCompleted && m.winner != null) {
          buf.writeln("• ${m.roundName} : ${m.winner!.displayName} bat ${m.loser?.displayName ?? 'Adversaire'} ($scoreStr)");
        } else {
          buf.writeln("• ${m.roundName} : ${m.pair1?.displayName ?? 'TBD'} vs ${m.pair2?.displayName ?? 'TBD'} ($scoreStr)");
        }
      }
      if (bracket.consolationMatches.isNotEmpty) {
        buf.writeln("\n🛡️ TABLEAU DE CONSOLANTE :");
        for (final m in bracket.consolationMatches) {
          final scoreStr = m.isCompleted ? (m.score ?? 'NC') : 'À venir';
          if (m.isCompleted && m.winner != null) {
            buf.writeln("• ${m.roundName} : ${m.winner!.displayName} bat ${m.loser?.displayName ?? 'Adversaire'} ($scoreStr)");
          } else {
            buf.writeln("• ${m.roundName} : ${m.pair1?.displayName ?? 'TBD'} vs ${m.pair2?.displayName ?? 'TBD'} ($scoreStr)");
          }
        }
      }
    }

    buf.writeln("\n=================================================");
    buf.writeln("✍️ Saisie certifiée et transmise par le Juge-Arbitre (JAT).");
    buf.writeln("Source : Application BeachMatch Officielle FFT");
    buf.writeln("=================================================");

    return buf.toString();
  }

  static pw.Widget _buildOfficialHeader(
    TournamentModel tournament,
    String fullCategoryLabel,
    String shortCategory,
    PdfColor navyColor,
    PdfColor goldColor,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: navyColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      "FFT · BEACH TENNIS",
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    "FÉDÉRATION FRANÇAISE DE TENNIS",
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: darkGrayPdf,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "FEUILLE OFFICIELLE DE CLASSEMENT",
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: navyColor,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                children: [
                  pw.Text(
                    "ÉPREUVE : ",
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFFEF3C7),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      border: pw.Border.all(color: goldColor, width: 0.8),
                    ),
                    child: pw.Text(
                      fullCategoryLabel,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF92400E),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    "· ${cleanText(tournament.name)}",
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: navyColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF1F5F9),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Text(
                  "Homologation : ${cleanText(tournament.id)}",
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyColor),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                "Club : ${cleanText(tournament.club)}",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              if (tournament.location.isNotEmpty && tournament.location != tournament.club)
                pw.Text(
                  "Lieu : ${cleanText(tournament.location)}",
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                ),
              pw.Text(
                "Dates : ${cleanText(tournament.dateString)}",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              if (tournament.referee?.isNotEmpty == true)
                pw.Text(
                  "JAT : ${cleanText(tournament.referee!)}",
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyColor),
                ),
            ],
          ),
        ],
      ),
    );
  }



  static const darkGrayPdf = PdfColor.fromInt(0xFF475569);

  static pw.Widget _buildFooter(pw.Context context, PdfColor darkGray) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "Document officiel FFT généré via BeachMatch",
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            "Page ${context.pageNumber} / ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPoolSection(
    TournamentPool pool,
    PdfColor navyColor,
    PdfColor lightGray,
  ) {
    final standings = pool.calculateStandings();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: navyColor,
          child: pw.Text(
            pool.name.toUpperCase(),
            style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FlexColumnWidth(5),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.2),
            4: pw.FlexColumnWidth(1.5),
            5: pw.FlexColumnWidth(1.5),
            6: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
              children: [
                _th("#"),
                _th("Équipe"),
                _th("V"),
                _th("D"),
                _th("Sets"),
                _th("+/-"),
                _th("Pts"),
              ],
            ),
            for (int i = 0; i < standings.length; i++)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i < 2 ? const PdfColor.fromInt(0xFFF0FDF4) : PdfColors.white,
                ),
                children: [
                  _td("${i + 1}"),
                  _td("${standings[i].pair.displayName} ${i < 2 ? '(Qualifié 1/2)' : ''}", alignLeft: true),
                  _td("${standings[i].won}"),
                  _td("${standings[i].lost}"),
                  _td("${standings[i].setsWon}-${standings[i].setsLost}"),
                  _td(standings[i].diffGames >= 0 ? "+${standings[i].diffGames}" : "${standings[i].diffGames}"),
                  _td("${standings[i].points}", isBold: true),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 6),
        // Matches de la poule
        pw.Text("Matches joués :", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        for (final m in pool.matches)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1),
            child: pw.Row(
              children: [
                pw.Text("• ${m.roundName} : ", style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                  "${m.pair1?.displayName ?? '?'} vs ${m.pair2?.displayName ?? '?'}",
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Spacer(),
                pw.Text(
                  m.score != null ? "Score : ${m.score}" : "À jouer",
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildFinalPhaseSection(
    TournamentBracket bracket,
    PdfColor navyColor,
    PdfColor lightGray,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: navyColor,
          child: pw.Text(
            "PHASE FINALE CROISÉE & MATCHES DE CLASSEMENT",
            style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(4),
            2: pw.FlexColumnWidth(4),
            3: pw.FlexColumnWidth(2.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
              children: [
                _th("Tour"),
                _th("Paire 1"),
                _th("Paire 2"),
                _th("Score"),
              ],
            ),
            for (final m in bracket.mainMatches)
              pw.TableRow(
                children: [
                  _td(m.roundName, alignLeft: true),
                  _td(m.pair1?.displayName ?? "À définir", alignLeft: true, isBold: m.winnerId == m.pair1?.id),
                  _td(m.pair2?.displayName ?? "À définir", alignLeft: true, isBold: m.winnerId == m.pair2?.id),
                  _td(m.score ?? "À jouer", isBold: true),
                ],
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildEliminationSection(
    TournamentBracket bracket,
    PdfColor navyColor,
    PdfColor lightGray,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: navyColor,
          child: pw.Text(
            "TABLEAU PRINCIPAL À ÉLIMINATION DIRECTE",
            style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5),
            1: pw.FlexColumnWidth(4),
            2: pw.FlexColumnWidth(4),
            3: pw.FlexColumnWidth(2.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
              children: [
                _th("Tour"),
                _th("Paire 1"),
                _th("Paire 2"),
                _th("Score"),
              ],
            ),
            for (final m in bracket.mainMatches)
              pw.TableRow(
                children: [
                  _td(m.roundName, alignLeft: true),
                  _td(
                    "${m.pair1?.displayName ?? '?'}${m.pair1?.seed != null ? ' (TS${m.pair1!.seed})' : ''}",
                    alignLeft: true,
                    isBold: m.winnerId == m.pair1?.id,
                  ),
                  _td(
                    m.isBye ? "EXEMPT (BYE)" : "${m.pair2?.displayName ?? '?'}${m.pair2?.seed != null ? ' (TS${m.pair2!.seed})' : ''}",
                    alignLeft: true,
                    isBold: m.winnerId == m.pair2?.id,
                  ),
                  _td(m.score ?? (m.isBye ? "BYE" : "À jouer"), isBold: true),
                ],
              ),
          ],
        ),
        if (bracket.consolationMatches.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: darkGrayPdf,
            child: pw.Text(
              "TABLEAU DE CONSOLANTE",
              style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(4),
              2: pw.FlexColumnWidth(4),
              3: pw.FlexColumnWidth(2.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
                children: [
                  _th("Tour"),
                  _th("Paire 1"),
                  _th("Paire 2"),
                  _th("Score"),
                ],
              ),
              for (final m in bracket.consolationMatches)
                pw.TableRow(
                  children: [
                    _td(m.roundName, alignLeft: true),
                    _td(m.pair1?.displayName ?? "À définir", alignLeft: true, isBold: m.winnerId == m.pair1?.id),
                    _td(m.pair2?.displayName ?? "À définir", alignLeft: true, isBold: m.winnerId == m.pair2?.id),
                    _td(m.score ?? "À jouer", isBold: true),
                  ],
                ),
            ],
          ),
        ],
        if (bracket.pools.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          for (final pool in bracket.pools) ...[
            _buildPoolSection(pool, navyColor, lightGray),
            pw.SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  /// 🏆 Classement unifié et continu du tournoi (de la 1ère place à la dernière place)
  /// avec 1er mis en grand prestige (Or), 2e (Argent), 3e (Bronze) et 4e à Ne continu
  static pw.Widget _buildUnifiedRankingsSection(
    List<PdfPairRanking> rankings,
    PdfColor navyColor,
    PdfColor goldColor,
  ) {
    if (rankings.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("CLASSEMENT DU TOURNOI :", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyColor)),
            pw.Text("Classement en attente de la saisie des résultats", style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          ],
        ),
      );
    }

    final first = rankings[0];
    final second = rankings.length > 1 ? rankings[1] : null;
    final third = rankings.length > 2 ? rankings[2] : null;
    final others = rankings.length > 3 ? rankings.sublist(3) : <PdfPairRanking>[];

    final firstName = "${first.pair.displayName}${first.pair.seed != null && first.pair.seed! > 0 ? ' [TS${first.pair.seed}]' : ''}";
    final secondName = second != null ? "${second.pair.displayName}${second.pair.seed != null && second.pair.seed! > 0 ? ' [TS${second.pair.seed}]' : ''}" : "";
    final thirdName = third != null ? "${third.pair.displayName}${third.pair.seed != null && third.pair.seed! > 0 ? ' [TS${third.pair.seed}]' : ''}" : "";

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // En-tête de section principal
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: navyColor,
            borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "CLASSEMENT OFFICIEL DU TOURNOI (DU 1ER AU ${rankings.length}E)",
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.5),
              ),
              pw.Text(
                "${rankings.length} paires engagées · Homologation FFT",
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFDE68A)),
              ),
            ],
          ),
        ),

        // 🥇 1ER EN GROS PRESTIGE OR (Hero grand format)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFEF9C3),
            border: pw.Border.all(color: const PdfColor.fromInt(0xFFD97706), width: 1.6),
          ),
          child: pw.Row(
            children: [
              // Grand Badge Or
              pw.Container(
                width: 44,
                height: 40,
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFB45309),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Center(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text("1er", style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text("OR", style: pw.TextStyle(color: const PdfColor.fromInt(0xFFFEF08A), fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFD97706),
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                          child: pw.Text(
                            "CHAMPIONS / VAINQUEURS DU TOURNOI",
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 6.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          cleanText(first.stage),
                          style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF92400E)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      cleanText(firstName),
                      maxLines: 1,
                      style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF78350F)),
                    ),
                  ],
                ),
              ),
              if (first.score != null && first.score!.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFFEF08A),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFD97706), width: 0.8),
                  ),
                  child: pw.Text(
                    cleanText(first.score!),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E)),
                  ),
                ),
            ],
          ),
        ),

        // 🥈 2E (ARGENT) & 🥉 3E (BRONZE) CÔTE À CÔTE
        if (second != null)
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
                right: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              ),
            ),
            child: pw.Row(
              children: [
                // 2e Place (Argent)
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    color: const PdfColor.fromInt(0xFFF8FAFC),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 32,
                          height: 30,
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFF64748B),
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Center(
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text("2e", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                pw.Text("ARGENT", style: pw.TextStyle(color: const PdfColor.fromInt(0xFFE2E8F0), fontSize: 5, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("FINALISTE", style: pw.TextStyle(color: const PdfColor.fromInt(0xFF64748B), fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                              pw.Text(cleanText(secondName), maxLines: 1, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B))),
                              if (second.score != null && second.score!.isNotEmpty)
                                pw.Text(cleanText(second.score!), maxLines: 1, style: const pw.TextStyle(fontSize: 6.5, color: PdfColor.fromInt(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Séparateur vertical si 3e existe
                if (third != null) ...[
                  pw.Container(width: 1, height: 42, color: PdfColors.grey300),
                  // 3e Place (Bronze)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      color: const PdfColor.fromInt(0xFFFFEDD5),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 32,
                            height: 30,
                            decoration: const pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFC2410C),
                              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Center(
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text("3e", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  pw.Text("BRONZE", style: pw.TextStyle(color: const PdfColor.fromInt(0xFFFED7AA), fontSize: 5, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("3e PLACE (PODIUM)", style: pw.TextStyle(color: const PdfColor.fromInt(0xFFC2410C), fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                                pw.Text(cleanText(thirdName), maxLines: 1, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7C2D12))),
                                if (third.score != null && third.score!.isNotEmpty)
                                  pw.Text(cleanText(third.score!), maxLines: 1, style: const pw.TextStyle(fontSize: 6.5, color: PdfColor.fromInt(0xFFC2410C))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // 4E À DERNIÈRE ÉQUIPE (DANS LA CONTINUITÉ DE LA MÊME LISTE)
        if (others.isNotEmpty)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(36),
              1: pw.FlexColumnWidth(6),
              2: pw.FlexColumnWidth(3.5),
              3: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
                children: [
                  _thTable("RANG"),
                  _thTable("ÉQUIPE (PAIRE)", alignLeft: true),
                  _thTable("PARCOURS / STADE"),
                  _thTable("SCORE / BILAN"),
                ],
              ),
              for (int i = 0; i < others.length; i++) ...[
                () {
                  final r = others[i];
                  final rowBg = (i % 2 == 0) ? PdfColors.white : const PdfColor.fromInt(0xFFF8FAFC);
                  final pair = r.pair;
                  final seed = pair.seed != null && pair.seed! > 0 ? " [TS${pair.seed}]" : "";
                  final names = "${pair.player1Name} / ${pair.player2Name}$seed";

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBg),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 2),
                        alignment: pw.Alignment.center,
                        child: pw.Container(
                          width: 22,
                          height: 15,
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFF94A3B8),
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              "${r.rank}e",
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              cleanText(names),
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
                        child: pw.Text(
                          cleanText(r.stage),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF334155)),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
                        child: pw.Text(
                          cleanText(r.score ?? "-"),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A)),
                        ),
                      ),
                    ],
                  );
                }(),
              ],
            ],
          ),
      ],
    );
  }

  static pw.Widget _thTable(String text, {bool alignLeft = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        cleanText(text),
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF1E293B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// 🎾 Récapitulatif exhaustif et complet de tous les matches du tournoi
  /// incluant impérativement tous les scores des phases finales et des poules
  static pw.Widget _buildCleanScoresRecap(
    TournamentBracket bracket,
    PdfColor navyColor,
    PdfColor darkGray,
  ) {
    // 1. EXTRACTION ET TRI DES MATCHES DE PHASE FINALE
    final List<({
      String tour,
      String winnerName,
      String loserName,
      String score,
      bool isFinal,
      bool isP34,
      PdfColor rowBg,
      PdfColor scoreBg,
      PdfColor scoreBorder,
      PdfColor scoreTextColor,
    })> finalMatchesList = [];

    // Priorité de tri : Finale (1), Petite Finale (2), DF1 (3), DF2 (4), autres DF (5), Places 5-6 (6), Places 7-8 (7), QF (8), autres (10)
    int getPhasePriority(BracketMatch m) {
      final code = m.matchCode ?? '';
      final id = m.id.toLowerCase();
      final name = m.roundName.toLowerCase();
      if (code == 'FINALE' || id == 'final_fin' || (name.contains('finale') && !name.contains('demi') && !name.contains('1/4') && !name.contains('1/8') && !name.contains('consolante') && !name.contains('3') && !name.contains('5') && !name.contains('7'))) return 1;
      if (code == 'PLACE_3_4' || id == 'final_p34' || name.contains('place 3') || name.contains('3/4') || name.contains('petite finale')) return 2;
      if (code == 'DF1' || id == 'final_df1') return 3;
      if (code == 'DF2' || id == 'final_df2') return 4;
      if (code.startsWith('DF') || name.contains('demi')) return 5;
      if (code == 'PLACE_5_6' || id == 'final_p56' || name.contains('5/6') || name.contains('place 5')) return 6;
      if (code == 'PLACE_7_8' || id == 'final_p78' || name.contains('7/8') || name.contains('place 7')) return 7;
      if (code.startsWith('QF') || name.contains('quart') || name.contains('1/4')) return 8;
      return 10;
    }

    final sortedMainMatches = List<BracketMatch>.from(bracket.mainMatches)
      ..sort((a, b) => getPhasePriority(a).compareTo(getPhasePriority(b)));

    for (final m in sortedMainMatches) {
      final code = m.matchCode ?? '';
      final id = m.id.toLowerCase();
      final name = m.roundName.toLowerCase();
      final isFin = code == 'FINALE' || id == 'final_fin' || (name.contains('finale') && !name.contains('demi') && !name.contains('1/4') && !name.contains('3') && !name.contains('5') && !name.contains('7'));
      final isP34 = code == 'PLACE_3_4' || id == 'final_p34' || name.contains('place 3') || name.contains('3/4') || name.contains('petite finale');

      String tourLabel = m.roundName;
      if (isFin) {
        tourLabel = "GRANDE FINALE (Places 1 & 2)";
      } else if (isP34) {
        tourLabel = "PETITE FINALE (Places 3 & 4)";
      } else if (code == 'DF1' || id == 'final_df1') {
        tourLabel = "DEMI-FINALE 1 (1A vs 2B)";
      } else if (code == 'DF2' || id == 'final_df2') {
        tourLabel = "DEMI-FINALE 2 (1B vs 2A)";
      } else if (code == 'PLACE_5_6' || id == 'final_p56') {
        tourLabel = "MATCH PLACES 5 & 6";
      } else if (code == 'PLACE_7_8' || id == 'final_p78') {
        tourLabel = "MATCH PLACES 7 & 8";
      }

      final w = _resolveWinner(m);
      final l = _resolveLoser(m);

      String wName;
      String lName;
      if (w != null) {
        wName = w.displayName;
        lName = (l != null ? l.displayName : (m.pair1?.id == w.id ? m.pair2?.displayName : m.pair1?.displayName)) ?? "Adversaire";
      } else {
        wName = m.pair1?.displayName ?? "Paire 1";
        lName = m.pair2?.displayName ?? "Paire 2";
      }

      final sc = (m.score != null && m.score!.trim().isNotEmpty && m.score!.trim() != 'Terminé')
          ? m.score!.trim()
          : (m.isCompleted ? "NC" : "À disputer");

      final rowBg = isFin
          ? const PdfColor.fromInt(0xFFFEF9C3)
          : (isP34
              ? const PdfColor.fromInt(0xFFFFEDD5)
              : (code.startsWith('DF') || id.contains('df') ? const PdfColor.fromInt(0xFFF1F5F9) : const PdfColor.fromInt(0xFFFFFFFF)));

      final scoreBg = isFin
          ? const PdfColor.fromInt(0xFFFEF08A)
          : (isP34
              ? const PdfColor.fromInt(0xFFFED7AA)
              : const PdfColor.fromInt(0xFFE2E8F0));

      final scoreBorder = isFin
          ? const PdfColor.fromInt(0xFFD97706)
          : (isP34
              ? const PdfColor.fromInt(0xFFEA580C)
              : const PdfColor.fromInt(0xFFCBD5E1));

      final scoreTextColor = isFin
          ? const PdfColor.fromInt(0xFF92400E)
          : (isP34
              ? const PdfColor.fromInt(0xFFC2410C)
              : const PdfColor.fromInt(0xFF0F172A));

      finalMatchesList.add((
        tour: tourLabel,
        winnerName: wName,
        loserName: lName,
        score: sc,
        isFinal: isFin,
        isP34: isP34,
        rowBg: rowBg,
        scoreBg: scoreBg,
        scoreBorder: scoreBorder,
        scoreTextColor: scoreTextColor,
      ));
    }

    // 2. EXTRACTION DES MATCHES DE POULES
    final List<({String tour, String winnerName, String loserName, String score})> poolMatchesList = [];
    for (final pool in bracket.pools) {
      for (final m in pool.matches) {
        final w = _resolveWinner(m);
        final l = _resolveLoser(m);
        String wName;
        String lName;
        if (w != null) {
          wName = w.displayName;
          lName = (l != null ? l.displayName : (m.pair1?.id == w.id ? m.pair2?.displayName : m.pair1?.displayName)) ?? "Adversaire";
        } else {
          wName = m.pair1?.displayName ?? "Paire 1";
          lName = m.pair2?.displayName ?? "Paire 2";
        }
        final sc = (m.score != null && m.score!.trim().isNotEmpty && m.score!.trim() != 'Terminé')
            ? m.score!.trim()
            : (m.isCompleted ? "NC" : "À jouer");

        poolMatchesList.add((
          tour: "${pool.name} · ${m.roundName}",
          winnerName: wName,
          loserName: lName,
          score: sc,
        ));
      }
    }

    // 3. EXTRACTION DE LA CONSOLANTE
    final List<({String tour, String winnerName, String loserName, String score})> consoMatchesList = [];
    for (final m in bracket.consolationMatches) {
      final w = _resolveWinner(m);
      final l = _resolveLoser(m);
      String wName;
      String lName;
      if (w != null) {
        wName = w.displayName;
        lName = (l != null ? l.displayName : (m.pair1?.id == w.id ? m.pair2?.displayName : m.pair1?.displayName)) ?? "Adversaire";
      } else {
        wName = m.pair1?.displayName ?? "Paire 1";
        lName = m.pair2?.displayName ?? "Paire 2";
      }
      final sc = (m.score != null && m.score!.trim().isNotEmpty && m.score!.trim() != 'Terminé')
          ? m.score!.trim()
          : (m.isCompleted ? "NC" : "À jouer");
      consoMatchesList.add((
        tour: "Consolante · ${m.roundName}",
        winnerName: wName,
        loserName: lName,
        score: sc,
      ));
    }

    if (finalMatchesList.isEmpty && poolMatchesList.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("RÉCAPITULATIF DES MATCHES :", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyColor)),
            pw.Text("Scores et résultats en cours de saisie par le JAT", style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Grand bandeau d'en-tête de section
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: navyColor,
            borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "RÉCAPITULATIF OFFICIEL DE TOUS LES MATCHES & SCORES DU TOURNOI",
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.5),
              ),
              pw.Text(
                "${finalMatchesList.length + poolMatchesList.length} matches enregistrés · FFT",
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFDE68A)),
              ),
            ],
          ),
        ),

        // 🏆 SOUS-SECTION A : PHASES FINALES & MATCHES DE CLASSEMENT (AVEC TOUS LES SCORES)
        if (finalMatchesList.isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: const PdfColor.fromInt(0xFFE2E8F0),
            child: pw.Row(
              children: [
                pw.Text(
                  "PHASES FINALES & MATCHES DE CLASSEMENT (SCORES OFFICIELS)",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                ),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3.0),
              1: pw.FlexColumnWidth(3.8),
              2: pw.FlexColumnWidth(3.8),
              3: pw.FlexColumnWidth(2.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                children: [
                  _thTable("TOUR / PHASE"),
                  _thTable("VAINQUEUR / PAIRE 1", alignLeft: true),
                  _thTable("ADVERSAIRE / PAIRE 2", alignLeft: true),
                  _thTable("SCORE OFFICIEL"),
                ],
              ),
              for (final fm in finalMatchesList)
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: fm.rowBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
                      child: pw.Text(
                        cleanText(fm.tour),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 7.2,
                          fontWeight: fm.isFinal ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: fm.isFinal ? const PdfColor.fromInt(0xFF92400E) : const PdfColor.fromInt(0xFF334155),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
                      child: pw.Text(
                        cleanText(fm.winnerName),
                        style: pw.TextStyle(
                          fontSize: 7.8,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF0F172A),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
                      child: pw.Text(
                        cleanText(fm.loserName),
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          color: const PdfColor.fromInt(0xFF64748B),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                      child: pw.Container(
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
                        decoration: pw.BoxDecoration(
                          color: fm.scoreBg,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          border: pw.Border.all(color: fm.scoreBorder, width: 0.6),
                        ),
                        child: pw.Text(
                          cleanText(fm.score),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 7.8,
                            fontWeight: pw.FontWeight.bold,
                            color: fm.scoreTextColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 6),
        ],

        // 🎾 SOUS-SECTION B : PHASES DE GROUPES / POULES (TOUS LES RÉSULTATS & SCORES)
        if (poolMatchesList.isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: const PdfColor.fromInt(0xFFE2E8F0),
            child: pw.Row(
              children: [
                pw.Text(
                  "PHASE PRÉLIMINAIRE EN POULES (TOUS LES MATCHES & SCORES)",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                ),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.6),
              1: pw.FlexColumnWidth(4.0),
              2: pw.FlexColumnWidth(4.0),
              3: pw.FlexColumnWidth(2.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                children: [
                  _thTable("POULE / TOUR"),
                  _thTable("VAINQUEUR / PAIRE 1", alignLeft: true),
                  _thTable("ADVERSAIRE / PAIRE 2", alignLeft: true),
                  _thTable("SCORE"),
                ],
              ),
              for (int i = 0; i < poolMatchesList.length; i++) ...[
                () {
                  final pm = poolMatchesList[i];
                  final rowBg = (i % 2 == 0) ? PdfColors.white : const PdfColor.fromInt(0xFFF8FAFC);
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBg),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                        child: pw.Text(
                          cleanText(pm.tour),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF475569)),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
                        child: pw.Text(
                          cleanText(pm.winnerName),
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A)),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
                        child: pw.Text(
                          cleanText(pm.loserName),
                          style: const pw.TextStyle(fontSize: 7.2, color: PdfColor.fromInt(0xFF64748B)),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                        child: pw.Container(
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            cleanText(pm.score),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B)),
                          ),
                        ),
                      ),
                    ],
                  );
                }(),
              ],
            ],
          ),
        ],

        // 🏅 SOUS-SECTION C : CONSOLANTE (si présente)
        if (consoMatchesList.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: const PdfColor.fromInt(0xFFE2E8F0),
            child: pw.Text(
              "TABLEAU CONSOLANTE (SCORES)",
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.6),
              1: pw.FlexColumnWidth(4.0),
              2: pw.FlexColumnWidth(4.0),
              3: pw.FlexColumnWidth(2.4),
            },
            children: [
              for (final cm in consoMatchesList)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                      child: pw.Text(cleanText(cm.tour), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF475569))),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
                      child: pw.Text(cleanText(cm.winnerName), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A))),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
                      child: pw.Text(cleanText(cm.loserName), style: const pw.TextStyle(fontSize: 7.2, color: PdfColor.fromInt(0xFF64748B))),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                      child: pw.Text(cleanText(cm.score), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B))),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildJatSignatureBox(
    PdfColor navyColor,
    PdfColor darkGray, {
    TournamentModel? tournament,
    String? categoryLabel,
  }) {
    final hasTournament = tournament != null;
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "HOMOLOGATION & VISA DU JUGE-ARBITRE (JAT)",
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                ),
                pw.SizedBox(height: 3),
                if (hasTournament && categoryLabel != null) ...[
                  pw.Text(
                    cleanText("Je soussigné(e) certifie conformes et sincères les résultats ci-dessus pour l'épreuve $categoryLabel."),
                    style: const pw.TextStyle(fontSize: 7.5, color: darkGrayPdf),
                  ),
                  pw.Text(
                    cleanText("Tournoi : ${tournament.name} · Homologation FFT N° ${tournament.id}"),
                    style: const pw.TextStyle(fontSize: 7.5, color: darkGrayPdf),
                  ),
                  pw.Text(
                    cleanText("JAT Officiel : ${tournament.referee?.isNotEmpty == true ? tournament.referee! : 'Juge-Arbitre FFT'}"),
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                  ),
                ] else ...[
                  pw.Text("Tournoi clôturé et homologué sous contrôle FFT.", style: const pw.TextStyle(fontSize: 7.5, color: darkGrayPdf)),
                  pw.Text("Télétransmission des résultats effectuée à la ligue.", style: const pw.TextStyle(fontSize: 7.5, color: darkGrayPdf)),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Container(
            width: 130,
            height: 44,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Center(
              child: pw.Text("Signature & Cachet JAT", style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
            ),
          ),
        ],
      ),
    );
  }

  static String cleanText(String text) {
    return text
        .replaceAll('🏆', '')
        .replaceAll('🥇', '')
        .replaceAll('🥈', '')
        .replaceAll('🥉', '')
        .replaceAll('⚔️', '')
        .replaceAll('📊', '')
        .replaceAll('🛡️', '')
        .replaceAll('🏖️', '')
        .replaceAll('🔥', '')
        .replaceAll('☕', '')
        .replaceAll('🔄', '')
        .replaceAll('✅', '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '')
        .trim();
  }

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        cleanText(text),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B)),
      ),
    );
  }

  static pw.Widget _td(String text, {bool alignLeft = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: pw.Text(
        cleanText(text),
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _getCategoryLabel(String category) {
    if (category.contains('messieurs') || category == 'DH') return 'DH';
    if (category.contains('dames') || category == 'DD') return 'DD';
    if (category.contains('mixtes') || category == 'DX') return 'DX';
    return category;
  }

  static pw.Widget _buildFullHeader(
    TournamentModel tournament,
    PdfColor navyColor,
    PdfColor goldColor,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "FÉDÉRATION FRANÇAISE DE TENNIS · BEACH TENNIS",
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: navyColor,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                "${tournament.name} · DOSSIER OFFICIEL DU TOURNOI",
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: goldColor,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                "Homologation : ${tournament.id}",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                "Lieu : ${tournament.location.isNotEmpty ? tournament.location : tournament.club}",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                "Date : ${tournament.dateString}",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMasterPodiumSummary(
    List<TournamentBracket> brackets,
    PdfColor navyColor,
    PdfColor goldColor,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: goldColor, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "PALMARÈS GÉNÉRAL DU TOURNOI",
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navyColor),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: brackets.map((b) {
              final label = _getCategoryLabel(b.category);
              final (winner, runnerUp, _) = resolvePalmares(b);

              return pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(color: navyColor, borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Text(
                          label,
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "1er : ${winner?.displayName ?? 'En cours...'}",
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: goldColor),
                      ),
                      pw.Text(
                        "2e : ${runnerUp?.displayName ?? 'En cours...'}",
                        style: const pw.TextStyle(fontSize: 7.5, color: darkGrayPdf),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCategorySectionHeader(
    TournamentBracket bracket,
    PdfColor navyColor,
    PdfColor goldColor,
  ) {
    final label = _getCategoryLabel(bracket.category);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: navyColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "ÉPREUVE : ${label.toUpperCase()} (${bracket.format == 'pools_and_bracket' ? 'POULES + ARBRE' : 'ÉLIMINATION DIRECTE'})",
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          ),
          pw.Text(
            "${bracket.pairs.length} paires",
            style: pw.TextStyle(fontSize: 8, color: goldColor, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// 🏟️ Construit les octets du PDF de programmation et rotation des terrains (A4 Paysage)
  static Future<Uint8List> buildCourtRotationsPdfBytes({
    required TournamentModel tournament,
    required List<Map<String, dynamic>> rotations,
    required int numCourts,
    required Set<String> categories,
  }) async {
    final pdf = pw.Document();

    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFB8860B);
    const darkGray = PdfColor.fromInt(0xFF334155);
    const lightGray = PdfColor.fromInt(0xFFF1F5F9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: navyColor, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "FÉDÉRATION FRANÇAISE DE TENNIS · BEACH TENNIS",
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkGray),
                  ),
                  pw.Text(
                    "FEUILLE OFFICIELLE DE PROGRAMMATION ET ROTATION DES TERRAINS",
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: navyColor),
                  ),
                  pw.Text(
                    "Tournoi : ${cleanText(tournament.name)} (${cleanText(tournament.category)}) · Club : ${cleanText(tournament.club)}",
                    style: const pw.TextStyle(fontSize: 8.5, color: darkGray),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "$numCourts Terrains mutualisés · Tableaux : ${categories.join(' + ')}",
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: goldColor),
                  ),
                  pw.Text(
                    "Date : ${tournament.dateString} · JAT : ${cleanText(tournament.referee ?? 'JAT Officiel')}",
                    style: const pw.TextStyle(fontSize: 8, color: darkGray),
                  ),
                  pw.Text(
                    "Page ${context.pageNumber} / ${context.pagesCount}",
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => _buildFooter(context, darkGray),
        build: (context) => [
          pw.SizedBox(height: 8),

          // Grille des rotations
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(80),
              for (int i = 1; i <= numCourts; i++)
                i: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: navyColor),
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                    child: pw.Text("Horaire / Rotation", style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                  ),
                  for (int c = 1; c <= numCourts; c++)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      child: pw.Text(
                        c == 1 ? "Court 1 (Central)" : "Court $c",
                        style: pw.TextStyle(color: c == 1 ? goldColor : PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                ],
              ),

              // Data rows
              for (int r = 0; r < rotations.length; r++) ...[
                () {
                  final rot = rotations[r];
                  final courts = (rot['courts'] as List<dynamic>?) ?? [];
                  final isEven = r % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : lightGray),
                    children: [
                      // Horaire column
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(cleanText(rot['time']?.toString().split(' - ').first ?? ''), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyColor)),
                            pw.Text("Rot. ${r + 1}", style: const pw.TextStyle(fontSize: 7, color: darkGray)),
                          ],
                        ),
                      ),

                      // Court columns
                      for (int c = 1; c <= numCourts; c++) ...[
                        () {
                          final slot = courts.where(
                            (item) => item is Map && item['court'] == c,
                          ).firstOrNull as Map?;

                          if (slot == null || slot['type'] == 'Disponible' || slot['p1'] == 'Court disponible') {
                            return pw.Container(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Center(
                                child: pw.Text("Disponible", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                              ),
                            );
                          }

                          final type = slot['type']?.toString() ?? '';
                          final tour = slot['tour']?.toString() ?? '';
                          final p1 = slot['p1']?.toString() ?? '';
                          final p2 = slot['p2']?.toString() ?? '';
                          final score = slot['score']?.toString() ?? '';

                          return pw.Container(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text("[$type] ${cleanText(tour)}", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: navyColor)),
                                    if (score.isNotEmpty && score != '-' && score != 'À jouer')
                                      pw.Text(score, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: goldColor)),
                                  ],
                                ),
                                pw.SizedBox(height: 1),
                                pw.Text(cleanText(p1), style: const pw.TextStyle(fontSize: 6.5)),
                                pw.Text("vs ${cleanText(p2)}", style: const pw.TextStyle(fontSize: 6.5, color: darkGray)),
                              ],
                            ),
                          );
                        }(),
                      ],
                    ],
                  );
                }(),
              ],
            ],
          ),

          pw.SizedBox(height: 12),
          _buildJatSignatureBox(navyColor, darkGray),
        ],
      ),
    );

    return pdf.save();
  }

  /// 🏟️ Génère et exporte la feuille officielle de programmation et rotation des terrains (A4 Paysage)
  static Future<void> generateAndExportCourtRotationsPdf({
    required TournamentModel tournament,
    required List<Map<String, dynamic>> rotations,
    required int numCourts,
    required Set<String> categories,
  }) async {
    final pdfBytes = await buildCourtRotationsPdfBytes(
      tournament: tournament,
      rotations: rotations,
      numCourts: numCourts,
      categories: categories,
    );

    final filename = 'Rotations_Terrains_${tournament.name.replaceAll(' ', '_')}.pdf';
    await exportOrDownloadPdf(bytes: pdfBytes, filename: filename);
  }

  // =========================================================================
  // 🦋 TABLEAU PAPILLON OFFICIEL FFT (AFFICHEUR CLUB A4 / A3 PAYSAGE)
  // Tableau Central 1er Tour avec Tableau Principal à droite, Consolante à gauche,
  // Matches de classement intégral (1 à 16) et QR Code "Live Score" BeachMatch.
  // =========================================================================

  static Future<Uint8List> buildButterflyPosterPdfBytes({
    required TournamentModel tournament,
    required TournamentBracket bracket,
    Uint8List? clubLogoBytes,
    String? customRules,
    bool isA3 = false,
    int numberOfCourts = 4,
  }) async {
    final tLoc = '${tournament.club} ${tournament.location} ${tournament.name}'.toLowerCase();
    if (tLoc.contains('valentine') || tLoc.contains('tennis park')) {
      if (bracket.numCourts > 0 && bracket.numCourts != 4) {
        numberOfCourts = bracket.numCourts;
      } else {
        numberOfCourts = 3;
      }
    }
    final pdf = pw.Document();

    final pageFormat = isA3 ? PdfPageFormat.a3.landscape : PdfPageFormat.a4.landscape;

    // Palette officielle
    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFB8860B);
    const darkGray = PdfColor.fromInt(0xFF334155);
    const lightGray = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFF1E293B);

    // 1. Extraction de toutes les paires réelles du tournoi (depuis pairs ou pools)
    List<TournamentPair> allRealPairs = [];
    if (bracket.pairs.isNotEmpty) {
      allRealPairs = List<TournamentPair>.from(bracket.pairs);
    } else if (bracket.pools.isNotEmpty) {
      allRealPairs = bracket.pools.expand((p) => p.pairs).toList();
    }

    final isPoolFormat = bracket.pools.isNotEmpty ||
        bracket.format == 'pools_and_bracket' ||
        bracket.format == 'single_pool';

    // 2. Extraction des matches du 1er tour réel (Round 0)
    List<BracketMatch> r0Matches = bracket.mainMatches
        .where((m) => m.roundIndex == 0)
        .toList()
      ..sort((a, b) => a.matchIndex.compareTo(b.matchIndex));

    if (!isPoolFormat && r0Matches.isEmpty && allRealPairs.isNotEmpty) {
      final generated = BracketGeneratorService.generateBracket(
        tournamentId: tournament.id,
        category: bracket.category,
        registeredPairs: allRealPairs,
        numCourts: numberOfCourts,
      );
      r0Matches = generated.mainMatches
          .where((m) => m.roundIndex == 0)
          .toList()
        ..sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
    }

    List<TournamentPair> startingPairs = [];
    for (final m in r0Matches) {
      startingPairs.add(m.pair1 ??
          const TournamentPair(id: 'bye', player1Name: 'EXEMPT', player2Name: 'BYE', isBye: true));
      startingPairs.add(m.pair2 ??
          const TournamentPair(id: 'bye', player1Name: 'EXEMPT', player2Name: 'BYE', isBye: true));
    }
    while (startingPairs.length < 16 && r0Matches.length > 4) {
      startingPairs.add(
          const TournamentPair(id: 'bye', player1Name: 'EXEMPT', player2Name: 'BYE', isBye: true));
    }

    final categoryLabel = bracket.category == 'double_messieurs' || bracket.category == 'DH'
        ? 'DOUBLE MESSIEURS'
        : (bracket.category == 'double_dames' || bracket.category == 'DD' ? 'DOUBLE DAMES' : 'DOUBLE MIXTE');

    final rulesText = customRules ??
        "2 sets de 4 jeux · Tie-Break à 4/4 · 3e set = Super Tie-Break (10 pts) · No-Ad (Point décisif)";

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. EN-TÊTE OFFICIEL FFT & CLUB
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: navyColor, width: 1.5)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Logo Club ou Blason FFT
                    if (clubLogoBytes != null && clubLogoBytes.isNotEmpty)
                      pw.Container(
                        width: 44,
                        height: 44,
                        margin: const pw.EdgeInsets.only(right: 10),
                        child: pw.Image(pw.MemoryImage(clubLogoBytes), fit: pw.BoxFit.contain),
                      )
                    else
                      pw.Container(
                        width: 42,
                        height: 42,
                        margin: const pw.EdgeInsets.only(right: 10),
                        padding: const pw.EdgeInsets.all(3),
                        decoration: pw.BoxDecoration(
                          color: navyColor,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: goldColor, width: 1),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            "FFT\nBEACH",
                            style: pw.TextStyle(color: goldColor, fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),

                    // Titre & Épreuve
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            cleanText("${tournament.club.isNotEmpty ? tournament.club : 'CLUB ORGANISATEUR'} · FFT BEACH TENNIS"),
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkGray, letterSpacing: 0.8),
                          ),
                          pw.Text(
                            cleanText("${tournament.name.toUpperCase()} · $categoryLabel${isPoolFormat ? ' · FORMAT POULES' : ''}"),
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: navyColor),
                          ),
                          pw.Text(
                            isPoolFormat
                                ? "Tableau Officiel des Poules & Phase Finale · JAT : ${cleanText(tournament.referee ?? 'Juge-Arbitre Référent')}"
                                : "Tableau Officiel à Classement Intégral · JAT : ${cleanText(tournament.referee ?? 'Juge-Arbitre Référent')}",
                            style: const pw.TextStyle(fontSize: 7.5, color: darkGray),
                          ),
                        ],
                      ),
                    ),

                    // Encadré des Règles de jeu (comme manuscrit à Narbonne)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: lightGray,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: navyColor, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            "FORMAT DES MATCHES · $numberOfCourts TERRAINS ALLOUÉS",
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            rulesText,
                            style: const pw.TextStyle(fontSize: 7, color: darkGray),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // 2. CORPS DU TABLEAU (POULES OU PAPILLON 8 / 16)
              pw.Expanded(
                child: isPoolFormat
                    ? _buildPoolsPosterContent(
                        bracket: bracket,
                        navyColor: navyColor,
                        goldColor: goldColor,
                        borderColor: borderColor,
                        lightGray: lightGray,
                        darkGray: darkGray,
                        numberOfCourts: numberOfCourts,
                      )
                    : (r0Matches.length == 4
                        ? _buildButterflyGrid8(
                            r0Matches: r0Matches,
                            bracket: bracket,
                            navyColor: navyColor,
                            goldColor: goldColor,
                            borderColor: borderColor,
                            lightGray: lightGray,
                            numberOfCourts: numberOfCourts,
                          )
                        : _buildButterflyGrid(
                            r0Matches: r0Matches,
                            startingPairs: startingPairs,
                            bracket: bracket,
                            navyColor: navyColor,
                            goldColor: goldColor,
                            borderColor: borderColor,
                            lightGray: lightGray,
                            numberOfCourts: numberOfCourts,
                          )),
              ),

              pw.SizedBox(height: 4),

              // 3. PIED DE PAGE : LEVIER D'ACQUISITION POSITIF & QR CODE
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: lightGray,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: goldColor, width: 0.8),
                ),
                child: pw.Row(
                  children: [
                    // QR Code vers l'application / Live Score
                    pw.Container(
                      width: 28,
                      height: 28,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'https://beach-tennis-216f4.web.app/download',
                        drawText: false,
                        color: navyColor,
                      ),
                    ),
                    pw.SizedBox(width: 8),

                    // Accroche positive
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Vivez le tournoi en direct ! Scannez ce QR Code pour suivre les scores en temps réel et vos terrains sur BeachMatch.",
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                          ),
                          pw.Text(
                            "Application officielle BeachMatch · Convocations · Live Scores · Tableaux & Feuilles de matches FFT",
                            style: const pw.TextStyle(fontSize: 6.5, color: darkGray),
                          ),
                        ],
                      ),
                    ),

                    // Date & Mention
                    pw.Text(
                      "Édité le ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} · BeachMatch System",
                      style: const pw.TextStyle(fontSize: 6.5, color: darkGray),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Grille papillon complète vectorielle (16 paires officielle FFT)
  static pw.Widget _buildButterflyGrid({
    required List<BracketMatch> r0Matches,
    required List<TournamentPair> startingPairs,
    required TournamentBracket bracket,
    required PdfColor navyColor,
    required PdfColor goldColor,
    required PdfColor borderColor,
    required PdfColor lightGray,
    int numberOfCourts = 4,
  }) {
    TournamentPair? getExempt(int matchIdx) {
      if (matchIdx >= r0Matches.length) return null;
      final m = r0Matches[matchIdx];
      if (m.pair1?.isBye == true && m.pair2 != null && !m.pair2!.isBye) return m.pair2;
      if (m.pair2?.isBye == true && m.pair1 != null && !m.pair1!.isBye) return m.pair1;
      return null;
    }

    final quart0 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 0).firstOrNull;
    final quart1 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 1).firstOrNull;
    final quart2 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 2).firstOrNull;
    final quart3 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 3).firstOrNull;

    final demi0 = bracket.mainMatches.where((m) => m.roundIndex == 2 && m.matchIndex == 0).firstOrNull;
    final demi1 = bracket.mainMatches.where((m) => m.roundIndex == 2 && m.matchIndex == 1).firstOrNull;
    final finale = bracket.mainMatches.where((m) => m.roundIndex == 3 && m.matchIndex == 0).firstOrNull;
    final petiteFinale = bracket.mainMatches.where((m) => m.roundIndex == 3 && m.matchIndex == 1).firstOrNull;

    final ex0 = getExempt(0);
    final ex1 = getExempt(1);
    final ex2 = getExempt(2);
    final ex3 = getExempt(3);
    final ex4 = getExempt(4);
    final ex5 = getExempt(5);
    final ex6 = getExempt(6);
    final ex7 = getExempt(7);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ==========================================
        // GAUCHE : TABLEAU CONSOLANTE (Places 9 à 16)
        // ==========================================
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                color: const PdfColor.fromInt(0xFFE2E8F0),
                child: pw.Text(
                  "<< TABLEAU CONSOLANTE (PLACES 9 À 16)",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Finales Consolante (Places 9-10 & 11-12 & 13-14 & 15-16)
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "MATCH 31 · PLACES 9-10",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(31, numberOfCourts),
                            p1Placeholder: "Vainqueur Match 18",
                            p2Placeholder: "Vainqueur Match 22",
                          ),
                          _buildMatchBox(
                            label: "MATCH 29 · PLACES 11-12",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(29, numberOfCourts),
                            p1Placeholder: "Perdant Match 18",
                            p2Placeholder: "Perdant Match 22",
                          ),
                          _buildMatchBox(
                            label: "MATCH 27 · PLACES 13-14",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(27, numberOfCourts),
                            p1Placeholder: "Vainqueur Match 17",
                            p2Placeholder: "Vainqueur Match 19",
                          ),
                          _buildMatchBox(
                            label: "MATCH 25 · PLACES 15-16",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(25, numberOfCourts),
                            p1Placeholder: "Perdant Match 17",
                            p2Placeholder: "Perdant Match 19",
                          ),
                        ],
                      ),
                    ),
                    _buildConnectorColumn(forkCount: 2, pointingRight: false, color: borderColor),
                    // Demies Consolante
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "MATCH 18 · DEMIE CONSO",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(18, numberOfCourts),
                            p1Placeholder: "Vainqueur Match 9",
                            p2Placeholder: "Vainqueur Match 10",
                          ),
                          _buildMatchBox(
                            label: "MATCH 22 · DEMIE CONSO",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(22, numberOfCourts),
                            p1Placeholder: "Vainqueur Match 13",
                            p2Placeholder: "Vainqueur Match 14",
                          ),
                        ],
                      ),
                    ),
                    _buildConnectorColumn(forkCount: 2, pointingRight: false, color: borderColor),
                    // Quarts Consolante (issus des perdants T1)
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "MATCH 9 (Perd. 1 vs 2)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(9, numberOfCourts),
                            p1Placeholder: "Perdant Match 1",
                            p2Placeholder: "Perdant Match 2",
                          ),
                          _buildMatchBox(
                            label: "MATCH 10 (Perd. 3 vs 4)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(10, numberOfCourts),
                            p1Placeholder: "Perdant Match 3",
                            p2Placeholder: "Perdant Match 4",
                          ),
                          _buildMatchBox(
                            label: "MATCH 13 (Perd. 5 vs 6)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(13, numberOfCourts),
                            p1Placeholder: "Perdant Match 5",
                            p2Placeholder: "Perdant Match 6",
                          ),
                          _buildMatchBox(
                            label: "MATCH 14 (Perd. 7 vs 8)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(14, numberOfCourts),
                            p1Placeholder: "Perdant Match 7",
                            p2Placeholder: "Perdant Match 8",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Connecteur entre Quarts Consolante et Tour 1
        _buildConnectorColumn(forkCount: 4, pointingRight: false, color: borderColor),

        // ==========================================
        // AU CENTRE : COLONNE 1ER TOUR (DÉPART)
        // ==========================================
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                color: navyColor,
                child: pw.Text(
                  "1ER TOUR · TOUTES PAIRES",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    for (int i = 0; i < 8; i++) ...[
                      _buildFirstRoundBox(
                        matchNumber: i + 1,
                        p1: i * 2 < startingPairs.length ? startingPairs[i * 2] : const TournamentPair(id: 'bye', player1Name: 'EXEMPT', player2Name: 'BYE', isBye: true),
                        p2: i * 2 + 1 < startingPairs.length ? startingPairs[i * 2 + 1] : const TournamentPair(id: 'bye', player1Name: 'EXEMPT', player2Name: 'BYE', isBye: true),
                        navyColor: navyColor,
                        goldColor: goldColor,
                        courtBadge: getCourtBadgeForMatch(i + 1, numberOfCourts),
                        targetQuartMatch: (i ~/ 2) + 1,
                        targetSeed: i % 2 == 0 ? (i + 1 < 8 ? getExempt(i + 1) : null) : getExempt(i - 1),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Connecteur entre Tour 1 et Quarts Principaux
        _buildConnectorColumn(forkCount: 4, pointingRight: true, color: borderColor),

        // ==========================================
        // DROITE : TABLEAU PRINCIPAL (Places 1 à 8)
        // ==========================================
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                color: goldColor,
                child: pw.Text(
                  "TABLEAU PRINCIPAL (PLACES 1 À 8) >>",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Quarts de finale (issus des vainqueurs T1 et têtes de série exemptées)
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "QUART 1 (M1 vs M2)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: quart0?.court != null ? "Terrain ${quart0!.court}" : getCourtBadgeForMatch(11, numberOfCourts),
                            p1: quart0?.pair1 ?? ex0,
                            p2: quart0?.pair2 ?? ex1,
                            p1Placeholder: "Vainqueur Match 1",
                            p2Placeholder: "Vainqueur Match 2",
                            p1Subtext: ex0 != null ? "Exempt T1 (${ex0.seed != null ? 'TS' + ex0.seed.toString() : ''})" : null,
                            p2Subtext: ex1 != null ? "Exempt T1 (${ex1.seed != null ? 'TS' + ex1.seed.toString() : ''})" : null,
                          ),
                          _buildMatchBox(
                            label: "QUART 2 (M3 vs M4)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: quart1?.court != null ? "Terrain ${quart1!.court}" : getCourtBadgeForMatch(12, numberOfCourts),
                            p1: quart1?.pair1 ?? ex2,
                            p2: quart1?.pair2 ?? ex3,
                            p1Placeholder: "Vainqueur Match 3",
                            p2Placeholder: "Vainqueur Match 4",
                            p1Subtext: ex2 != null ? "Exempt T1 (${ex2.seed != null ? 'TS' + ex2.seed.toString() : ''})" : null,
                            p2Subtext: ex3 != null ? "Exempt T1 (${ex3.seed != null ? 'TS' + ex3.seed.toString() : ''})" : null,
                          ),
                          _buildMatchBox(
                            label: "QUART 3 (M5 vs M6)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: quart2?.court != null ? "Terrain ${quart2!.court}" : getCourtBadgeForMatch(15, numberOfCourts),
                            p1: quart2?.pair1 ?? ex4,
                            p2: quart2?.pair2 ?? ex5,
                            p1Placeholder: "Vainqueur Match 5",
                            p2Placeholder: "Vainqueur Match 6",
                            p1Subtext: ex4 != null ? "Exempt T1 (${ex4.seed != null ? 'TS' + ex4.seed.toString() : ''})" : null,
                            p2Subtext: ex5 != null ? "Exempt T1 (${ex5.seed != null ? 'TS' + ex5.seed.toString() : ''})" : null,
                          ),
                          _buildMatchBox(
                            label: "QUART 4 (M7 vs M8)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: quart3?.court != null ? "Terrain ${quart3!.court}" : getCourtBadgeForMatch(16, numberOfCourts),
                            p1: quart3?.pair1 ?? ex6,
                            p2: quart3?.pair2 ?? ex7,
                            p1Placeholder: "Vainqueur Match 7",
                            p2Placeholder: "Vainqueur Match 8",
                            p1Subtext: ex6 != null ? "Exempt T1 (${ex6.seed != null ? 'TS' + ex6.seed.toString() : ''})" : null,
                            p2Subtext: ex7 != null ? "Exempt T1 (${ex7.seed != null ? 'TS' + ex7.seed.toString() : ''})" : null,
                          ),
                        ],
                      ),
                    ),
                    _buildConnectorColumn(forkCount: 2, pointingRight: true, color: borderColor),
                    // Demi-finales
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "MATCH 20 · DEMI-FINALE 1",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: demi0?.court != null ? "Terrain ${demi0!.court}" : getCourtBadgeForMatch(20, numberOfCourts),
                            p1: demi0?.pair1,
                            p2: demi0?.pair2,
                            p1Placeholder: "Vainqueur Quart 1",
                            p2Placeholder: "Vainqueur Quart 2",
                          ),
                          _buildMatchBox(
                            label: "MATCH 24 · DEMI-FINALE 2",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: demi1?.court != null ? "Terrain ${demi1!.court}" : getCourtBadgeForMatch(24, numberOfCourts),
                            p1: demi1?.pair1,
                            p2: demi1?.pair2,
                            p1Placeholder: "Vainqueur Quart 3",
                            p2Placeholder: "Vainqueur Quart 4",
                          ),
                        ],
                      ),
                    ),
                    _buildConnectorColumn(forkCount: 2, pointingRight: true, color: borderColor),
                    // Finales (Places 1-2 & 3-4 & 5-6 & 7-8)
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "MATCH 32 · GRANDE FINALE (1-2)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            isFinal: true,
                            courtBadge: finale?.court != null ? "Terrain ${finale!.court}" : getCourtBadgeForMatch(32, numberOfCourts),
                            p1: finale?.pair1,
                            p2: finale?.pair2,
                            p1Placeholder: "Vainqueur Demi 1",
                            p2Placeholder: "Vainqueur Demi 2",
                          ),
                          _buildMatchBox(
                            label: "MATCH 30 · PETITE FINALE (3-4)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: petiteFinale?.court != null ? "Terrain ${petiteFinale!.court}" : getCourtBadgeForMatch(30, numberOfCourts),
                            p1Placeholder: "Perdant Demi 1",
                            p2Placeholder: "Perdant Demi 2",
                          ),
                          _buildMatchBox(
                            label: "MATCH 28 · PLACES 5-6",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(28, numberOfCourts),
                            p1Placeholder: "Vainqueur Conso Q1",
                            p2Placeholder: "Vainqueur Conso Q2",
                          ),
                          _buildMatchBox(
                            label: "MATCH 26 · PLACES 7-8",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(26, numberOfCourts),
                            p1Placeholder: "Perdant Conso Q1",
                            p2Placeholder: "Perdant Conso Q2",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Grille papillon pour tableau de 8 paires (Quarts -> Demies -> Finales)
  static pw.Widget _buildButterflyGrid8({
    required List<BracketMatch> r0Matches,
    required TournamentBracket bracket,
    required PdfColor navyColor,
    required PdfColor goldColor,
    required PdfColor borderColor,
    required PdfColor lightGray,
    int numberOfCourts = 4,
  }) {
    final demi0 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 0).firstOrNull;
    final demi1 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 1).firstOrNull;
    final finale = bracket.mainMatches.where((m) => m.roundIndex == 2 && m.matchIndex == 0).firstOrNull;
    final petiteFinale = bracket.mainMatches.where((m) => m.roundIndex == 2 && m.matchIndex == 1).firstOrNull;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // GAUCHE : CONSOLANTE (Places 5 à 8)
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                color: const PdfColor.fromInt(0xFFE2E8F0),
                child: pw.Text(
                  "<< CONSOLANTE (PLACES 5 À 8)",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Finales Consolante
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "MATCH 7 · PLACES 5-6",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: "T1",
                            p1Placeholder: "Vainqueur Conso D1",
                            p2Placeholder: "Vainqueur Conso D2",
                          ),
                          _buildMatchBox(
                            label: "MATCH 8 · PLACES 7-8",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: "T2",
                            p1Placeholder: "Perdant Conso D1",
                            p2Placeholder: "Perdant Conso D2",
                          ),
                        ],
                      ),
                    ),
                    _buildConnectorColumn(forkCount: 2, pointingRight: false, color: borderColor),
                    // Demies Consolante
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "CONSO DEMIE 1 (Perd. Q1 vs Q2)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: "T1",
                            p1Placeholder: "Perdant Quart 1",
                            p2Placeholder: "Perdant Quart 2",
                          ),
                          _buildMatchBox(
                            label: "CONSO DEMIE 2 (Perd. Q3 vs Q4)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: "T2",
                            p1Placeholder: "Perdant Quart 3",
                            p2Placeholder: "Perdant Quart 4",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Connecteur
        _buildConnectorColumn(forkCount: 2, pointingRight: false, color: borderColor),

        // AU CENTRE : QUARTS DE FINALE (DÉPART 8 PAIRES)
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                color: navyColor,
                child: pw.Text(
                  "1ER TOUR · QUARTS DE FINALE (8 PAIRES)",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      if (i < r0Matches.length)
                        _buildFirstRoundBox(
                          matchNumber: i + 1,
                          p1: r0Matches[i].pair1 ?? const TournamentPair(id: 'bye', player1Name: 'EXEMPT', player2Name: 'BYE', isBye: true),
                          p2: r0Matches[i].pair2 ?? const TournamentPair(id: 'bye', player1Name: 'EXEMPT', player2Name: 'BYE', isBye: true),
                          navyColor: navyColor,
                          goldColor: goldColor,
                          courtBadge: r0Matches[i].court != null ? "Terrain ${r0Matches[i].court}" : "T${(i % numberOfCourts) + 1}",
                          targetQuartMatch: (i ~/ 2) + 1,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Connecteur
        _buildConnectorColumn(forkCount: 2, pointingRight: true, color: borderColor),

        // DROITE : TABLEAU PRINCIPAL (Places 1 à 4)
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                color: goldColor,
                child: pw.Text(
                  "TABLEAU PRINCIPAL (PLACES 1 À 4) >>",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Demi-finales
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "DEMI-FINALE 1 (Vainq. Q1 vs Q2)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: demi0?.court != null ? "Terrain ${demi0!.court}" : "T1",
                            p1: demi0?.pair1,
                            p2: demi0?.pair2,
                            p1Placeholder: "Vainqueur Quart 1",
                            p2Placeholder: "Vainqueur Quart 2",
                          ),
                          _buildMatchBox(
                            label: "DEMI-FINALE 2 (Vainq. Q3 vs Q4)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: demi1?.court != null ? "Terrain ${demi1!.court}" : "T2",
                            p1: demi1?.pair1,
                            p2: demi1?.pair2,
                            p1Placeholder: "Vainqueur Quart 3",
                            p2Placeholder: "Vainqueur Quart 4",
                          ),
                        ],
                      ),
                    ),
                    _buildConnectorColumn(forkCount: 2, pointingRight: true, color: borderColor),
                    // Finales
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(
                            label: "GRANDE FINALE (PLACES 1-2)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            isFinal: true,
                            courtBadge: finale?.court != null ? "Terrain ${finale!.court}" : "T1",
                            p1: finale?.pair1,
                            p2: finale?.pair2,
                            p1Placeholder: "Vainqueur Demi 1",
                            p2Placeholder: "Vainqueur Demi 2",
                          ),
                          _buildMatchBox(
                            label: "PETITE FINALE (PLACES 3-4)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: petiteFinale?.court != null ? "Terrain ${petiteFinale!.court}" : "T2",
                            p1: petiteFinale?.pair1,
                            p2: petiteFinale?.pair2,
                            p1Placeholder: "Perdant Demi 1",
                            p2Placeholder: "Perdant Demi 2",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Grille officielle des Poules & Phase Finale (Afficheur Club Paysage)
  static pw.Widget _buildPoolsPosterContent({
    required TournamentBracket bracket,
    required PdfColor navyColor,
    required PdfColor goldColor,
    required PdfColor borderColor,
    required PdfColor lightGray,
    required PdfColor darkGray,
    int numberOfCourts = 4,
  }) {
    final poolA = bracket.pools.firstWhere(
      (p) => p.id == "poule_a",
      orElse: () => bracket.pools.first,
    );
    final poolB = bracket.pools.length > 1
        ? bracket.pools.firstWhere(
            (p) => p.id == "poule_b",
            orElse: () => bracket.pools[1],
          )
        : null;

    final poolAStandings = poolA.calculateStandings();
    final poolBStandings = poolB?.calculateStandings() ?? [];

    final demi0 = bracket.mainMatches.where((m) => m.roundIndex == 0 && m.matchIndex == 0).firstOrNull;
    final demi1 = bracket.mainMatches.where((m) => m.roundIndex == 0 && m.matchIndex == 1).firstOrNull;
    final finale = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 0).firstOrNull;
    final petiteFinale = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 1).firstOrNull;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // POULE A
        pw.Expanded(
          flex: 4,
          child: _buildSinglePoolPosterCard(
            pool: poolA,
            standings: poolAStandings,
            navyColor: navyColor,
            accentColor: goldColor,
            isPoolA: true,
            numberOfCourts: numberOfCourts,
          ),
        ),
        pw.SizedBox(width: 8),

        // POULE B
        pw.Expanded(
          flex: 4,
          child: poolB != null
              ? _buildSinglePoolPosterCard(
                  pool: poolB,
                  standings: poolBStandings,
                  navyColor: navyColor,
                  accentColor: const PdfColor.fromInt(0xFFEA580C),
                  isPoolA: false,
                  numberOfCourts: numberOfCourts,
                )
              : pw.Container(),
        ),
        pw.SizedBox(width: 8),

        // PHASE FINALE CROISÉE
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: goldColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  "PHASE FINALE CROISÉE",
                  style: pw.TextStyle(color: navyColor, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildMatchBox(
                      label: "DEMI-FINALE 1 (1er A vs 2e B)",
                      navyColor: navyColor,
                      goldColor: goldColor,
                      courtBadge: demi0?.court != null ? "Terrain ${demi0!.court}" : "T1",
                      p1: demi0?.pair1 ?? (poolAStandings.isNotEmpty ? poolAStandings.first.pair : null),
                      p2: demi0?.pair2 ?? (poolBStandings.length > 1 ? poolBStandings[1].pair : null),
                      p1Placeholder: "1er Poule A",
                      p2Placeholder: "2e Poule B",
                      p1Subtext: poolAStandings.isNotEmpty ? "1er Poule A" : null,
                      p2Subtext: poolBStandings.length > 1 ? "2e Poule B" : null,
                    ),
                    _buildMatchBox(
                      label: "DEMI-FINALE 2 (1er B vs 2e A)",
                      navyColor: navyColor,
                      goldColor: goldColor,
                      courtBadge: demi1?.court != null ? "Terrain ${demi1!.court}" : "T2",
                      p1: demi1?.pair1 ?? (poolBStandings.isNotEmpty ? poolBStandings.first.pair : null),
                      p2: demi1?.pair2 ?? (poolAStandings.length > 1 ? poolAStandings[1].pair : null),
                      p1Placeholder: "1er Poule B",
                      p2Placeholder: "2e Poule A",
                      p1Subtext: poolBStandings.isNotEmpty ? "1er Poule B" : null,
                      p2Subtext: poolAStandings.length > 1 ? "2e Poule A" : null,
                    ),
                    _buildMatchBox(
                      label: "GRANDE FINALE · TITRE (1-2)",
                      navyColor: navyColor,
                      goldColor: goldColor,
                      isFinal: true,
                      courtBadge: finale?.court != null ? "Terrain ${finale!.court}" : "T1",
                      p1: finale?.pair1,
                      p2: finale?.pair2,
                      p1Placeholder: "Vainqueur Demi 1",
                      p2Placeholder: "Vainqueur Demi 2",
                    ),
                    _buildMatchBox(
                      label: "PETITE FINALE (3-4)",
                      navyColor: navyColor,
                      goldColor: goldColor,
                      courtBadge: petiteFinale?.court != null ? "Terrain ${petiteFinale!.court}" : "T2",
                      p1: petiteFinale?.pair1,
                      p2: petiteFinale?.pair2,
                      p1Placeholder: "Perdant Demi 1",
                      p2Placeholder: "Perdant Demi 2",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Carte d'une poule avec classement et liste ordonnée des matches
  static pw.Widget _buildSinglePoolPosterCard({
    required TournamentPool pool,
    required List<PoolStanding> standings,
    required PdfColor navyColor,
    required PdfColor accentColor,
    required bool isPoolA,
    int numberOfCourts = 4,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: accentColor, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            decoration: pw.BoxDecoration(
              color: accentColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  pool.name.toUpperCase(),
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  "${pool.pairs.length} Équipes · Top 2 qualifiés",
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 7),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(16),
              1: pw.FlexColumnWidth(5),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.5),
              5: pw.FlexColumnWidth(1.5),
              6: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                children: [
                  _th("#"),
                  _th("Équipe"),
                  _th("V"),
                  _th("D"),
                  _th("Sets"),
                  _th("+/-"),
                  _th("Pts"),
                ],
              ),
              for (int i = 0; i < standings.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i < 2 ? const PdfColor.fromInt(0xFFFEFCE8) : PdfColors.white,
                  ),
                  children: [
                    _td("${i + 1}"),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              standings[i].pair.displayName,
                              style: pw.TextStyle(
                                fontSize: 6.5,
                                fontWeight: i < 2 ? pw.FontWeight.bold : pw.FontWeight.normal,
                                color: navyColor,
                              ),
                              maxLines: 1,
                            ),
                          ),
                          if (standings[i].pair.seed != null)
                            pw.Container(
                              margin: const pw.EdgeInsets.only(left: 2),
                              padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                              decoration: pw.BoxDecoration(color: accentColor, borderRadius: pw.BorderRadius.circular(2)),
                              child: pw.Text("TS${standings[i].pair.seed}", style: const pw.TextStyle(fontSize: 5, color: PdfColors.white)),
                            ),
                        ],
                      ),
                    ),
                    _td("${standings[i].won}"),
                    _td("${standings[i].lost}"),
                    _td("${standings[i].setsWon}-${standings[i].setsLost}"),
                    _td(standings[i].diffGames >= 0 ? "+${standings[i].diffGames}" : "${standings[i].diffGames}"),
                    _td("${standings[i].points}", isBold: true),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            color: const PdfColor.fromInt(0xFFF1F5F9),
            child: pw.Text(
              "CALENDRIER DES MATCHES DE POULE",
              style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: navyColor),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Expanded(
            child: pw.Column(
              children: [
                for (int mIdx = 0; mIdx < pool.matches.length; mIdx++) ...[
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 2),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: pw.BoxDecoration(
                      color: pool.matches[mIdx].isCompleted ? const PdfColor.fromInt(0xFFF0FDF4) : PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(3),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.4),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: pw.BoxDecoration(
                            color: navyColor,
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                          child: pw.Text(
                            pool.matches[mIdx].court != null ? "Terrain ${pool.matches[mIdx].court}" : "T${(mIdx % numberOfCourts) + 1}",
                            style: const pw.TextStyle(fontSize: 5, color: PdfColors.white),
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Expanded(
                          child: pw.Text(
                            "${pool.matches[mIdx].pair1?.displayName ?? '?'} vs ${pool.matches[mIdx].pair2?.displayName ?? '?'}",
                            style: pw.TextStyle(
                              fontSize: 6,
                              fontWeight: pool.matches[mIdx].isCompleted ? pw.FontWeight.bold : pw.FontWeight.normal,
                              color: navyColor,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        if (pool.matches[mIdx].score != null && pool.matches[mIdx].score!.isNotEmpty)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFF16A34A),
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                            child: pw.Text(
                              pool.matches[mIdx].score!,
                              style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white),
                            ),
                          )
                        else
                          pw.Text(
                            "À jouer",
                            style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey500),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Connecteur vectoriel d'arbre (fourches reliant les confrontations pour suivre le sens des matchs)
  static pw.Widget _buildConnectorColumn({
    required int forkCount,
    required bool pointingRight,
    required PdfColor color,
  }) {
    return pw.Container(
      width: 7,
      child: pw.Column(
        children: [
          for (int i = 0; i < forkCount; i++)
            pw.Expanded(
              child: _buildSingleFork(pointingRight: pointingRight, color: color),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildSingleFork({
    required bool pointingRight,
    required PdfColor color,
  }) {
    return pw.Row(
      children: [
        if (pointingRight) ...[
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 2),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        right: pw.BorderSide(color: color, width: 0.8),
                        bottom: pw.BorderSide(color: color, width: 0.8),
                      ),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 2),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        right: pw.BorderSide(color: color, width: 0.8),
                        top: pw.BorderSide(color: color, width: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.Container(width: 3.5, height: 0.8, color: color),
        ] else ...[
          pw.Container(width: 3.5, height: 0.8, color: color),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 2),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: color, width: 0.8),
                        bottom: pw.BorderSide(color: color, width: 0.8),
                      ),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 2),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: color, width: 0.8),
                        top: pw.BorderSide(color: color, width: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Calcul et affiliation automatique du terrain selon le choix du JAT (3, 4, 5 ou 6 terrains)
  static String getCourtBadgeForMatch(int matchNumber, int numberOfCourts) {
    if (numberOfCourts < 1) numberOfCourts = 4;
    // Tour 1: Matchs 1 à 8
    if (matchNumber >= 1 && matchNumber <= 8) {
      int idx = matchNumber - 1;
      int court = (idx % numberOfCourts) + 1;
      return "T$court";
    }
    // Tour 2 (Quarts): Matchs 9 à 16
    final t2Order = [11, 12, 15, 16, 9, 10, 13, 14];
    int idxT2 = t2Order.indexOf(matchNumber);
    if (idxT2 != -1) {
      int court = (idxT2 % numberOfCourts) + 1;
      return "T$court";
    }
    // Tour 3 (Demies & Class. 13-16 / 5-8): Matchs 17 à 24
    final t3Order = [20, 24, 18, 22, 19, 23, 17, 21];
    int idxT3 = t3Order.indexOf(matchNumber);
    if (idxT3 != -1) {
      int court = (idxT3 % numberOfCourts) + 1;
      return "T$court";
    }
    // Tour 4 (Finales & Matchs de classement): Matchs 25 à 32
    final t4Order = [32, 30, 28, 26, 31, 29, 27, 25];
    int idxT4 = t4Order.indexOf(matchNumber);
    if (idxT4 != -1) {
      int court = (idxT4 % numberOfCourts) + 1;
      return "T$court";
    }
    return "T${((matchNumber - 1) % numberOfCourts) + 1}";
  }

  /// Boîte du 1er Tour (Centre) avec affichage clair des exemptions ou du match joué
  static pw.Widget _buildFirstRoundBox({
    required int matchNumber,
    required TournamentPair p1,
    required TournamentPair p2,
    required PdfColor navyColor,
    required PdfColor goldColor,
    String? courtBadge,
    int? targetQuartMatch,
    TournamentPair? targetSeed,
  }) {
    const darkGray = PdfColor.fromInt(0xFF334155);
    final hasBye = p1.isBye || p2.isBye;

    if (hasBye) {
      final exemptPair = p1.isBye ? p2 : p1;
      return pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 1.5),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFFEFCE8), // Teinte dorée subtile officielle FFT
          borderRadius: pw.BorderRadius.circular(3),
          border: pw.Border.all(color: goldColor, width: 0.9),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // En-tête exemption
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 3),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFFEF3C7),
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(2),
                  topRight: pw.Radius.circular(2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "MATCH $matchNumber · EXEMPT T1",
                    style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: navyColor),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                    decoration: pw.BoxDecoration(color: goldColor, borderRadius: pw.BorderRadius.circular(2)),
                    child: pw.Text(
                      "QUALIFIÉ DIRECT T2",
                      style: pw.TextStyle(fontSize: 4.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
                ],
              ),
            ),
            // Nom de la Tête de Série
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      exemptPair.displayName,
                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                      maxLines: 1,
                    ),
                  ),
                  if (exemptPair.seed != null)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: pw.BoxDecoration(color: goldColor, borderRadius: pw.BorderRadius.circular(2)),
                      child: pw.Text("TS${exemptPair.seed}", style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white)),
                    ),
                ],
              ),
            ),
            // Indication de destination Quarts
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              color: const PdfColor.fromInt(0xFFF1F5F9),
              child: pw.Text(
                "★ Avance en Quarts de finale (Quart ${targetQuartMatch ?? 1})",
                style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: darkGray),
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }

    // Match normal joué sur le terrain
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 1.5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: navyColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Ligne Paire 1
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    p1.displayName,
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: p1.seed != null ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: navyColor,
                    ),
                    maxLines: 1,
                  ),
                ),
                if (p1.seed != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                    decoration: pw.BoxDecoration(color: goldColor, borderRadius: pw.BorderRadius.circular(2)),
                    child: pw.Text("TS${p1.seed}", style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white)),
                  ),
              ],
            ),
          ),
          // Séparateur MATCH X avec badge terrain
          pw.Container(
            color: const PdfColor.fromInt(0xFFF1F5F9),
            padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 3),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "MATCH $matchNumber",
                  style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: darkGray),
                ),
                if (courtBadge != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                    decoration: pw.BoxDecoration(
                      color: navyColor,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      courtBadge,
                      style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
              ],
            ),
          ),
          // Ligne Paire 2
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    p2.displayName,
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: p2.seed != null ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: navyColor,
                    ),
                    maxLines: 1,
                  ),
                ),
                if (p2.seed != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                    decoration: pw.BoxDecoration(color: goldColor, borderRadius: pw.BorderRadius.circular(2)),
                    child: pw.Text("TS${p2.seed}", style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white)),
                  ),
              ],
            ),
          ),
          if (targetQuartMatch != null)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
              ),
              child: pw.Text(
                targetSeed != null
                    ? "➔ Vainq. vs TS${targetSeed.seed} (${targetSeed.displayName}) en Quarts"
                    : "➔ Vainq. qualifié au Quart $targetQuartMatch",
                style: const pw.TextStyle(fontSize: 4.8, color: PdfColor.fromInt(0xFF64748B)),
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }

  /// Boîte standard de match (Quarts, Demies, Finales, Consolantes) avec joueurs pré-remplis ou lignes pour stylo
  static pw.Widget _buildMatchBox({
    required String label,
    required PdfColor navyColor,
    required PdfColor goldColor,
    bool isFinal = false,
    String? courtBadge,
    TournamentPair? p1,
    TournamentPair? p2,
    String? p1Placeholder,
    String? p2Placeholder,
    String? p1Subtext,
    String? p2Subtext,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: pw.BoxDecoration(
        color: isFinal ? const PdfColor.fromInt(0xFFFEF9C3) : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(
          color: isFinal ? goldColor : navyColor,
          width: isFinal ? 1.2 : 0.6,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 3),
            color: isFinal ? goldColor : const PdfColor.fromInt(0xFFF1F5F9),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: 5.2,
                      fontWeight: pw.FontWeight.bold,
                      color: isFinal ? PdfColors.white : navyColor,
                    ),
                    maxLines: 1,
                  ),
                ),
                if (courtBadge != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                    decoration: pw.BoxDecoration(
                      color: isFinal ? navyColor : const PdfColor.fromInt(0xFF0F172A),
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      courtBadge,
                      style: pw.TextStyle(
                        fontSize: 4.8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: pw.Column(
              children: [
                // Ligne Paire 1
                if (p1 != null && !p1.isBye)
                  pw.Container(
                    height: 12,
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                p1.displayName,
                                style: pw.TextStyle(
                                  fontSize: 6,
                                  fontWeight: pw.FontWeight.bold,
                                  color: navyColor,
                                ),
                                maxLines: 1,
                              ),
                              if (p1Subtext != null)
                                pw.Text(
                                  p1Subtext,
                                  style: const pw.TextStyle(fontSize: 4.5, color: PdfColor.fromInt(0xFFB45309)),
                                  maxLines: 1,
                                ),
                            ],
                          ),
                        ),
                        if (p1.seed != null)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                            decoration: pw.BoxDecoration(color: goldColor, borderRadius: pw.BorderRadius.circular(2)),
                            child: pw.Text("TS${p1.seed}", style: const pw.TextStyle(fontSize: 5, color: PdfColors.white)),
                          ),
                      ],
                    ),
                  )
                else
                  pw.Container(
                    height: 12,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                    ),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      p1Placeholder ?? '',
                      style: pw.TextStyle(fontSize: 5, color: const PdfColor.fromInt(0xFF94A3B8), fontStyle: pw.FontStyle.italic),
                      maxLines: 1,
                    ),
                  ),
                pw.SizedBox(height: 1),
                // Ligne Paire 2
                if (p2 != null && !p2.isBye)
                  pw.Container(
                    height: 12,
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                p2.displayName,
                                style: pw.TextStyle(
                                  fontSize: 6,
                                  fontWeight: pw.FontWeight.bold,
                                  color: navyColor,
                                ),
                                maxLines: 1,
                              ),
                              if (p2Subtext != null)
                                pw.Text(
                                  p2Subtext,
                                  style: const pw.TextStyle(fontSize: 4.5, color: PdfColor.fromInt(0xFFB45309)),
                                  maxLines: 1,
                                ),
                            ],
                          ),
                        ),
                        if (p2.seed != null)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                            decoration: pw.BoxDecoration(color: goldColor, borderRadius: pw.BorderRadius.circular(2)),
                            child: pw.Text("TS${p2.seed}", style: const pw.TextStyle(fontSize: 5, color: PdfColors.white)),
                          ),
                      ],
                    ),
                  )
                else
                  pw.Container(
                    height: 12,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                    ),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      p2Placeholder ?? '',
                      style: pw.TextStyle(fontSize: 5, color: const PdfColor.fromInt(0xFF94A3B8), fontStyle: pw.FontStyle.italic),
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Génère et lance l'impression / partage du Tableau Papillon
  static Future<void> generateAndExportButterflyPosterPdf({
    required TournamentModel tournament,
    required TournamentBracket bracket,
    Uint8List? clubLogoBytes,
    String? customRules,
    bool isA3 = false,
    int numberOfCourts = 4,
  }) async {
    final pdfBytes = await buildButterflyPosterPdfBytes(
      tournament: tournament,
      bracket: bracket,
      clubLogoBytes: clubLogoBytes,
      customRules: customRules,
      isA3: isA3,
      numberOfCourts: numberOfCourts,
    );

    final isPools = bracket.pools.isNotEmpty || bracket.format == 'pools_and_bracket' || bracket.format == 'single_pool';
    final cleanCategory = bracket.category.replaceAll('double_', '').toUpperCase();
    final filename = isPools
        ? 'Tableau_Poules_${tournament.name.replaceAll(' ', '_')}_$cleanCategory.pdf'
        : 'Tableau_Papillon_${tournament.name.replaceAll(' ', '_')}_$cleanCategory.pdf';
    await exportOrDownloadPdf(bytes: pdfBytes, filename: filename);
  }
}
