import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/colors.dart';
import '../../models/tournament.dart';
import '../profile_screen.dart';
import 'tournament_detail_screen.dart';
import 'beach_score_hub_screen.dart';
import '../../services/sound_service.dart';
import '../../l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  String _selectedCountryFilter = 'ALL';
  String _selectedCategoryFilter = 'Toutes 🏆';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Position? _currentPosition;
  bool _isLocating = false;
  
  final List<Map<String, String>> _countryFilters = [
    {'id': 'ALL', 'label': 'Tous 🌍'},
    {'id': 'NEARBY', 'label': 'À proximité 📍'},
    {'id': 'FR', 'label': 'France 🇫🇷'},
    {'id': 'RE', 'label': 'Réunion 🇷🇪'},
    {'id': 'BR', 'label': 'Brésil 🇧🇷'},
    {'id': 'IT', 'label': 'Italie 🇮🇹'},
    {'id': 'ES', 'label': 'Espagne 🇪🇸'},
  ];

  final List<String> _categoryFilters = [
    'Toutes 🏆',
    'Sand Series 🌟',
    'BT 2000 / 400',
    'BT 1000',
    'BT 500',
    'BT 250',
    'BT 100 / 25',
    'Terminés'
  ];

  @override
  void initState() {
    super.initState();
    _initUserLocation();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initUserLocation() async {
    try {
      final pos = context.read<AppState>().currentPosition;
      if (pos != null) {
        setState(() => _currentPosition = pos);
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final currentPos = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _currentPosition = currentPos);
      }
    } catch (_) {}
  }

  Future<void> _handleCountryFilter(String filterId) async {
    setState(() {
      _selectedCountryFilter = filterId;
    });

    if (filterId == 'NEARBY') {
      setState(() { _isLocating = true; });
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw Exception("Location services disabled.");
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) throw Exception("Location denied.");
        }
        if (permission == LocationPermission.deniedForever) {
          throw Exception("Location denied forever.");
        }

        _currentPosition = await Geolocator.getCurrentPosition();
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible de vous localiser. Vérifiez vos permissions.")));
        }
      } finally {
        if (mounted) {
          setState(() { _isLocating = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTournaments = context.watch<AppState>().tournaments;
    
    // Filtering logic
    var filteredTournaments = allTournaments.where((t) {
      // Filter by status (Passed / Active)
      if (_selectedCategoryFilter == 'Terminés') {
        if (!t.isPassed) return false;
      } else {
        if (t.isPassed) return false;
      }

      // Filter by Country / Distance
      if (_selectedCountryFilter == 'NEARBY') {
        final userPos = _currentPosition ?? context.read<AppState>().currentPosition;
        if (userPos == null || t.latitude == null || t.longitude == null) return false;
        final distance = Geolocator.distanceBetween(
          userPos.latitude, 
          userPos.longitude, 
          t.latitude!, 
          t.longitude!
        );
        if (distance > 100000) return false; // Tournois à moins de 100 km
      } else if (_selectedCountryFilter == 'FR') {
        final loc = t.location.toLowerCase();
        final c = (t.country ?? '').toLowerCase();
        final isOther = loc.contains('réunion') || loc.contains('reunion') || loc.contains('brésil') || loc.contains('brasil') || loc.contains('italie') || loc.contains('italy') || loc.contains('espagne') || loc.contains('spain') || c.contains('réunion') || c.contains('brésil') || c.contains('italie') || c.contains('espagne');
        if (isOther) return false;
      } else if (_selectedCountryFilter == 'RE') {
        final loc = t.location.toLowerCase();
        final c = (t.country ?? '').toLowerCase();
        final name = t.name.toLowerCase();
        if (!loc.contains('réunion') && !loc.contains('reunion') && !c.contains('réunion') && !name.contains('brisants') && !name.contains('bourbon') && !name.contains('tcbsp')) return false;
      } else if (_selectedCountryFilter == 'BR') {
        final loc = t.location.toLowerCase();
        final c = (t.country ?? '').toLowerCase();
        final name = t.name.toLowerCase();
        if (!loc.contains('brésil') && !loc.contains('brasil') && !c.contains('brésil') && !name.contains('brasilia') && !name.contains('copacabana')) return false;
      } else if (_selectedCountryFilter == 'IT') {
        final loc = t.location.toLowerCase();
        final c = (t.country ?? '').toLowerCase();
        final name = t.name.toLowerCase();
        if (!loc.contains('italie') && !loc.contains('italy') && !c.contains('italie') && !name.contains('cervia') && !name.contains('terracina')) return false;
      } else if (_selectedCountryFilter == 'ES') {
        final loc = t.location.toLowerCase();
        final c = (t.country ?? '').toLowerCase();
        final name = t.name.toLowerCase();
        if (!loc.contains('espagne') && !loc.contains('spain') && !c.contains('espagne') && !name.contains('canaria') && !name.contains('barcelona')) return false;
      }

      // Filter by Category
      if (_selectedCategoryFilter != 'ALL' && 
          _selectedCategoryFilter != 'Toutes' && 
          _selectedCategoryFilter != 'Toutes 🏆' && 
          _selectedCategoryFilter != 'Terminés') {
        if (_selectedCategoryFilter == 'Sand Series 🌟') {
          if (!t.category.toLowerCase().contains('sand')) return false;
        } else if (_selectedCategoryFilter == 'BT 2000 / 400') {
          if (!t.category.contains('2000') && !t.category.contains('400')) return false;
        } else if (_selectedCategoryFilter == 'BT 100 / 25') {
          if (!t.category.contains('100') && !t.category.contains('25') && !t.category.contains('50')) return false;
        } else {
          final regex = RegExp(_selectedCategoryFilter + r'(?!\d)');
          if (!regex.hasMatch(t.category)) return false;
        }
      }

      // Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final nameMatches = t.name.toLowerCase().contains(_searchQuery);
        final locMatches = t.location.toLowerCase().contains(_searchQuery);
        final clubMatches = t.club.toLowerCase().contains(_searchQuery);
        final catMatches = t.category.toLowerCase().contains(_searchQuery);
        if (!nameMatches && !locMatches && !clubMatches && !catMatches) return false;
      }

      return true;
    }).toList();
    
    // Sort logic : If nearby filter selected, sort by closest distance, otherwise by date
    final userPos = _currentPosition ?? context.read<AppState>().currentPosition;
    if (_selectedCountryFilter == 'NEARBY' && userPos != null) {
      filteredTournaments.sort((a, b) {
        if (a.latitude == null || a.longitude == null) return 1;
        if (b.latitude == null || b.longitude == null) return -1;
        final distA = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, a.latitude!, a.longitude!);
        final distB = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, b.latitude!, b.longitude!);
        return distA.compareTo(distB);
      });
    } else {
      filteredTournaments.sort((a, b) {
        DateTime? parseDate(String dateStr) {
          if (dateStr.length >= 10) {
            try {
              final parts = dateStr.substring(0, 10).split('/');
              if (parts.length == 3) {
                return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            } catch (_) {}
          }
          return null;
        }
        
        final dateA = parseDate(a.dateString) ?? DateTime(2100);
        final dateB = parseDate(b.dateString) ?? DateTime(2100);
        
        if (_selectedCategoryFilter == 'Terminés') {
          return dateB.compareTo(dateA);
        }
        return dateA.compareTo(dateB);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_court_aerial_1785052250131.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.tournamentListTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                            Text(
                              AppLocalizations.of(context)!.tournamentListCount(filteredTournaments.length), 
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.radar, color: AppColors.coral, size: 28),
                        tooltip: "Radar des alertes",
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                        },
                      ),
                    ],
                  ),
                ),

                // 🔴 BANNIÈRE HERO INTERACTIVE BEACHSCORE LIVE (Option 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BeachScoreHubScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF8B0000), // Deep ruby
                            Color(0xFFE53935), // Vivid red
                            Color(0xFFF4A535), // Warm gold
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.gold.withOpacity(0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "BEACHSCORE LIVE 🔴",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "ITF / FFT",
                                      style: TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Scores en direct, calendrier mondial & pronostics",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Ouvrir",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11.5,
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(Icons.arrow_forward_ios_rounded, color: Colors.black, size: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 🔍 Barre de Recherche Instantanée
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Rechercher une ville, club, catégorie...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),

                // 🌍 1ère Rangée : Filtres Pays & Proximité
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _countryFilters.length,
                    itemBuilder: (context, index) {
                      final item = _countryFilters[index];
                      final isSelected = _selectedCountryFilter == item['id'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            item['label']!,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              _handleCountryFilter(item['id']!);
                            }
                          },
                          backgroundColor: Colors.black.withOpacity(0.6),
                          selectedColor: AppColors.gold,
                          side: BorderSide(
                            color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 6),

                // 🏆 2ème Rangée : Filtres Catégories (BT 2000, BT 1000, BT 500...)
                SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categoryFilters.length,
                    itemBuilder: (context, index) {
                      final cat = _categoryFilters[index];
                      final isSelected = _selectedCategoryFilter == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : (cat == 'Terminés' ? Colors.grey : Colors.white70),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategoryFilter = cat);
                            }
                          },
                          backgroundColor: Colors.black.withOpacity(0.4),
                          selectedColor: AppColors.coral,
                          side: BorderSide(
                            color: isSelected ? AppColors.coral : Colors.white.withOpacity(0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (_isLocating)
                  const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text("Localisation en cours...", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),

                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.coral,
                    backgroundColor: const Color(0xFF141D30),
                    onRefresh: () async {
                      HapticFeedback.mediumImpact();
                      SoundService.playRacketPop();
                      _initUserLocation();
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (mounted) setState(() {});
                    },
                    child: filteredTournaments.isEmpty 
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(AppLocalizations.of(context)!.tournamentListEmpty, style: const TextStyle(color: Colors.white70)),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 100),
                          itemCount: filteredTournaments.length,
                          itemBuilder: (context, index) {
                            return _buildTournamentCard(context, filteredTournaments[index]);
                          },
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(BuildContext context, TournamentModel tournament) {
    String? distanceText;
    final userPos = _currentPosition ?? context.read<AppState>().currentPosition;
    if (userPos != null && tournament.latitude != null && tournament.longitude != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        tournament.latitude!,
        tournament.longitude!,
      );
      final km = (distanceInMeters / 1000).round();
      distanceText = "$km km";
    }

    String? flag;
    final locLower = tournament.location.toLowerCase();
    final countryLower = (tournament.country ?? '').toLowerCase();
    if (locLower.contains('italie') || locLower.contains('italy') || countryLower.contains('italie')) {
      flag = '🇮🇹';
    } else if (locLower.contains('espagne') || locLower.contains('spain') || countryLower.contains('espagne')) {
      flag = '🇪🇸';
    } else if (locLower.contains('nouméa') || locLower.contains('noumea')) {
      flag = '🇳🇨';
    } else if (locLower.contains('reunion') || locLower.contains('réunion') || locLower.contains('clotilde') || locLower.contains('paul')) {
      flag = '🇷🇪';
    } else {
      flag = '🇫🇷';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TournamentDetailScreen(tournament: tournament),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tournament.isPassed ? Colors.grey.withOpacity(0.08) : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: tournament.isPassed ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.2), 
                width: 1.2
              ),
            ),
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.coral.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.coral.withOpacity(0.5)),
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(tournament.category), 
                    color: AppColors.gold, 
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🏷️ Rangée Badges : Catégorie + Drapeau + Distance + Statut
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(tournament.category),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tournament.category,
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (flag.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(flag, style: const TextStyle(fontSize: 10)),
                          ),
                        ],
                        const Spacer(),
                        if (distanceText != null && !tournament.isPassed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.gold.withOpacity(0.6), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.near_me_rounded, color: AppColors.gold, size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  distanceText,
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (tournament.isPassed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'TERMINÉ',
                              style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 🎾 Titre du Tournoi (Largeur complète, jamais écrasé)
                    Text(
                      tournament.name,
                      style: TextStyle(
                        color: tournament.isPassed ? Colors.white60 : Colors.white, 
                        fontSize: 15.5, 
                        fontWeight: FontWeight.bold, 
                        height: 1.25,
                        decoration: tournament.isPassed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white60, size: 14),
                        const SizedBox(width: 4),
                        Text(tournament.dateString, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white60, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tournament.location,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (tournament.club.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(tournament.club, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Color _getCategoryColor(String category) {
    if (category.contains("2000")) return Colors.purpleAccent;
    if (category.contains("1000")) return Colors.redAccent;
    if (category.contains("500")) return Colors.orangeAccent;
    if (category.contains("250")) return AppColors.coral;
    if (category.contains("100")) return Colors.greenAccent;
    return AppColors.gold;
  }
  
  IconData _getCategoryIcon(String category) {
    if (category.contains("2000") || category.contains("1000")) return Icons.diamond;
    return Icons.star;
  }
}
