import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/colors.dart';
import '../widgets/feature_discovery_bubble.dart';
import 'public_profile_screen.dart';

class FftRankingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const FftRankingsScreen({super.key, this.isEmbedded = false});

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

  String _normalize(String s) {
    return s.toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .trim();
  }

  Future<List<Map<String, dynamic>>> _searchRankings(String query, String gender) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];

    final normQ = _normalize(cleanQ);
    final tokens = normQ.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    final digits = cleanQ.replaceAll(RegExp(r'\D'), '');

    final Map<String, Map<String, dynamic>> resultMap = {};
    void addCandidate(Map<String, dynamic> data, String docId) {
      if (data['gender'] != null && data['gender'] != gender) return;

      final fName = (data['firstName'] ?? '').toString().trim();
      final lName = (data['lastName'] ?? '').toString().trim();
      final rawName = (data['name'] ?? '$fName $lName').toString().trim();
      final nameKey = _normalize(rawName);
      final lic = (data['licenceNumber'] ?? '').toString().trim();

      if (nameKey.isNotEmpty && resultMap.containsKey(nameKey)) {
        final existing = resultMap[nameKey]!;
        final existingLic = (existing['licenceNumber'] ?? '').toString().trim();
        if (existingLic.isEmpty && lic.isNotEmpty) {
          resultMap[nameKey] = data;
        }
        return;
      }

      final key = nameKey.isNotEmpty ? nameKey : (lic.isNotEmpty ? lic : docId);
      resultMap[key] = data;
    }

    // 1. Recherche directe par numéro de licence
    if (digits.length >= 3) {
      final doc = await FirebaseFirestore.instance.collection('fft_rankings').doc(digits).get();
      if (doc.exists && doc.data() != null) {
        addCandidate(Map<String, dynamic>.from(doc.data()!), digits);
      }

      final licSnap = await FirebaseFirestore.instance
          .collection('fft_rankings')
          .where('searchTokens', arrayContains: digits)
          .where('gender', isEqualTo: gender)
          .limit(40)
          .get();
      for (var d in licSnap.docs) {
        addCandidate(Map<String, dynamic>.from(d.data()), d.id);
      }
    }

    // 2. Recherche rapide par searchTokens (insensible aux accents et à la casse)
    for (var tok in tokens) {
      final snap = await FirebaseFirestore.instance
          .collection('fft_rankings')
          .where('searchTokens', arrayContains: tok)
          .where('gender', isEqualTo: gender)
          .limit(80)
          .get();
      for (var d in snap.docs) {
        addCandidate(Map<String, dynamic>.from(d.data()), d.id);
      }
    }

    // 3. Fallback range queries si peu de résultats
    if (resultMap.length < 10) {
      final upperQ = cleanQ.toUpperCase();
      final titleQ = cleanQ[0].toUpperCase() + cleanQ.substring(1).toLowerCase();

      final snaps = await Future.wait([
        FirebaseFirestore.instance
            .collection('fft_rankings')
            .where('lastName', isGreaterThanOrEqualTo: upperQ)
            .where('lastName', isLessThanOrEqualTo: '$upperQ\uf8ff')
            .where('gender', isEqualTo: gender)
            .limit(30)
            .get(),
        FirebaseFirestore.instance
            .collection('fft_rankings')
            .where('firstName', isGreaterThanOrEqualTo: upperQ)
            .where('firstName', isLessThanOrEqualTo: '$upperQ\uf8ff')
            .where('gender', isEqualTo: gender)
            .limit(30)
            .get(),
        FirebaseFirestore.instance
            .collection('fft_rankings')
            .where('firstName', isGreaterThanOrEqualTo: titleQ)
            .where('firstName', isLessThanOrEqualTo: '$titleQ\uf8ff')
            .where('gender', isEqualTo: gender)
            .limit(30)
            .get(),
      ]);

      for (var s in snaps) {
        for (var d in s.docs) {
          addCandidate(Map<String, dynamic>.from(d.data()), d.id);
        }
      }
    }

    // Filtrage multi-tokens en mémoire
    final filtered = resultMap.values.where((data) {
      if (tokens.isEmpty) return true;
      final f = _normalize((data['firstName'] ?? '').toString());
      final l = _normalize((data['lastName'] ?? '').toString());
      final n = _normalize((data['name'] ?? '$f $l').toString());
      final c = _normalize((data['club'] ?? '').toString());
      final lic = (data['licenceNumber'] ?? '').toString();

      return tokens.every((tok) =>
          n.contains(tok) ||
          f.contains(tok) ||
          l.contains(tok) ||
          c.contains(tok) ||
          lic.contains(tok));
    }).toList();

    filtered.sort((a, b) {
      final aLic = (a['licenceNumber'] ?? '').toString();
      final bLic = (b['licenceNumber'] ?? '').toString();
      if (aLic == cleanQ && bLic != cleanQ) return -1;
      if (aLic != cleanQ && bLic == cleanQ) return 1;

      final rankA = _parseRank(a['rank'] ?? a['level']);
      final rankB = _parseRank(b['rank'] ?? b['level']);
      return rankA.compareTo(rankB);
    });

    return filtered;
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
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                if (!widget.isEmbedded)
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
                                color: AppColors.gold.withValues(alpha: 0.4),
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
                                "Source : FFT Ten'Up · Classement officiel",
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
                  )
                else
                  const SizedBox(height: 12),

                // Search Bar Glass
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.2),
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

                const FeatureDiscoveryBubble(
                  featureKey: 'fft_rankings_tip',
                  title: "Classement National Officiel Ten'Up",
                  message: "Retrouvez les 3 300+ joueurs et joueuses classés en France. Utilisez la recherche pour trouver un joueur par nom ou numéro de licence !",
                  icon: Icons.search_rounded,
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                ),

                // Glass Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
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
                  child: _searchQuery.isNotEmpty
                      ? FutureBuilder<List<Map<String, dynamic>>>(
                          future: _searchRankings(_searchQuery, currentGender),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(color: AppColors.gold),
                              );
                            }
                            final items = snapshot.data ?? [];
                            return _buildListFromMaps(items);
                          },
                        )
                      : StreamBuilder<QuerySnapshot>(
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
    final items = docs.map((d) => d.data() as Map<String, dynamic>).toList();
    return _buildListFromMaps(items);
  }

  Widget _buildListFromMaps(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
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
              "Essayez un autre mot-clé ou vérifiez l'orthographe",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 90),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildRankingCard(items[index], index);
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

    return GestureDetector(
      onTap: () => _showPlayerRankingModal(context, data, rank, evolution, points, tournaments, league, name),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
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
                            color: Colors.white.withValues(alpha: 0.50),
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
      ),
    );
  }

  void _showPlayerRankingModal(
    BuildContext context,
    Map<String, dynamic> data,
    int rank,
    int evolution,
    String points,
    String tournaments,
    String league,
    String name,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1B29).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          rank <= 3 ? (rank == 1 ? "🥇" : (rank == 2 ? "🥈" : "🥉")) : "#$rank",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            league.isNotEmpty ? league : "Fédération Française de Tennis",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildModalStat("Classement FFT", "#$rank", AppColors.gold),
                      _buildModalStat("Points Ten'Up", points, Colors.white),
                      _buildModalStat("Tournois joués", tournaments, Colors.white70),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.person_search_rounded, size: 20),
                    label: const Text("Consulter la fiche profil", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      PublicProfileScreen.open(
                        context,
                        userId: (data['licenceNumber'] ?? data['userId'] ?? data['name'])?.toString(),
                        displayName: name,
                        ranking: rank.toString(),
                        location: league,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("Partager cette fiche joueur", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      SharePlus.instance.share(ShareParams(text: "🎾 $name est classé(e) #$rank au Beach Tennis français avec $points pts sur BeachMatch !"));
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
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
              color: Colors.white.withValues(alpha: 0.4),
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
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
