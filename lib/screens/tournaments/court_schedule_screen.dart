import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/tournament.dart';
import '../../models/tournament_bracket_model.dart';
import '../../services/bracket_generator_service.dart';
import '../../services/tournament_pdf_service.dart';
import '../../services/whatsapp_share_service.dart';
import '../../theme/colors.dart';

class CourtScheduleScreen extends StatefulWidget {
  final TournamentModel tournament;
  final bool isAuthorized;
  final Set<String> initialCategories;
  final int initialNumCourts;
  final TournamentBracket? bracket;
  final List<TournamentBracket>? initialBrackets;
  final Future<void> Function(Map<String, int> matchCourts)? onApplyCourtAssignments;

  const CourtScheduleScreen({
    super.key,
    required this.tournament,
    required this.isAuthorized,
    this.initialCategories = const {'DH', 'DD'},
    this.initialNumCourts = 5,
    this.bracket,
    this.initialBrackets,
    this.onApplyCourtAssignments,
  });

  @override
  State<CourtScheduleScreen> createState() => _CourtScheduleScreenState();
}

class _CourtScheduleScreenState extends State<CourtScheduleScreen> {
  late Set<String> _selectedCategories;
  late int _numCourts;
  int _selectedRotationIndex = 0;
  String _activeCategoryFilter = 'all'; // 'all', 'DH', 'DD', 'DX', 'Poule'
  bool _isTableView = false;
  bool _isApplying = false;
  bool _isLoading = true;
  List<TournamentBracket> _brackets = [];

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.from(widget.initialCategories.isEmpty ? {'DH', 'DD'} : widget.initialCategories);
    _numCourts = widget.bracket?.numCourts ?? widget.initialNumCourts;
    if (widget.initialBrackets != null && widget.initialBrackets!.isNotEmpty) {
      _brackets = List.from(widget.initialBrackets!);
      _isLoading = false;
    } else {
      _loadBracketsFromFirestore();
    }
  }

  Future<void> _loadBracketsFromFirestore() async {
    setState(() => _isLoading = true);
    try {
      final List<TournamentBracket> list = [];
      final snap = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('brackets')
          .get();

      for (final doc in snap.docs) {
        try {
          list.add(TournamentBracket.fromMap(doc.data(), widget.tournament.id));
        } catch (e) {
          debugPrint("Error parsing bracket doc ${doc.id}: $e");
        }
      }

      // Fallback legacy bracket/current
      if (list.isEmpty) {
        final leg = await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournament.id)
            .collection('bracket')
            .doc('current')
            .get();
        if (leg.exists && leg.data() != null) {
          list.add(TournamentBracket.fromMap(leg.data()!, widget.tournament.id));
        }
      }

      if (widget.bracket != null && !list.any((b) => b.category == widget.bracket!.category)) {
        list.add(widget.bracket!);
      }

      if (mounted) {
        setState(() {
          _brackets = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading brackets for schedule: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Modèle d'un match programmé sur un court (dynamique sur mesure basé sur les vrais brackets)
  List<Map<String, dynamic>> _getRotationsData() {
    final activeBrackets = <TournamentBracket>[];
    for (final b in _brackets) {
      final cat = b.category.toLowerCase();
      final isDh = _selectedCategories.contains('DH') &&
          (cat == 'double_messieurs' || cat == 'dh' || cat.contains('messieurs') || cat.contains('homme'));
      final isDd = _selectedCategories.contains('DD') &&
          (cat == 'double_dames' || cat == 'dd' || cat.contains('dames') || cat.contains('femme'));
      final isDx = _selectedCategories.contains('DX') &&
          (cat == 'double_mixtes' || cat == 'dx' || cat.contains('mixte'));
      if (isDh || isDd || isDx) {
        activeBrackets.add(b);
      }
    }

    if (activeBrackets.isEmpty && widget.bracket != null) {
      activeBrackets.add(widget.bracket!);
    }

    if (activeBrackets.isNotEmpty &&
        activeBrackets.any((b) => b.pools.isNotEmpty || b.mainMatches.isNotEmpty || b.pairs.isNotEmpty)) {
      return _generateCustomRotationsFromBrackets(activeBrackets);
    }

    return _generateGenericPreviewRotations();
  }

  String _normalizeCategory(String rawCat) {
    final s = rawCat.toLowerCase().trim();
    if (s == 'double_dames' || s == 'dd' || s.contains('dame') || s.contains('femme')) return 'DD';
    if (s == 'double_mixtes' || s == 'dx' || s.contains('mixte')) return 'DX';
    return 'DH';
  }

  String _formatRotationTime(int rotIndex) {
    final startMinutes = 9 * 60 + rotIndex * 75; // 1h15 par rotation FFT
    final endMinutes = startMinutes + 75;
    final startH = (startMinutes ~/ 60).toString().padLeft(2, '0');
    final startM = (startMinutes % 60).toString().padLeft(2, '0');
    final endH = (endMinutes ~/ 60).toString().padLeft(2, '0');
    final endM = (endMinutes % 60).toString().padLeft(2, '0');
    return "${startH}h$startM - ${endH}h$endM";
  }

  List<Map<String, dynamic>> _generateCustomRotationsFromBrackets(List<TournamentBracket> rawBrackets) {
    final List<Map<String, dynamic>> rawMatchList = [];

    for (var b in rawBrackets) {
      final catCode = _normalizeCategory(b.category);
      if (!_selectedCategories.contains(catCode)) continue;

      // Si le tableau a des paires mais aucun match généré, les générer à la volée
      if (b.pools.isEmpty && b.mainMatches.isEmpty && b.pairs.isNotEmpty) {
        if (b.format == 'pools_and_bracket') {
          if (b.pairs.length <= 5) {
            b = BracketGeneratorService.generatePoolsAndBracket(
              tournamentId: widget.tournament.id,
              category: b.category,
              pouleAPairs: b.pairs,
              pouleBPairs: const [],
              numCourts: _numCourts,
            );
          } else {
            final half = (b.pairs.length / 2).ceil();
            b = BracketGeneratorService.generatePoolsAndBracket(
              tournamentId: widget.tournament.id,
              category: b.category,
              pouleAPairs: b.pairs.take(half).toList(),
              pouleBPairs: b.pairs.skip(half).toList(),
              numCourts: _numCourts,
            );
          }
        } else {
          b = BracketGeneratorService.generateBracket(
            tournamentId: widget.tournament.id,
            category: b.category,
            registeredPairs: b.pairs,
            numCourts: _numCourts,
          );
        }
      }

      // 1. Matches de Poules
      for (final pool in b.pools) {
        for (final m in pool.matches) {
          if (m.isBye) continue;
          final p1Name = m.pair1?.displayName ?? "Paire 1";
          final p2Name = m.pair2?.displayName ?? "Paire 2";
          rawMatchList.add({
            'matchId': m.id,
            'bracketCategory': b.category,
            'cat': catCode,
            'type': 'Poule',
            'tour': "${pool.name} - ${m.roundName.contains('Tour') ? m.roundName : 'Match ${m.matchIndex + 1}'}",
            'p1': p1Name,
            'p2': p2Name,
            'p1Id': m.pair1?.id ?? p1Name,
            'p2Id': m.pair2?.id ?? p2Name,
            'phaseOrder': m.roundIndex * 2,
            'score': m.score,
            'winner': m.winnerId == null
                ? null
                : (m.winnerId == m.pair1?.id ? 1 : (m.winnerId == m.pair2?.id ? 2 : null)),
            'isFinished': m.isCompleted,
            'next': "Match de poule",
          });
        }
      }

      // 2. Matches du Tableau Principal
      final hasPools = b.pools.isNotEmpty;
      for (final m in b.mainMatches) {
        if (m.isBye) continue;
        final isFinal = m.roundName.toLowerCase().contains('finale') &&
            !m.roundName.toLowerCase().contains('1/') &&
            !m.roundName.toLowerCase().contains('demi');
        final isSemi = m.roundName.toLowerCase().contains('demi') || m.roundName.toLowerCase().contains('1/2');

        final p1Name = m.pair1?.displayName ?? (hasPools ? "1er / 2e Poule" : "Qualifié");
        final p2Name = m.pair2?.displayName ?? (hasPools ? "1er / 2e Poule" : "Qualifié");

        rawMatchList.add({
          'matchId': m.id,
          'bracketCategory': b.category,
          'cat': catCode,
          'type': isFinal ? 'Final' : catCode,
          'tour': "$catCode ${m.roundName}",
          'p1': p1Name,
          'p2': p2Name,
          'p1Id': m.pair1?.id ?? p1Name,
          'p2Id': m.pair2?.id ?? p2Name,
          'phaseOrder': hasPools ? (10 + m.roundIndex * 2) : (m.roundIndex * 2),
          'score': m.score,
          'winner': m.winnerId == null
              ? null
              : (m.winnerId == m.pair1?.id ? 1 : (m.winnerId == m.pair2?.id ? 2 : null)),
          'isFinished': m.isCompleted,
          'next': isFinal ? "Podium & Remise des Prix" : (isSemi ? "Vainqueur en Grande Finale" : "Tour suivant"),
        });
      }

      // 3. Matches de Consolante
      for (final m in b.consolationMatches) {
        if (m.isBye) continue;
        final p1Name = m.pair1?.displayName ?? "Repêché";
        final p2Name = m.pair2?.displayName ?? "Repêché";

        rawMatchList.add({
          'matchId': m.id,
          'bracketCategory': b.category,
          'cat': catCode,
          'type': catCode,
          'tour': "$catCode ${m.roundName}",
          'p1': p1Name,
          'p2': p2Name,
          'p1Id': m.pair1?.id ?? p1Name,
          'p2Id': m.pair2?.id ?? p2Name,
          'phaseOrder': (hasPools ? 11 : 1) + m.roundIndex * 2,
          'score': m.score,
          'winner': m.winnerId == null
              ? null
              : (m.winnerId == m.pair1?.id ? 1 : (m.winnerId == m.pair2?.id ? 2 : null)),
          'isFinished': m.isCompleted,
          'next': "Classement consolante",
        });
      }
    }

    if (rawMatchList.isEmpty) {
      return _generateGenericPreviewRotations();
    }

    // Tri des matches par phase chronologique et catégorie
    rawMatchList.sort((a, b) {
      final orderA = a['phaseOrder'] as int;
      final orderB = b['phaseOrder'] as int;
      if (orderA != orderB) return orderA.compareTo(orderB);
      return (a['cat'] as String).compareTo(b['cat'] as String);
    });

    final List<Map<String, dynamic>> rotations = [];
    final unassigned = List<Map<String, dynamic>>.from(rawMatchList);
    int rotId = 0;

    while (unassigned.isNotEmpty && rotId < 20) {
      final currentCourtSlots = <Map<String, dynamic>>[];
      final playingPairIds = <String>{};
      final scheduledIndices = <int>[];

      for (int court = 1; court <= _numCourts; court++) {
        int pickedIndex = -1;
        for (int i = 0; i < unassigned.length; i++) {
          if (scheduledIndices.contains(i)) continue;
          final m = unassigned[i];
          final p1Id = m['p1Id'] as String;
          final p2Id = m['p2Id'] as String;

          final hasCollision = (p1Id.isNotEmpty && playingPairIds.contains(p1Id)) ||
              (p2Id.isNotEmpty && playingPairIds.contains(p2Id));

          if (!hasCollision) {
            pickedIndex = i;
            break;
          }
        }

        if (pickedIndex != -1) {
          scheduledIndices.add(pickedIndex);
          final m = unassigned[pickedIndex];
          final p1Id = m['p1Id'] as String;
          final p2Id = m['p2Id'] as String;
          if (p1Id.isNotEmpty) playingPairIds.add(p1Id);
          if (p2Id.isNotEmpty) playingPairIds.add(p2Id);

          currentCourtSlots.add({
            'court': court,
            'courtName': court == 1 ? "Court 1 (Central)" : "Court $court",
            'matchId': m['matchId'],
            'cat': m['cat'],
            'type': m['type'],
            'tour': m['tour'],
            'p1': m['p1'],
            'p2': m['p2'],
            'score': m['score'] ?? (m['isFinished'] == true ? "Terminé" : "À jouer"),
            'pause': "Pause FFT 1h15 garantie",
            'next': m['next'],
            'isFinished': m['isFinished'] ?? false,
            'winner': m['winner'],
            'bracketCategory': m['bracketCategory'],
          });
        } else {
          currentCourtSlots.add({
            'court': court,
            'courtName': court == 1 ? "Court 1 (Central)" : "Court $court",
            'cat': '',
            'type': 'Libre',
            'tour': 'Court Libre / Échauffement',
            'p1': 'Court disponible',
            'p2': 'Entraînement / Repos FFT',
            'score': '—',
            'pause': 'Libre',
            'next': 'Rotation suivante',
            'isFinished': false,
            'winner': null,
          });
        }
      }

      scheduledIndices.sort((a, b) => b.compareTo(a));
      for (final idx in scheduledIndices) {
        unassigned.removeAt(idx);
      }

      // Sécurité anti-blocage si collision totale
      if (scheduledIndices.isEmpty && unassigned.isNotEmpty) {
        final m = unassigned.removeAt(0);
        currentCourtSlots[0] = {
          'court': 1,
          'courtName': "Court 1 (Central)",
          'matchId': m['matchId'],
          'cat': m['cat'],
          'type': m['type'],
          'tour': m['tour'],
          'p1': m['p1'],
          'p2': m['p2'],
          'score': m['score'] ?? (m['isFinished'] == true ? "Terminé" : "À jouer"),
          'pause': "Pause FFT 1h15 garantie",
          'next': m['next'],
          'isFinished': m['isFinished'] ?? false,
          'winner': m['winner'],
          'bracketCategory': m['bracketCategory'],
        };
      }

      final timeStr = _formatRotationTime(rotId);
      final hasFinal = currentCourtSlots.any((c) => c['type'] == 'Final');
      final hasSemi = currentCourtSlots.any((c) => (c['tour'] ?? '').toString().toLowerCase().contains('demi'));
      final hasQuarts = currentCourtSlots.any((c) =>
          (c['tour'] ?? '').toString().toLowerCase().contains('1/4') ||
          (c['tour'] ?? '').toString().toLowerCase().contains('quart'));

      String title;
      String desc;
      if (hasFinal) {
        title = "ROTATION ${rotId + 1} (${timeStr.split(' - ').first}) · GRANDES FINALES";
        desc = "Finales et podiums officiels des épreuves";
      } else if (hasSemi) {
        title = "ROTATION ${rotId + 1} (${timeStr.split(' - ').first}) · DEMI-FINALES";
        desc = "Dernier carré qualificatif pour les finales";
      } else if (hasQuarts) {
        title = "ROTATION ${rotId + 1} (${timeStr.split(' - ').first}) · QUARTS DE FINALE";
        desc = "Entrée en lice des meilleures têtes de série";
      } else {
        title = "ROTATION ${rotId + 1} (${timeStr.split(' - ').first})";
        desc = "Matchs de poules et tours éliminatoires";
      }

      rotations.add({
        'id': rotId,
        'time': timeStr,
        'title': title,
        'desc': desc,
        'courts': currentCourtSlots,
      });

      rotId++;
    }

    return rotations.isNotEmpty ? rotations : _generateGenericPreviewRotations();
  }

  List<Map<String, dynamic>> _generateGenericPreviewRotations() {
    final List<Map<String, dynamic>> rotations = [];
    final catsList = _selectedCategories.toList();

    for (int r = 0; r < 4; r++) {
      final timeStr = _formatRotationTime(r);
      final List<Map<String, dynamic>> courtSlots = [];

      for (int c = 1; c <= _numCourts; c++) {
        final cat = catsList[(c + r) % catsList.length];
        final pairAIndex = (c * 2) - 1;
        final pairBIndex = c * 2;
        courtSlots.add({
          'court': c,
          'courtName': c == 1 ? "Court 1 (Central)" : "Court $c",
          'cat': cat,
          'type': cat,
          'tour': r == 3 ? "Finale $cat" : (r == 2 ? "1/2 Finale $cat" : "Tour ${r + 1} $cat"),
          'p1': "Paire $pairAIndex",
          'p2': "Paire $pairBIndex",
          'score': "À jouer",
          'pause': "Pause FFT 1h15 garantie",
          'next': r == 3 ? "Podium & Clôture" : "Tour suivant",
          'isFinished': false,
          'winner': null,
        });
      }

      rotations.add({
        'id': r,
        'time': timeStr,
        'title': "ROTATION ${r + 1} (${timeStr.split(' - ').first}) · EXEMPLE",
        'desc': "Saisissez vos paires dans l'onglet Tableau pour afficher le planning réel sur mesure",
        'courts': courtSlots,
      });
    }

    return rotations;
  }

  Future<void> _shareScheduleWhatsApp() async {
    final rotations = _getRotationsData();
    final buffer = StringBuffer();
    buffer.writeln("📅 PROGRAMMATION & ROTATION DES TERRAINS");
    buffer.writeln("🏆 Tournoi : ${widget.tournament.name}");
    if (widget.tournament.club.isNotEmpty) {
      buffer.writeln("📍 Club : ${widget.tournament.club}");
    }
    buffer.writeln("🏟️ Terrains mutualisés : $_numCourts courts");
    buffer.writeln("🎾 Tableaux : ${_selectedCategories.join(' + ')}");
    buffer.writeln("⏱️ Repos FFT garanti : mini 1h15 entre chaque tour\n");

    for (int i = 0; i < rotations.length; i++) {
      final rot = rotations[i];
      buffer.writeln("🔹 Rot. ${i + 1} (${rot['time']}) : ${rot['title']}");
      final courts = (rot['courts'] as List<dynamic>?) ?? [];
      for (final c in courts) {
        if (c is Map && c['p1'] != null && c['p2'] != null && c['type'] != 'Libre') {
          buffer.writeln("   • Court ${c['court']} [${c['cat'] ?? ''}] : ${c['p1']} vs ${c['p2']} (${c['tour'] ?? ''})");
        }
      }
      buffer.writeln();
    }

    buffer.writeln("🎾 Beach Tennis FFT - Généré sur mesure par BeachMatch");

    await WhatsAppShareService.shareToWhatsAppOrNative(
      text: buffer.toString(),
      subject: "Feuille de rotation ${widget.tournament.name}",
    );
  }

  Future<void> _openPdf() async {
    try {
      final rotations = _getRotationsData();
      await TournamentPdfService.generateAndExportCourtRotationsPdf(
        tournament: widget.tournament,
        rotations: rotations,
        numCourts: _numCourts,
        categories: _selectedCategories,
      );
    } catch (e) {
      debugPrint("Error generating rotations PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur génération PDF : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _applyCourtsToTournament() async {
    setState(() => _isApplying = true);
    try {
      final rotations = _getRotationsData();
      final Map<String, int> assignments = {};
      for (final r in rotations) {
        final courts = (r['courts'] as List<dynamic>?) ?? [];
        for (final c in courts) {
          if (c is Map && c['matchId'] != null && c['court'] != null) {
            assignments[c['matchId'] as String] = (c['court'] as num).toInt();
          }
        }
      }

      if (widget.onApplyCourtAssignments != null) {
        await widget.onApplyCourtAssignments!(assignments);
      } else if (assignments.isNotEmpty) {
        for (final b in _brackets) {
          bool modified = false;
          final updatedPools = b.pools.map((pool) {
            final updatedMatches = pool.matches.map((m) {
              if (assignments.containsKey(m.id)) {
                modified = true;
                return m.copyWith(court: assignments[m.id]);
              }
              return m;
            }).toList();
            return pool.copyWith(matches: updatedMatches);
          }).toList();

          final updatedMain = b.mainMatches.map((m) {
            if (assignments.containsKey(m.id)) {
              modified = true;
              return m.copyWith(court: assignments[m.id]);
            }
            return m;
          }).toList();

          final updatedConso = b.consolationMatches.map((m) {
            if (assignments.containsKey(m.id)) {
              modified = true;
              return m.copyWith(court: assignments[m.id]);
            }
            return m;
          }).toList();

          if (modified) {
            final updatedBracket = b.copyWith(
              pools: updatedPools,
              mainMatches: updatedMain,
              consolationMatches: updatedConso,
              numCourts: _numCourts,
              updatedAt: DateTime.now(),
            );
            await FirebaseFirestore.instance
                .collection('tournaments')
                .doc(widget.tournament.id)
                .collection('brackets')
                .doc(b.category)
                .set(updatedBracket.toMap(), SetOptions(merge: true));
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${assignments.length} terrains enregistrés avec succès !"),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error applying court assignments: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur enregistrement terrains : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _callPlayersToCourt(Map<String, dynamic> match) {
    HapticFeedback.heavyImpact();
    final court = (match['court'] as num?)?.toInt() ?? int.tryParse('${match['court']}') ?? 1;
    final tour = match['tour']?.toString() ?? '';
    final p1 = match['p1']?.toString() ?? '';
    final p2 = match['p2']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: AppColors.gold, size: 24),
            const SizedBox(width: 8),
            Text("Appel Court $court", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Convoquer les joueurs pour : $tour", style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("🎾 $p1", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text("CONTRE", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("🎾 $p2", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text("Diffuser l'appel", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              final text = "📢 APPEL MATCH · COURT $court\n"
                  "🏆 ${widget.tournament.name}\n"
                  "📍 $tour\n"
                  "🎾 $p1\n"
                  "VS\n"
                  "🎾 $p2\n"
                  "➡️ Les joueurs sont priés de se présenter immédiatement sur le Terrain $court !";

              await WhatsAppShareService.shareToWhatsAppOrNative(
                text: text,
                subject: "Appel Court $court",
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("📢 Appel diffusé pour le Court $court !"),
                    backgroundColor: AppColors.gold,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showConfigDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppColors.gold, size: 22),
                      SizedBox(width: 8),
                      Text(
                        "Configuration des Terrains",
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Choisissez les tableaux et le nombre de terrains pour recalculer le planning :",
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 18),

                  // Choix des catégories
                  const Text("Tableaux à intégrer :", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChipModal("Double Messieurs (DH)", "DH", _selectedCategories.contains("DH"), (selected) {
                        setModalState(() {
                          if (selected) {
                            _selectedCategories.add("DH");
                          } else if (_selectedCategories.length > 1) {
                            _selectedCategories.remove("DH");
                          }
                        });
                      }),
                      _buildFilterChipModal("Double Dames (DD)", "DD", _selectedCategories.contains("DD"), (selected) {
                        setModalState(() {
                          if (selected) {
                            _selectedCategories.add("DD");
                          } else if (_selectedCategories.length > 1) {
                            _selectedCategories.remove("DD");
                          }
                        });
                      }),
                      _buildFilterChipModal("Double Mixte (DX)", "DX", _selectedCategories.contains("DX"), (selected) {
                        setModalState(() {
                          if (selected) {
                            _selectedCategories.add("DX");
                          } else if (_selectedCategories.length > 1) {
                            _selectedCategories.remove("DX");
                          }
                        });
                      }),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Nombre de terrains
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Terrains disponibles :", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text("De 2 à 10 courts en simultané", style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white, size: 18),
                              onPressed: _numCourts > 2
                                  ? () => setModalState(() => _numCourts--)
                                  : null,
                            ),
                            Text(
                              "$_numCourts courts",
                              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white, size: 18),
                              onPressed: _numCourts < 12
                                  ? () => setModalState(() => _numCourts++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Bouton Appliquer
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Planning recalculé pour $_numCourts terrains (${_selectedCategories.join(', ')}) !"),
                            backgroundColor: AppColors.gold,
                          ),
                        );
                      },
                      child: const Text("Appliquer la configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChipModal(String label, String code, bool isSelected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      selectedColor: AppColors.gold.withValues(alpha: 0.25),
      checkmarkColor: AppColors.gold,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.gold : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _brackets.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D14),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    final rotations = _getRotationsData();
    final safeRotationIndex = _selectedRotationIndex.clamp(0, (rotations.length - 1).clamp(0, 999));
    final currentRotation = rotations[safeRotationIndex];
    final allCourts = (currentRotation['courts'] as List<Map<String, dynamic>>)
        .where((c) => ((c['court'] as num?)?.toInt() ?? 1) <= _numCourts)
        .toList();

    // Filtrage par catégorie
    final filteredCourts = allCourts.where((c) {
      if (_activeCategoryFilter == 'all') return true;
      if (_activeCategoryFilter == 'DH' && c['type'] == 'DH') return true;
      if (_activeCategoryFilter == 'DD' && c['type'] == 'DD') return true;
      if (_activeCategoryFilter == 'DX' && c['type'] == 'DX') return true;
      if (_activeCategoryFilter == 'Poule' && c['type'] == 'Poule') return true;
      if (c['type'] == 'Final' || c['type'] == 'Ceremonie') return true;
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF090D14),
      body: Stack(
        children: [
          // Fond Sunset
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xDF090D14),
                    Color(0xF5090D14),
                    Color(0xFF070A0F),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                _buildHeader(),

                // Bandeau d'infos et filtres
                _buildSummaryBar(),

                // Sélecteur de Rotation (Rot 1 à 8)
                _buildRotationSelector(rotations),

                // Filtres de catégories rapides
                _buildCategoryFilterChips(),

                // Contenu des Terrains
                Expanded(
                  child: _isTableView
                      ? _buildGlobalMatrixView(rotations)
                      : _buildCourtsView(filteredCourts, currentRotation),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Bouton Retour
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          // Titre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      "RÉPARTITION DES TERRAINS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      "FFT",
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.tournament.name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Bouton Appliquer Terrains au Tableau JAT
          if (widget.isAuthorized) ...[
            Tooltip(
              message: "Enregistrer ces terrains sur les matches du tournoi",
              child: InkWell(
                onTap: _isApplying ? null : _applyCourtsToTournament,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isApplying
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.save_rounded, color: Colors.black, size: 14),
                      const SizedBox(width: 4),
                      const Text(
                        "Appliquer",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // Bouton Config
          IconButton(
            tooltip: "Paramètres terrains & tableaux",
            icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
            onPressed: _showConfigDialog,
          ),
          // Bouton Bascule Vue Grille / Vue Tableur
          IconButton(
            tooltip: _isTableView ? "Vue Cartes Terrains" : "Vue Tableur Global",
            icon: Icon(_isTableView ? Icons.dashboard_rounded : Icons.table_chart_rounded, color: AppColors.gold, size: 20),
            onPressed: () => setState(() => _isTableView = !_isTableView),
          ),
          // Bouton Partager WhatsApp
          IconButton(
            tooltip: "Partager sur WhatsApp",
            icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 20),
            onPressed: _shareScheduleWhatsApp,
          ),
          // Bouton PDF
          IconButton(
            tooltip: "Ouvrir PDF Officiel",
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
            onPressed: _openPdf,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withValues(alpha: 0.25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  "$_numCourts Terrains Mutualisés",
                  style: const TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _selectedCategories.join(' + '),
                  style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
              SizedBox(width: 4),
              Text(
                "Pause FFT 1h15 garantie",
                style: TextStyle(color: Colors.greenAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRotationSelector(List<Map<String, dynamic>> rotations) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: rotations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final rot = rotations[index];
          final isSelected = _selectedRotationIndex == index;

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedRotationIndex = index);
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.12),
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.2), blurRadius: 8)]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Rot. ${index + 1}",
                    style: TextStyle(
                      color: isSelected ? AppColors.gold : Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rot['time'].toString().split(' - ')[0],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          _buildPill("Tous", 'all'),
          if (_selectedCategories.contains('DH')) ...[
            const SizedBox(width: 6),
            _buildPill("🎾 DH", 'DH'),
          ],
          if (_selectedCategories.contains('DD')) ...[
            const SizedBox(width: 6),
            _buildPill("🎽 DD", 'DD'),
          ],
          if (_selectedCategories.contains('DX')) ...[
            const SizedBox(width: 6),
            _buildPill("⭐ DX", 'DX'),
          ],
          const SizedBox(width: 6),
          _buildPill("🏆 Finales", 'Final'),
        ],
      ),
    );
  }

  Widget _buildPill(String label, String key) {
    final isSelected = _activeCategoryFilter == key;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeCategoryFilter = key);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCourtsView(List<Map<String, dynamic>> courts, Map<String, dynamic> rotation) {
    if (courts.isEmpty) {
      return const Center(
        child: Text(
          "Aucun match correspondant à ce filtre sur ce créneau",
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rotation['title'],
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                rotation['desc'],
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: courts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final c = courts[index];
              return _buildCourtCard(c);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCourtCard(Map<String, dynamic> c) {
    Color typeColor = Colors.blue;
    Color typeBg = Colors.blue.withValues(alpha: 0.15);
    String typeLabel = "DH ${widget.tournament.category}";

    if (c['type'] == 'DD') {
      typeColor = Colors.pinkAccent;
      typeBg = Colors.pinkAccent.withValues(alpha: 0.15);
      typeLabel = "DD ${widget.tournament.category}";
    } else if (c['type'] == 'DX') {
      typeColor = Colors.purpleAccent;
      typeBg = Colors.purpleAccent.withValues(alpha: 0.15);
      typeLabel = "DX ${widget.tournament.category}";
    } else if (c['type'] == 'Poule') {
      typeColor = Colors.amber;
      typeBg = Colors.amber.withValues(alpha: 0.15);
      typeLabel = "POULE";
    } else if (c['type'] == 'Final') {
      typeColor = Colors.greenAccent;
      typeBg = Colors.greenAccent.withValues(alpha: 0.15);
      typeLabel = "🏆 FINALE";
    } else if (c['type'] == 'Libre') {
      typeColor = Colors.white38;
      typeBg = Colors.white.withValues(alpha: 0.05);
      typeLabel = "COURT LIBRE";
    } else if (c['type'] == 'Ceremonie') {
      typeColor = Colors.deepPurpleAccent;
      typeBg = Colors.deepPurpleAccent.withValues(alpha: 0.15);
      typeLabel = "🎖️ CÉRÉMONIE";
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la carte
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.sports_tennis_rounded, color: typeColor, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      c['courtName'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: typeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(color: typeColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Contenu du match
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c['tour'],
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    if (c['score'] != null && c['score'].toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          c['score'],
                          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Paires
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            c['winner'] == 1 ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            color: c['winner'] == 1 ? Colors.greenAccent : Colors.white30,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c['p1'],
                              style: TextStyle(
                                color: c['winner'] == 1 ? Colors.white : Colors.white70,
                                fontWeight: c['winner'] == 1 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      Row(
                        children: [
                          Icon(
                            c['winner'] == 2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            color: c['winner'] == 2 ? Colors.greenAccent : Colors.white30,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c['p2'],
                              style: TextStyle(
                                color: c['winner'] == 2 ? Colors.white : Colors.white70,
                                fontWeight: c['winner'] == 2 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Repos et Suite
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Colors.greenAccent, size: 12),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  c['pause'] ?? "Repos conforme",
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 10.5, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.arrow_forward_rounded, color: Colors.lightBlueAccent, size: 12),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  c['next'] ?? "",
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.isAuthorized && c['type'] != 'Ceremonie') ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _callPlayersToCourt(c),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.campaign_rounded, color: AppColors.gold, size: 14),
                              SizedBox(width: 4),
                              Text("Appeler", style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Vue Tableur Global
  Widget _buildGlobalMatrixView(List<Map<String, dynamic>> rotations) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.08)),
          dataRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.03)),
          headingTextStyle: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
          dataTextStyle: const TextStyle(color: Colors.white, fontSize: 11),
          columns: [
            const DataColumn(label: Text("Horaire")),
            for (int i = 1; i <= _numCourts; i++)
              DataColumn(label: Text("Court $i")),
          ],
          rows: rotations.map((rot) {
            final courts = rot['courts'] as List<Map<String, dynamic>>;
            return DataRow(
              cells: [
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rot['time'].toString().split(' - ')[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                      Text("Rot. ${rot['id'] + 1}", style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                    ],
                  ),
                ),
                for (int i = 1; i <= _numCourts; i++) ...[
                  DataCell(
                    Builder(
                      builder: (_) {
                        final c = courts.firstWhere((item) => item['court'] == i, orElse: () => {});
                        if (c.isEmpty) return const Text("—", style: TextStyle(color: Colors.white24));

                        return Container(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['tour'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.lightBlueAccent), overflow: TextOverflow.ellipsis),
                              Text("${c['p1']} vs ${c['p2']}", style: const TextStyle(fontSize: 9.5, color: Colors.white70), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
