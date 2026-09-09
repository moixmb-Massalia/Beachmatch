import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'tournaments/tournament_list_screen.dart';
import 'fft_rankings_screen.dart';

class CompetitionScreen extends StatelessWidget {
  final int initialTabIndex;
  const CompetitionScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
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
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(
                icon: Icon(Icons.sports_tennis, size: 18),
                text: "Tournois FFT / ITF",
              ),
              Tab(
                icon: Icon(Icons.leaderboard, size: 18),
                text: "Classement Ten'Up",
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TournamentListScreen(),
            FftRankingsScreen(),
          ],
        ),
      ),
    );
  }
}
