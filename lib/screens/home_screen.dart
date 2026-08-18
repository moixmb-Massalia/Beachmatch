import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/match.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';
import '../services/weather_service.dart';
import '../widgets/beach_weather_widget.dart';
import '../models/match.dart' as bm_match;
import '../l10n/app_localizations.dart';
import '../models/court.dart';
import 'package:geolocator/geolocator.dart';
import 'create_match_screen.dart';
import 'clubs/club_detail_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = "Toutes";

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final allMatches = context.watch<AppState>().matches;
    final courts = context.watch<AppState>().courts;
    
    // Application du filtre sur les parties à venir (exclut les matchs terminés d'hier ou plus vieux)
    final now = DateTime.now();
    final activeMatches = allMatches.where((m) => m.scheduledTime.isAfter(now.subtract(const Duration(hours: 3)))).toList();

    List<MatchModel> matches = activeMatches;
    if (_selectedFilter == "Autour de moi" && user != null) {
      final userCityWords = user.location.toLowerCase().split(RegExp(r'\s+|,'));
      final nearbyCourtsIds = courts.where((c) {
        final courtCityLower = c.city.toLowerCase();
        return userCityWords.any((word) => word.length > 3 && courtCityLower.contains(word));
      }).map((c) => c.id).toList();
      
      if (nearbyCourtsIds.isNotEmpty) {
        matches = activeMatches.where((m) => nearbyCourtsIds.contains(m.courtId)).toList();
      } else {
        matches = [];
      }
    } else if (_selectedFilter == "Niveau 1-4") {
      matches = activeMatches.where((m) => m.targetLevel <= 4).toList();
    } else if (_selectedFilter == "Niveau 5+") {
      matches = activeMatches.where((m) => m.targetLevel >= 5).toList();
    } else if (_selectedFilter == "Aujourd'hui") {
      matches = activeMatches.where((m) => 
        m.scheduledTime.year == now.year && 
        m.scheduledTime.month == now.month && 
        m.scheduledTime.day == now.day
      ).toList();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Immersion Beach Background
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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              children: [
                _buildHeader(user),
                const SizedBox(height: 18),
                _buildRadarCard(context, user, courts),
                const SizedBox(height: 18),
                _buildWeekendRitualCard(context),
                _buildHeroBanner(),
                const SizedBox(height: 20),
                _buildWeatherCard(user),
                const SizedBox(height: 24),
                _buildWorldNewsSection(context),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.homeMatchesTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.coral.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("${matches.length} ${AppLocalizations.of(context)!.homeMatchesLive}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ["Toutes", "Autour de moi", "Aujourd'hui", "Niveau 1-4", "Niveau 5+"].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFilter = filter);
                            }
                          },
                          selectedColor: AppColors.gold,
                          backgroundColor: Colors.black.withOpacity(0.5),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                if (matches.isEmpty)
                  _buildGlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.sports_tennis, size: 64, color: AppColors.gold),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            AppLocalizations.of(context)!.homeEmptyStateTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.homeEmptyStateSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateMatchScreen()));
                            },
                            icon: const Icon(Icons.add, size: 20),
                            label: Text(AppLocalizations.of(context)!.homeCreateMatchButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 8,
                              shadowColor: AppColors.gold.withOpacity(0.5),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ...matches.map((m) => _buildMatchCard(context, user, m, courts)),
                const SizedBox(height: 90), // FAB space
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 95.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.coral.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.coral,
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateMatchScreen()));
          },
          icon: const Icon(Icons.sports_tennis, color: Colors.white),
          label: Text(AppLocalizations.of(context)!.homeFabCreate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    ),
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 24}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader(user) {
    return _buildGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                  image: user?.photoUrl != null ? DecorationImage(image: NetworkImage(user!.photoUrl!), fit: BoxFit.cover) : null,
                ),
                child: user?.photoUrl == null 
                    ? Center(child: Text(user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)))
                    : null,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${AppLocalizations.of(context)!.homeHeaderGreeting} ${user?.displayName.split(' ').first ?? ''} 🎾", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.gold, size: 14),
                      const SizedBox(width: 4),
                      Text(user?.location ?? 'Nice, France', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(AppLocalizations.of(context)!.homeHeaderLevel(user?.level ?? 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRadarCard(BuildContext context, UserModel? user, List<CourtModel> courts) {
    if (courts.isEmpty) return const SizedBox.shrink();

    final appState = context.watch<AppState>();
    final pos = appState.currentPosition;
    final bool hasGps = pos != null;
    final userCoords = hasGps ? (pos.latitude, pos.longitude) : _getUserCoordinates(user?.location);

    // Trier les terrains par distance réelle
    final List<Map<String, dynamic>> courtsWithDist = courts.map((court) {
      final distMeters = Geolocator.distanceBetween(
        userCoords.$1,
        userCoords.$2,
        court.latitude,
        court.longitude,
      );
      return {
        'court': court,
        'distKm': distMeters / 1000.0,
      };
    }).toList();

    courtsWithDist.sort((a, b) => (a['distKm'] as double).compareTo(b['distKm'] as double));

    final nearest = courtsWithDist.first;
    final CourtModel nearestCourt = nearest['court'];
    final double nearestDist = nearest['distKm'];
    final int closeCourtsCount = courtsWithDist.where((c) => (c['distKm'] as double) <= 35.0).length;

    // Détermination propre et claire du libellé de position
    final rawLoc = (user?.location ?? '').trim().toLowerCase();
    final isClubOrGeneric = rawLoc.contains('club') ||
        rawLoc.contains('beach tennis') ||
        rawLoc.contains('recherche') ||
        rawLoc.contains('non définie') ||
        rawLoc.contains('position') ||
        rawLoc.contains('ligue');

    String locationLabel;
    bool showGpsAction = false;

    if (hasGps) {
      locationLabel = nearestCourt.city.isNotEmpty ? "Autour de moi (${nearestCourt.city})" : "Autour de moi (GPS)";
    } else if (user?.location != null && user!.location.isNotEmpty && !isClubOrGeneric) {
      locationLabel = user.location.split(',').first.trim();
    } else {
      locationLabel = "Activer le GPS 📍";
      showGpsAction = true;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F1B29).withOpacity(0.92),
                  const Color(0xFF16253B).withOpacity(0.88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête Radar avec indicateur pulse bleu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const PulsingRadarDot(
                          color: Color(0xFF00D2FF), // Bleu vibrant vivant
                          size: 10,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "RADAR BEACHMATCH",
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: showGpsAction
                          ? () async {
                              await context.read<AppState>().refreshLocation();
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: showGpsAction ? AppColors.coral.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: showGpsAction ? Border.all(color: AppColors.coral, width: 1) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              showGpsAction ? Icons.my_location_rounded : Icons.near_me,
                              color: showGpsAction ? AppColors.coral : Colors.white70,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              locationLabel,
                              style: TextStyle(
                                color: showGpsAction ? AppColors.gold : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Info Spot le plus proche (Cliquable -> Maps ou Fiche Club)
                GestureDetector(
                  onTap: () => _handleCourtOrClubTap(context, nearestCourt),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          nearestCourt.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nearestCourt.accessType == 'CLUB_ONLY' ? "Club" : "Terrain",
                              style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 3 Puces métriques
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildRadarMetricChip(
                      icon: Icons.location_on,
                      label: "${nearestDist.toStringAsFixed(1)} km",
                      color: AppColors.coral,
                    ),
                    _buildRadarMetricChip(
                      icon: Icons.sports_tennis,
                      label: "$closeCourtsCount spot${closeCourtsCount > 1 ? 's' : ''} proche${closeCourtsCount > 1 ? 's' : ''}",
                      color: AppColors.gold,
                    ),
                    _buildRadarMetricChip(
                      icon: Icons.check_circle_outline,
                      label: nearestCourt.accessType == 'BEACH_FREE'
                          ? "Plage libre"
                          : (nearestCourt.accessType == 'CLUB_ONLY' ? "Club affilié" : "Complexe sportif"),
                      color: const Color(0xFF00D2FF),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bouton Action Radar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRadarScannerModal(context, courtsWithDist),
                    icon: const Icon(Icons.radar, size: 18, color: Colors.white),
                    label: const Text(
                      "Explorer les terrains autour de moi",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCourtOrClubTap(BuildContext context, CourtModel court) async {
    final bool isClub = court.accessType == 'CLUB_ONLY' || 
                        court.name.toLowerCase().contains('club') || 
                        court.name.toLowerCase().contains('tc ') ||
                        court.name.toLowerCase().contains('tennis club');

    if (isClub) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('clubs')
            .where('name', isEqualTo: court.name)
            .limit(1)
            .get();

        ClubModel club;
        if (snap.docs.isNotEmpty) {
          club = ClubModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
        } else {
          club = ClubModel(
            id: court.id,
            name: court.name,
            description: court.description ?? 'Club de beach tennis affilié FFT.',
            adminId: '',
            memberIds: [],
            location: court.city.isNotEmpty ? court.city : 'France',
            createdAt: DateTime.now(),
          );
        }

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ClubDetailScreen(club: club)),
          );
        }
        return;
      } catch (_) {}
    }

    // Terrain public / spot de plage -> Ouvrir la Maps centrée sur ce spot avec fiche détaillée
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MapScreen(initialCourt: court)),
      );
    }
  }

  Widget _buildRadarMetricChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showRadarScannerModal(BuildContext context, List<Map<String, dynamic>> courtsWithDist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1B29).withOpacity(0.96),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    PulsingRadarDot(color: Color(0xFF00D2FF), size: 12),
                    SizedBox(width: 10),
                    Text("Radar des Terrains", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text("Spots de beach tennis classés par proximité immédiate (cliquez pour ouvrir)", style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: courtsWithDist.take(6).length,
                    itemBuilder: (context, index) {
                      final item = courtsWithDist[index];
                      final CourtModel court = item['court'];
                      final double dist = item['distKm'];

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleCourtOrClubTap(context, court);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.coral.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.sports_tennis, color: AppColors.coral, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(court.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text("${court.city.isNotEmpty ? court.city : court.country} · ${court.accessType == 'BEACH_FREE' ? 'Plage libre' : (court.accessType == 'CLUB_ONLY' ? 'Club' : 'Complexe')}", style: const TextStyle(color: Colors.white60, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text("${dist.toStringAsFixed(1)} km", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.directions, color: Colors.blueAccent, size: 20),
                                        tooltip: "Itinéraire GPS",
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${court.latitude},${court.longitude}");
                                          launchUrl(url, mode: LaunchMode.externalApplication);
                                        },
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle, color: AppColors.coral, size: 20),
                                        tooltip: "Créer un match",
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => CreateMatchScreen(preselectedCourt: court)));
                                        },
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: AssetImage('assets/images/beach_tennis_racket_1785052259397.jpg'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.primary.withOpacity(0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(AppLocalizations.of(context)!.homeHeaderSeason, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)!.homeHeaderTitle, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text(AppLocalizations.of(context)!.homeHeaderSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  (double, double) _getUserCoordinates(String? location) {
    final text = (location ?? '').toLowerCase();
    if (text.contains('marseille')) return (43.2965, 5.3698);
    if (text.contains('nice') || text.contains('cannes') || text.contains('antibes')) return (43.7102, 7.2620);
    if (text.contains('bordeaux') || text.contains('arcachon')) return (44.8378, -0.5792);
    if (text.contains('montpellier') || text.contains('palavas')) return (43.6108, 3.8767);
    if (text.contains('toulon') || text.contains('hyères')) return (43.1242, 5.9280);
    if (text.contains('perpignan') || text.contains('canet')) return (42.6886, 2.8948);
    if (text.contains('la rochelle') || text.contains('île de ré')) return (46.1603, -1.1511);
    if (text.contains('paris') || text.contains('île-de-france')) return (48.8566, 2.3522);
    if (text.contains('rennes') || text.contains('bretagne')) return (48.1173, -1.6778);
    if (text.contains('nantes') || text.contains('baule')) return (47.2184, -1.5536);
    if (text.contains('lyon')) return (45.7640, 4.8357);
    if (text.contains('toulouse')) return (43.6047, 1.4442);
    return (43.2965, 5.3698); // Défaut Méditerranée
  }

  Widget _buildWeekendRitualCard(BuildContext context) {
    final now = DateTime.now();
    // Afficher le jeudi (4), vendredi (5), samedi (6), dimanche (7)
    final isWeekendPrep = now.weekday >= DateTime.thursday;
    if (!isWeekendPrep) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8604C).withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Text("🌴", style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Rituel du Weekend 🎾",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Qui est chaud pour jouer ce weekend ? Remplis le terrain !",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFE8604C),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMatchScreen()));
            },
            child: const Text(
              "Créer",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(UserModel? user) {
    final coords = _getUserCoordinates(user?.location);
    return BeachWeatherWidget(
      latitude: coords.$1,
      longitude: coords.$2,
    );
  }

  Widget _buildWorldNewsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(AppLocalizations.of(context)!.homeNewsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(width: 6),
                const Text("🌍", style: TextStyle(fontSize: 18)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.gold, size: 12),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context)!.homeDirectNews, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: StreamBuilder<List<NewsItemModel>>(
            initialData: NewsService.getCuratedNews(),
            stream: NewsService().getNewsStream(),
            builder: (context, snapshot) {
              final newsList = (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty)
                  ? snapshot.data!
                  : NewsService.getCuratedNews();
                  
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: newsList.length,
                itemBuilder: (context, index) {
                  return _buildNewsCard(context, newsList[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCard(BuildContext context, NewsItemModel item) {
    Color badgeColor = AppColors.gold;
    String badgeText = AppLocalizations.of(context)!.homeNewsBadgeDefault;
    IconData badgeIcon = Icons.newspaper;

    if (item.type == NewsType.live) {
      badgeColor = Colors.redAccent;
      badgeText = AppLocalizations.of(context)!.homeNewsBadgeLive;
      badgeIcon = Icons.live_tv;
    } else if (item.type == NewsType.tutorial) {
      badgeColor = Colors.greenAccent;
      badgeText = AppLocalizations.of(context)!.homeNewsBadgeTuto;
      badgeIcon = Icons.play_circle_fill;
    }

    final bool isAsset = item.imageUrl.startsWith('assets/');

    return GestureDetector(
      onTap: () => _showNewsDetailModal(context, item),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Image (Asset or Network)
              Positioned.fill(
                child: isAsset
                    ? Image.asset(
                        item.imageUrl,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, _, __) => Container(color: Colors.black54),
                      ),
              ),
              // Dark Gradient Overlay for Maximum Readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),
              // Play Icon Overlay for Videos/Lives
              if (item.videoUrl != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: badgeColor.withOpacity(0.5), blurRadius: 15)
                      ],
                    ),
                    child: Icon(
                      item.type == NewsType.live ? Icons.play_arrow_rounded : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              // Content Info
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 11, color: item.type == NewsType.tutorial ? Colors.black : Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: TextStyle(
                              color: item.type == NewsType.tutorial ? Colors.black : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewsDetailModal(BuildContext context, NewsItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF141923).withOpacity(0.95), // Deep dark solid background for maximum contrast
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.type == NewsType.live 
                            ? Colors.redAccent 
                            : (item.type == NewsType.tutorial ? Colors.greenAccent : AppColors.gold),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          color: item.type == NewsType.tutorial ? Colors.black : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.3),
                ),
                const SizedBox(height: 16),
                Text(
                  item.description,
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 28),
                if (item.videoUrl != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: item.type == NewsType.live ? Colors.redAccent : AppColors.gold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 6,
                      ),
                      icon: const Icon(Icons.play_circle_fill, size: 24),
                      label: Text(
                        item.type == NewsType.live ? AppLocalizations.of(context)!.homeNewsBtnLive : AppLocalizations.of(context)!.homeNewsBtnTuto,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final uri = Uri.parse(item.videoUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, user, MatchModel match, courts) {
    final int courtIdx = courts.indexWhere((c) => c.id == match.courtId);
    final court = courtIdx != -1 ? courts[courtIdx] : null;
    final courtName = court?.name ?? "Terrain Beach Tennis";
    final timeFormatted = DateFormat('dd MMM à HH:mm').format(match.scheduledTime);
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showMatchDetailsBottomSheet(context, user, match, court),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: _buildGlassContainer(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_tennis, color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text(AppLocalizations.of(context)!.homeMatchOnSand, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(AppLocalizations.of(context)!.homeMatchPlayersInfo(match.participantsIds.length, match.maxPlayers), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(courtName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.access_time_filled, color: Colors.white70, size: 12),
                const SizedBox(width: 6),
                Text(timeFormatted, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.homeMatchRequiredLevel(match.targetLevel), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                _buildMatchButton(context, user, match),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppLocalizations.of(context)!.homeMatchTapDetails, style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.touch_app, color: AppColors.gold, size: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMatchButton(BuildContext context, user, MatchModel match) {
    if (user == null) return const SizedBox();
    
    bool isParticipating = match.participantsIds.contains(user.id);
    bool isHost = match.hostId == user.id;
    bool isFull = match.participantsIds.length >= match.maxPlayers;
    
    if (isParticipating) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHost && match.participantsIds.length > 1)
            IconButton(
              icon: const Icon(Icons.manage_accounts, color: Colors.white),
              onPressed: () => _showManagePlayersDialog(context, match),
              tooltip: AppLocalizations.of(context)!.homeMatchManageTooltip,
            ),
          if (!isFull)
            IconButton(
              onPressed: () {
                final dateStr = DateFormat('dd MMM à HH:mm').format(match.scheduledTime);
                final link = 'https://beachmatch.app/match/${match.id}';
                final msg = AppLocalizations.of(context)!.homeMatchShareMessage(dateStr, match.targetLevel, match.id);
                Share.share('$msg\n\nRejoindre le match directement dans l\'app : $link');
              },
              icon: const Icon(Icons.share, color: Colors.white, size: 22),
              tooltip: AppLocalizations.of(context)!.homeMatchShareTooltip,
            ),
          if (!isFull) const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (isHost) {
                _showCancelMatchDialog(context, match.id);
              } else {
                context.read<AppState>().leaveMatch(match.id);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isHost ? Colors.redAccent.withOpacity(0.8) : Colors.white24,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(isHost ? AppLocalizations.of(context)!.homeMatchCancel : AppLocalizations.of(context)!.homeMatchQuit, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }
    
    if (isFull) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.withOpacity(0.5),
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(AppLocalizations.of(context)!.homeMatchFull, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      );
    }
    
    bool isJoining = context.watch<AppState>().isJoiningMatch;
    
    return ElevatedButton(
      onPressed: isJoining ? null : () {
        context.read<AppState>().joinMatch(match.id);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      child: isJoining 
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(AppLocalizations.of(context)!.homeMatchJoin, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  void _showCancelMatchDialog(BuildContext context, String matchId) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.homeDialogCancelTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.homeDialogCancelContent,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(AppLocalizations.of(context)!.homeDialogNoKeep, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await context.read<AppState>().cancelMatch(matchId);
                          },
                          child: Text(AppLocalizations.of(context)!.homeDialogYesCancel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showManagePlayersDialog(BuildContext context, MatchModel match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2B), // Solid dark background for readability
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final players = context.watch<AppState>().players;
        // Filter players in this match (excluding host)
        final matchPlayers = players.where((p) => match.participantsIds.contains(p.id) && p.id != match.hostId).toList();
        
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.homeManagePlayersTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 16),
              if (matchPlayers.isEmpty)
                Text(AppLocalizations.of(context)!.homeManagePlayersEmpty, style: const TextStyle(color: Colors.white70)),
              ...matchPlayers.map((p) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                  backgroundColor: AppColors.coral,
                  child: p.photoUrl == null ? Text(p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white)) : null,
                ),
                title: Text(p.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(AppLocalizations.of(context)!.homeHeaderLevel(p.level), style: const TextStyle(color: AppColors.gold)),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                  onPressed: () {
                    context.read<AppState>().kickPlayer(match.id, p.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.homeManagePlayersRemoved(p.displayName))));
                  },
                ),
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showMatchDetailsBottomSheet(BuildContext context, user, MatchModel match, court) {
    final timeFormatted = DateFormat('EEEE dd MMM à HH:mm', 'fr_FR').format(match.scheduledTime);
    final courtName = court?.name ?? "Terrain Beach Tennis";
    final isParticipating = match.participantsIds.contains(user?.id);
    final isHost = match.hostId == user?.id;
    final isFull = match.participantsIds.length >= match.maxPlayers;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            image: DecorationImage(
              image: AssetImage('assets/images/beach_sunset_players_1785052273648.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(20)),
                        child: Text(AppLocalizations.of(context)!.homeMatchOnSand, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      SizedBox(height: 16),
                      Text(courtName, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_month, color: AppColors.gold, size: 20),
                          SizedBox(width: 8),
                          Text(timeFormatted, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.star, color: AppColors.gold, size: 20),
                          SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.homeMatchDetailsRequiredLevel(match.targetLevel), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // NEW: Weather Badge
                      if (court != null)
                        BeachWeatherWidget(
                          latitude: court.latitude,
                          longitude: court.longitude,
                        ),
                      const SizedBox(height: 24),
                      // Badges Premium Beach Tennis
                      Row(
                        children: [
                          _buildDetailBadge(Icons.pool, "Sable chaud"),
                          const SizedBox(width: 8),
                          _buildDetailBadge(Icons.sports_baseball, "Balles fournies"),
                          const SizedBox(width: 8),
                          _buildDetailBadge(Icons.verified, "Terrain officiel"),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(AppLocalizations.of(context)!.homeMatchDetailsPlayersRegistered(match.participantsIds.length, match.maxPlayers), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final allPlayers = context.watch<AppState>().players;
                          final currentUser = context.watch<AppState>().currentUser;
                          final List<UserModel> participants = [];
                          if (currentUser != null && match.participantsIds.contains(currentUser.id)) {
                            participants.add(currentUser);
                          }
                          for (var id in match.participantsIds) {
                            if (currentUser != null && id == currentUser.id) continue;
                            final pIdx = allPlayers.indexWhere((p) => p.id == id);
                            if (pIdx != -1) {
                              participants.add(allPlayers[pIdx]);
                            } else {
                              participants.add(UserModel(
                                id: id,
                                displayName: "Joueur Inconnu",
                                level: match.targetLevel,
                                eloScore: 0,
                                location: "Inconnue",
                                isPremium: false,
                                createdAt: DateTime.now(),
                              ));
                            }
                          }
                          return Column(
                            children: participants.map<Widget>((p) {
                              final isHost = p.id == match.hostId;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isHost ? AppColors.gold : Colors.white24, width: 1.2),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.coral,
                                      backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                                      child: p.photoUrl == null ? Text(p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(p.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                              if (isHost) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                                                  child: Text(AppLocalizations.of(context)!.homeMatchDetailsHost, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                                                ),
                                              ]
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(AppLocalizations.of(context)!.homeMatchDetailsPlayerStats(p.level, p.eloScore), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isParticipating)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.9),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                if (isHost) {
                                  _showCancelMatchDialog(context, match.id);
                                } else {
                                  context.read<AppState>().leaveMatch(match.id);
                                }
                              },
                              child: Text(isHost ? AppLocalizations.of(context)!.homeMatchDetailsCancelGame : AppLocalizations.of(context)!.homeMatchDetailsQuitGame, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                        else if (!isFull)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.read<AppState>().joinMatch(match.id);
                              },
                              child: Text(AppLocalizations.of(context)!.homeMatchDetailsJoinGame, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                        else
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Text(AppLocalizations.of(context)!.homeMatchDetailsFull, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 🔵 Point Radar Vivant : pulse et respire chaque seconde (agrandissement/rétractation subtile)
class PulsingRadarDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingRadarDot({
    super.key,
    this.color = const Color(0xFF00D2FF),
    this.size = 10.0,
  });

  @override
  State<PulsingRadarDot> createState() => _PulsingRadarDotState();
}

class _PulsingRadarDotState extends State<PulsingRadarDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Respiration continue chaque seconde
    )..repeat(reverse: true);

    // Variation subtile de 1 à 2 millimètres (0.85x à 1.30x)
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.30).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Effet de halo lumineux synchronisé
    _glowAnimation = Tween<double>(begin: 3.0, end: 10.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final currentSize = widget.size * _scaleAnimation.value;
        return Container(
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.85),
                blurRadius: _glowAnimation.value,
                spreadRadius: (_scaleAnimation.value - 0.85) * 3,
              ),
            ],
          ),
        );
      },
    );
  }
}
