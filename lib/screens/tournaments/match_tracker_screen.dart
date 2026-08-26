import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/colors.dart';
import '../../services/sound_service.dart';

/// Écran Match Tracker 2D Animé Beach Tennis (Style SofaScore / FlashScore)
class MatchTrackerScreen extends StatefulWidget {
  final Map<String, dynamic> match;
  final Map<String, dynamic> tournament;

  const MatchTrackerScreen({
    super.key,
    required this.match,
    required this.tournament,
  });

  @override
  State<MatchTrackerScreen> createState() => _MatchTrackerScreenState();
}

class _MatchTrackerScreenState extends State<MatchTrackerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _ballPulseController;
  late Animation<double> _ballPulseAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _ballPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _ballPulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _ballPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ballPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchId = widget.match['id'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.tournament['countryFlag'] ?? '🌍', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.tournament['name'] ?? 'Tournoi Pro',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              "${widget.match['round'] ?? 'Match'} · ${widget.match['court'] ?? 'Court Central'}",
              style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
            tooltip: "Actualiser le direct",
            onPressed: () {
              HapticFeedback.mediumImpact();
              SoundService.playRacketPop();
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: matchId.isNotEmpty
            ? FirebaseFirestore.instance.collection('pro_matches').doc(matchId).snapshots()
            : null,
        builder: (context, snapshot) {
          Map<String, dynamic> currentMatch = widget.match;
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              currentMatch = data;
            }
          }

          final bool isLive = currentMatch['status'] == 'LIVE';
          final bool isFinished = currentMatch['status'] == 'FINISHED';

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // 🏆 Scoreboard Principal
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildScoreboardCard(currentMatch, isLive, isFinished),
                  ),
                ),

                // 🏟️ Terrain 2D de Beach Tennis Animé
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildBeachCourt2D(currentMatch, isLive, isFinished),
                  ),
                ),

                // 📑 Barre d'onglets (Direct / Statistiques / Chronologie)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141D30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        tabs: const [
                          Tab(text: "Direct 2D 🔴"),
                          Tab(text: "Statistiques 📊"),
                          Tab(text: "Chronologie ⏱️"),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildLiveTab(currentMatch, isLive, isFinished),
                _buildStatsTab(currentMatch),
                _buildTimelineTab(currentMatch, isFinished),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🏆 Scoreboard Card Hero
  Widget _buildScoreboardCard(Map<String, dynamic> match, bool isLive, bool isFinished) {
    final team1 = match['team1'] ?? 'Paire 1';
    final team2 = match['team2'] ?? 'Paire 2';
    final serving = match['serving'];
    final winner = match['winner'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF16253B).withOpacity(0.95),
            const Color(0xFF1F3554).withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive ? Colors.redAccent.withOpacity(0.6) : Colors.white.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Statut du Match (Direct / Terminé / Heure)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLive
                      ? Colors.redAccent.withOpacity(0.2)
                      : (isFinished ? AppColors.gold.withOpacity(0.2) : Colors.white.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLive
                        ? Colors.redAccent
                        : (isFinished ? AppColors.gold : Colors.white.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    if (isLive) ...[
                      ScaleTransition(
                        scale: _ballPulseAnimation,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "EN DIRECT",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ] else if (isFinished) ...[
                      const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 14),
                      const SizedBox(width: 6),
                      const Text(
                        "TERMINÉ",
                        style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ] else ...[
                      const Icon(Icons.schedule_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        match['time'] ?? 'Programmé',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                match['day'] ?? 'Aujourd\'hui',
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ligne Équipe 1
          _buildTeamScoreRow(
            teamName: team1,
            isWinner: winner == 1,
            isServing: serving == 1,
            set1: match['set1'],
            set2: match['set2'],
            set3: match['set3'],
            currentPoints: isLive ? "40" : null,
          ),
          const Divider(color: Colors.white12, height: 16),

          // Ligne Équipe 2
          _buildTeamScoreRow(
            teamName: team2,
            isWinner: winner == 2,
            isServing: serving == 2,
            set1: match['set1'],
            set2: match['set2'],
            set3: match['set3'],
            currentPoints: isLive ? "15" : null,
            isTeam2: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamScoreRow({
    required String teamName,
    required bool isWinner,
    required bool isServing,
    required String? set1,
    required String? set2,
    required String? set3,
    String? currentPoints,
    bool isTeam2 = false,
  }) {
    final s1 = _extractSetScore(set1, isTeam2);
    final s2 = _extractSetScore(set2, isTeam2);
    final s3 = _extractSetScore(set3, isTeam2);

    return Row(
      children: [
        // Indicateur Service 🎾
        SizedBox(
          width: 20,
          child: isServing
              ? const Text("🎾", style: TextStyle(fontSize: 12))
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 6),
        // Nom Équipe
        Expanded(
          child: Text(
            teamName,
            style: TextStyle(
              color: isWinner ? AppColors.gold : Colors.white,
              fontSize: 14,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Scores Sets
        if (s1 != null) _buildSetScoreBox(s1),
        if (s2 != null) _buildSetScoreBox(s2),
        if (s3 != null) _buildSetScoreBox(s3),
        if (currentPoints != null)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.coral.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.coral),
            ),
            child: Text(
              currentPoints,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildSetScoreBox(String score) {
    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          score,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
        ),
      ),
    );
  }

  String? _extractSetScore(String? setString, bool isTeam2) {
    if (setString == null || !setString.contains('/')) return null;
    final parts = setString.split('/');
    if (parts.length == 2) {
      return isTeam2 ? parts[1].trim() : parts[0].trim();
    }
    return null;
  }

  // 🏟️ Terrain 2D de Beach Tennis en Sable
  Widget _buildBeachCourt2D(Map<String, dynamic> match, bool isLive, bool isFinished) {
    final team1 = match['team1'] ?? 'Paire 1';
    final team2 = match['team2'] ?? 'Paire 2';
    final serving = match['serving'] ?? 1;

    final names1 = _parsePlayerNames(team1);
    final names2 = _parsePlayerNames(team2);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5B566), Color(0xFFC9943B)], // Texture sable doré
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF3D59B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Lignes du terrain dessinées avec CustomPainter
            CustomPaint(
              size: const Size(double.infinity, 260),
              painter: BeachCourtPainter(),
            ),

            // Joueurs & Animation du Serveur
            SizedBox(
              height: 260,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🏖️ Équipe 1 (Haut du court)
                  Padding(
                    padding: const EdgeInsets.only(top: 24, left: 30, right: 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPlayerBadge(names1[0], serving == 1, 1),
                        _buildPlayerBadge(names1[1], false, 2),
                      ],
                    ),
                  ),

                  // 🏐 Balle de Match / Bandeau Action Centrale
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLive) ...[
                          ScaleTransition(
                            scale: _ballPulseAnimation,
                            child: const Text("🎾", style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Échange en cours · Attaque smashée",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ] else if (isFinished) ...[
                          const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            "Match Terminé · Score Final Officiel",
                            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ] else ...[
                          const Icon(Icons.schedule_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          const Text(
                            "Échauffement des joueurs sur le court",
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 🏖️ Équipe 2 (Bas du court)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, left: 30, right: 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPlayerBadge(names2[0], serving == 2, 3),
                        _buildPlayerBadge(names2[1], false, 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBadge(String name, bool isServing, int index) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF141D30),
                border: Border.all(
                  color: isServing ? AppColors.gold : Colors.white,
                  width: isServing ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: isServing ? AppColors.gold : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (isServing)
              Positioned(
                top: -6,
                right: -6,
                child: ScaleTransition(
                  scale: _ballPulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                    child: const Text("🎾", style: TextStyle(fontSize: 10)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<String> _parsePlayerNames(String teamString) {
    // Nettoie [1], [2] et sépare par "/"
    var clean = teamString.replaceAll(RegExp(r'\[\d+\]'), '').trim();
    final parts = clean.split('/');
    if (parts.length >= 2) {
      return [parts[0].trim(), parts[1].trim()];
    }
    return [clean, 'Partenaire'];
  }

  // 🔴 Onglet Direct 2D (Momentum & Informations)
  Widget _buildLiveTab(Map<String, dynamic> match, bool isLive, bool isFinished) {
    final team1 = _parsePlayerNames(match['team1'] ?? 'Paire 1')[0];
    final team2 = _parsePlayerNames(match['team2'] ?? 'Paire 2')[0];
    final stats = _computeMatchStats(match);
    final p1Flex = stats.p1Momentum;
    final p2Flex = 100 - p1Flex;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Barre de Domination / Momentum
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141D30),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.gold, size: 18),
                  SizedBox(width: 8),
                  Text("MOMENTUM & DOMINATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("$team1 ($p1Flex%)", style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text("$team2 ($p2Flex%)", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(flex: p1Flex, child: const ColoredBox(color: AppColors.coral)),
                      const SizedBox(width: 2),
                      Expanded(flex: p2Flex, child: const ColoredBox(color: AppColors.gold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Détails du match
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141D30),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              _buildInfoRow(Icons.emoji_events_rounded, "Tournoi", widget.tournament['name'] ?? 'Tournoi Pro'),
              const Divider(color: Colors.white10, height: 16),
              _buildInfoRow(Icons.place_rounded, "Lieu", widget.tournament['city'] ?? 'Plage du tournoi'),
              const Divider(color: Colors.white10, height: 16),
              _buildInfoRow(Icons.waves_rounded, "Surface", widget.tournament['surface'] ?? "Sable fin de plage (Outdoor)"),
              const Divider(color: Colors.white10, height: 16),
              _buildInfoRow(Icons.sports_rounded, "Tableau", "${match['draw'] ?? 'DH'} (${match['draw'] == 'DD' ? 'Double Dames' : (match['draw'] == 'DX' ? 'Double Mixte' : 'Double Hommes')})"),
              const Divider(color: Colors.white10, height: 16),
              _buildInfoRow(Icons.timer_rounded, "Format", "2 sets gagnants (Tie-break à 6-6)"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const Spacer(),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 📊 Onglet Statistiques du Match (Calculé dynamiquement selon le match)
  Widget _buildStatsTab(Map<String, dynamic> match) {
    final stats = _computeMatchStats(match);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF141D30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              _buildStatBar("Smashs & Points Gagnants", stats.winnersP1, stats.winnersP2),
              _buildStatBar("Aces / Services Gagnants", stats.acesP1, stats.acesP2),
              _buildStatBar("% 1er Service Réussi", stats.firstServeP1, stats.firstServeP2, isPercentage: true),
              _buildStatBar("Balles de Break Converties", stats.breakPointsP1, stats.breakPointsP2),
              _buildStatBar("Fautes Directes", stats.unforcedErrorsP1, stats.unforcedErrorsP2, inverseWinner: true),
              _buildStatBar("Total des Points Gagnés", stats.totalPointsP1, stats.totalPointsP2),
            ],
          ),
        ),
      ],
    );
  }

  _MatchStatsData _computeMatchStats(Map<String, dynamic> match) {
    final id = match['id'] ?? 'match';
    final int seed = id.hashCode.abs() % 10;
    final set1 = match['set1'] as String?;
    final set2 = match['set2'] as String?;
    final winner = match['winner'] ?? 1;

    int g1 = 0;
    int g2 = 0;

    void parseSet(String? s) {
      if (s != null && s.contains('/')) {
        final parts = s.split('/');
        g1 += int.tryParse(parts[0].trim()) ?? 0;
        g2 += int.tryParse(parts[1].trim()) ?? 0;
      }
    }

    parseSet(set1);
    parseSet(set2);

    if (g1 == 0 && g2 == 0) {
      // Match programmé : Stats d'avant-match estimées
      return _MatchStatsData(
        p1Momentum: 52 + (seed % 6),
        winnersP1: 20 + seed,
        winnersP2: 18 + (seed % 4),
        acesP1: 4 + (seed % 3),
        acesP2: 3 + (seed % 2),
        firstServeP1: 72 + (seed % 6),
        firstServeP2: 69 + (seed % 5),
        breakPointsP1: 2 + (seed % 2),
        breakPointsP2: 1 + (seed % 2),
        unforcedErrorsP1: 10 + (seed % 3),
        unforcedErrorsP2: 12 + (seed % 4),
        totalPointsP1: 48 + seed * 2,
        totalPointsP2: 44 + seed * 2,
      );
    }

    final bool p1Won = winner == 1 || g1 > g2;
    final int totalGames = g1 + g2;
    final int p1Ratio = ((g1 / (totalGames == 0 ? 1 : totalGames)) * 100).round().clamp(35, 75);

    return _MatchStatsData(
      p1Momentum: p1Ratio,
      winnersP1: (g1 * 2.8).round() + (seed % 4) + (p1Won ? 4 : 0),
      winnersP2: (g2 * 2.6).round() + (seed % 3) + (!p1Won ? 4 : 0),
      acesP1: (g1 * 0.6).round() + (seed % 3),
      acesP2: (g2 * 0.5).round() + (seed % 2),
      firstServeP1: (p1Won ? 74 : 67) + (seed % 6),
      firstServeP2: (!p1Won ? 73 : 66) + (seed % 5),
      breakPointsP1: (g1 ~/ 3) + (p1Won ? 1 : 0),
      breakPointsP2: (g2 ~/ 3) + (!p1Won ? 1 : 0),
      unforcedErrorsP1: (g2 * 1.2).round() + (seed % 3),
      unforcedErrorsP2: (g1 * 1.3).round() + (seed % 4),
      totalPointsP1: (g1 * 4.4).round() + (seed * 2) + (p1Won ? 6 : 0),
      totalPointsP2: (g2 * 4.2).round() + (seed * 2) + (!p1Won ? 6 : 0),
    );
  }

  Widget _buildStatBar(String title, int val1, int val2, {bool isPercentage = false, bool inverseWinner = false}) {
    final int flex1 = val1 <= 0 ? 1 : val1;
    final int flex2 = val2 <= 0 ? 1 : val2;
    final bool p1Wins = inverseWinner ? val1 < val2 : val1 > val2;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPercentage ? "$val1%" : "$val1",
                style: TextStyle(
                  color: p1Wins ? AppColors.coral : Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                isPercentage ? "$val2%" : "$val2",
                style: TextStyle(
                  color: !p1Wins ? AppColors.gold : Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: flex1,
                    child: Container(color: p1Wins ? AppColors.coral : Colors.white24),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: flex2,
                    child: Container(color: !p1Wins ? AppColors.gold : Colors.white24),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ⏱️ Onglet Chronologie (Jeu par jeu Généré Dynamiquement selon le Score Réel)
  Widget _buildTimelineTab(Map<String, dynamic> match, bool isFinished) {
    final set1 = match['set1'] as String?;
    final set2 = match['set2'] as String?;
    final set3 = match['set3'] as String?;
    final team1 = _parsePlayerNames(match['team1'] ?? 'Paire 1')[0];
    final team2 = _parsePlayerNames(match['team2'] ?? 'Paire 2')[0];

    if (set1 == null && set2 == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_outlined, color: AppColors.gold, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                "Match Programmé · ${match['time'] ?? 'Aujourd\'hui'}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Le fil des jeux et des points en direct s'activera dès le début du premier échange sur le court !",
                style: TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> sections = [];

    if (set1 != null && set1.contains('/')) {
      final games1 = _generateSetGames(set1, 1, team1, team2, isFinished && set2 == null);
      sections.add(_buildSetTimelineSection("Set 1 (Score: $set1)", games1));
    }

    if (set2 != null && set2.contains('/')) {
      sections.add(const SizedBox(height: 16));
      final games2 = _generateSetGames(set2, 2, team1, team2, isFinished && set3 == null);
      sections.add(_buildSetTimelineSection("Set 2 (Score: $set2)", games2));
    }

    if (set3 != null && set3.contains('/')) {
      sections.add(const SizedBox(height: 16));
      final games3 = _generateSetGames(set3, 3, team1, team2, isFinished);
      sections.add(_buildSetTimelineSection("Super Tie-Break (Score: $set3)", games3));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections,
    );
  }

  List<Map<String, dynamic>> _generateSetGames(String setScore, int setNum, String team1, String team2, bool isFinalSet) {
    final parts = setScore.split('/');
    final int max1 = int.tryParse(parts[0].trim()) ?? 6;
    final int max2 = int.tryParse(parts[1].trim()) ?? 4;
    final bool p1WonSet = max1 > max2;

    List<Map<String, dynamic>> games = [];
    int cur1 = 0;
    int cur2 = 0;

    // Simulation intelligente pas à pas arrivant exactement à max1 - max2
    while (cur1 < max1 || cur2 < max2) {
      if (cur1 < max1 && (cur2 >= max2 || (p1WonSet ? (cur1 <= cur2 || (cur1 + cur2) % 2 == 0) : (cur2 > cur1)))) {
        cur1++;
        final bool isBreak = (cur1 == 4 && cur2 == 2) || (cur1 == 6 && cur2 == 4 && p1WonSet) || (cur1 == max1 && max1 == 7);
        final bool isSetPoint = cur1 == max1;

        String desc;
        if (isSetPoint && isFinalSet) {
          desc = "🏆 Grande Victoire finale remportée par $team1 !";
        } else if (isSetPoint) {
          desc = "Set remporté par $team1 ($setScore)";
        } else if (isBreak) {
          desc = "🔥 Break décisif réalisé par $team1 !";
        } else if (cur1 == 1 && cur2 == 0) {
          desc = "Jeu blanc au service pour $team1";
        } else {
          desc = "Jeu au service maîtrisé par $team1";
        }

        games.add({
          'game': '$cur1 - $cur2',
          'desc': desc,
          'break': isBreak,
        });
      } else if (cur2 < max2) {
        cur2++;
        final bool isBreak = (cur2 == 3 && cur1 == 1) || (cur2 == 6 && cur1 == 4 && !p1WonSet) || (cur2 == max2 && max2 == 7);
        final bool isSetPoint = cur2 == max2;

        String desc;
        if (isSetPoint && isFinalSet) {
          desc = "🏆 Grande Victoire finale remportée par $team2 !";
        } else if (isSetPoint) {
          desc = "Set remporté par $team2 ($setScore)";
        } else if (isBreak) {
          desc = "🔥 Break décisif réalisé par $team2 !";
        } else if (cur2 == 1 && cur1 == 0) {
          desc = "Jeu blanc au service pour $team2";
        } else {
          desc = "Jeu au service maîtrisé par $team2";
        }

        games.add({
          'game': '$cur1 - $cur2',
          'desc': desc,
          'break': isBreak,
        });
      } else {
        break;
      }
    }

    return games;
  }

  Widget _buildSetTimelineSection(String title, List<Map<String, dynamic>> games) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141D30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.gold, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...games.map((g) {
            final bool isBreak = g['break'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isBreak ? AppColors.coral.withOpacity(0.25) : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isBreak ? AppColors.coral : Colors.white12,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        g['game'],
                        style: TextStyle(
                          color: isBreak ? AppColors.coral : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g['desc'],
                      style: TextStyle(
                        color: isBreak ? Colors.white : Colors.white70,
                        fontWeight: isBreak ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MatchStatsData {
  final int p1Momentum;
  final int winnersP1;
  final int winnersP2;
  final int acesP1;
  final int acesP2;
  final int firstServeP1;
  final int firstServeP2;
  final int breakPointsP1;
  final int breakPointsP2;
  final int unforcedErrorsP1;
  final int unforcedErrorsP2;
  final int totalPointsP1;
  final int totalPointsP2;

  _MatchStatsData({
    required this.p1Momentum,
    required this.winnersP1,
    required this.winnersP2,
    required this.acesP1,
    required this.acesP2,
    required this.firstServeP1,
    required this.firstServeP2,
    required this.breakPointsP1,
    required this.breakPointsP2,
    required this.unforcedErrorsP1,
    required this.unforcedErrorsP2,
    required this.totalPointsP1,
    required this.totalPointsP2,
  });
}

/// Peintre vectoriel du terrain officiel de Beach Tennis en 2D (16m × 8m)
class BeachCourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final courtPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final netMeshPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(16, 16, size.width - 32, size.height - 32),
      const Radius.circular(10),
    );

    // Lignes de contour du terrain
    canvas.drawRRect(rect, courtPaint);

    // Filet central
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(12, centerY),
      Offset(size.width - 12, centerY),
      netPaint,
    );

    // Maillage léger du filet
    for (double x = 18; x < size.width - 18; x += 12) {
      canvas.drawLine(
        Offset(x, centerY - 4),
        Offset(x, centerY + 4),
        netMeshPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
