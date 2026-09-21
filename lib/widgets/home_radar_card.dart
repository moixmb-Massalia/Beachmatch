import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import '../models/court.dart';
import '../models/club.dart';
import '../screens/create_match_screen.dart';
import '../screens/clubs/club_detail_screen.dart';
import '../screens/map_screen.dart';
import 'pulsing_radar_dot.dart';

/// Calcule des coordonnées approximatives à partir d'un nom de ville/localisation
(double, double) getUserCoordinates(String? location) {
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

/// Carte Radar de l'écran d'accueil BeachMatch
class HomeRadarCard extends StatelessWidget {
  final UserModel? user;
  final List<CourtModel> courts;

  const HomeRadarCard({
    super.key,
    required this.user,
    required this.courts,
  });

  @override
  Widget build(BuildContext context) {
    if (courts.isEmpty) return const SizedBox.shrink();

    // Écoute sélective du GPS pour éviter les rebuilds inutiles
    final pos = context.select<AppState, Position?>((s) => s.currentPosition);
    final bool hasGps = pos != null;
    final userCoords = hasGps ? (pos.latitude, pos.longitude) : getUserCoordinates(user?.location);

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
    final userLocation = user?.location;
    if (hasGps) {
      locationLabel = nearestCourt.city.isNotEmpty ? "Autour de moi (${nearestCourt.city})" : "Autour de moi (GPS)";
    } else if (userLocation != null && userLocation.isNotEmpty && !isClubOrGeneric) {
      locationLabel = userLocation.split(',').first.trim();
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
                  const Color(0xFF0F1B29).withValues(alpha: 0.92),
                  const Color(0xFF16253B).withValues(alpha: 0.88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
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
                    const Row(
                      children: [
                        PulsingRadarDot(
                          color: Color(0xFF00D2FF), // Bleu vibrant vivant
                          size: 10,
                        ),
                        SizedBox(width: 8),
                        Text(
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
                          color: showGpsAction ? AppColors.coral.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
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
                          color: Colors.white.withValues(alpha: 0.08),
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

  static Widget _buildRadarMetricChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  static Future<void> _handleCourtOrClubTap(BuildContext context, CourtModel court) async {
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

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MapScreen(initialCourt: court)),
      );
    }
  }

  static void _showRadarScannerModal(BuildContext context, List<Map<String, dynamic>> courtsWithDist) {
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
              color: const Color(0xFF0F1B29).withValues(alpha: 0.96),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
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
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.coral.withValues(alpha: 0.2),
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
                                      color: AppColors.gold.withValues(alpha: 0.2),
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
}
