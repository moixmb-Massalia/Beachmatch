import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/tournament.dart';
import '../../models/tournament_bracket_model.dart';
import '../../services/bracket_generator_service.dart';
import '../../services/draw_certification_service.dart';
import '../../theme/colors.dart';
import '../../widgets/add_pair_autocomplete_dialog.dart';

class JatDrawCeremonyScreen extends StatefulWidget {
  final TournamentModel tournament;
  final TournamentBracket initialBracket;
  final String categoryKey;
  final String categoryLabel;
  final Function(TournamentBracket updatedBracket) onSaveBracket;

  const JatDrawCeremonyScreen({
    super.key,
    required this.tournament,
    required this.initialBracket,
    required this.categoryKey,
    required this.categoryLabel,
    required this.onSaveBracket,
  });

  @override
  State<JatDrawCeremonyScreen> createState() => _JatDrawCeremonyScreenState();
}

class _JatDrawCeremonyScreenState extends State<JatDrawCeremonyScreen> with SingleTickerProviderStateMixin {
  late String _format; // 'pools_and_bracket' or 'elimination'
  late String _finalPhaseType; // 'direct_finals' or 'crossover_semis'
  late int _numCourts; // Nombre de terrains configurés par le JAT
  bool _invertSeeds = true; // Suggéré pour la France (FFT) : TS2 en haut / Poule A, TS1 en bas / Poule B
  late List<TournamentPair> _pairs;

  // Clés d'ancrage pour le guide pas-à-pas JAT
  final GlobalKey _step1Key = GlobalKey();
  final GlobalKey _step2Key = GlobalKey();
  final GlobalKey _step3Key = GlobalKey();
  final GlobalKey _step4Key = GlobalKey();

