import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tournament.dart';
import '../models/tournament_bracket_model.dart';

class TournamentPdfService {
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

    if (kIsWeb) {
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename,
        );
        return;
      } catch (_) {}

      try {
        final dataUri = Uri.dataFromBytes(bytes, mimeType: 'application/pdf');
        await launchUrl(dataUri, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        debugPrint("PDF fallback error: $e");
      }
    } else {
      try {
        final shared = await Printing.sharePdf(bytes: bytes, filename: filename);
        if (shared) return;
      } catch (_) {}

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename,
        );
        return;
      } catch (_) {}
    }
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

    if (kIsWeb) {
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename,
        );
        return;
      } catch (_) {}

      try {
        final dataUri = Uri.dataFromBytes(bytes, mimeType: 'application/pdf');
        await launchUrl(dataUri, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        debugPrint("PDF fallback error: $e");
      }
    } else {
      try {
        final shared = await Printing.sharePdf(bytes: bytes, filename: filename);
        if (shared) return;
      } catch (_) {}

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename,
        );
        return;
      } catch (_) {}
    }
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

    if (kIsWeb) {
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename,
        );
        return;
      } catch (_) {}

      try {
        final dataUri = Uri.dataFromBytes(bytes, mimeType: 'application/pdf');
        await launchUrl(dataUri, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        debugPrint("PDF fallback error: $e");
      }
    } else {
      try {
        final shared = await Printing.sharePdf(bytes: bytes, filename: filename);
        if (shared) return;
      } catch (_) {}

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: filename,
        );
        return;
      } catch (_) {}
    }
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

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Rotations_Terrains_${tournament.name.replaceAll(' ', '_')}.pdf',
    );
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
  }) async {
    final pdf = pw.Document();

    final pageFormat = isA3 ? PdfPageFormat.a3.landscape : PdfPageFormat.a4.landscape;

    // Palette officielle
    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFB8860B);
    const darkGray = PdfColor.fromInt(0xFF334155);
    const lightGray = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFF1E293B);

    // Extraction des 16 paires (ou 8 paires) pour le 1er tour
    List<TournamentPair> startingPairs = [];
    if (bracket.mainMatches.isNotEmpty) {
      final r0Matches = bracket.mainMatches.where((m) => m.roundIndex == 0).toList();
      r0Matches.sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
      for (final m in r0Matches) {
        startingPairs.add(m.pair1 ?? const TournamentPair(id: 'bye', player1Name: 'À déterminer', player2Name: ''));
        startingPairs.add(m.pair2 ?? const TournamentPair(id: 'bye', player1Name: 'À déterminer', player2Name: ''));
      }
    } else if (bracket.pairs.isNotEmpty) {
      startingPairs = List<TournamentPair>.from(bracket.pairs);
    }

    // Compléter jusqu'à 16 ou 8 avec des BYE si nécessaire
    final targetSize = startingPairs.length <= 8 ? 8 : 16;
    while (startingPairs.length < targetSize) {
      final byeIdx = startingPairs.length + 1;
      startingPairs.add(TournamentPair(
        id: 'bye_$byeIdx',
        player1Name: 'EXEMPT',
        player2Name: 'BYE #$byeIdx',
        isBye: true,
      ));
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
                            "FORMAT DES MATCHES",
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
                        data: 'https://beachmatch.app/tournaments/${tournament.id}',
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

  /// Grille papillon complète vectorielle (16 ou 8 paires)
  static pw.Widget _buildButterflyGrid({
    required List<TournamentPair> startingPairs,
    required TournamentBracket bracket,
    required PdfColor navyColor,
    required PdfColor goldColor,
    required PdfColor borderColor,
    required PdfColor lightGray,
  }) {
    // 8 matches au 1er tour
    final int matchCount = startingPairs.length ~/ 2;

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
                  "◄── TABLEAU CONSOLANTE (PLACES 9 À 16)",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Finales Consolante (Places 9-10 & 11-12)
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(label: "MATCH 31 · PLACES 9-10", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 29 · PLACES 11-12", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 27 · PLACES 13-14", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 25 · PLACES 15-16", navyColor: navyColor, goldColor: goldColor),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    // Demies Consolante
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(label: "MATCH 18 · DEMIE CONSO", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 22 · DEMIE CONSO", navyColor: navyColor, goldColor: goldColor),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    // Quarts Consolante (issus des perdants T1)
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(label: "MATCH 9 (Perd. 4 vs 1)", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 10 (Perd. 3 vs 2)", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 13 (Perd. 5 vs 7)", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 14 (Perd. 6 vs 8)", navyColor: navyColor, goldColor: goldColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 6),

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
                    for (int i = 0; i < matchCount; i++) ...[
                      _buildFirstRoundBox(
                        matchNumber: _getMatchNumberForIndex(i),
                        p1: startingPairs[i * 2],
                        p2: startingPairs[i * 2 + 1],
                        navyColor: navyColor,
                        goldColor: goldColor,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 6),

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
                  "TABLEAU PRINCIPAL (PLACES 1 À 8) ──►",
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Quarts de finale (issus des vainqueurs T1)
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(label: "MATCH 11 (Vainq. 4 vs 1)", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 12 (Vainq. 3 vs 2)", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 15 (Vainq. 5 vs 7)", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 16 (Vainq. 6 vs 8)", navyColor: navyColor, goldColor: goldColor),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    // Demi-finales
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(label: "MATCH 20 · DEMI-FINALE 1", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 24 · DEMI-FINALE 2", navyColor: navyColor, goldColor: goldColor),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    // Finales (Places 1-2 & 3-4 & 5-6 & 7-8)
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox(label: "MATCH 32 · GRANDE FINALE (1-2)", navyColor: navyColor, goldColor: goldColor, isFinal: true),
                          _buildMatchBox(label: "MATCH 30 · PETITE FINALE (3-4)", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 28 · PLACES 5-6", navyColor: navyColor, goldColor: goldColor),
                          _buildMatchBox(label: "MATCH 26 · PLACES 7-8", navyColor: navyColor, goldColor: goldColor),
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

  /// Numérotation officielle des matches du 1er tour selon le standard FFT de Narbonne
  static int _getMatchNumberForIndex(int idx) {
    const mapping = [4, 1, 3, 2, 5, 7, 6, 8];
    if (idx < mapping.length) return mapping[idx];
    return idx + 1;
  }

  /// Boîte du 1er Tour (Centre)
  static pw.Widget _buildFirstRoundBox({
    required int matchNumber,
    required TournamentPair p1,
    required TournamentPair p2,
    required PdfColor navyColor,
    required PdfColor goldColor,
  }) {
    const darkGray = PdfColor.fromInt(0xFF334155);
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 2),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: navyColor, width: 0.8),
      ),
      child: pw.Column(
        children: [
          // Ligne Paire 1
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    p1.displayName,
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: p1.seed != null ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: p1.isBye ? PdfColors.grey500 : navyColor,
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
          // Séparateur MATCH X
          pw.Container(
            color: const PdfColor.fromInt(0xFFF1F5F9),
            padding: const pw.EdgeInsets.symmetric(vertical: 1),
            child: pw.Center(
              child: pw.Text(
                "MATCH $matchNumber",
                style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: darkGray),
              ),
            ),
          ),
          // Ligne Paire 2
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    p2.displayName,
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: p2.seed != null ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: p2.isBye ? PdfColors.grey500 : navyColor,
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
        ],
      ),
    );
  }

  /// Boîte standard de match (Quarts, Demies, Finales, Consolantes) avec lignes pour stylo
  static pw.Widget _buildMatchBox({
    required String label,
    required PdfColor navyColor,
    required PdfColor goldColor,
    bool isFinal = false,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: pw.BoxDecoration(
        color: isFinal ? const PdfColor.fromInt(0xFFFEF9C3) : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(
          color: isFinal ? goldColor : navyColor,
          width: isFinal ? 1.2 : 0.6,
        ),
      ),
      child: pw.Column(
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
                      fontSize: 5.5,
                      fontWeight: pw.FontWeight.bold,
                      color: isFinal ? PdfColors.white : navyColor,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Column(
              children: [
                // Ligne 1 pour stylo
                pw.Container(
                  height: 10,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                ),
                pw.SizedBox(height: 3),
                // Ligne 2 pour stylo
                pw.Container(
                  height: 10,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
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
  }) async {
    final pdfBytes = await buildButterflyPosterPdfBytes(
      tournament: tournament,
      bracket: bracket,
      clubLogoBytes: clubLogoBytes,
      customRules: customRules,
      isA3: isA3,
    );

    final cleanCategory = bracket.category.replaceAll('double_', '').toUpperCase();
    final filename = 'Tableau_Papillon_${tournament.name.replaceAll(' ', '_')}_$cleanCategory.pdf';

    if (kIsWeb) {
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: filename,
        );
        return;
      } catch (_) {}

      try {
        final dataUri = Uri.dataFromBytes(pdfBytes, mimeType: 'application/pdf');
        await launchUrl(dataUri, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        debugPrint("PDF fallback error: $e");
      }
    } else {
      try {
        final shared = await Printing.sharePdf(bytes: pdfBytes, filename: filename);
        if (shared) return;
      } catch (_) {}

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: filename,
        );
        return;
      } catch (_) {}
    }
  }
}
