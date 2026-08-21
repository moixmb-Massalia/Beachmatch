import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/club.dart';
import '../../theme/colors.dart';
import '../../services/sound_service.dart';
import 'club_detail_screen.dart';
import 'dart:ui';

class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});

  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  String _getClubPhotoAsset(String name) {
    const beachPhotos = [
      'assets/images/beach_sunset_players_1785052273648.jpg',
      'assets/images/beach_tennis_racket_1785052259397.jpg',
      'assets/images/beach_court_aerial_1785052250131.jpg',
      'assets/images/beach_tennis_ball_1785052281869.jpg',
      'assets/images/hero_beach_tennis_1785051787379.jpg',
    ];
    int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return beachPhotos[hash.abs() % beachPhotos.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background beach tennis players sunset
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.50),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('clubs').orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.white)));
                      }
                      
                      var clubs = snapshot.data?.docs.map((doc) => ClubModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList() ?? [];

                      if (_searchQuery.isNotEmpty) {
                        clubs = clubs.where((club) => club.name.toLowerCase().contains(_searchQuery.toLowerCase()) || club.location.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                      }

                      if (clubs.isEmpty) {
                        return const Center(
                          child: Text(
                            "Aucun club trouvé.",
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: AppColors.coral,
                        backgroundColor: const Color(0xFF141D30),
                        onRefresh: () async {
                          HapticFeedback.mediumImpact();
                          SoundService.playRacketPop();
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (context.mounted) setState(() {});
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 100),
                          itemCount: clubs.length,
                          itemBuilder: (context, index) {
                            final club = clubs[index];
                            return _buildClubCard(context, club);
                          },
                        ),
                      );
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.2),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un club, une ville...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = "";
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClubCard(BuildContext context, ClubModel club) {
    final displayLocation = (club.location.isEmpty || club.location.toLowerCase().contains('recherche'))
        ? 'France'
        : club.location;
    final initial = club.name.isNotEmpty ? club.name[0].toUpperCase() : 'C';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ClubDetailScreen(club: club)));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.2),
            ),
            child: Row(
              children: [
                // Avatar du club (Photo HD Beach Tennis ou photo personnalisée)
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8604C).withOpacity(0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: (club.bannerUrl != null && club.bannerUrl!.trim().isNotEmpty && club.bannerUrl!.startsWith('http'))
                        ? Image.network(
                            club.bannerUrl!.trim(),
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              _getClubPhotoAsset(club.name),
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.sports_tennis, color: Colors.white, size: 24),
                              ),
                            ),
                          )
                        : Image.asset(
                            _getClubPhotoAsset(club.name),
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.sports_tennis, color: Colors.white, size: 24),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Infos du club
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.coral),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              displayLocation,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.coral.withOpacity(0.5)),
                        ),
                        child: Text(
                          "${club.memberIds.length} membre${club.memberIds.length > 1 ? 's' : ''}",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


