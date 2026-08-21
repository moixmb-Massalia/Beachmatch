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
                  Text("MOMENTUM DU MATCH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Paire 1 (56%)", style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text("Paire 2 (44%)", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: const [
                      Expanded(flex: 56, child: ColoredBox(color: AppColors.coral)),
                      SizedBox(width: 2),
                      Expanded(flex: 44, child: ColoredBox(color: AppColors.gold)),
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
              _buildInfoRow(Icons.place_rounded, "Lieu", widget.tournament['city'] ?? 'Vitória, Brésil'),
              const Divider(color: Colors.white10, height: 16),
              _buildInfoRow(Icons.waves_rounded, "Surface", "Sable fin de plage (Outdoor)"),
              const Divider(color: Colors.white10, height: 16),
              _buildInfoRow(Icons.sports_rounded, "Tableau", "${match['draw'] ?? 'DH'} (Double Hommes)"),
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
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  // 📊 Onglet Statistiques du Match
  Widget _buildStatsTab(Map<String, dynamic> match) {
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
              _buildStatBar("Smashs & Points Gagnants", 28, 22),
              _buildStatBar("Aces / Services Gagnants", 7, 4),
              _buildStatBar("% 1er Service Réussi", 76, 68, isPercentage: true),
              _buildStatBar("Balles de Break Converties", 3, 1),
              _buildStatBar("Fautes Directes", 11, 15, inverseWinner: true),
              _buildStatBar("Total des Points Gagnés", 64, 52),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBar(String title, int val1, int val2, {bool isPercentage = false, bool inverseWinner = false}) {
    final total = val1 + val2 == 0 ? 1 : val1 + val2;
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
                    flex: val1,
                    child: Container(color: p1Wins ? AppColors.coral : Colors.white24),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: val2,
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

  // ⏱️ Onglet Chronologie (Jeu par jeu)
  Widget _buildTimelineTab(Map<String, dynamic> match, bool isFinished) {
    final set1 = match['set1'] ?? '6/3';
    final set2 = match['set2'] ?? '7/5';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSetTimelineSection("Set 1 (Score: $set1)", [
          {'game': '1 - 0', 'desc': 'Jeu blanc au service', 'break': false},
          {'game': '1 - 1', 'desc': 'Égalisation', 'break': false},
          {'game': '2 - 1', 'desc': 'Jeu remporté', 'break': false},
          {'game': '3 - 1', 'desc': '🔥 Break décisif !', 'break': true},
          {'game': '4 - 1', 'desc': 'Confirmation du break', 'break': false},
          {'game': '4 - 2', 'desc': 'Jeu remporté', 'break': false},
          {'game': '5 - 2', 'desc': 'Jeu remporté', 'break': false},
          {'game': '5 - 3', 'desc': 'Jeu sauvé', 'break': false},
          {'game': '6 - 3', 'desc': '🏆 Set remporté par Paire 1', 'break': false},
        ]),
        const SizedBox(height: 16),
        _buildSetTimelineSection("Set 2 (Score: $set2)", [
          {'game': '1 - 0', 'desc': 'Jeu au service', 'break': false},
          {'game': '1 - 1', 'desc': 'Égalisation', 'break': false},
          {'game': '2 - 1', 'desc': 'Jeu remporté', 'break': false},
          {'game': '2 - 2', 'desc': 'Égalisation', 'break': false},
          {'game': '3 - 2', 'desc': 'Jeu remporté', 'break': false},
          {'game': '3 - 3', 'desc': 'Égalisation', 'break': false},
          {'game': '4 - 3', 'desc': 'Jeu remporté', 'break': false},
          {'game': '4 - 4', 'desc': 'Égalisation', 'break': false},
          {'game': '5 - 4', 'desc': 'Balle de match sauvée', 'break': false},
          {'game': '5 - 5', 'desc': 'Égalisation intense', 'break': false},
          {'game': '6 - 5', 'desc': '🔥 Break sous haute tension !', 'break': true},
          {'game': '7 - 5', 'desc': '🏆 Grande Finale remportée !', 'break': false},
        ]),
      ],
    );
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
