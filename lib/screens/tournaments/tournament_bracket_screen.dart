import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/tournament.dart';
import '../../models/tournament_bracket_model.dart';
import '../../services/bracket_generator_service.dart';
import '../../theme/colors.dart';

class TournamentBracketScreen extends StatefulWidget {
  final TournamentModel tournament;
  final bool isAuthorized;

  const TournamentBracketScreen({
    super.key,
    required this.tournament,
    required this.isAuthorized,
  });

  @override
  State<TournamentBracketScreen> createState() => _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _bracketRef => FirebaseFirestore.instance
      .collection('tournaments')
      .doc(widget.tournament.id)
      .collection('bracket')
      .doc('current');

  Future<void> _saveBracket(TournamentBracket bracket) async {
    setState(() => _isSaving = true);
    try {
      await _bracketRef.set(bracket.toMap(), SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de sauvegarde : $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tableau & Arbre Officiel",
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.tournament.name,
              style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (widget.isAuthorized)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: AppColors.gold, size: 14),
                  SizedBox(width: 4),
                  Text("JAT", style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events_outlined, size: 20), text: "Principal"),
            Tab(icon: Icon(Icons.shield_outlined, size: 20), text: "Consolante"),
            Tab(icon: Icon(Icons.people_outline, size: 20), text: "Paires"),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _bracketRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }

