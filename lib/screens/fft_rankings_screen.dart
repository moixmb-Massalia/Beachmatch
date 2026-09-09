import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';

class FftRankingsScreen extends StatefulWidget {
  const FftRankingsScreen({super.key});

  @override
  State<FftRankingsScreen> createState() => _FftRankingsScreenState();
}

class _FftRankingsScreenState extends State<FftRankingsScreen> {
  int _selectedTabIndex = 0; // 0: Hommes ('M'), 1: Dames ('F')
  String _searchQuery = '';

  int _parseRank(dynamic value, {int defaultRank = 0}) {
    if (value == null) return defaultRank;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned) ?? defaultRank;
    }
    return defaultRank;
  }

  int _parseEvolution(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      final isNegative = trimmed.contains('-') || trimmed.contains('▼');
      final cleaned = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(cleaned) ?? 0;
      return isNegative ? -parsed : parsed;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final String currentGender = _selectedTabIndex == 0 ? 'M' : 'F';

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Black Overlay 55%
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Classement FFT Beach Tennis",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Source: Ten'Up · 09/09/2026",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar Glass
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.20), width: 1.2),
                        ),
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                          decoration: InputDecoration(
                            hintText: "Rechercher par nom, prénom ou club...",
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.white60),
                            prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                                    onPressed: () => setState(() => _searchQuery = ""),
                                  )
                                : null,
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Glass Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedTabIndex = 0;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 0 ? AppColors.gold : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "🏆 Hommes",
                                style: TextStyle(
                                  color: _selectedTabIndex == 0 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedTabIndex = 1;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 1 ? AppColors.coral : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "🎽 Dames",
                                style: TextStyle(
                                  color: _selectedTabIndex == 1 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Ranking List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('fft_rankings')
                        .where('gender', isEqualTo: currentGender)
                        .orderBy('rank', descending: false)
                        .limit(200)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        // Fallback query in case the composite index is building or missing
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('fft_rankings')
                              .where('gender', isEqualTo: currentGender)
                              .limit(200)
                              .snapshots(),
                          builder: (context, fallbackSnap) {
                            if (fallbackSnap.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(color: AppColors.gold),
                              );
                            }
                            if (!fallbackSnap.hasData || fallbackSnap.data!.docs.isEmpty) {
                              return _buildEmptyState();
                            }
                            final docs = fallbackSnap.data!.docs.toList();
                            docs.sort((a, b) {
                              final dataA = a.data() as Map<String, dynamic>;
                              final dataB = b.data() as Map<String, dynamic>;
                              final rankA = _parseRank(dataA['rank'] ?? dataA['level']);
                              final rankB = _parseRank(dataB['rank'] ?? dataB['level']);
                              return rankA.compareTo(rankB);
                            });
                            return _buildListFromDocs(docs);
                          },
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.gold),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      return _buildListFromDocs(docs);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListFromDocs(List<QueryDocumentSnapshot> docs) {
    final filteredDocs = docs.where((doc) {
      if (_searchQuery.isEmpty) return true;
      final data = doc.data() as Map<String, dynamic>;
      final firstName = (data['firstName'] ?? '').toString().toLowerCase();
      final lastName = (data['lastName'] ?? '').toString().toLowerCase();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final club = (data['club'] ?? '').toString().toLowerCase();
      final league = (data['league'] ?? data['ligue'] ?? '').toString().toLowerCase();
      final licence = (data['licenceNumber'] ?? '').toString().toLowerCase();

      return name.contains(_searchQuery) ||
          firstName.contains(_searchQuery) ||
          lastName.contains(_searchQuery) ||
          club.contains(_searchQuery) ||
          league.contains(_searchQuery) ||
          licence.contains(_searchQuery);
    }).toList();

    if (filteredDocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: Colors.white60),
            const SizedBox(height: 12),
            const Text(
              "Aucun joueur trouvé",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Essayez un autre mot-clé",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 90),
        itemCount: filteredDocs.length,
        itemBuilder: (context, index) {
          final data = filteredDocs[index].data() as Map<String, dynamic>;
          return _buildRankingCard(data, index);
        },
      ),
    );
  }

  Widget _buildRankingCard(Map<String, dynamic> data, int index) {
    final dynamic rawRank = data['rank'] ?? data['level'];
    final int rank = _parseRank(rawRank, defaultRank: index + 1);

    final dynamic rawEvolution = data['evolution'] ?? data['rankChange'] ?? data['progression'];
    final int evolution = _parseEvolution(rawEvolution);

    String name = (data['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['lastName'] ?? '').toString().trim();
      name = "$first $last".trim();
    }
    if (name.isEmpty) {
      name = "Joueur Inconnu";
    }

    final dynamic rawPoints = data['points'] ?? data['elo'] ?? 0;
    final String points = rawPoints.toString();

    final dynamic rawTournaments = data['tournaments'] ?? data['tournamentsCount'] ?? data['nbTournois'] ?? 0;
    final String tournaments = rawTournaments.toString();

    final String league = (data['league'] ?? data['ligue'] ?? data['club'] ?? '').toString().trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.20),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // Rank & Evolution column
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRankBadge(rank),
                    const SizedBox(height: 3),
                    _buildEvolution(evolution),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Player Name + League
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (league.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        league,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.50),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Points & Tournaments
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$points pts",
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$tournaments tournois",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return const Text("🥇", style: TextStyle(fontSize: 22));
    } else if (rank == 2) {
      return const Text("🥈", style: TextStyle(fontSize: 22));
    } else if (rank == 3) {
      return const Text("🥉", style: TextStyle(fontSize: 22));
    } else {
      return Text(
        "$rank",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      );
    }
  }

  Widget _buildEvolution(int evo) {
    if (evo > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "▲",
            style: TextStyle(
              color: Color(0xFF4ADE80),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 1),
          Text(
            "$evo",
            style: const TextStyle(
              color: Color(0xFF4ADE80),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (evo < 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "▼",
            style: TextStyle(
              color: Color(0xFFF87171),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 1),
          Text(
            "${evo.abs()}",
            style: const TextStyle(
              color: Color(0xFFF87171),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      return const Text(
        "—",
        style: TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              "Aucun classement disponible",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Les données FFT Ten'Up apparaîtront ici dès synchronisation.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
