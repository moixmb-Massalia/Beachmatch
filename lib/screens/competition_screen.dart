import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'tournaments/tournament_list_screen.dart';
import 'tournaments/tournament_radar_screen.dart';
import 'fft_rankings_screen.dart';

class CompetitionScreen extends StatelessWidget {
  final int initialTabIndex;
  const CompetitionScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex.clamp(0, 2),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
          title: const Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.gold, size: 22),
              SizedBox(width: 8),
              Text(
                "Compétition",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            tabs: [
              Tab(
                icon: Icon(Icons.calendar_month, size: 18),
                text: "Calendrier",
              ),
              Tab(
                icon: Icon(Icons.leaderboard_rounded, size: 18),
                text: "Classement FFT",
              ),
              Tab(
                icon: Icon(Icons.radar, size: 18),
                text: "Radar 360°",
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TournamentListScreen(showHeader: false),
            FftRankingsScreen(isEmbedded: true),
            TournamentRadarScreen(),
          ],
        ),
      ),
    );
  }
}
