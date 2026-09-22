import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';
import '../models/tournament.dart';
import '../models/live_match_model.dart';
import '../screens/tournaments/referee_live_score_screen.dart';

class TournamentLiveScoresCard extends StatelessWidget {
  final TournamentModel tournament;
  final bool isAuthorized;

  const TournamentLiveScoresCard({
    super.key,
    required this.tournament,
    required this.isAuthorized,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournament.id)
          .collection('live_matches')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final matches = snapshot.hasData
            ? snapshot.data!.docs.map((d) => LiveMatchModel.fromFirestore(d)).toList()
            : <LiveMatchModel>[];

        final liveMatches = matches.where((m) => m.status == 'LIVE').toList();
        final finishedMatches = matches.where((m) => m.status == 'FINISHED').toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0F1B29).withValues(alpha: 0.95),
                      const Color(0xFF16253B).withValues(alpha: 0.92),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: liveMatches.isNotEmpty ? Colors.redAccent.withValues(alpha: 0.6) : AppColors.gold.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: liveMatches.isNotEmpty ? Colors.redAccent.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête Live Scores
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (liveMatches.isNotEmpty) ...[
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              liveMatches.isNotEmpty ? "🔴 LIVE SCORES EN DIRECT" : "🏆 SCORES DU TOURNOI",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RefereeLiveScoreScreen(tournament: tournament),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.coral.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sports_tennis_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  "Arbitrer un match",
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (matches.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, color: AppColors.gold, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Aucun match en direct pour le moment.\nCliquez sur 'Arbitrer un match' pour démarrer un live !",
                                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Liste des Matchs en Direct (LIVE)
                      ...liveMatches.map((m) => _buildLiveMatchItem(context, m, isAuthorized)),
                      // Liste des Matchs Terminés
                      ...finishedMatches.take(3).map((m) => _buildLiveMatchItem(context, m, isAuthorized)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveMatchItem(BuildContext context, LiveMatchModel m, bool isAuthorized) {
    final isLive = m.status == 'LIVE';

    // Déduction intelligente du vainqueur
    final effWinner = (m.winner == 1 || m.winner == 2)
        ? m.winner!
        : (m.status == 'FINISHED'
            ? (((m.set1Team1 > m.set1Team2 ? 1 : 0) + (m.set2Team1 > m.set2Team2 ? 1 : 0) + ((m.set3Team1 ?? 0) > (m.set3Team2 ?? 0) ? 1 : 0)) >
               ((m.set1Team2 > m.set1Team1 ? 1 : 0) + (m.set2Team2 > m.set2Team1 ? 1 : 0) + ((m.set3Team2 ?? 0) > (m.set3Team1 ?? 0) ? 1 : 0)) ? 1 : 2)
            : 0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RefereeLiveScoreScreen(tournament: tournament, match: m),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isLive ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive ? AppColors.coral.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            // Court & Tour
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLive ? Colors.redAccent : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLive ? "EN DIRECT" : "TERMINÉ",
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${m.courtName} • ${m.round}",
                      style: const TextStyle(color: AppColors.gold, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (isAuthorized)
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Colors.white54, size: 16),
                      SizedBox(width: 2),
                      Text("Modifier", style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Équipe 1
            _buildMatchRow(
              teamName: m.team1,
              isServing: isLive && m.servingTeam == 1,
              set1: m.set1Team1,
              set2: m.set2Team1,
              set3: m.set3Team1,
              isSet1Winner: m.set1Team1 > m.set1Team2,
              isSet2Winner: m.set2Team1 > m.set2Team2,
              isSet3Winner: (m.set3Team1 ?? 0) > (m.set3Team2 ?? 0),
              isWinner: effWinner == 1,
              currentSet: m.currentSet,
              isLive: isLive,
            ),
            const SizedBox(height: 6),

            // Équipe 2
            _buildMatchRow(
              teamName: m.team2,
              isServing: isLive && m.servingTeam == 2,
              set1: m.set1Team2,
              set2: m.set2Team2,
              set3: m.set3Team2,
              isSet1Winner: m.set1Team2 > m.set1Team1,
              isSet2Winner: m.set2Team2 > m.set2Team1,
              isSet3Winner: (m.set3Team2 ?? 0) > (m.set3Team1 ?? 0),
              isWinner: effWinner == 2,
              currentSet: m.currentSet,
              isLive: isLive,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchRow({
    required String teamName,
    required bool isServing,
    required int set1,
    required int set2,
    required int? set3,
    required bool isSet1Winner,
    required bool isSet2Winner,
    required bool isSet3Winner,
    required bool isWinner,
    required int currentSet,
    required bool isLive,
  }) {
    return Row(
      children: [
        if (isServing)
          const Text("🎾 ", style: TextStyle(fontSize: 12))
        else if (isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 14),
          )
        else
          const SizedBox(width: 18),
        Expanded(
          child: Text(
            teamName,
            style: TextStyle(
              color: isWinner ? AppColors.gold : Colors.white,
              fontWeight: isWinner ? FontWeight.w900 : (isServing ? FontWeight.bold : FontWeight.w600),
              fontSize: 13.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _buildScorePill(set1, isActive: isLive && currentSet == 1, isSetWinner: isSet1Winner),
        const SizedBox(width: 4),
        _buildScorePill(set2, isActive: isLive && currentSet == 2, isSetWinner: isSet2Winner),
        if (set3 != null || (isLive && currentSet == 3)) ...[
          const SizedBox(width: 4),
          _buildScorePill(set3 ?? 0, isActive: isLive && currentSet == 3, isSetWinner: isSet3Winner),
        ],
      ],
    );
  }

  Widget _buildScorePill(int score, {required bool isActive, required bool isSetWinner}) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: isSetWinner
            ? const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : (isActive
                ? const LinearGradient(
                    colors: [Color(0xFFE53935), AppColors.coral],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      const Color(0xFF0F172A).withValues(alpha: 0.95),
                      const Color(0xFF1E293B).withValues(alpha: 0.90),
                    ],
                  )),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isSetWinner
              ? const Color(0xFFFFE066)
              : (isActive ? Colors.white : Colors.white.withValues(alpha: 0.25)),
          width: isSetWinner || isActive ? 1.5 : 1.0,
        ),
        boxShadow: isSetWinner
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : (isActive
                ? [
                    BoxShadow(
                      color: AppColors.coral.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(
          color: isSetWinner ? Colors.black : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}
