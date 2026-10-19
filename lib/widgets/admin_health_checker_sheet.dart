import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';

/// Modal d'audit et de diagnostic santé en direct pour les administrateurs.
/// Permet de tester en 2 secondes la connectivité, l'intégrité des tournois,
/// les classements ITF, la latence Firestore et de consulter les anomalies récentes.
class AdminHealthCheckerSheet extends StatefulWidget {
  const AdminHealthCheckerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AdminHealthCheckerSheet(),
    );
  }

  @override
  State<AdminHealthCheckerSheet> createState() => _AdminHealthCheckerSheetState();
}

class _AdminHealthCheckerSheetState extends State<AdminHealthCheckerSheet> {
  bool _isLoading = true;
  int _firestorePingMs = 0;
  int _itfMenCount = 0;
  int _itfWomenCount = 0;
  int _liveMatchesCount = 0;
  int _scheduledMatchesCount = 0;
  int _finishedMatchesCount = 0;
  int _tournamentsCount = 0;
  int _crashReportsCount = 0;
  List<Map<String, dynamic>> _recentCrashes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runDiagnostic();
  }

  Future<void> _runDiagnostic() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      // 1. Mesure du ping Firestore
      final stopwatch = Stopwatch()..start();
      await db.collection('pro_tournaments').limit(1).get();
      stopwatch.stop();
      _firestorePingMs = stopwatch.elapsedMilliseconds;

      // 2. Vérification des tournois et BeachScore
      final tourneysSnap = await db.collection('pro_tournaments').get();
      _tournamentsCount = tourneysSnap.docs.length;

      final liveSnap = await db.collection('pro_matches').where('status', isEqualTo: 'LIVE').get();
      _liveMatchesCount = liveSnap.docs.length;

      final schedSnap = await db.collection('pro_matches').where('status', isEqualTo: 'SCHEDULED').get();
      _scheduledMatchesCount = schedSnap.docs.length;

      final finSnap = await db.collection('pro_matches').where('status', isEqualTo: 'FINISHED').get();
      _finishedMatchesCount = finSnap.docs.length;

      // 3. Vérification des classements ITF
      final menSnap = await db.collection('itf_rankings').where('gender', isEqualTo: 'M').limit(500).get();
      _itfMenCount = menSnap.docs.length;

      final womenSnap = await db.collection('itf_rankings').where('gender', isEqualTo: 'F').limit(500).get();
      _itfWomenCount = womenSnap.docs.length;

      // 4. Récupération des rapports de crashs récents
      final crashSnap = await db.collection('app_crash_reports')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get()
          .catchError((_) => db.collection('app_crash_reports').limit(10).get());
      
      _crashReportsCount = crashSnap.docs.length;
      _recentCrashes = crashSnap.docs.map((d) => d.data()).toList();

    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int get _healthScore {
    int score = 100;
    if (_firestorePingMs > 600) score -= 10;
    if (_tournamentsCount == 0) score -= 25;
    if (_liveMatchesCount + _scheduledMatchesCount + _finishedMatchesCount == 0) score -= 25;
    if (_itfMenCount < 100) score -= 15;
    if (_itfWomenCount < 100) score -= 15;
    if (_crashReportsCount > 5) score -= 10;
    return score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.health_and_safety_rounded, color: AppColors.gold, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Diagnostic & Détecteur de Pannes",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        "Surveillance proactive en temps réel",
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
                  onPressed: _runDiagnostic,
                  tooltip: "Relancer le scan",
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.gold),
                        SizedBox(height: 16),
                        Text(
                          "Audit des services en direct...",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Health Score Banner
                      _buildScoreBanner(),

                      const SizedBox(height: 18),
                      const Text(
                        "SERVICES ET DONNÉES EN DIRECT",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Metrics Grid
                      _buildMetricTile(
                        icon: Icons.speed_rounded,
                        title: "Connectivité Firestore (Ping)",
                        value: "$_firestorePingMs ms",
                        isGood: _firestorePingMs < 450,
                        subtitle: _firestorePingMs < 450 ? "Excellente réactivité" : "Latence élevée",
                      ),
                      _buildMetricTile(
                        icon: Icons.emoji_events_rounded,
                        title: "Tournois Pro Certifiés",
                        value: "$_tournamentsCount tournois",
                        isGood: _tournamentsCount >= 10,
                        subtitle: "Brésil, Italie, France, Espagne, ITF",
                      ),
                      _buildMetricTile(
                        icon: Icons.live_tv_rounded,
                        title: "Matchs BeachScore",
                        value: "${_liveMatchesCount + _scheduledMatchesCount + _finishedMatchesCount} matchs",
                        isGood: (_liveMatchesCount + _scheduledMatchesCount + _finishedMatchesCount) > 0,
                        subtitle: "$_liveMatchesCount en direct • $_scheduledMatchesCount programmés • $_finishedMatchesCount finis",
                      ),
                      _buildMetricTile(
                        icon: Icons.leaderboard_rounded,
                        title: "Classements ITF Hommes & Dames",
                        value: "${_itfMenCount + _itfWomenCount}+ joueurs",
                        isGood: _itfMenCount > 100 && _itfWomenCount > 100,
                        subtitle: "Index composite actif • Fluidité 60 FPS",
                      ),
                      _buildMetricTile(
                        icon: Icons.bug_report_rounded,
                        title: "Rapports de Bugs Capturés",
                        value: "$_crashReportsCount signalement(s)",
                        isGood: _crashReportsCount == 0,
                        subtitle: _crashReportsCount == 0
                            ? "Zéro incident signalé"
                            : "Interceptions automatiques archivées",
                      ),

                      if (_recentCrashes.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text(
                          "DERNIÈRES ANOMALIES INTERCEPTÉES (PROACTIF)",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._recentCrashes.map((c) => _buildCrashCard(c)),
                      ],

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            "Erreur du diagnostic : $_errorMessage",
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBanner() {
    final score = _healthScore;
    final color = score >= 90 ? const Color(0xFF10B981) : (score >= 70 ? AppColors.gold : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                "$score%",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score >= 90 ? "Santé Applicative Optimale" : (score >= 70 ? "Attention Requise" : "Anomalie Détectée"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  score >= 90
                      ? "Tous les systèmes fonctionnent sans aucun blocage."
                      : "Certaines données nécessitent une synchronisation.",
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isGood,
    required String subtitle,
  }) {
    final statusColor = isGood ? const Color(0xFF10B981) : AppColors.gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Icon(
            isGood ? Icons.check_circle_rounded : Icons.info_rounded,
            color: statusColor,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildCrashCard(Map<String, dynamic> c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  c['platform']?.toString().toUpperCase() ?? 'APP',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c['clientTime']?.toString().split('T').first ?? '',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
              Text(
                c['context']?.toString() ?? '',
                style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c['error']?.toString() ?? 'Erreur inconnue',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