  void _scrollToStep(GlobalKey key) {
    HapticFeedback.lightImpact();
    final targetContext = key.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // Contrôleur de défilement pour auto-scroll vers le bas pendant le tirage
  final ScrollController _scrollController = ScrollController();

  // État de l'animation de tirage
  bool _isDrawing = false;
  double _drawProgress = 0.0;
  bool _drawCompleted = false;
  DateTime? _drawTimestamp;
  String? _certificateId;
  TournamentBracket? _generatedBracket;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _format = widget.initialBracket.pools.length == 1
        ? 'single_pool'
        : (widget.initialBracket.format.isNotEmpty ? widget.initialBracket.format : 'pools_and_bracket');
    _finalPhaseType = widget.initialBracket.finalPhaseType.isNotEmpty ? widget.initialBracket.finalPhaseType : 'direct_finals';
    _numCourts = widget.initialBracket.numCourts > 0 ? widget.initialBracket.numCourts : 4;
    final initialPairs = widget.initialBracket.pairs.isNotEmpty
        ? widget.initialBracket.pairs
        : (widget.initialBracket.pools.isNotEmpty
            ? widget.initialBracket.pools.expand((p) => p.pairs).toList()
            : <TournamentPair>[]);
    _pairs = List<TournamentPair>.from(initialPairs);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _addNewPair() async {
    final newPair = await AddPairAutocompleteDialog.show(
      context,
      category: widget.categoryKey,
    );
    if (newPair != null && mounted) {
      setState(() {
        _pairs.add(newPair);
        _drawCompleted = false;
      });
    }
  }

  void _editPair(int index) async {
    final pair = _pairs[index];
    if (pair.isBye) return;
    final updated = await AddPairAutocompleteDialog.show(
      context,
      category: widget.categoryKey,
      existingPair: pair,
    );
    if (updated != null && mounted) {
      setState(() {
        _pairs[index] = updated;
        _drawCompleted = false;
      });
    }
  }

  void _addByePair() {
    HapticFeedback.selectionClick();
    setState(() {
      final byeCount = _pairs.where((p) => p.isBye).length + 1;
      _pairs.add(TournamentPair(
        id: 'bye_${DateTime.now().millisecondsSinceEpoch}_$byeCount',
        player1Name: 'EXEMPT',
        player2Name: 'BYE #$byeCount',
        player1Rank: 9999,
        player2Rank: 9999,
        isBye: true,
      ));
      _drawCompleted = false;
    });
  }

  void _removePair(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _pairs.removeAt(index);
      _drawCompleted = false;
    });
  }

  void _toggleTsInversion() {
    HapticFeedback.mediumImpact();
    setState(() {
      _invertSeeds = !_invertSeeds;
      _drawCompleted = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _invertSeeds
              ? "Position France (FFT) : TS2 en haut (Poule A), TS1 en bas (Poule B)"
              : "Standard ITF : TS1 en haut (Poule A), TS2 en bas (Poule B)",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.gold,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _startDrawCeremony() async {
    if (_pairs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ajoutez au moins 2 paires pour effectuer le tirage au sort."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isDrawing = true;
      _drawProgress = 0.0;
      _drawCompleted = false;
    });

    // 1. Assigner d'abord les Têtes de Série mathématiques par poids
    var seededPairs = BracketGeneratorService.assignSeeds(_pairs);

    // Si inversion demandée par le JAT (selon règlement fédéral particulier)
    if (_invertSeeds && seededPairs.length >= 2) {
      final pTs1 = seededPairs.firstWhere((p) => p.seed == 1, orElse: () => seededPairs[0]);
      final pTs2 = seededPairs.firstWhere((p) => p.seed == 2, orElse: () => seededPairs[1]);

      seededPairs = seededPairs.map((p) {
        if (p.id == pTs1.id) return p.copyWith(seed: 2);
        if (p.id == pTs2.id) return p.copyWith(seed: 1);
        return p;
      }).toList();
    }

    // 2. Animation de suspense pas-à-pas (effet WOW) avec auto-scroll fluide
    for (int step = 1; step <= 10; step++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _drawProgress = step / 10.0;
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent * (step / 10.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }

    // 3. Tirage aléatoire pour les non têtes de série (mélange équitable Fisher-Yates)
    final random = Random();
    final seeds = seededPairs.where((p) => p.seed != null).toList();
    final unseeded = seededPairs.where((p) => p.seed == null).toList()..shuffle(random);

    TournamentBracket resultBracket;

    if (_format == 'single_pool') {
      final orderedPairs = [...seeds, ...unseeded];
      resultBracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: widget.tournament.id,
        category: widget.categoryKey,
        pouleAPairs: orderedPairs,
        pouleBPairs: const [], // Poule Unique !
        finalPhaseType: 'direct_finals',
        numCourts: _numCourts,
      );
    } else if (_format == 'pools_and_bracket') {
      // Répartition en Poule A et Poule B
      final pouleAPairs = <TournamentPair>[];
      final pouleBPairs = <TournamentPair>[];

      // Têtes de poules selon règles
      final ts1 = seeds.firstWhere((p) => p.seed == (_invertSeeds ? 2 : 1), orElse: () => seededPairs[0]);
      final ts2 = seeds.firstWhere((p) => p.seed == (_invertSeeds ? 1 : 2), orElse: () => seededPairs.length > 1 ? seededPairs[1] : seededPairs[0]);

      pouleAPairs.add(ts1);
      pouleBPairs.add(ts2);

      // TS3 et TS4 si présentes (serpentine)
      if (seeds.any((p) => p.seed == 3)) {
        pouleBPairs.add(seeds.firstWhere((p) => p.seed == 3));
      }
      if (seeds.any((p) => p.seed == 4)) {
        pouleAPairs.add(seeds.firstWhere((p) => p.seed == 4));
      }

      // Distribuer les paires non têtes de série alternativement
      for (int i = 0; i < unseeded.length; i++) {
        if (pouleAPairs.length <= pouleBPairs.length) {
          pouleAPairs.add(unseeded[i]);
        } else {
          pouleBPairs.add(unseeded[i]);
        }
      }

      resultBracket = BracketGeneratorService.generatePoolsAndBracket(
        tournamentId: widget.tournament.id,
        category: widget.categoryKey,
        pouleAPairs: pouleAPairs,
        pouleBPairs: pouleBPairs,
        finalPhaseType: _finalPhaseType,
        numCourts: _numCourts,
      );
    } else {
      // Élimination directe
      final orderedPairs = [...seeds, ...unseeded];
      resultBracket = BracketGeneratorService.generateBracket(
        tournamentId: widget.tournament.id,
        category: widget.categoryKey,
        registeredPairs: orderedPairs,
        numCourts: _numCourts,
      );
    }

    final now = DateTime.now();
    final certId = DrawCertificationService.generateCertificateId(widget.tournament.id, widget.categoryKey, now);

    HapticFeedback.heavyImpact();
    setState(() {
      _isDrawing = false;
      _drawCompleted = true;
      _drawTimestamp = now;
      _certificateId = certId;
      _generatedBracket = resultBracket;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _exportPdfCertificate() async {
    if (_generatedBracket == null || _drawTimestamp == null) return;
    HapticFeedback.mediumImpact();
    await DrawCertificationService.generateAndExportDrawPvPdf(
      tournament: widget.tournament,
      bracket: _generatedBracket!,
      drawTimestamp: _drawTimestamp!,
      jatName: widget.tournament.referee,
      drawLocation: widget.tournament.location,
      poolModeDescription: _format == 'single_pool'
          ? 'Poule Unique (Toutes Rondes · Championnat FFT)'
          : (_format == 'pools_and_bracket'
              ? (_finalPhaseType == 'direct_finals'
                  ? 'Finale Directe (1er A vs 1er B en Finale · Formule 1 jour)'
                  : 'Demi-finales Croisées (1A vs 2B / 1B vs 2A · Championnat)')
              : 'Tableau Principal Élimination Directe FFT/ITF'),
      isTsInverted: _invertSeeds,
    );
  }

  Future<void> _shareWhatsApp() async {
    if (_generatedBracket == null || _drawTimestamp == null) return;
    HapticFeedback.mediumImpact();
    await DrawCertificationService.shareOnWhatsApp(
      tournament: widget.tournament,
      bracket: _generatedBracket!,
      drawTimestamp: _drawTimestamp!,
      jatName: widget.tournament.referee,
    );
  }

  Future<void> _applyAndSave() async {
    if (_generatedBracket == null) return;
    HapticFeedback.heavyImpact();
    widget.onSaveBracket(_generatedBracket!);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.black),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Tirage officiel homologué appliqué au tableau (${_certificateId ?? 'Certifié'})",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.gold,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Arrière-plan Sunset Beach Tennis immersif
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0B132B)),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.68),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTournamentHeaderCard(),
                        const SizedBox(height: 14),
                        _buildJatStepWizardBar(),
                        const SizedBox(height: 16),
                        Container(key: _step1Key, child: _buildRulesSettingsCard()),
                        const SizedBox(height: 16),
                        Container(key: _step2Key, child: _buildPairsManagerCard()),
                        const SizedBox(height: 20),
                        Container(key: _step3Key, child: _buildDrawCeremonyAction()),
                        if (_drawCompleted) ...[
                          const SizedBox(height: 20),
                          _buildDrawResultsCard(),
                          const SizedBox(height: 16),
                          Container(key: _step4Key, child: _buildCertificationActionButtons()),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded, color: AppColors.gold, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "CÉRÉMONIE DU TIRAGE AU SORT",
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.categoryLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: AppColors.gold, size: 14),
                SizedBox(width: 4),
                Text(
                  "JAT Officiel",
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gold, Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tournament.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "${widget.tournament.club} · ${widget.tournament.dateString}",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJatStepWizardBar() {
    const step1Done = true; // Paramètres par défaut prêts
    final step2Done = _pairs.length >= 4;
    final step3Done = _drawCompleted;
    final step4Done = _drawCompleted;

    int currentStep = 1;
    if (step3Done) {
      currentStep = 4;
    } else if (step2Done) {
      currentStep = 3;
    } else {
      currentStep = 2;
    }

    String hintMessage;
    if (currentStep == 2) {
      hintMessage = "Étape 2 : ${_pairs.length}/4 paires engagées. Ajoutez ou importez vos paires pour lancer le tirage.";
    } else if (currentStep == 3) {
      hintMessage = "Étape 3 : Paires prêtes (${_pairs.length} paires) ! Vous pouvez lancer la cérémonie du tirage officiel.";
    } else {
      hintMessage = "Étape 4 : Tirage homologué ! Cliquez sur « Appliquer au tableau officiel » pour publier les matchs.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.route_rounded, color: AppColors.gold, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "GUIDE JAT ÉTAPE PAR ÉTAPE",
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Étape $currentStep / 4",
                  style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStepIndicatorItem(
                stepNumber: "1",
                label: "Règles",
                isDone: step1Done,
                isActive: currentStep == 1,
                onTap: () => _scrollToStep(_step1Key),
              ),
              _buildStepDivider(step2Done),
              _buildStepIndicatorItem(
                stepNumber: "2",
                label: "Paires",
                isDone: step2Done,
                isActive: currentStep == 2,
                onTap: () => _scrollToStep(_step2Key),
              ),
              _buildStepDivider(step3Done),
              _buildStepIndicatorItem(
                stepNumber: "3",
                label: "Tirage",
                isDone: step3Done,
                isActive: currentStep == 3,
                onTap: () => _scrollToStep(_step3Key),
              ),
              _buildStepDivider(step4Done),
              _buildStepIndicatorItem(
                stepNumber: "4",
                label: "Tableau",
                isDone: step4Done,
                isActive: currentStep == 4,
                onTap: () => _scrollToStep(_step4Key),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  currentStep == 4 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 14,
                  color: currentStep == 4 ? const Color(0xFF00E676) : AppColors.gold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hintMessage,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicatorItem({
    required String stepNumber,
    required String label,
    required bool isDone,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    Color circleColor;
    Widget iconWidget;

    if (isDone) {
      circleColor = const Color(0xFF00E676);
      iconWidget = const Icon(Icons.check, size: 12, color: Colors.black);
    } else if (isActive) {
      circleColor = AppColors.gold;
      iconWidget = Text(
        stepNumber,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
      );
    } else {
      circleColor = Colors.white24;
      iconWidget = Text(
        stepNumber,
        style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 11),
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.gold : (isDone ? Colors.white : Colors.white60),
                fontSize: 10,
                fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDivider(bool isDone) {
    return Container(
      width: 16,
      height: 2,
      margin: const EdgeInsets.only(bottom: 14),
      color: isDone ? const Color(0xFF00E676) : Colors.white24,
    );
  }

  Widget _buildRulesSettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text(
                "1. Paramètres & Règles Fédérales",
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Format : Poule Unique vs 2 Poules vs Élimination directe
          const Text("Format de l'épreuve :", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSelectChip(
                  label: "Poule Unique",
                  icon: Icons.view_headline_rounded,
                  isSelected: _format == 'single_pool',
                  onTap: () => setState(() {
                    _format = 'single_pool';
                    _drawCompleted = false;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSelectChip(
                  label: "2 Poules + Arbre",
                  icon: Icons.grid_view_rounded,
                  isSelected: _format == 'pools_and_bracket',
                  onTap: () => setState(() {
                    _format = 'pools_and_bracket';
                    _drawCompleted = false;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildSelectChip(
            label: "Tableau Arbre (Élimination Directe FFT)",
            icon: Icons.account_tree_rounded,
            isSelected: _format == 'elimination',
            onTap: () => setState(() {
              _format = 'elimination';
              _drawCompleted = false;
            }),
          ),

          // Si format Poule Unique : Explication Règle Toutes Rondes
          if (_format == 'single_pool') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Poule Unique : Toutes les paires se rencontrent (Round-Robin). Le classement officiel détermine directement le Vainqueur (1er 🥇) et le Finaliste (2e 🥈).",
                      style: TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Si format Poules : Choix Sortie de Poule (Règle FFT/ITF)
          if (_format == 'pools_and_bracket') ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.alt_route_rounded, color: AppColors.gold, size: 14),
                SizedBox(width: 6),
                Text(
                  "Règle de sortie de poule :",
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildRadioOption(
              title: "Finale Directe (1er A vs 1er B)",
              subtitle: "Recommandé tournoi 1 jour · Gain d'un tour · Zéro retard",
              isSelected: _finalPhaseType == 'direct_finals',
              onTap: () => setState(() {
                _finalPhaseType = 'direct_finals';
                _drawCompleted = false;
              }),
            ),
            const SizedBox(height: 6),
            _buildRadioOption(
              title: "Demi-finales Croisées (1A vs 2B / 1B vs 2A)",
              subtitle: "Format Championnat officiel · Tournois sur 2 jours",
              isSelected: _finalPhaseType == 'crossover_semis',
              onTap: () => setState(() {
                _finalPhaseType = 'crossover_semis';
                _drawCompleted = false;
              }),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Règle TS1 / TS2 & Inversion 1-Tap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.swap_vert_rounded, color: AppColors.gold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _invertSeeds ? "Position TS : Suggérée France (FFT)" : "Position TS : Standard ITF",
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _invertSeeds
                          ? "TS1 en bas · TS2 en haut (Recommandé en France)"
                          : "TS1 en haut (Ligne 1 / Poule A) · TS2 en bas (Poule B)",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _toggleTsInversion,
                icon: const Icon(Icons.sync_alt_rounded, size: 14, color: Colors.black),
                label: Text(
                  _invertSeeds ? "Standard ITF" : "Suggérer France",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _invertSeeds ? AppColors.gold : Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Choix du nombre de terrains disponibles
          Row(
            children: [
              const Icon(Icons.stadium_rounded, color: AppColors.gold, size: 16),
              const SizedBox(width: 6),
              const Text(
                "Nombre de Terrains disponibles :",
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  "$_numCourts courts",
                  style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [2, 3, 4, 5, 6, 8].map((c) {
                final isSel = _numCourts == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _numCourts = c;
                        _drawCompleted = false;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.gold : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? AppColors.gold : Colors.white24,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        "$c terrains",
                        style: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.stars_rounded, color: AppColors.gold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Attribution automatique intelligente : Le Terrain 1 (Court Central) et le Terrain 2 sont prioritairement réservés aux têtes de série (TS1 / TS2) et aux grandes finales !",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.gold : Colors.white70),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.gold.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.gold : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairsManagerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "2. Paires Engagées (${_pairs.length})",
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _addNewPair,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 14, color: AppColors.coral),
                    label: const Text(
                      "+ Paire",
                      style: TextStyle(color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.coral.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: _addByePair,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 14, color: AppColors.gold),
                    label: const Text(
                      "+ Exempt",
                      style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_pairs.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                "Aucune paire enregistrée. Ajoutez des paires ou des exempts.",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pairs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final pair = _pairs[index];
                return InkWell(
                  onTap: pair.isBye ? null : () => _editPair(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: pair.isBye ? Colors.amber.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: pair.isBye ? Colors.amber.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          alignment: Alignment.center,
                          child: Text(
                            "${index + 1}",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      pair.displayName,
                                      style: TextStyle(
                                        color: pair.isBye ? AppColors.gold : Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (pair.seed != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "TS ${pair.seed}",
                                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (!pair.isBye && pair.weight > 0)
                                Text(
                                  "Poids : ${pair.weight} pts (Rangs: ${pair.player1Rank} / ${pair.player2Rank})",
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                        if (!pair.isBye)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.white54),
                            onPressed: () => _editPair(index),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.only(right: 6),
                            constraints: const BoxConstraints(),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white38),
                          onPressed: () => _removePair(index),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDrawCeremonyAction() {
    return Center(
      child: Column(
        children: [
          if (_isDrawing) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: AppColors.gold, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    "TIRAGE AU SORT OFFICIEL EN COURS...",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Attribution aléatoire certifiée des chapeaux",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _drawProgress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.45),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _startDrawCeremony,
                  icon: const Icon(Icons.casino_rounded, size: 24, color: Colors.black),
                  label: Text(
                    _drawCompleted ? "🎲 Relancer le Tirage Officiel" : "🎲 Lancer le Tirage au Sort Officiel",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawResultsCard() {
    if (_generatedBracket == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sceau d'homologation
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppColors.gold, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TIRAGE OFFICIEL HOMOLOGUÉ",
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (_drawTimestamp != null)
                          Text(
                            DateFormat('dd/MM/yyyy à HH:mm:ss').format(_drawTimestamp!),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Bulle de référence officielle adaptative (ne déborde jamais de l'écran)
              InkWell(
                onTap: () {
                  if (_certificateId != null) {
                    Clipboard.setData(ClipboardData(text: _certificateId!));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Référence du tirage copiée dans le presse-papiers !"),
                        backgroundColor: AppColors.gold,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, size: 13, color: AppColors.gold),
                      const SizedBox(width: 6),
                      const Text(
                        "RÉF : ",
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _certificateId ?? 'CERTIFIED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy_rounded, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Contenu du tirage (Poules ou 1er Tour)
          if ((_format == 'pools_and_bracket' || _format == 'single_pool') && _generatedBracket!.pools.isNotEmpty) ...[
            for (final pool in _generatedBracket!.pools) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.grid_3x3_rounded, color: AppColors.gold, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          pool.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < pool.pairs.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text("${i + 1}. ", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                            Expanded(
                              child: Text(
                                pool.pairs[i].displayName,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (pool.pairs[i].seed != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "TS ${pool.pairs[i].seed}",
                                  style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ] else ...[
            const Text(
              "AFFICHES DU 1ER TOUR :",
              style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final m in _generatedBracket!.mainMatches.where((m) => m.roundIndex == 0).take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "M${m.matchIndex + 1}",
                        style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${m.pair1?.displayName ?? 'TBD'}  🆚  ${m.pair2?.displayName ?? 'TBD'}",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCertificationActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _exportPdfCertificate,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                label: const Text(
                  "PV Officiel (PDF)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: AppColors.gold, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareWhatsApp,
                icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                label: const Text(
                  "Partager WhatsApp",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _applyAndSave,
            icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.black),
            label: const Text(
              "Valider & Appliquer au Tableau en Direct",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
