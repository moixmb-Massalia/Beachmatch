import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'players_screen.dart';
import 'clubs/club_list_screen.dart';
import '../l10n/app_localizations.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: const Text(
            "Clubs & Joueurs",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.coral,
            labelColor: AppColors.coral,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Joueurs"),
              Tab(text: "Clubs"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PlayersScreen(),
            ClubListScreen(),
          ],
        ),
      ),
    );
  }
}
