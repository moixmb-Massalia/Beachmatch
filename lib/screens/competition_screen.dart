import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import 'tournaments/tournament_list_screen.dart';
import 'tournaments/beach_score_hub_screen.dart';
import 'fft_rankings_screen.dart';
import 'tournaments/tournament_radar_screen.dart';

class CompetitionScreen extends StatelessWidget {
  final int initialTabIndex;
  const CompetitionScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true;

    return DefaultTabController(
      length: 4,
      initialIndex: initialTabIndex.clamp(0, 3),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
          title: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Text(
                isBr ? "Competição" : "Compétition",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            tabs: [
              Tab(
                icon: const Icon(Icons.calendar_month, size: 18),
                text: isBr ? "Torneios" : "Tournois",
              ),
              const Tab(
                icon: Icon(Icons.scoreboard_rounded, size: 18),
                text: "BeachScore",
              ),
              Tab(
                icon: const Icon(Icons.leaderboard_rounded, size: 18),
                text: isBr ? "Ranking" : "Classement",
              ),
              const Tab(
                icon: Icon(Icons.radar, size: 18),
                text: "Radar 360°",
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TournamentListScreen(showHeader: false),
            BeachScoreHubScreen(isEmbedded: true),
            FftRankingsScreen(isEmbedded: true),
            TournamentRadarScreen(),
          ],
        ),
      ),
    );
  }
}
