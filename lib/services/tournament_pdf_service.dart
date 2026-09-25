import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
    final categoryLabel = bracket.category == 'double_messieurs'
        ? 'Double Messieurs'
        : (bracket.category == 'double_dames' ? 'Double Dames' : 'Double Mixtes');

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

    // Déclenche l'aperçu, l'impression ou le téléchargement PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'FFT_Resultats_${tournament.id}_${bracket.category}.pdf',
    );
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
                "Lieu : Plages du Mourillon, Toulon",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                "Date : 27/09/2026",
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

    final winner = finalMatch?.winner;
    final runnerUp = finalMatch?.loser;
    final third = p34Match?.winner;

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
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(names, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
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

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E293B)),
      ),
    );
  }

  static pw.Widget _td(String text, {bool alignLeft = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
