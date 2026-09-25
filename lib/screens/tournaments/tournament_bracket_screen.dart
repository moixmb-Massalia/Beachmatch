import 'package:firebase_auth/firebase_auth.dart';
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
  String _selectedCategory = 'double_messieurs';
  bool _forceJatMode = true; // Activé par défaut pour permettre au JAT de gérer immédiatement

  bool get _isJat =>
      widget.isAuthorized ||
      _forceJatMode ||
      (FirebaseAuth.instance.currentUser != null);

  final List<Map<String, dynamic>> _categories = [
    {'key': 'double_messieurs', 'label': 'Double Hommes', 'icon': Icons.sports_tennis},
    {'key': 'double_dames', 'label': 'Double Dames', 'icon': Icons.sports_tennis_outlined},
    {'key': 'double_mixtes', 'label': 'Double Mixtes', 'icon': Icons.star_rounded},
  ];

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
      .collection('brackets')
      .doc(_selectedCategory);

  DocumentReference<Map<String, dynamic>> get _legacyRef => FirebaseFirestore.instance
      .collection('tournaments')
      .doc(widget.tournament.id)
      .collection('bracket')
      .doc('current');

  Future<void> _saveBracket(TournamentBracket bracket) async {
    setState(() => _isSaving = true);
    try {
      await _bracketRef.set(bracket.toMap(), SetOptions(merge: true));
      // Sync legacy root if double_messieurs
      if (_selectedCategory == 'double_messieurs') {
        await _legacyRef.set(bracket.toMap(), SetOptions(merge: true));
      }
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
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                setState(() => _forceJatMode = !_forceJatMode);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isJat ? "Mode JAT (Juge-Arbitre) Activé" : "Mode Spectateur Activé"),
                    duration: const Duration(seconds: 2),
                    backgroundColor: _isJat ? AppColors.gold : Colors.grey[800],
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isJat ? AppColors.gold.withValues(alpha: 0.2) : Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isJat ? AppColors.gold : Colors.white24, width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: _isJat ? AppColors.gold : Colors.white70, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      _isJat ? "JAT ACTIF" : "SPECTATEUR",
                      style: TextStyle(
                        color: _isJat ? AppColors.gold : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. SELECTEUR DE CATEGORIE (Hommes / Dames / Mixtes)
          _buildCategorySelector(),

          // 2. STREAM DE DONNEES FIRESTORE
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _bracketRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.gold));
                }

                TournamentBracket bracket;
                if (snapshot.hasData && snapshot.data?.exists == true && snapshot.data?.data() != null) {
                  bracket = TournamentBracket.fromMap(snapshot.data!.data()!, widget.tournament.id);
                } else {
                  // Fallback: check legacy ref if category is messieurs
                  bracket = TournamentBracket(
                    tournamentId: widget.tournament.id,
                    category: _selectedCategory,
                    format: _selectedCategory == 'double_mixtes' ? 'elimination' : 'pools_and_bracket',
                    numCourts: 4,
                    status: 'draft',
                    updatedAt: DateTime.now(),
                  );
                }

                final isPoolFormat = bracket.format == 'pools_and_bracket';

                return Column(
                  children: [
                    // Sub-tab bar dynamically adapted to format
                    Container(
                      color: const Color(0xFF161F2E),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.gold,
                        indicatorWeight: 3,
                        labelColor: AppColors.gold,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: isPoolFormat
                            ? const [
                                Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: "Poules A & B"),
                                Tab(icon: Icon(Icons.emoji_events_outlined, size: 18), text: "Phase Finale"),
                                Tab(icon: Icon(Icons.people_outline, size: 18), text: "Paires"),
                              ]
                            : const [
                                Tab(icon: Icon(Icons.emoji_events_outlined, size: 18), text: "Principal"),
                                Tab(icon: Icon(Icons.shield_outlined, size: 18), text: "Consolante"),
                                Tab(icon: Icon(Icons.people_outline, size: 18), text: "Paires"),
                              ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          TabBarView(
                            controller: _tabController,
                            children: isPoolFormat
                                ? [
                                    _buildPoolsTab(bracket),
                                    _buildFinalPhaseTab(bracket),
                                    _buildPairsManagementTab(bracket),
                                  ]
                                : [
                                    _buildMainDrawTab(bracket),
                                    _buildConsolationTab(bracket),
                                    _buildPairsManagementTab(bracket),
                                  ],
                          ),
                          if (_isSaving)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: CircularProgressIndicator(color: AppColors.gold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SELECTEUR DE CATEGORIE
  // ==========================================
  Widget _buildCategorySelector() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  if (_selectedCategory != cat['key']) {
                    setState(() {
                      _selectedCategory = cat['key'];
                      _tabController.index = 0;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.gold : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : Colors.white24,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==========================================
  // FORMAT POULES : ONGLET 1 - POULES A & B
  // ==========================================
  Widget _buildPoolsTab(TournamentBracket bracket) {
    if (bracket.pools.isEmpty) {
      return _buildEmptyState(
        title: "Poules non générées",
        subtitle: _isJat
            ? "Inscrivez vos équipes dans l'onglet 'Paires' puis générez les poules."
            : "Le juge-arbitre n'a pas encore publié les poules de ce tableau.",
        actionText: _isJat ? "Gérer les Paires" : null,
        onAction: _isJat ? () => _tabController.animateTo(2) : null,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        for (final pool in bracket.pools) ...[
          _buildPoolSection(pool, bracket),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildPoolSection(TournamentPool pool, TournamentBracket bracket) {
    final standings = pool.calculateStandings();
    final isPouleA = pool.id == "poule_a";
    final accentColor = isPouleA ? AppColors.gold : AppColors.coral;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête Poule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(Icons.sports_tennis, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  pool.name.toUpperCase(),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Text(
                  "${pool.pairs.length} Équipes · ${pool.matches.length} Matches",
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Tableau de classement de la poule
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CLASSEMENT EN DIRECT",
                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(30), // Rang
                      1: FlexColumnWidth(4),  // Équipe
                      2: FlexColumnWidth(1.2), // V
                      3: FlexColumnWidth(1.2), // D
                      4: FlexColumnWidth(1.5), // Sets
                      5: FlexColumnWidth(1.5), // Diff
                      6: FlexColumnWidth(1.5), // Pts
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white12)),
                        ),
                        children: [
                          _buildTh("#"),
                          _buildTh("ÉQUIPE"),
                          _buildTh("V"),
                          _buildTh("D"),
                          _buildTh("SETS"),
                          _buildTh("+/-"),
                          _buildTh("PTS"),
                        ],
                      ),
                      for (int i = 0; i < standings.length; i++)
                        _buildStandingRow(i + 1, standings[i], accentColor),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Matches de la poule
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "MATCHES DE POULE",
                      style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    if (_isJat)
                      Text(
                        "Arbitre : Saisie des scores & terrains",
                        style: TextStyle(color: AppColors.gold.withValues(alpha: 0.8), fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ...pool.matches.map((m) => _buildPoolMatchCard(m, pool, bracket)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTh(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }

  TableRow _buildStandingRow(int rank, PoolStanding standing, Color accent) {
    String medal = "$rank";
    if (rank == 1) medal = "🥇";
    if (rank == 2) medal = "🥈";
    if (rank == 3) medal = "🥉";

    return TableRow(
      decoration: BoxDecoration(
        color: rank <= 2 ? accent.withValues(alpha: 0.05) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(medal, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                standing.pair.displayName,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              if (standing.pair.seed != null)
                Text(
                  "TS${standing.pair.seed} · Poids ${standing.pair.weight}",
                  style: const TextStyle(color: AppColors.gold, fontSize: 10),
                ),
            ],
          ),
        ),
        Text("${standing.won}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
        Text("${standing.lost}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
        Text("${standing.setsWon}-${standing.setsLost}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(standing.diffGames >= 0 ? "+${standing.diffGames}" : "${standing.diffGames}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "${standing.points}",
            textAlign: TextAlign.center,
            style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CARTE MATCH DE POULE
  // ==========================================
  Widget _buildPoolMatchCard(BracketMatch match, TournamentPool pool, TournamentBracket bracket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: match.isCompleted ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: match.isCompleted
                      ? Colors.greenAccent.withValues(alpha: 0.2)
                      : (match.isInProgress ? AppColors.gold.withValues(alpha: 0.2) : Colors.white12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  match.isCompleted ? "TERMINÉ" : (match.isInProgress ? "EN COURS" : "À VENIR"),
                  style: TextStyle(
                    color: match.isCompleted ? Colors.greenAccent : (match.isInProgress ? AppColors.gold : Colors.white70),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (match.court != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "TERRAIN ${match.court}",
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
              const Spacer(),
              if (match.score != null)
                Text(
                  match.score!,
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              if (_isJat) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.white70, size: 18),
                  tooltip: "Saisie libre / Modifier",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showManualMatchEditDialog(match, bracket),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _buildPairRow(match.pair1, match.winnerId == match.pair1?.id, match.isCompleted),
          const SizedBox(height: 4),
          _buildPairRow(match.pair2, match.winnerId == match.pair2?.id, match.isCompleted),
          if (_isJat) ...[
            const Divider(color: Colors.white12, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.stadium_outlined, size: 14, color: Colors.blueAccent),
                  label: Text(
                    match.court != null ? "Terrain ${match.court}" : "Attribuer Terrain",
                    style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showAssignCourtDialog(match, bracket),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit, size: 14, color: Colors.black),
                  label: Text(
                    match.isCompleted ? "Modifier Score" : "Saisir Score",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showRecordScoreDialog(match, bracket, poolId: pool.id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // FORMAT POULES : ONGLET 2 - PHASE FINALE
  // ==========================================
  Widget _buildFinalPhaseTab(TournamentBracket bracket) {
    if (bracket.mainMatches.isEmpty) {
      return _buildEmptyState(
        title: "Phase Finale non programmée",
        subtitle: "Les demi-finales et finales apparaîtront dès que les poules seront configurées.",
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Info JAT
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Les équipes se qualifient automatiquement à l'issue des poules (1er A vs 2ème B, 1er B vs 2ème A, et 3ème A vs 3ème B). Vous pouvez aussi forcer manuellement n'importe quelle équipe avec l'icône crayon.",
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),

        const Text(
          "DEMI-FINALES CROISÉES",
          style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        ...bracket.mainMatches.where((m) => m.matchCode == 'DF1' || m.matchCode == 'DF2').map(
          (m) => _buildFinalPhaseMatchCard(m, bracket),
        ),

        const SizedBox(height: 20),
        const Text(
          "GRANDE FINALE & PETITE FINALE (PLACE 3 / 4)",
          style: TextStyle(color: AppColors.coral, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        ...bracket.mainMatches.where((m) => m.matchCode == 'FINALE' || m.matchCode == 'PLACE_3_4').map(
          (m) => _buildFinalPhaseMatchCard(m, bracket),
        ),

        const SizedBox(height: 20),
        const Text(
          "MATCH DE CLASSEMENT (PLACE 5 / 6)",
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        ...bracket.mainMatches.where((m) => m.matchCode == 'PLACE_5_6').map(
          (m) => _buildFinalPhaseMatchCard(m, bracket),
        ),
      ],
    );
  }

  Widget _buildFinalPhaseMatchCard(BracketMatch match, TournamentBracket bracket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: match.isCompleted
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : (match.isInProgress ? AppColors.gold.withValues(alpha: 0.5) : Colors.white12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                match.roundName.toUpperCase(),
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              if (match.court != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "TERRAIN ${match.court}",
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              if (match.score != null)
                Text(
                  match.score!,
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              if (_isJat) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.white70, size: 20),
                  tooltip: "Saisie libre JAT",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showManualMatchEditDialog(match, bracket),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _buildPairRow(
            match.pair1,
            match.winnerId == match.pair1?.id,
            match.isCompleted,
            fallbackLabel: _getFallbackSlotName(match, 1),
          ),
          const SizedBox(height: 6),
          _buildPairRow(
            match.pair2,
            match.winnerId == match.pair2?.id,
            match.isCompleted,
            fallbackLabel: _getFallbackSlotName(match, 2),
          ),
          if (_isJat) ...[
            const Divider(color: Colors.white12, height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.stadium_outlined, size: 14, color: Colors.blueAccent),
                  label: Text(
                    match.court != null ? "Terrain ${match.court}" : "Terrain",
                    style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showAssignCourtDialog(match, bracket),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit, size: 14, color: Colors.black),
                  label: Text(
                    match.isCompleted ? "Modifier Score" : "Saisir Score",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showRecordScoreDialog(match, bracket),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getFallbackSlotName(BracketMatch match, int slot) {
    if (match.matchCode == 'DF1') return slot == 1 ? "1er Poule A" : "2ème Poule B";
    if (match.matchCode == 'DF2') return slot == 1 ? "1er Poule B" : "2ème Poule A";
    if (match.matchCode == 'FINALE') return slot == 1 ? "Vainqueur Demi 1" : "Vainqueur Demi 2";
    if (match.matchCode == 'PLACE_3_4') return slot == 1 ? "Perdant Demi 1" : "Perdant Demi 2";
    if (match.matchCode == 'PLACE_5_6') return slot == 1 ? "3ème Poule A" : "3ème Poule B";
    return "En attente...";
  }

  // ==========================================
  // FORMAT ELIMINATION : ONGLET 1 - TABLEAU PRINCIPAL
  // ==========================================
  Widget _buildMainDrawTab(TournamentBracket bracket) {
    if (bracket.mainMatches.isEmpty) {
      return _buildEmptyState(
        title: "Tableau non généré",
        subtitle: _isJat
            ? "Inscrivez vos paires dans l'onglet 'Paires' puis cliquez sur 'Générer l'Arbre Officiel'."
            : "Le juge-arbitre n'a pas encore publié l'arbre de ce tournoi.",
        actionText: _isJat ? "Gérer les Paires" : null,
        onAction: _isJat ? () => _tabController.animateTo(2) : null,
      );
    }

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
            width: 300,
            margin: const EdgeInsets.only(right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                ...matches.map((m) => _buildMatchCard(m, bracket, isConsolation: false)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // FORMAT ELIMINATION : ONGLET 2 - CONSOLANTE
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
            width: 300,
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
  // CARTE DE MATCH (Arbre Élimination Directe)
  // ==========================================
  Widget _buildMatchCard(BracketMatch match, TournamentBracket bracket, {required bool isConsolation}) {
    final borderColor = match.isCompleted
        ? Colors.greenAccent.withValues(alpha: 0.4)
        : (match.isInProgress ? AppColors.gold.withValues(alpha: 0.6) : Colors.white12);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: match.isInProgress ? 1.5 : 1),
        boxShadow: match.isInProgress
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: match.isCompleted
                        ? Colors.greenAccent.withValues(alpha: 0.2)
                        : (match.isInProgress ? AppColors.gold.withValues(alpha: 0.2) : Colors.white12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    match.isCompleted ? "TERMINÉ" : (match.isInProgress ? "EN COURS" : "À VENIR"),
                    style: TextStyle(
                      color: match.isCompleted ? Colors.greenAccent : (match.isInProgress ? AppColors.gold : Colors.white70),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (match.court != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "TERRAIN ${match.court}",
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
                const Spacer(),
                if (match.score != null)
                  Text(
                    match.score!,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (_isJat) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.white70, size: 18),
                    tooltip: "Saisie libre JAT",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showManualMatchEditDialog(match, bracket),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildPairRow(match.pair1, match.winnerId == match.pair1?.id, match.isCompleted),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _buildPairRow(match.pair2, match.winnerId == match.pair2?.id, match.isCompleted),
              ],
            ),
          ),
          if (_isJat && !match.isBye)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                border: const Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.stadium_outlined, size: 13, color: Colors.blueAccent),
                    label: Text(
                      match.court != null ? "T.${match.court}" : "Terrain",
                      style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showAssignCourtDialog(match, bracket),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 13, color: Colors.black),
                    label: Text(
                      match.isCompleted ? "Score" : "Saisir",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showRecordScoreDialog(match, bracket),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPairRow(TournamentPair? pair, bool isWinner, bool isCompleted, {String? fallbackLabel}) {
    if (pair == null) {
      return Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fallbackLabel ?? "En attente du tour précédent...",
              style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      );
    }

    if (pair.isBye) {
      return const Row(
        children: [
          Icon(Icons.remove_circle_outline, size: 14, color: Colors.white30),
          SizedBox(width: 8),
          Text(
            "EXEMPT (BYE)",
            style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (isCompleted && isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
          )
        else
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isWinner ? AppColors.gold : Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
        Expanded(
          child: Text(
            pair.displayName,
            style: TextStyle(
              color: isCompleted ? (isWinner ? Colors.white : Colors.white54) : Colors.white,
              fontSize: 13,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (pair.seed != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
            ),
            child: Text(
              "TS${pair.seed}",
              style: const TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // ONGLET 3 : GESTION DES PAIRES
  // ==========================================
  Widget _buildPairsManagementTab(TournamentBracket bracket) {
    final pairs = bracket.pairs;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isJat) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Actions Juge-Arbitre (JAT)",
                      style: TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Configurez les équipes de la catégorie (${_getCategoryLabel(_selectedCategory)}) et générez le format adapté.",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.person_add_alt_1, size: 16, color: AppColors.gold),
                        label: const Text("Inscrire Paire", style: TextStyle(color: AppColors.gold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.gold),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _showAddPairDialog(bracket),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.account_tree_rounded, size: 16, color: Colors.black),
                        label: const Text("Générer Tableau", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _showGenerateBracketDialog(bracket),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "ÉQUIPES INSCRITES (${pairs.length})",
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const Text(
              "Poids = Rang 1 + Rang 2",
              style: TextStyle(color: AppColors.gold, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (pairs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                "Aucune paire enregistrée pour cette catégorie.",
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          ...pairs.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: p.seed != null ? AppColors.gold.withValues(alpha: 0.4) : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.seed != null ? AppColors.gold : const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      p.seed != null ? "${p.seed}" : "${idx + 1}",
                      style: TextStyle(
                        color: p.seed != null ? Colors.black : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${p.player1Name} (${p.player1Rank}) · ${p.player2Name} (${p.player2Rank})",
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Poids ${p.weight}",
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      if (p.seed != null)
                        const Text(
                          "TÊTE DE SÉRIE",
                          style: TextStyle(color: AppColors.coral, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // DIALOG : SAISIE LIBRE JAT
  // ==========================================
  void _showManualMatchEditDialog(BracketMatch match, TournamentBracket bracket) {
    final p1Ctrl = TextEditingController(text: match.pair1?.displayName ?? "");
    final p2Ctrl = TextEditingController(text: match.pair2?.displayName ?? "");
    final scoreCtrl = TextEditingController(text: match.score ?? "");
    int? selectedWinner = match.winnerId != null ? (match.winnerId == match.pair1?.id ? 1 : 2) : null;
    int? selectedCourt = match.court;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF161F2E),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: AppColors.gold, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Saisie Libre JAT · ${match.roundName}",
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Vous pouvez modifier directement le score, assigner un terrain, ou forcer les noms des paires.",
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 12),

                // Équipe 1
                const Text("ÉQUIPE 1", style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: p1Ctrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Nom de la Paire 1",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),

                // Équipe 2
                const Text("ÉQUIPE 2", style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: p2Ctrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Nom de la Paire 2",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // Score
                const Text("SCORE (Ex: 6/4 6/3, 9/4, WO)", style: TextStyle(color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: scoreCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Ex: 6/4 6/3",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // Vainqueur
                const Text("PAIRE GAGNANTE", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Équipe 1"),
                        selected: selectedWinner == 1,
                        onSelected: (val) => setDlgState(() => selectedWinner = val ? 1 : null),
                        selectedColor: AppColors.gold,
                        labelStyle: TextStyle(color: selectedWinner == 1 ? Colors.black : Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Équipe 2"),
                        selected: selectedWinner == 2,
                        onSelected: (val) => setDlgState(() => selectedWinner = val ? 2 : null),
                        selectedColor: AppColors.gold,
                        labelStyle: TextStyle(color: selectedWinner == 2 ? Colors.black : Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Terrain
                const Text("TERRAIN", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [null, 1, 2, 3, 4, 5].map((c) {
                    final isSel = selectedCourt == c;
                    return ChoiceChip(
                      label: Text(c == null ? "Aucun" : "T.$c"),
                      selected: isSel,
                      onSelected: (val) => setDlgState(() => selectedCourt = val ? c : null),
                      selectedColor: Colors.blueAccent,
                      labelStyle: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 11),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () async {
                Navigator.pop(ctx);
                TournamentPair? pair1 = match.pair1;
                TournamentPair? pair2 = match.pair2;

                if (p1Ctrl.text.trim().isNotEmpty && p1Ctrl.text.trim() != match.pair1?.displayName) {
                  pair1 = TournamentPair(
                    id: match.pair1?.id ?? "free_p1_${DateTime.now().millisecondsSinceEpoch}",
                    player1Name: p1Ctrl.text.trim(),
                    player2Name: "",
                  );
                }
                if (p2Ctrl.text.trim().isNotEmpty && p2Ctrl.text.trim() != match.pair2?.displayName) {
                  pair2 = TournamentPair(
                    id: match.pair2?.id ?? "free_p2_${DateTime.now().millisecondsSinceEpoch}",
                    player1Name: p2Ctrl.text.trim(),
                    player2Name: "",
                  );
                }

                String? winId;
                if (selectedWinner == 1) winId = pair1?.id;
                if (selectedWinner == 2) winId = pair2?.id;

                final isDone = scoreCtrl.text.trim().isNotEmpty && winId != null;

                final updatedMatch = match.copyWith(
                  pair1: pair1,
                  pair2: pair2,
                  score: scoreCtrl.text.trim().isEmpty ? null : scoreCtrl.text.trim(),
                  winnerId: winId,
                  court: selectedCourt,
                  clearCourt: selectedCourt == null,
                  status: isDone ? 'completed' : (selectedCourt != null ? 'in_progress' : 'pending'),
                );

                TournamentBracket newBracket = bracket;
                if (match.poolId != null) {
                  final newPools = bracket.pools.map((p) {
                    if (p.id == match.poolId) {
                      final updatedMatches = p.matches.map((m) => m.id == match.id ? updatedMatch : m).toList();
                      return p.copyWith(matches: updatedMatches);
                    }
                    return p;
                  }).toList();
                  newBracket = newBracket.copyWith(pools: newPools);
                } else {
                  final isMain = bracket.mainMatches.any((m) => m.id == match.id);
                  if (isMain) {
                    final updatedMain = bracket.mainMatches.map((m) => m.id == match.id ? updatedMatch : m).toList();
                    newBracket = newBracket.copyWith(mainMatches: updatedMain);
                  } else {
                    final updatedConso = bracket.consolationMatches.map((m) => m.id == match.id ? updatedMatch : m).toList();
                    newBracket = newBracket.copyWith(consolationMatches: updatedConso);
                  }
                }

                if (isDone) {
                  if (match.poolId != null) {
                    newBracket = BracketGeneratorService.recordPoolMatchScore(
                      bracket: newBracket,
                      poolId: match.poolId!,
                      matchId: match.id,
                      score: scoreCtrl.text.trim(),
                      winnerId: winId,
                    );
                  } else {
                    newBracket = BracketGeneratorService.recordMatchScore(
                      bracket: newBracket,
                      matchId: match.id,
                      score: scoreCtrl.text.trim(),
                      winnerId: winId,
                    );
                  }
                }

                await _saveBracket(newBracket);
              },
              child: const Text("Enregistrer", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOG : SAISIE DU SCORE
  // ==========================================
  void _showRecordScoreDialog(BracketMatch match, TournamentBracket bracket, {String? poolId}) {
    if (match.pair1 == null || match.pair2 == null) return;

    final scoreController = TextEditingController(text: match.score ?? "");
    String? winnerId = match.winnerId ?? match.pair1!.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF161F2E),
          title: Text(
            match.roundName,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Sélectionnez la paire gagnante :", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setDlgState(() => winnerId = match.pair1!.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: winnerId == match.pair1!.id ? AppColors.gold.withValues(alpha: 0.2) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: winnerId == match.pair1!.id ? AppColors.gold : Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(winnerId == match.pair1!.id ? Icons.check_circle : Icons.radio_button_unchecked, color: winnerId == match.pair1!.id ? AppColors.gold : Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(match.pair1!.displayName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setDlgState(() => winnerId = match.pair2!.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: winnerId == match.pair2!.id ? AppColors.gold.withValues(alpha: 0.2) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: winnerId == match.pair2!.id ? AppColors.gold : Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(winnerId == match.pair2!.id ? Icons.check_circle : Icons.radio_button_unchecked, color: winnerId == match.pair2!.id ? AppColors.gold : Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(match.pair2!.displayName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text("Score du match (obligatoire) :", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: scoreController,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "ex: 6/4 6/3 ou 9/4",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: ["6/4 6/3", "6/2 6/2", "6/4 3/6 10/8", "9/4", "9/7"].map((s) {
                  return ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                    backgroundColor: const Color(0xFF1E293B),
                    onPressed: () => setDlgState(() => scoreController.text = s),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () async {
                if (scoreController.text.trim().isEmpty || winnerId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Veuillez saisir un score et désigner le gagnant")),
                  );
                  return;
                }
                Navigator.pop(ctx);
                TournamentBracket updated;
                if (poolId != null) {
                  updated = BracketGeneratorService.recordPoolMatchScore(
                    bracket: bracket,
                    poolId: poolId,
                    matchId: match.id,
                    score: scoreController.text.trim(),
                    winnerId: winnerId!,
                  );
                } else {
                  updated = BracketGeneratorService.recordMatchScore(
                    bracket: bracket,
                    matchId: match.id,
                    score: scoreController.text.trim(),
                    winnerId: winnerId!,
                  );
                }
                await _saveBracket(updated);
              },
              child: const Text("Valider le Score", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOG : ATTRIBUTION D'UN TERRAIN
  // ==========================================
  void _showAssignCourtDialog(BracketMatch match, TournamentBracket bracket) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF161F2E),
        title: const Text("Attribuer un Terrain", style: TextStyle(color: Colors.white, fontSize: 16)),
        children: List.generate(bracket.numCourts, (index) {
          final courtNum = index + 1;
          final isAssigned = match.court == courtNum;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = BracketGeneratorService.assignCourt(
                bracket: bracket,
                matchId: match.id,
                court: courtNum,
              );
              await _saveBracket(updated);
            },
            child: Row(
              children: [
                Icon(
                  isAssigned ? Icons.check_circle : Icons.stadium_outlined,
                  color: isAssigned ? AppColors.gold : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  "Terrain $courtNum",
                  style: TextStyle(
                    color: isAssigned ? AppColors.gold : Colors.white,
                    fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // DIALOG : GENERER LE TABLEAU
  // ==========================================
  void _showGenerateBracketDialog(TournamentBracket bracket) {
    int courts = bracket.numCourts;
    String formatChoice = bracket.format;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF161F2E),
          title: Text(
            "Générer le Tableau (${_getCategoryLabel(_selectedCategory)})",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Paires inscrites : ${bracket.pairs.length} équipes.",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text("Format de jeu :", style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: formatChoice,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: 'pools_and_bracket', child: Text("Poules A & B + Phase Finale")),
                  DropdownMenuItem(value: 'elimination', child: Text("Tableau Élimination Directe + Consolante")),
                ],
                onChanged: (val) => setDlgState(() => formatChoice = val ?? formatChoice),
              ),
              const SizedBox(height: 14),
              const Text("Terrains disponibles :", style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: courts,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: [1, 2, 3, 4, 5, 6, 8].map((c) {
                  return DropdownMenuItem(value: c, child: Text("$c Terrains"));
                }).toList(),
                onChanged: (val) => setDlgState(() => courts = val ?? 4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () async {
                Navigator.pop(ctx);
                TournamentBracket newBracket;
                if (formatChoice == 'pools_and_bracket') {
                  final half = (bracket.pairs.length / 2).ceil();
                  final pouleA = bracket.pairs.take(half).toList();
                  final pouleB = bracket.pairs.skip(half).toList();
                  newBracket = BracketGeneratorService.generatePoolsAndBracket(
                    tournamentId: widget.tournament.id,
                    category: _selectedCategory,
                    pouleAPairs: pouleA,
                    pouleBPairs: pouleB,
                    numCourts: courts,
                  );
                } else {
                  newBracket = BracketGeneratorService.generateBracket(
                    tournamentId: widget.tournament.id,
                    category: _selectedCategory,
                    registeredPairs: bracket.pairs,
                    numCourts: courts,
                  );
                }
                await _saveBracket(newBracket);
              },
              child: const Text("Générer", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOG : AJOUTER UNE PAIRE
  // ==========================================
  void _showAddPairDialog(TournamentBracket bracket) {
    final p1Ctrl = TextEditingController();
    final r1Ctrl = TextEditingController(text: "500");
    final p2Ctrl = TextEditingController();
    final r2Ctrl = TextEditingController(text: "500");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        title: const Text("Inscrire une Paire", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: p1Ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Joueur 1 (Nom Prénom)", labelStyle: TextStyle(color: Colors.white70)),
              ),
              TextField(
                controller: r1Ctrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Classement FFT Joueur 1", labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: p2Ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Joueur 2 (Nom Prénom)", labelStyle: TextStyle(color: Colors.white70)),
              ),
              TextField(
                controller: r2Ctrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Classement FFT Joueur 2", labelStyle: TextStyle(color: Colors.white70)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              if (p1Ctrl.text.trim().isEmpty || p2Ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final newPair = TournamentPair(
                id: "pair_${DateTime.now().millisecondsSinceEpoch}",
                player1Name: p1Ctrl.text.trim(),
                player1Rank: int.tryParse(r1Ctrl.text) ?? 500,
                player2Name: p2Ctrl.text.trim(),
                player2Rank: int.tryParse(r2Ctrl.text) ?? 500,
              );
              final updatedPairs = List<TournamentPair>.from(bracket.pairs)..add(newPair);
              final seeded = BracketGeneratorService.assignSeeds(updatedPairs);
              await _saveBracket(bracket.copyWith(pairs: seeded));
            },
            child: const Text("Ajouter", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
            Icon(Icons.sports_tennis, size: 56, color: AppColors.gold.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                onPressed: onAction,
                child: Text(actionText, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String key) {
    if (key == 'double_dames') return "Double Dames";
    if (key == 'double_mixtes') return "Double Mixtes";
    return "Double Hommes";
  }
}
