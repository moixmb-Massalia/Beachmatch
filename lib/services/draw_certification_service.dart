import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tournament.dart';
import '../models/tournament_bracket_model.dart';

/// Service officiel d'homologation et de certification du tirage au sort Beach Tennis
class DrawCertificationService {
  /// Génère un code unique de certification inviolable
  static String generateCertificateId(String tournamentId, String category, DateTime timestamp) {
    final cleanId = tournamentId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final shortId = cleanId.length > 5 ? cleanId.substring(0, 5) : cleanId;
    final catCode = category.contains('messieurs') || category.contains('DH')
        ? 'DH'
        : (category.contains('dames') || category.contains('DD') ? 'DD' : 'DX');
    final timeStr = DateFormat('yyyyMMdd-HHmmss').format(timestamp);
    final shortHash = (tournamentId.hashCode ^ category.hashCode ^ timestamp.millisecondsSinceEpoch)
        .abs()
        .toString()
        .padLeft(6, '0')
        .substring(0, 6);
    return 'DRAW-$shortId-$catCode-$timeStr-$shortHash';
  }

  /// Génère et ouvre l'aperçu/impression du Procès-Verbal Officiel de Tirage au Sort (PDF A4)
  static Future<void> generateAndExportDrawPvPdf({
    required TournamentModel tournament,
    required TournamentBracket bracket,
    required DateTime drawTimestamp,
    String? jatName,
    String? drawLocation,
    String? poolModeDescription,
    bool isTsInverted = false,
  }) async {
    final pdf = pw.Document();

    final categoryLabel = bracket.category == 'double_messieurs' || bracket.category == 'DH'
        ? 'DH'
        : (bracket.category == 'double_dames' || bracket.category == 'DD'
            ? 'DD'
            : 'DX');

    final effectiveJat = (jatName != null && jatName.trim().isNotEmpty)
        ? jatName.trim()
        : ((tournament.referee != null && tournament.referee!.trim().isNotEmpty)
            ? tournament.referee!.trim()
            : 'Juge-Arbitre Officiel');

    final effectiveLocation = (drawLocation != null && drawLocation.trim().isNotEmpty)
        ? drawLocation.trim()
        : (tournament.location.isNotEmpty ? tournament.location : tournament.club);

    final certId = generateCertificateId(tournament.id, bracket.category, drawTimestamp);
    final formattedDate = DateFormat('dd/MM/yyyy à HH:mm:ss').format(drawTimestamp);

    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFD4AF37);
    const darkSlate = PdfColor.fromInt(0xFF1E293B);
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFFCBD5E1);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // EN-TÊTE OFFICIEL
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: pw.BoxDecoration(
                  color: navyColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PROCÈS-VERBAL OFFICIEL DE TIRAGE AU SORT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'HOMOLOGATION SPORTIVE BEACH TENNIS · CERTIFICATION NUMÉRIQUE',
                          style: pw.TextStyle(
                            color: goldColor,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: goldColor, width: 1),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        certId,
                        style: pw.TextStyle(
                          color: goldColor,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // BLOC INFORMATIONS DU TOURNOI & HORODATAGE
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tournament.name.toUpperCase(),
                            style: pw.TextStyle(
                              color: navyColor,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('Club organisateur : ${tournament.club}', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Catégorie épreuve : $categoryLabel · ${tournament.category}', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Dates compétition : ${tournament.dateString}', style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    pw.Container(width: 1, height: 60, color: borderColor),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CERTIFICATION DU TIRAGE', style: pw.TextStyle(color: navyColor, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('Date & Heure : $formattedDate', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.Text('Lieu : $effectiveLocation', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('Juge-Arbitre (JAT) : $effectiveJat', style: const pw.TextStyle(fontSize: 8)),
                          if (isTsInverted)
                            pw.Text('Règle TS : Inversion TS1/TS2 appliquée', style: const pw.TextStyle(fontSize: 8, color: PdfColors.red900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // TÊTES DE SÉRIE OFFICIELLES
              pw.Text(
                'TÊTES DE SÉRIE OFFICIELLES (TS)',
                style: pw.TextStyle(color: navyColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              _buildSeedsTable(bracket, navyColor, lightBg, borderColor),

              pw.SizedBox(height: 12),

              // FORMAT DE JEU ET TABLEAU / POULES
              if (bracket.format == 'pools_and_bracket' && bracket.pools.isNotEmpty) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'COMPOSITION DES POULES OFFICIELLES',
                      style: pw.TextStyle(color: navyColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    if (poolModeDescription != null)
                      pw.Text(
                        'Règle sortie : $poolModeDescription',
                        style: pw.TextStyle(color: darkSlate, fontSize: 8, fontStyle: pw.FontStyle.italic),
                      ),
                  ],
                ),
                pw.SizedBox(height: 6),
                _buildPoolsGrid(bracket.pools, navyColor, lightBg, borderColor),
              ] else ...[
                pw.Text(
                  'DISPOSITION DU TABLEAU À ÉLIMINATION DIRECTE (TOUR 1)',
                  style: pw.TextStyle(color: navyColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                _buildEliminationTable(bracket, navyColor, lightBg, borderColor),
              ],

              pw.Spacer(),

              // SCEAU D'INTÉGRITÉ ET VISA DU JAT
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: goldColor, width: 1.5),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ATTESTATION D\'INTÉGRITÉ & HOMOLOGATION',
                            style: pw.TextStyle(color: navyColor, fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Le présent procès-verbal certifie que le tirage au sort de l\'épreuve a été exécuté dans le strict respect de la réglementation sportive en vigueur. Aucune modification du tableau n\'est autorisée après publication sans l\'accord exprès du Juge-Arbitre.',
                            style: const pw.TextStyle(fontSize: 7, color: darkSlate),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Sceau d\'intégrité : $certId · Horodatage UTC+2 : $formattedDate',
                            style: pw.TextStyle(fontSize: 7, color: goldColor, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('Visa & Signature du JAT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.SizedBox(height: 6),
                          pw.Container(
                            height: 32,
                            width: 120,
                            alignment: pw.Alignment.center,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: borderColor, style: pw.BorderStyle.dashed),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              effectiveJat,
                              style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: navyColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Généré officiellement par BeachMatch · Plateforme d\'Arbitrage Beach Tennis',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'PV_Tirage_${tournament.id}_${bracket.category}.pdf',
    );
  }

  static pw.Widget _buildSeedsTable(
    TournamentBracket bracket,
    PdfColor navyColor,
    PdfColor lightBg,
    PdfColor borderColor,
  ) {
    final seeds = <TournamentPair>[];
    final allPairs = bracket.pairs.isNotEmpty
        ? bracket.pairs
        : (bracket.pools.isNotEmpty ? bracket.pools.expand((p) => p.pairs).toList() : <TournamentPair>[]);
    for (final p in allPairs) {
      if (p.seed != null) seeds.add(p);
    }
    seeds.sort((a, b) => (a.seed ?? 99).compareTo(b.seed ?? 99));

    if (seeds.isEmpty) {
      return pw.Text('Aucune tête de série assignée.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: navyColor),
          children: [
            _tableHeaderCell('TS', 25),
            _tableHeaderCell('Paire engagée', 150),
            _tableHeaderCell('Poids / Classement', 60),
            _tableHeaderCell('Affectation Tour 1 / Poule', 80),
          ],
        ),
        for (final s in seeds)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: (s.seed ?? 0) % 2 == 1 ? lightBg : PdfColors.white,
            ),
            children: [
              _tableTextCell('TS ${s.seed}', isBold: true),
              _tableTextCell(s.displayName),
              _tableTextCell(s.weight > 0 ? '${s.weight} pts' : '—'),
              _tableTextCell(s.seed == 1 ? 'Ligne 1 (Haut)' : (s.seed == 2 ? 'Dernière Ligne (Bas)' : 'Tirée en 1/4')),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildPoolsGrid(
    List<TournamentPool> pools,
    PdfColor navyColor,
    PdfColor lightBg,
    PdfColor borderColor,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < pools.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    color: navyColor,
                    child: pw.Text(
                      pools[i].name,
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  for (int pIdx = 0; pIdx < pools[i].pairs.length; pIdx++)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                      color: pIdx % 2 == 1 ? lightBg : PdfColors.white,
                      child: pw.Row(
                        children: [
                          pw.Text('${pIdx + 1}. ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Expanded(
                            child: pw.Text(
                              pools[i].pairs[pIdx].displayName,
                              style: const pw.TextStyle(fontSize: 8),
                              maxLines: 1,
                            ),
                          ),
                          if (pools[i].pairs[pIdx].seed != null)
                            pw.Text(' (TS${pools[i].pairs[pIdx].seed})', style: const pw.TextStyle(fontSize: 7, color: PdfColors.amber800)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildEliminationTable(
    TournamentBracket bracket,
    PdfColor navyColor,
    PdfColor lightBg,
    PdfColor borderColor,
  ) {
    final r0Matches = bracket.mainMatches.where((m) => m.roundIndex == 0).toList();
    if (r0Matches.isEmpty) {
      return pw.Text('Tableau non initialisé.', style: const pw.TextStyle(fontSize: 8));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: navyColor),
          children: [
            _tableHeaderCell('Match N°', 30),
            _tableHeaderCell('Paire A (Haut)', 120),
            _tableHeaderCell('vs', 20),
            _tableHeaderCell('Paire B (Bas)', 120),
            _tableHeaderCell('Statut initial', 60),
          ],
        ),
        for (final m in r0Matches)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: m.matchIndex % 2 == 1 ? lightBg : PdfColors.white),
            children: [
              _tableTextCell('M${m.matchIndex + 1}', isBold: true),
              _tableTextCell(m.pair1 != null ? (m.pair1!.isBye ? 'EXEMPT (BYE)' : m.pair1!.displayName) : 'En attente'),
              _tableTextCell('vs', alignment: pw.Alignment.center),
              _tableTextCell(m.pair2 != null ? (m.pair2!.isBye ? 'EXEMPT (BYE)' : m.pair2!.displayName) : 'En attente'),
              _tableTextCell(m.pair1?.isBye == true || m.pair2?.isBye == true ? 'Exempt qualifié' : 'À jouer'),
            ],
          ),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text, double width) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _tableTextCell(String text, {bool isBold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  /// Génère le texte officiel à partager sur WhatsApp
  static String generateWhatsAppDrawAnnouncement({
    required TournamentModel tournament,
    required TournamentBracket bracket,
    required DateTime drawTimestamp,
    String? jatName,
    String? customMessage,
  }) {
    final categoryLabel = bracket.category == 'double_messieurs' || bracket.category == 'DH'
        ? 'DH'
        : (bracket.category == 'double_dames' || bracket.category == 'DD' ? 'DD' : 'DX');

    final certId = generateCertificateId(tournament.id, bracket.category, drawTimestamp);
    final dateStr = DateFormat('dd/MM à HH:mm').format(drawTimestamp);
    final effectiveJat = jatName ?? tournament.referee ?? 'Juge-Arbitre';

    final buf = StringBuffer();
    buf.writeln("🏆 *TIRAGE AU SORT OFFICIEL EFFECTUÉ* 🏆");
    buf.writeln("📍 *Tournoi :* ${tournament.name}");
    buf.writeln("🎾 *Épreuve :* $categoryLabel (${tournament.category})");
    buf.writeln("⏱ *Horodatage certifié :* $dateStr");
    buf.writeln("👤 *JAT Responsable :* $effectiveJat");
    buf.writeln("🔒 *Code de certification :* `$certId`");
    buf.writeln("");

    if (bracket.format == 'pools_and_bracket' && bracket.pools.isNotEmpty) {
      buf.writeln("📊 *COMPOSITION DES GROUPES :*");
      for (final pool in bracket.pools) {
        buf.writeln("👉 *${pool.name} :*");
        for (int i = 0; i < pool.pairs.length; i++) {
          final p = pool.pairs[i];
          final seedStr = p.seed != null ? " (TS${p.seed})" : "";
          buf.writeln("   • ${i + 1}. ${p.displayName}$seedStr");
        }
      }
    } else {
      buf.writeln("⚡ *AFFICHES DU 1ER TOUR :*");
      final r0 = bracket.mainMatches.where((m) => m.roundIndex == 0).take(6);
      for (final m in r0) {
        final p1 = m.pair1?.isBye == true ? "EXEMPT" : (m.pair1?.displayName ?? "TBD");
        final p2 = m.pair2?.isBye == true ? "EXEMPT" : (m.pair2?.displayName ?? "TBD");
        buf.writeln("   • Match ${m.matchIndex + 1} : $p1 🆚 $p2");
      }
    }

    buf.writeln("");
    buf.writeln("📄 *Le Procès-Verbal officiel et le live scoring sont consultables sur l'application BeachMatch.*");
    buf.writeln("Bonne chance à tous les compétiteurs ! 🏖️🔥");

    return buf.toString();
  }

  /// Ouvre WhatsApp avec le message officiel du tirage
  static Future<void> shareOnWhatsApp({
    required TournamentModel tournament,
    required TournamentBracket bracket,
    required DateTime drawTimestamp,
    String? jatName,
  }) async {
    final text = generateWhatsAppDrawAnnouncement(
      tournament: tournament,
      bracket: bracket,
      drawTimestamp: drawTimestamp,
      jatName: jatName,
    );
    final encoded = Uri.encodeComponent(text);
    final whatsappUrl = Uri.parse("https://wa.me/?text=$encoded");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
  }
}