          TournamentBracket bracket;
          if (snapshot.hasData && snapshot.data?.exists == true && snapshot.data?.data() != null) {
            bracket = TournamentBracket.fromMap(snapshot.data!.data()!, widget.tournament.id);
          } else {
            bracket = TournamentBracket(
              tournamentId: widget.tournament.id,
              numCourts: 4,
              status: 'draft',
              updatedAt: DateTime.now(),
            );
          }

          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  _buildMainDrawTab(bracket),
                  _buildConsolationTab(bracket),
                  _buildPairsManagementTab(bracket),
                ],
              ),
              if (_isSaving)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 1: TABLEAU PRINCIPAL
  // ==========================================
  Widget _buildMainDrawTab(TournamentBracket bracket) {
    if (bracket.mainMatches.isEmpty) {
      return _buildEmptyState(
        title: "Tableau non généré",
        subtitle: widget.isAuthorized
            ? "Inscrivez vos paires dans l'onglet 'Paires' puis cliquez sur 'Générer l'Arbre Officiel'."
            : "Le juge-arbitre n'a pas encore publié l'arbre de ce tournoi.",
        actionText: widget.isAuthorized ? "Gérer les Paires" : null,
        onAction: widget.isAuthorized ? () => _tabController.animateTo(2) : null,
      );
    }

    // Regrouper les matches par roundIndex
    final Map<int, List<BracketMatch>> rounds = {};
    for (var m in bracket.mainMatches) {
      rounds.putIfAbsent(m.roundIndex, () => []).add(m);
    }
    final sortedRoundKeys = rounds.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedRoundKeys.map((roundIdx) {
          final matches = rounds[roundIdx]!;
          final roundName = matches.first.roundName.toUpperCase();
          return Container(
            width: 290,
            margin: const EdgeInsets.only(right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête du tour
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    roundName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Liste des matches du tour
                ...matches.map((m) => _buildMatchCard(m, bracket, isConsolation: false)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // TAB 2: TABLEAU DE CONSOLANTE
  // ==========================================
  Widget _buildConsolationTab(TournamentBracket bracket) {
    if (bracket.consolationMatches.isEmpty) {
      return _buildEmptyState(
        title: "Consolante non disponible",
        subtitle: "Le tableau de consolante se remplit automatiquement dès que les matches du 1er tour sont joués.",
      );
    }

    final Map<int, List<BracketMatch>> rounds = {};
    for (var m in bracket.consolationMatches) {
      rounds.putIfAbsent(m.roundIndex, () => []).add(m);
    }
    final sortedRoundKeys = rounds.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedRoundKeys.map((roundIdx) {
          final matches = rounds[roundIdx]!;
          final roundName = matches.first.roundName.toUpperCase();
          return Container(
            width: 290,
            margin: const EdgeInsets.only(right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    roundName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...matches.map((m) => _buildMatchCard(m, bracket, isConsolation: true)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // CARTE DE MATCH INTERACTIVE
  // ==========================================
  Widget _buildMatchCard(BracketMatch match, TournamentBracket bracket, {required bool isConsolation}) {
    final isDone = match.isCompleted;
    final isLive = match.isInProgress;
    final isBye = match.isBye;

    Color borderColor = Colors.white12;
    if (isDone) borderColor = const Color(0xFF10B981).withValues(alpha: 0.5); // Vert émeraude
    if (isLive) borderColor = AppColors.gold.withValues(alpha: 0.8);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isLive ? 2.0 : 1.2),
        boxShadow: [
          BoxShadow(
            color: isLive ? AppColors.gold.withValues(alpha: 0.15) : Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barre supérieure : Numéro + Terrain + Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Court
                InkWell(
                  onTap: (widget.isAuthorized && !isDone && !isBye)
                      ? () => _showCourtDialog(match, bracket)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: match.court != null ? AppColors.gold.withValues(alpha: 0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sports_tennis,
                          size: 12,
                          color: match.court != null ? AppColors.gold : Colors.white60,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          match.court != null ? "Court ${match.court}" : "Court -",
                          style: TextStyle(
                            color: match.court != null ? AppColors.gold : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.isAuthorized && !isDone && !isBye) ...[
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white60),
                        ],
                      ],
                    ),
                  ),
                ),
                // Statut badge
                if (isBye)
                  const Text("EXEMPT (BYE)", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold))
                else if (isDone)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        match.score ?? "Terminé",
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ],
                  )
                else if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text("EN COURS", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                  )
                else
                  const Text("À VENIR", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Paires (Slot 1 & Slot 2)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildPairRow(match.pair1, isWinner: match.winnerId == match.pair1?.id, isCompleted: isDone),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _buildPairRow(match.pair2, isWinner: match.winnerId == match.pair2?.id, isCompleted: isDone),
              ],
            ),
          ),

          // Bouton d'action pour le Juge-Arbitre
          if (widget.isAuthorized && !isBye)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: InkWell(
                onTap: match.isReady ? () => _showScoreDialog(match, bracket) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDone ? Icons.edit_note_rounded : Icons.scoreboard_outlined,
                          size: 15,
                          color: match.isReady ? AppColors.gold : Colors.white24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDone ? "Modifier le score" : "Saisir le score officiel",
                          style: TextStyle(
                            color: match.isReady ? AppColors.gold : Colors.white24,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPairRow(TournamentPair? pair, {required bool isWinner, required bool isCompleted}) {
    if (pair == null) {
      return const Row(
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 14, color: Colors.white38),
          SizedBox(width: 8),
          Text("En attente...", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      );
    }

    if (pair.isBye) {
      return const Row(
        children: [
          Icon(Icons.remove_circle_outline, size: 14, color: Colors.white38),
          SizedBox(width: 8),
          Text("EXEMPT (BYE)", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      );
    }

    return Row(
      children: [
        // Seed Badge
        if (pair.seed != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "TS${pair.seed}",
              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),
        ],
        // Noms des joueurs
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pair.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isWinner ? AppColors.gold : Colors.white,
                  fontSize: 13,
                  fontWeight: isWinner ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
              Text(
                "Poids : ${pair.weight < 9999 ? pair.weight : 'NC'}",
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
        if (isWinner)
          const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 16),
      ],
    );
  }

  // ==========================================
  // TAB 3: GESTION DES PAIRES & TÊTES DE SÉRIE
  // ==========================================
  Widget _buildPairsManagementTab(TournamentBracket bracket) {
    final pairs = bracket.pairs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.isAuthorized
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text("Inscrire une Paire", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddPairDialog(bracket),
            )
          : null,
      body: Column(
        children: [
          // Bandeau récapitulatif & Action Générer Arbre
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${pairs.length} Paires Inscrites",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Format estimé : Tableau de ${BracketGeneratorService.getBracketSize(pairs.length)}",
                          style: const TextStyle(color: AppColors.gold, fontSize: 12),
                        ),
                      ],
                    ),
                    if (widget.isAuthorized)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.account_tree_rounded, size: 18),
                        label: const Text("Générer l'Arbre", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        onPressed: pairs.length < 2
                            ? null
                            : () => _confirmGenerateBracket(bracket),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Liste des paires
          Expanded(
            child: pairs.isEmpty
                ? _buildEmptyState(
                    title: "Aucune paire inscrite",
                    subtitle: widget.isAuthorized
                        ? "Utilisez le bouton ci-dessous pour inscrire la première paire du tournoi."
                        : "Aucune équipe n'est encore enregistrée pour ce tournoi.",
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: pairs.length,
                    itemBuilder: (context, index) {
                      final pair = pairs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161F2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: pair.seed != null ? AppColors.gold.withValues(alpha: 0.5) : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Rang ou Seed
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: pair.seed != null ? AppColors.gold : Colors.white10,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  pair.seed != null ? "TS${pair.seed}" : "#${index + 1}",
                                  style: TextStyle(
                                    color: pair.seed != null ? Colors.black : Colors.white70,
                                    fontSize: pair.seed != null ? 11 : 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Noms et rangs
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${pair.player1Name} (N°${pair.player1Rank < 9999 ? pair.player1Rank : 'NC'})",
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "${pair.player2Name} (N°${pair.player2Rank < 9999 ? pair.player2Rank : 'NC'})",
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            // Poids
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Poids : ${pair.weight < 9999 ? pair.weight : 'NC'}",
                                style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (widget.isAuthorized) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  final updatedPairs = List<TournamentPair>.from(bracket.pairs)..removeAt(index);
                                  _saveBracket(bracket.copyWith(pairs: updatedPairs));
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGUES JAT (SAISIE SCORE & TERRAIN)
  // ==========================================
  void _showScoreDialog(BracketMatch match, TournamentBracket bracket) {
    if (match.pair1 == null || match.pair2 == null) return;

    final scoreCtrl = TextEditingController(text: match.score ?? '');
    String selectedWinnerId = match.winnerId ?? match.pair1!.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF141923),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.sports_score_rounded, color: AppColors.gold, size: 24),
                SizedBox(width: 10),
                Text("Score Officiel du Match", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Désignez la paire gagnante :", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 10),
                  // Choix Gagnant Paire 1
                  _buildWinnerSelectionTile(
                    pair: match.pair1!,
                    isSelected: selectedWinnerId == match.pair1!.id,
                    onTap: () => setDialogState(() => selectedWinnerId = match.pair1!.id),
                  ),
                  const SizedBox(height: 8),
                  // Choix Gagnant Paire 2
                  _buildWinnerSelectionTile(
                    pair: match.pair2!,
                    isSelected: selectedWinnerId == match.pair2!.id,
                    onTap: () => setDialogState(() => selectedWinnerId = match.pair2!.id),
                  ),
                  const SizedBox(height: 16),
                  const Text("Score officiel (obligatoire) :", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: scoreCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Ex : 6/4 7/5 ou 9/4",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black38,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Raccourcis rapides
                  Wrap(
                    spacing: 6,
                    children: ["6/4 6/3", "6/3 6/4", "9/4", "9/5", "6/2 6/2"].map((preset) {
                      return ActionChip(
                        label: Text(preset, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        backgroundColor: Colors.white10,
                        padding: EdgeInsets.zero,
                        onPressed: () => setDialogState(() => scoreCtrl.text = preset),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                onPressed: () {
                  final scoreText = scoreCtrl.text.trim();
                  if (scoreText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Veuillez saisir le score du match."), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final updated = BracketGeneratorService.recordMatchScore(
                    bracket: bracket,
                    matchId: match.id,
                    score: scoreText,
                    winnerId: selectedWinnerId,
                  );
                  _saveBracket(updated);
                },
                child: const Text("Valider & Avancer", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWinnerSelectionTile({
    required TournamentPair pair,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.15) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.gold : Colors.white12,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.gold : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pair.displayName,
                style: TextStyle(
                  color: isSelected ? AppColors.gold : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourtDialog(BracketMatch match, TournamentBracket bracket) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF141923),
        title: const Text("Attribuer un Terrain", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        children: List.generate(bracket.numCourts, (i) {
          final courtNum = i + 1;
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              final updated = BracketGeneratorService.assignCourt(
                bracket: bracket,
                matchId: match.id,
                court: courtNum,
              );
              _saveBracket(updated);
            },
            child: Row(
              children: [
                const Icon(Icons.sports_tennis, color: AppColors.gold, size: 18),
                const SizedBox(width: 12),
                Text("Terrain $courtNum", style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showAddPairDialog(TournamentBracket bracket) {
    final p1NameCtrl = TextEditingController();
    final p1RankCtrl = TextEditingController();
    final p2NameCtrl = TextEditingController();
    final p2RankCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141923),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.gold),
            SizedBox(width: 10),
            Text("Inscrire une Paire", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Joueur 1
              TextField(
                controller: p1NameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Joueur 1 (Nom Prénom)",
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              TextField(
                controller: p1RankCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Classement FFT (ex: 25 ou vide si NC)",
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 16),
              // Joueur 2
              TextField(
                controller: p2NameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Joueur 2 (Nom Prénom)",
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              TextField(
                controller: p2RankCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Classement FFT (ex: 30 ou vide si NC)",
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
            onPressed: () {
              final n1 = p1NameCtrl.text.trim();
              final n2 = p2NameCtrl.text.trim();
              if (n1.isEmpty || n2.isEmpty) return;

              final r1 = int.tryParse(p1RankCtrl.text.trim()) ?? 9999;
              final r2 = int.tryParse(p2RankCtrl.text.trim()) ?? 9999;

              final newPair = TournamentPair(
                id: "pair_${DateTime.now().millisecondsSinceEpoch}",
                player1Name: n1,
                player1Rank: r1,
                player2Name: n2,
                player2Rank: r2,
              );

              Navigator.pop(ctx);
              final updatedPairs = List<TournamentPair>.from(bracket.pairs)..add(newPair);
              _saveBracket(bracket.copyWith(pairs: updatedPairs));
            },
            child: const Text("Ajouter", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmGenerateBracket(TournamentBracket bracket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141923),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Générer l'Arbre Officiel ?", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          "L'application va ordonner les ${bracket.pairs.length} paires selon les règles FFT (TS1 en bas, TS2 en haut, et placer les BYE). Êtes-vous sûr ?",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler", style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              final newBracket = BracketGeneratorService.generateBracket(
                tournamentId: widget.tournament.id,
                registeredPairs: bracket.pairs,
                numCourts: bracket.numCourts,
              );
              _saveBracket(newBracket);
              _tabController.animateTo(0);
            },
            child: const Text("Générer", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle, String? actionText, VoidCallback? onAction}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_tree_outlined, size: 54, color: Colors.white24),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                onPressed: onAction,
                child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
