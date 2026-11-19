import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/tournament.dart';
import '../models/tournament_bracket_model.dart';
import 'bracket_generator_service.dart';
import 'web_file_downloader.dart';

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

  /// Génère et ouvre la boîte de dialogue d'impression / export PDF officiel FFT
  static Future<void> generateAndExportPdf({
    required TournamentModel tournament,
    required TournamentBracket bracket,
  }) async {
    final pdf = pw.Document();

    final isPoolFormat = bracket.format == 'pools_and_bracket';
    final categoryLabel = bracket.category == 'double_messieurs' || bracket.category == 'DH'
        ? 'DH'
        : (bracket.category == 'double_dames' || bracket.category == 'DD' ? 'DD' : 'DX');

    // Couleurs officielles
    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFB8860B);
    const darkGray = PdfColor.fromInt(0xFF334155);
    const lightGray = PdfColor.fromInt(0xFFF1F5F9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(tournament, categoryLabel, navyColor, goldColor),
        footer: (context) => _buildFooter(context, darkGray),
        build: (context) => [
          pw.SizedBox(height: 12),

          // 1. Synthèse Palmarès Officiel si matches finis
          _buildPodiumSummary(bracket, navyColor, goldColor),
          pw.SizedBox(height: 14),

          // 2. Si Poules : Tableaux des Poules A & B
          if (isPoolFormat) ...[
            for (final pool in bracket.pools) ...[
              _buildPoolSection(pool, navyColor, lightGray),
              pw.SizedBox(height: 12),
            ],
            // Phase finale
            _buildFinalPhaseSection(bracket, navyColor, lightGray),
          ] else ...[
            // Élimination directe
            _buildEliminationSection(bracket, navyColor, lightGray),
          ],

          pw.SizedBox(height: 18),
          // 3. Cadre d'homologation JAT
          _buildJatSignatureBox(navyColor, darkGray),
        ],
      ),
    );

    final bytes = await pdf.save();
    final filename = 'FFT_Resultats_${tournament.id}_${bracket.category}.pdf';
    await exportOrDownloadPdf(bytes: bytes, filename: filename);
  }

  /// Génère le Dossier Officiel Homologué A4 Paysage (Widescreen Landscape)
  static Future<void> generateAndExportLandscapePdf({
    required TournamentModel tournament,
    required TournamentBracket bracket,
  }) async {
    final pdf = pw.Document();

    final isPoolFormat = bracket.format == 'pools_and_bracket';
    final categoryLabel = bracket.category == 'double_messieurs' || bracket.category == 'DH'
        ? 'DH'
        : (bracket.category == 'double_dames' || bracket.category == 'DD' ? 'DD' : 'DX');

    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFB8860B);
    const darkGray = PdfColor.fromInt(0xFF334155);
    const lightGray = PdfColor.fromInt(0xFFF1F5F9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _buildHeader(tournament, "$categoryLabel (Homologation Paysage)", navyColor, goldColor),
        footer: (context) => _buildFooter(context, darkGray),
        build: (context) => [
          pw.SizedBox(height: 8),
          _buildPodiumSummary(bracket, navyColor, goldColor),
          pw.SizedBox(height: 12),
          if (isPoolFormat) ...[
            for (final pool in bracket.pools) ...[
              _buildPoolSection(pool, navyColor, lightGray),
              pw.SizedBox(height: 10),
            ],
            _buildFinalPhaseSection(bracket, navyColor, lightGray),
          ] else ...[
            _buildEliminationSection(bracket, navyColor, lightGray),
          ],
          pw.SizedBox(height: 14),
          _buildJatSignatureBox(navyColor, darkGray),
        ],
      ),
    );

    final bytes = await pdf.save();
    final filename = 'FFT_Dossier_Paysage_${tournament.id}_${bracket.category}.pdf';
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
        final scoreStr = m.isCompleted ? (m.score ?? 'Terminé') : 'À venir';
        if (m.isCompleted && m.winner != null) {
          buf.writeln("• ${m.roundName} : ${m.winner!.displayName} bat ${m.loser?.displayName ?? 'Adversaire'} ($scoreStr)");
        } else {
          buf.writeln("• ${m.roundName} : ${m.pair1?.displayName ?? 'TBD'} vs ${m.pair2?.displayName ?? 'TBD'} ($scoreStr)");
        }
      }
    } else {
      buf.writeln("⚔️ TABLEAU PRINCIPAL :");
      for (final m in bracket.mainMatches) {
        final scoreStr = m.isCompleted ? (m.score ?? 'Terminé') : (m.isBye ? 'BYE' : 'À venir');
        if (m.isCompleted && m.winner != null) {
          buf.writeln("• ${m.roundName} : ${m.winner!.displayName} bat ${m.loser?.displayName ?? 'Adversaire'} ($scoreStr)");
        } else {
          buf.writeln("• ${m.roundName} : ${m.pair1?.displayName ?? 'TBD'} vs ${m.pair2?.displayName ?? 'TBD'} ($scoreStr)");
        }
      }
      if (bracket.consolationMatches.isNotEmpty) {
        buf.writeln("\n🛡️ TABLEAU DE CONSOLANTE :");
        for (final m in bracket.consolationMatches) {
          final scoreStr = m.isCompleted ? (m.score ?? 'Terminé') : 'À venir';
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

  static pw.Widget _buildHeader(
    TournamentModel tournament,
    String categoryLabel,
    PdfColor navyColor,
    PdfColor goldColor,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "FÉDÉRATION FRANÇAISE DE TENNIS",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: darkGrayPdf,
                ),
              ),
              pw.Text(
                "FEUILLE OFFICIELLE DE RÉSULTATS · BEACH TENNIS",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: navyColor,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                "${tournament.name} · Épreuve : $categoryLabel",
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

  static pw.Widget _buildPodiumSummary(
    TournamentBracket bracket,
    PdfColor navyColor,
    PdfColor goldColor,
  ) {
    final (winner, runnerUp, third) = resolvePalmares(bracket);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPodiumItem("1er (Vainqueurs)", winner?.displayName ?? "En cours...", goldColor, true),
          _buildPodiumItem("2e (Finalistes)", runnerUp?.displayName ?? "En cours...", navyColor, false),
          _buildPodiumItem("3e Place", third?.displayName ?? "En cours...", darkGrayPdf, false),
        ],
      ),
    );
  }

  static pw.Widget _buildPodiumItem(String label, String names, PdfColor color, bool isBold) {
    return pw.Column(
      children: [
        pw.Text(cleanText(label), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(cleanText(names), style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
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

  static pw.Widget _buildJatSignatureBox(PdfColor navyColor, PdfColor darkGray) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Visa du Juge-Arbitre (JAT) :", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text("Tournoi clôturé et homologué sous contrôle FFT.", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text("Télétransmission des résultats effectuée à la ligue.", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
          pw.Container(
            width: 140,
            height: 40,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
            ),
            child: pw.Center(
              child: pw.Text("Signature & Cachet JAT", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ),
          ),
        ],
      ),
    );
  }

  static String cleanText(String text) {
    return text
        .replaceAll('🏆', '')
        .replaceAll('🥇', '[1er]')
        .replaceAll('🥈', '[2e]')
        .replaceAll('🥉', '[3e]')
        .replaceAll('⚔️', '')
        .replaceAll('📊', '')
        .replaceAll('🛡️', '')
        .replaceAll('🏖️', '')
        .replaceAll('🔥', '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
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

    // 2. Extraction des 16 paires pour les 8 cases du 1er tour papillon
    List<TournamentPair> startingPairs = [];
    final r0Matches = bracket.mainMatches.where((m) => m.roundIndex == 0).toList();
    r0Matches.sort((a, b) => a.matchIndex.compareTo(b.matchIndex));

    if (r0Matches.length == 8) {
      // 8 matches de 1er tour déjà formés
      for (final m in r0Matches) {
        startingPairs.add(m.pair1 ?? const TournamentPair(id: 'bye', player1Name: 'EXEMPT', player2Name: 'BYE', isBye: true));
        startingPairs.add(m.pair2 ?? const TournamentPair(id: 'bye', player1Name: 'EXEMPT', player2Name: 'BYE', isBye: true));
      }
    } else {
      // Construction automatique d'une grille officielle FFT 16 avec répartition des graines et BYEs
      final seeded = BracketGeneratorService.assignSeeds(allRealPairs);
      final seedMap = <int, TournamentPair>{};
      final unseeded = <TournamentPair>[];
      for (final p in seeded) {
        if (p.seed != null) {
          seedMap[p.seed!] = p;
        } else {
          unseeded.add(p);
        }
      }

      final slots = List<TournamentPair?>.filled(16, null);
      if (allRealPairs.length <= 12) {
        // Formule FFT standard pour tableau 12 équipes avec 4 BYE (TS1, TS2, TS3, TS4)
        if (seedMap.containsKey(2)) slots[0] = seedMap[2];
        slots[1] = const TournamentPair(id: "bye_ts2", player1Name: "EXEMPT", player2Name: "BYE", isBye: true);

        final remainingSlots = [2, 3, 4, 5, 10, 11, 12, 13];
        for (int i = 0; i < remainingSlots.length; i++) {
          if (i < unseeded.length) {
            slots[remainingSlots[i]] = unseeded[i];
          } else {
            slots[remainingSlots[i]] = TournamentPair(
              id: "bye_${i + 5}",
              player1Name: "EXEMPT",
              player2Name: "BYE #${i + 5}",
              isBye: true,
            );
          }
        }

        slots[6] = const TournamentPair(id: "bye_ts3", player1Name: "EXEMPT", player2Name: "BYE", isBye: true);
        if (seedMap.containsKey(3)) slots[7] = seedMap[3];

        if (seedMap.containsKey(4)) slots[8] = seedMap[4];
        slots[9] = const TournamentPair(id: "bye_ts4", player1Name: "EXEMPT", player2Name: "BYE", isBye: true);

        slots[14] = const TournamentPair(id: "bye_ts1", player1Name: "EXEMPT", player2Name: "BYE", isBye: true);
        if (seedMap.containsKey(1)) slots[15] = seedMap[1];
      } else {
        if (seedMap.containsKey(2)) slots[0] = seedMap[2];
        if (seedMap.containsKey(1)) slots[15] = seedMap[1];
        if (seedMap.containsKey(4)) slots[7] = seedMap[4];
        if (seedMap.containsKey(3)) slots[8] = seedMap[3];

        int unseededIdx = 0;
        int byeIdx = 1;
        for (int s = 0; s < 16; s++) {
          if (slots[s] == null) {
            if (unseededIdx < unseeded.length) {
              slots[s] = unseeded[unseededIdx++];
            } else {
              slots[s] = TournamentPair(
                id: "bye_$byeIdx",
                player1Name: "EXEMPT",
                player2Name: "BYE #$byeIdx",
                isBye: true,
              );
              byeIdx++;
            }
          }
        }
      }

      for (int s = 0; s < 16; s++) {
        startingPairs.add(slots[s] ?? TournamentPair(id: "bye_$s", player1Name: "EXEMPT", player2Name: "BYE", isBye: true));
      }
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
                            cleanText("${tournament.name.toUpperCase()} · $categoryLabel"),
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: navyColor),
                          ),
                          pw.Text(
                            "Tableau Officiel à Classement Intégral · JAT : ${cleanText(tournament.referee ?? 'Juge-Arbitre Référent')}",
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

              // 2. CORPS DU TABLEAU PAPILLON (CONSOLANTE ◄── DÉPART AU CENTRE ──► PRINCIPAL)
              pw.Expanded(
                child: _buildButterflyGrid(
                  startingPairs: startingPairs,
                  bracket: bracket,
                  navyColor: navyColor,
                  goldColor: goldColor,
                  borderColor: borderColor,
                  lightGray: lightGray,
                  numberOfCourts: numberOfCourts,
                ),
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
    required List<TournamentPair> startingPairs,
    required TournamentBracket bracket,
    required PdfColor navyColor,
    required PdfColor goldColor,
    required PdfColor borderColor,
    required PdfColor lightGray,
    int numberOfCourts = 4,
  }) {
    // Map des têtes de série du tableau
    final seedMap = <int, TournamentPair>{};
    for (final p in startingPairs) {
      if (p.seed != null && !p.isBye) {
        seedMap[p.seed!] = p;
      }
    }

    // Récupération des matches de Quarts de finale réels s'ils existent
    final quart0 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 0).firstOrNull;
    final quart1 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 1).firstOrNull;
    final quart2 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 2).firstOrNull;
    final quart3 = bracket.mainMatches.where((m) => m.roundIndex == 1 && m.matchIndex == 3).firstOrNull;

    // Récupération des Demi-finales et Finale
    final demi0 = bracket.mainMatches.where((m) => m.roundIndex == 2 && m.matchIndex == 0).firstOrNull;
    final demi1 = bracket.mainMatches.where((m) => m.roundIndex == 2 && m.matchIndex == 1).firstOrNull;
    final finale = bracket.mainMatches.where((m) => m.roundIndex == 3 && m.matchIndex == 0).firstOrNull;

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
                            label: "MATCH 9 (Perd. 4 vs 1)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(9, numberOfCourts),
                            p1Placeholder: "Perdant Match 4 (Exempt)",
                            p2Placeholder: "Perdant Match 1",
                          ),
                          _buildMatchBox(
                            label: "MATCH 10 (Perd. 3 vs 2)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(10, numberOfCourts),
                            p1Placeholder: "Perdant Match 3",
                            p2Placeholder: "Perdant Match 2 (Exempt)",
                          ),
                          _buildMatchBox(
                            label: "MATCH 13 (Perd. 5 vs 7)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(13, numberOfCourts),
                            p1Placeholder: "Perdant Match 5 (Exempt)",
                            p2Placeholder: "Perdant Match 7",
                          ),
                          _buildMatchBox(
                            label: "MATCH 14 (Perd. 6 vs 8)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(14, numberOfCourts),
                            p1Placeholder: "Perdant Match 6",
                            p2Placeholder: "Perdant Match 8 (Exempt)",
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
                        matchNumber: _getMatchNumberForIndex(i),
                        p1: startingPairs[i * 2],
                        p2: startingPairs[i * 2 + 1],
                        navyColor: navyColor,
                        goldColor: goldColor,
                        courtBadge: getCourtBadgeForMatch(_getMatchNumberForIndex(i), numberOfCourts),
                        targetQuartMatch: _getTargetQuartForIndex(i),
                        targetSeed: _getTargetSeedForIndex(i, seedMap),
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
                            label: "MATCH 11 (Vainq. 4 vs 1)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(11, numberOfCourts),
                            p1: quart0?.pair1 ?? seedMap[2],
                            p2: quart0?.pair2,
                            p1Placeholder: "Vainqueur Match 4",
                            p2Placeholder: "Vainqueur Match 1",
                            p1Subtext: seedMap.containsKey(2) ? "Exempt T1 (TS2)" : null,
                          ),
                          _buildMatchBox(
                            label: "MATCH 12 (Vainq. 3 vs 2)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(12, numberOfCourts),
                            p1: quart1?.pair1,
                            p2: quart1?.pair2 ?? seedMap[3],
                            p1Placeholder: "Vainqueur Match 3",
                            p2Placeholder: "Vainqueur Match 2",
                            p2Subtext: seedMap.containsKey(3) ? "Exempt T1 (TS3)" : null,
                          ),
                          _buildMatchBox(
                            label: "MATCH 15 (Vainq. 5 vs 7)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(15, numberOfCourts),
                            p1: quart2?.pair1 ?? seedMap[4],
                            p2: quart2?.pair2,
                            p1Placeholder: "Vainqueur Match 5",
                            p2Placeholder: "Vainqueur Match 7",
                            p1Subtext: seedMap.containsKey(4) ? "Exempt T1 (TS4)" : null,
                          ),
                          _buildMatchBox(
                            label: "MATCH 16 (Vainq. 6 vs 8)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(16, numberOfCourts),
                            p1: quart3?.pair1,
                            p2: quart3?.pair2 ?? seedMap[1],
                            p1Placeholder: "Vainqueur Match 6",
                            p2Placeholder: "Vainqueur Match 8",
                            p2Subtext: seedMap.containsKey(1) ? "Exempt T1 (TS1)" : null,
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
                            courtBadge: getCourtBadgeForMatch(20, numberOfCourts),
                            p1: demi0?.pair1,
                            p2: demi0?.pair2,
                            p1Placeholder: "Vainqueur Match 11",
                            p2Placeholder: "Vainqueur Match 12",
                          ),
                          _buildMatchBox(
                            label: "MATCH 24 · DEMI-FINALE 2",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(24, numberOfCourts),
                            p1: demi1?.pair1,
                            p2: demi1?.pair2,
                            p1Placeholder: "Vainqueur Match 15",
                            p2Placeholder: "Vainqueur Match 16",
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
                            courtBadge: getCourtBadgeForMatch(32, numberOfCourts),
                            p1: finale?.pair1,
                            p2: finale?.pair2,
                            p1Placeholder: "Vainqueur Match 20",
                            p2Placeholder: "Vainqueur Match 24",
                          ),
                          _buildMatchBox(
                            label: "MATCH 30 · PETITE FINALE (3-4)",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(30, numberOfCourts),
                            p1Placeholder: "Perdant Match 20",
                            p2Placeholder: "Perdant Match 24",
                          ),
                          _buildMatchBox(
                            label: "MATCH 28 · PLACES 5-6",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(28, numberOfCourts),
                            p1Placeholder: "Vainqueur Match 21",
                            p2Placeholder: "Vainqueur Match 23",
                          ),
                          _buildMatchBox(
                            label: "MATCH 26 · PLACES 7-8",
                            navyColor: navyColor,
                            goldColor: goldColor,
                            courtBadge: getCourtBadgeForMatch(26, numberOfCourts),
                            p1Placeholder: "Perdant Match 21",
                            p2Placeholder: "Perdant Match 23",
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

  /// Calcul et affiliation automatique du terrain et de la rotation selon le choix du JAT (3, 4, 5 ou 6 terrains)
  static String getCourtBadgeForMatch(int matchNumber, int numberOfCourts) {
    if (numberOfCourts < 1) numberOfCourts = 4;
    // Tour 1: Matchs 1 à 8
    if (matchNumber >= 1 && matchNumber <= 8) {
      int idx = matchNumber - 1;
      int court = (idx % numberOfCourts) + 1;
      int rot = (idx ~/ numberOfCourts) + 1;
      return "T$court · R$rot";
    }
    // Tour 2 (Quarts): Matchs 9 à 16
    final t2Order = [11, 12, 15, 16, 9, 10, 13, 14];
    int idxT2 = t2Order.indexOf(matchNumber);
    if (idxT2 != -1) {
      int t1Rotations = (8 / numberOfCourts).ceil();
      int court = (idxT2 % numberOfCourts) + 1;
      int rot = t1Rotations + (idxT2 ~/ numberOfCourts) + 1;
      return "T$court · R$rot";
    }
    // Tour 3 (Demies & Class. 13-16 / 5-8): Matchs 17 à 24
    final t3Order = [20, 24, 18, 22, 19, 23, 17, 21];
    int idxT3 = t3Order.indexOf(matchNumber);
    if (idxT3 != -1) {
      int t1Rot = (8 / numberOfCourts).ceil();
      int t2Rot = (8 / numberOfCourts).ceil();
      int court = (idxT3 % numberOfCourts) + 1;
      int rot = t1Rot + t2Rot + (idxT3 ~/ numberOfCourts) + 1;
      return "T$court · R$rot";
    }
    // Tour 4 (Finales & Matchs de classement): Matchs 25 à 32
    final t4Order = [32, 30, 28, 26, 31, 29, 27, 25];
    int idxT4 = t4Order.indexOf(matchNumber);
    if (idxT4 != -1) {
      int t1Rot = (8 / numberOfCourts).ceil();
      int t2Rot = (8 / numberOfCourts).ceil();
      int t3Rot = (8 / numberOfCourts).ceil();
      int court = (idxT4 % numberOfCourts) + 1;
      int rot = t1Rot + t2Rot + t3Rot + (idxT4 ~/ numberOfCourts) + 1;
      return "T$court · R$rot";
    }
    return "T${((matchNumber - 1) % numberOfCourts) + 1}";
  }

  /// Numérotation officielle des matches du 1er tour selon le standard FFT de Narbonne
  static int _getMatchNumberForIndex(int idx) {
    const mapping = [4, 1, 3, 2, 5, 7, 6, 8];
    if (idx < mapping.length) return mapping[idx];
    return idx + 1;
  }

  /// Détermine le Quart de finale cible (Tableau Principal) pour chaque case du 1er tour
  static int _getTargetQuartForIndex(int idx) {
    switch (idx) {
      case 0: // Match 4 -> feeds Quart 11
      case 1: // Match 1 -> feeds Quart 11
        return 11;
      case 2: // Match 3 -> feeds Quart 12
      case 3: // Match 2 -> feeds Quart 12
        return 12;
      case 4: // Match 5 -> feeds Quart 15
      case 5: // Match 7 -> feeds Quart 15
        return 15;
      case 6: // Match 6 -> feeds Quart 16
      case 7: // Match 8 -> feeds Quart 16
      default:
        return 11;
    }
  }

  /// Détermine la Tête de Série affrontée par le vainqueur du match du 1er tour
  static TournamentPair? _getTargetSeedForIndex(int idx, Map<int, TournamentPair> seedMap) {
    switch (idx) {
      case 1: // Vainqueur Match 1 affronte TS2 au Match 11
        return seedMap[2];
      case 2: // Vainqueur Match 3 affronte TS3 au Match 12
        return seedMap[3];
      case 5: // Vainqueur Match 7 affronte TS4 au Match 15
        return seedMap[4];
      case 6: // Vainqueur Match 6 affronte TS1 au Match 16
        return seedMap[1];
      default:
        return null;
    }
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
                "★ Avance au Match ${targetQuartMatch ?? 11} (Quarts de finale)",
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
                    ? "➔ Vainq. vs TS${targetSeed.seed} (${targetSeed.displayName}) au M$targetQuartMatch"
                    : "➔ Vainq. qualifié au Match $targetQuartMatch (Quarts)",
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

    final cleanCategory = bracket.category.replaceAll('double_', '').toUpperCase();
    final filename = 'Tableau_Papillon_${tournament.name.replaceAll(' ', '_')}_$cleanCategory.pdf';
    await exportOrDownloadPdf(bytes: pdfBytes, filename: filename);
  }
}
