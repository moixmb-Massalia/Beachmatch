import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'players_screen.dart';
import 'clubs/club_list_screen.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/beach_sunset_players_1785052273648.jpg',
                fit: BoxFit.cover,
                cacheWidth: 1080,
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Top Header
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        _CommunityHeaderIcon(),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Communauté",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                            ),
                            Text(
                              "Joueurs & Clubs de Beach Tennis",
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Segmented Glass TabBar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: _CommunityTabBar(),
                  ),

                  SizedBox(height: 4),

                  // Embedded Tab views
                  Expanded(
                    child: TabBarView(
                      children: [
                        PlayersScreen(isEmbedded: true),
                        ClubListScreen(isEmbedded: true),
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
}

class _CommunityHeaderIcon extends StatelessWidget {
  const _CommunityHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.coral, Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.coral.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 24),
    );
  }
}

class _CommunityTabBar extends StatelessWidget {
  const _CommunityTabBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          color: AppColors.coral,
          boxShadow: [
            BoxShadow(
              color: AppColors.coral.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_tennis, size: 16),
                SizedBox(width: 8),
                Text("Joueurs"),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 16),
                SizedBox(width: 8),
                Text("Clubs"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
