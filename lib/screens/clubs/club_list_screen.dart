import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/club.dart';
import '../../theme/colors.dart';
import '../../services/sound_service.dart';
import '../../providers/app_state.dart';
import 'club_detail_screen.dart';
import '../../widgets/link_fft_licence_modal.dart';
import 'dart:ui';

class ClubListScreen extends StatefulWidget {
  final bool isEmbedded;

  const ClubListScreen({super.key, this.isEmbedded = false});

  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedRegionFilter = "Tous";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AppState>().currentUser;
      if (user != null && user.isBrazilian) {
        setState(() => _selectedRegionFilter = "Brésil 🇧🇷");
      }
    });
  }

  String _getClubPhotoAsset(String name) => ClubModel.getClubPhotoAsset(name);

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .trim();
  }

  Widget _buildClubAffiliationBanner(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    if (user == null || (user.clubId != null && user.clubId!.isNotEmpty) || user.isBrazilian) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () => LinkFftLicenceModal.show(context),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.2),
                AppColors.coral.withValues(alpha: 0.16),
                const Color(0xFF141923).withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Rejoindre votre club officiel 🏟️",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Liez votre licence FFT pour intégrer automatiquement le salon et l'effectif de votre club.",
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 13),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _buildSearchBar(),
        _buildFilterChips(),
        _buildClubAffiliationBanner(context),
        const SizedBox(height: 4),
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

              if (_selectedRegionFilter == "Réunion 🇷🇪") {
                clubs = clubs.where((c) {
                  final loc = c.location.toLowerCase();
                  final name = c.name.toLowerCase();
                  return loc.contains('réunion') || loc.contains('reunion') || name.contains('bourbon') || name.contains('brisants');
                }).toList();
              } else if (_selectedRegionFilter == "Métropole 🇫🇷") {
                clubs = clubs.where((c) {
                  final loc = c.location.toLowerCase();
                  final ctry = (c.country ?? '').toLowerCase();
                  final name = c.name.toLowerCase();
                  final isOther = loc.contains('réunion') || loc.contains('reunion') || loc.contains('brésil') || loc.contains('brasil') || loc.contains('italie') || loc.contains('italy') || loc.contains('venezuela') || loc.contains('vénézuela') || loc.contains('aruba') || ctry.contains('br') || ctry.contains('it') || ctry.contains('ve') || ctry.contains('aw') || name.contains('bourbon') || name.contains('brisants');
                  return !isOther;
                }).toList();
              } else if (_selectedRegionFilter == "Brésil 🇧🇷") {
                clubs = clubs.where((c) {
                  final loc = c.location.toLowerCase();
                  final ctry = (c.country ?? '').toLowerCase();
                  return loc.contains('brésil') || loc.contains('brasil') || ctry.contains('br');
                }).toList();
              } else if (_selectedRegionFilter == "Italie 🇮🇹") {
                clubs = clubs.where((c) {
                  final loc = c.location.toLowerCase();
                  final ctry = (c.country ?? '').toLowerCase();
                  return loc.contains('italie') || loc.contains('italy') || ctry.contains('it');
                }).toList();
              } else if (_selectedRegionFilter == "Venezuela & Aruba 🇻🇪" || _selectedRegionFilter == "Venezuela 🇻🇪") {
                clubs = clubs.where((c) {
                  final loc = c.location.toLowerCase();
                  final ctry = (c.country ?? '').toLowerCase();
                  return loc.contains('venezuela') || loc.contains('vénézuela') || ctry.contains('ve') ||
                      loc.contains('aruba') || ctry.contains('aw');
                }).toList();
              }

              if (_searchQuery.trim().isNotEmpty) {
                final queryTokens = _normalize(_searchQuery)
                    .split(RegExp(r'\s+'))
                    .where((t) => t.isNotEmpty)
                    .toList();

                clubs = clubs.where((club) {
                  final haystack = _normalize('${club.name} ${club.location} ${club.description}');
                  return queryTokens.every((token) => haystack.contains(token));
                }).toList();
              }

              if (clubs.isEmpty) {
                return RefreshIndicator(
                  color: AppColors.coral,
                  backgroundColor: const Color(0xFF141D30),
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    SoundService.playRacketPop();
                    await context.read<AppState>().loadData();
                    if (context.mounted) setState(() {});
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(vertical: 80),
                    children: [
                      Center(
                        child: Text(
                          context.watch<AppState>().currentUser?.isBrazilian == true ? "Nenhuma arena encontrada." : "Aucun club trouvé.",
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.coral,
                backgroundColor: const Color(0xFF141D30),
                onRefresh: () async {
                  HapticFeedback.mediumImpact();
                  SoundService.playRacketPop();
                  await context.read<AppState>().loadData();
                  if (context.mounted) setState(() {});
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 100),
                  itemCount: (_searchQuery.isEmpty && _selectedRegionFilter == "Tous") ? clubs.length + 1 : clubs.length,
                  itemBuilder: (context, index) {
                    if (_searchQuery.isEmpty && _selectedRegionFilter == "Tous") {
                      if (index == 0) {
                        return _buildFeaturedArenasSection(context, clubs);
                      }
                      final club = clubs[index - 1];
                      return _buildClubCard(context, club);
                    }
                    final club = clubs[index];
                    return _buildClubCard(context, club);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background beach tennis players sunset
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.50),
            ),
          ),
          SafeArea(
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isBr = context.watch<AppState>().currentUser?.isBrazilian == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
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
                hintText: isBr ? 'Buscar uma arena, cidade...' : 'Rechercher un club, une ville...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
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

  Widget _buildFilterChips() {
    final isBr = context.watch<AppState>().currentUser?.isBrazilian == true;
    final filters = isBr
        ? [
            {'id': 'Brésil 🇧🇷', 'label': 'Brasil 🇧🇷'},
            {'id': 'Tous', 'label': 'Todos 🌍'},
            {'id': 'Métropole 🇫🇷', 'label': 'França 🇫🇷'},
            {'id': 'Réunion 🇷🇪', 'label': 'Reunião 🇷🇪'},
            {'id': 'Italie 🇮🇹', 'label': 'Itália 🇮🇹'},
            {'id': 'Venezuela & Aruba 🇻🇪', 'label': 'Venezuela & Aruba 🇻🇪'},
          ]
        : [
            {'id': 'Tous', 'label': 'Tous 🌍'},
            {'id': 'Métropole 🇫🇷', 'label': 'Métropole 🇫🇷'},
            {'id': 'Réunion 🇷🇪', 'label': 'Réunion 🇷🇪'},
            {'id': 'Brésil 🇧🇷', 'label': 'Brésil 🇧🇷'},
            {'id': 'Italie 🇮🇹', 'label': 'Italie 🇮🇹'},
            {'id': 'Venezuela & Aruba 🇻🇪', 'label': 'Venezuela & Aruba 🇻🇪'},
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((item) {
            final filterId = item['id']!;
            final filterLabel = item['label']!;
            final isSelected = _selectedRegionFilter == filterId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  filterLabel,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedRegionFilter = filterId);
                  }
                },
                backgroundColor: Colors.black.withValues(alpha: 0.60),
                selectedColor: AppColors.gold,
                side: BorderSide(
                  color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildClubCard(BuildContext context, ClubModel club) {
    final isBr = club.country == 'BR' || club.location.toLowerCase().contains('brasil') || club.location.toLowerCase().contains('brésil');
    final displayLocation = club.location.trim().isNotEmpty ? club.location.trim() : (isBr ? 'Brasil' : 'France');

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
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8604C).withValues(alpha: 0.35),
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
                              cacheWidth: 150,
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
                            cacheWidth: 150,
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
                          color: AppColors.coral.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
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

  Widget _buildFeaturedArenasSection(BuildContext context, List<ClubModel> allClubs) {
    final featuredList = [
      {
        'name': 'Beach Tennis Aruba (BTA)',
        'location': 'Eagle Beach, Aruba 🇦🇼',
        'badge': 'Mecque Mondiale',
        'courts': '12 terrains éclairés',
        'image': 'assets/images/beach_sunset_players_1785052273648.jpg',
        'matchName': 'aruba',
      },
      {
        'name': 'Palavas Beach Tennis',
        'location': 'Palavas-les-Flots 🇫🇷',
        'badge': 'Temple Méditerranéen',
        'courts': '14 courts de plage',
        'image': 'assets/images/beach_court_aerial_1785052250131.jpg',
        'matchName': 'palavas',
      },
      {
        'name': 'Bourbon Olympique BT',
        'location': "L'Étang-Salé, Réunion 🇷🇪",
        'badge': 'Île Intense',
        'courts': '8 courts permanents',
        'image': 'assets/images/beach_tennis_racket_1785052259397.jpg',
        'matchName': 'bourbon',
      },
      {
        'name': 'Gonzaga Santos Beach Tennis',
        'location': 'Santos, São Paulo 🇧🇷',
        'badge': 'Berceau Brésilien',
        'courts': '12 courts sur la plage',
        'image': 'assets/images/hero_beach_tennis_1785051787379.jpg',
        'matchName': 'santos',
      },
      {
        'name': 'Poetto Beach Tennis Arena',
        'location': 'Cagliari, Sardaigne 🇮🇹',
        'badge': 'Spot Mythique Italie',
        'courts': '8 courts mer cristalline',
        'image': 'assets/images/beach_tennis_ball_1785052281869.jpg',
        'matchName': 'poetto',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10, top: 4),
          child: Row(
            children: [
              Icon(Icons.stars_rounded, color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Text(
                "ARÈNES & SPOTS STARS",
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 155,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: featuredList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = featuredList[i];
              final match = allClubs.firstWhere(
                (c) => c.name.toLowerCase().contains(item['matchName']!) ||
                       c.location.toLowerCase().contains(item['matchName']!),
                orElse: () => ClubModel(
                  id: 'featured_$i',
                  name: item['name']!,
                  description: item['badge']!,
                  adminId: 'system',
                  memberIds: const [],
                  presidentEmails: const [],
                  location: item['location']!,
                  createdAt: DateTime.now(),
                ),
              );

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ClubDetailScreen(club: match)),
                  );
                },
                child: Container(
                  width: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                    image: DecorationImage(
                      image: AssetImage(item['image']!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.45),
                        BlendMode.darken,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.coral,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item['badge']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sports_tennis, color: AppColors.gold, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  item['courts']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: AppColors.gold, size: 13),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  item['location']!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TOUS LES CLUBS (${allClubs.length})",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const Icon(Icons.tune_rounded, color: Colors.white60, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}


