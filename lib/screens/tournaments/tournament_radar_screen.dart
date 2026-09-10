import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';
import '../../models/tournament.dart';
import '../../theme/colors.dart';
import '../../services/sound_service.dart';
import 'tournament_detail_screen.dart';

class TournamentRadarScreen extends StatefulWidget {
  const TournamentRadarScreen({super.key});

  @override
  State<TournamentRadarScreen> createState() => _TournamentRadarScreenState();
}

class _TournamentRadarScreenState extends State<TournamentRadarScreen> with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _pulseController;
  late AnimationController _lockController;

  // Portée sélectionnée en kilomètres (10, 200, 500, France, Monde)
  double _selectedRangeKm = 200.0;
  String _selectedCategoryFilter = 'ALL'; // 'ALL', 'MAJOR', 'CLUB'
  bool _soundEnabled = true;

  // Recherche rapide HUD
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Centre de référence personnalisé (ou GPS)
  String? _customCenterName;
  double? _customCenterLat;
  double? _customCenterLng;

  static const List<Map<String, dynamic>> _presetCenters = [
    {'name': 'Position GPS Actuelle 📡', 'lat': null, 'lng': null},
    {'name': 'Marseille (13) 🏖️', 'lat': 43.2965, 'lng': 5.3698},
    {'name': 'Toulon / Var (83) 🌴', 'lat': 43.1242, 'lng': 5.9280},
    {'name': 'Nice / Côte d\'Azur (06) ☀️', 'lat': 43.7102, 'lng': 7.2620},
    {'name': 'Montpellier / Hérault (34) 🌊', 'lat': 43.6108, 'lng': 3.8767},
    {'name': 'Paris / Île-de-France (75) 🗼', 'lat': 48.8566, 'lng': 2.3522},
    {'name': 'Bordeaux / Aquitaine (33) 🍷', 'lat': 44.8378, 'lng': -0.5792},
    {'name': 'Saint-Pierre / La Réunion (974) 🌋', 'lat': -20.8821, 'lng': 55.4507},
  ];

  TournamentModel? _selectedTournament;
  Map<String, Offset> _blipPositions = {};

  @override
  void initState() {
    super.initState();

    // Animation du faisceau tournant (360° en 3.5 secondes)
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    // Animation de l'onde sonar pulsante (du centre vers les bords)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Animation de verrouillage de cible (Target Lock HUD)
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    _lockController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Calcul du gisement (bearing en radians) entre l'utilisateur et un tournoi
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final deltaLambda = (lon2 - lon1) * math.pi / 180.0;

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final bearing = math.atan2(y, x);
    return (bearing + 2 * math.pi) % (2 * math.pi);
  }

  String _getCardinalDirection(double bearingDegrees) {
    if (bearingDegrees >= 337.5 || bearingDegrees < 22.5) return "N";
    if (bearingDegrees >= 22.5 && bearingDegrees < 67.5) return "NE";
    if (bearingDegrees >= 67.5 && bearingDegrees < 112.5) return "E";
    if (bearingDegrees >= 112.5 && bearingDegrees < 157.5) return "SE";
    if (bearingDegrees >= 157.5 && bearingDegrees < 202.5) return "S";
    if (bearingDegrees >= 202.5 && bearingDegrees < 247.5) return "SO";
    if (bearingDegrees >= 247.5 && bearingDegrees < 292.5) return "O";
    return "NO";
  }

  Future<void> _openMaps(double lat, double lng, String label) async {
    final googleUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    try {
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allTournaments = appState.tournaments;
    final userPos = appState.currentPosition;

    // Coordonnées de référence du Radar
    // Si centre choisi manuellement -> priorité. Sinon GPS. Sinon Marseille (13) par défaut.
    final double userLat = _customCenterLat ?? userPos?.latitude ?? 43.2965;
    final double userLng = _customCenterLng ?? userPos?.longitude ?? 5.3698;
    final String centerLabel = _customCenterName ?? (userPos != null ? "Position GPS" : "Marseille (13)");

    // Filtrage des tournois
    final validTournaments = allTournaments.where((t) {
      if (t.isPassed) return false;
      if (t.latitude == null || t.longitude == null) return false;

      // Filtre de recherche textuelle
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = t.name.toLowerCase();
        final club = t.club.toLowerCase();
        final loc = t.location.toLowerCase();
        final ref = (t.referee ?? '').toLowerCase();
        final cat = t.category.toLowerCase();
        final matches = name.contains(q) || club.contains(q) || loc.contains(q) || ref.contains(q) || cat.contains(q);
        if (!matches) return false;
      }

      // Filtre de catégorie
      if (_selectedCategoryFilter == 'MAJOR') {
        final cat = t.category.toUpperCase();
        if (!cat.contains('500') && !cat.contains('1000') && !cat.contains('2000') && !cat.contains('ITF') && !cat.contains('400')) {
          return false;
        }
      } else if (_selectedCategoryFilter == 'CLUB') {
        final cat = t.category.toUpperCase();
        if (cat.contains('1000') || cat.contains('2000') || cat.contains('ITF')) {
          return false;
        }
      }

      // Calcul distance
      final distanceInMeters = Geolocator.distanceBetween(userLat, userLng, t.latitude!, t.longitude!);
      final distanceKm = distanceInMeters / 1000.0;

      // Si recherche active, on étend jusqu'à la France entière pour trouver le tournoi
      if (_searchQuery.isNotEmpty) {
        return distanceKm <= math.max(_selectedRangeKm, 1500.0);
      }

      return distanceKm <= _selectedRangeKm;
    }).toList();

    // Tri par distance croissante
    validTournaments.sort((a, b) {
      final distA = Geolocator.distanceBetween(userLat, userLng, a.latitude!, a.longitude!);
      final distB = Geolocator.distanceBetween(userLat, userLng, b.latitude!, b.longitude!);
      return distA.compareTo(distB);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Stack(
        children: [
          // Fond d'écran avec halo sombre cockpit
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF050B14),
                    Color(0xFF02040A),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // En-tête HUD Tactique avec sélecteur de ville
                _buildTacticalHeader(validTournaments.length, centerLabel),

                // Barre de recherche textuelle rapide
                _buildSearchBar(),

                // Sélecteurs de filtres (Portée + Catégorie)
                _buildRangeSelector(),
                _buildCategorySelector(),

                // Écran Radar 360°
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.94;
                        return GestureDetector(
                          onTapDown: (details) => _handleRadarTap(details.localPosition, size, userLat, userLng, validTournaments),
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withOpacity(0.12),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.08),
                                  blurRadius: 50,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_sweepController, _pulseController]),
                              builder: (context, child) {
                                return CustomPaint(
                                  size: Size(size, size),
                                  painter: TacticalRadarPainter(
                                    sweepAngle: _sweepController.value * 2 * math.pi,
                                    pulseProgress: _pulseController.value,
                                    rangeKm: _selectedRangeKm,
                                    userLat: userLat,
                                    userLng: userLng,
                                    tournaments: validTournaments,
                                    selectedTournament: _selectedTournament,
                                    onBlipsCalculated: (positions) {
                                      _blipPositions = positions;
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Carte rétractable du tournoi sélectionné OU Carousel des échos détectés
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _selectedTournament != null
                      ? _buildSelectedTournamentHUDCard(_selectedTournament!, userLat, userLng)
                      : _buildDetectedTournamentsCarousel(validTournaments, userLat, userLng),
                ),
                const SizedBox(height: 72),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalHeader(int count, String centerLabel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.cyanAccent, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 10),
                  ],
                ),
                child: const Icon(Icons.radar_rounded, color: Colors.cyanAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        "RADAR 360°",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        "LIVE",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showCenterPicker(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$count à portée · ",
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: AppColors.gold, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                centerLabel,
                                style: const TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                              const Icon(Icons.arrow_drop_down, color: AppColors.gold, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _soundEnabled = !_soundEnabled);
                  if (_soundEnabled) {
                    SoundService.playRacketPop();
                  }
                  HapticFeedback.selectionClick();
                },
                icon: Icon(
                  _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _soundEnabled ? AppColors.gold : Colors.white38,
                  size: 20,
                ),
                tooltip: _soundEnabled ? "Couper le sonar" : "Activer le sonar",
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _customCenterName = null;
                    _customCenterLat = null;
                    _customCenterLng = null;
                  });
                  context.read<AppState>().refreshLocation();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Radar recentré sur votre position GPS.")),
                  );
                },
                icon: const Icon(Icons.my_location_rounded, color: Colors.cyanAccent, size: 20),
                tooltip: "Recentrer GPS",
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCenterPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Centrer le Radar sur :",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _presetCenters.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.08), height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _presetCenters[i];
                      final isSelected = (_customCenterName == item['name']) ||
                          (_customCenterName == null && item['lat'] == null);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          item['name'] as String,
                          style: TextStyle(
                            color: isSelected ? AppColors.gold : Colors.white,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 18) : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (item['lat'] == null) {
                              _customCenterName = null;
                              _customCenterLat = null;
                              _customCenterLng = null;
                              context.read<AppState>().refreshLocation();
                            } else {
                              _customCenterName = item['name'] as String;
                              _customCenterLat = item['lat'] as double;
                              _customCenterLng = item['lng'] as double;
                            }
                            _selectedTournament = null;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchQuery.isNotEmpty ? AppColors.gold : Colors.white.withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
        decoration: InputDecoration(
          hintText: "Rechercher (Duglos, Tennis Park, BT 500, Marseille...)",
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11.5),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 16),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 7),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
        },
      ),
    );
  }

  Widget _buildRangeSelector() {
    final ranges = [
      {'label': '10 km', 'val': 10.0},
      {'label': '200 km', 'val': 200.0},
      {'label': '500 km', 'val': 500.0},
      {'label': 'France 🇫🇷', 'val': 1200.0},
      {'label': 'Monde 🌍', 'val': 30000.0},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: ranges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = ranges[i];
          final isSelected = _selectedRangeKm == r['val'];
          return ChoiceChip(
            label: Text(
              r['label'] as String,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.gold,
            backgroundColor: Colors.black.withOpacity(0.65),
            side: BorderSide(
              color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.35),
              width: isSelected ? 1.5 : 1,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onSelected: (selected) {
              if (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedRangeKm = r['val'] as double;
                  _selectedTournament = null;
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      {'label': 'Tous 🏆', 'id': 'ALL'},
      {'label': 'Circuits Majeurs 🌟', 'id': 'MAJOR'},
      {'label': 'Conviviaux 🏖️', 'id': 'CLUB'},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = _selectedCategoryFilter == cat['id'];
          return ChoiceChip(
            label: Text(
              cat['label']!,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.coral,
            backgroundColor: Colors.black.withOpacity(0.5),
            side: BorderSide(
              color: isSelected ? AppColors.coral : Colors.white.withOpacity(0.25),
              width: isSelected ? 1.5 : 1,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (selected) {
              if (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCategoryFilter = cat['id']!;
                  _selectedTournament = null;
                });
              }
            },
          );
        },
      ),
    );
  }

  void _handleRadarTap(Offset tapPos, double radarSize, double userLat, double userLng, List<TournamentModel> tournaments) {
    TournamentModel? closest;
    double minDistance = 32.0; // Tolérance de toucher en pixels

    _blipPositions.forEach((id, pos) {
      final dist = (pos - tapPos).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closest = tournaments.firstWhere((t) => t.id == id);
      }
    });

    if (closest != null) {
      HapticFeedback.heavyImpact();
      if (_soundEnabled) {
        SoundService.playRacketPop();
      }
      _lockController.forward(from: 0.0);
      setState(() => _selectedTournament = closest);
    } else {
      if (_selectedTournament != null) {
        setState(() => _selectedTournament = null);
      }
    }
  }

  Widget _buildSelectedTournamentHUDCard(TournamentModel t, double userLat, double userLng) {
    final distanceMeters = (t.latitude != null && t.longitude != null)
        ? Geolocator.distanceBetween(userLat, userLng, t.latitude!, t.longitude!)
        : 0.0;
    final km = (distanceMeters / 1000).round();
    final bearing = (t.latitude != null && t.longitude != null)
        ? _calculateBearing(userLat, userLng, t.latitude!, t.longitude!) * 180 / math.pi
        : 0.0;
    final cardinal = _getCardinalDirection(bearing);

    // Estimation du temps de route (vitesse moyenne 80 km/h)
    final hours = km / 80;
    String routeTime;
    if (hours < 1) {
      routeTime = "~${math.max(15, (hours * 60).round())} min";
    } else {
      final h = hours.floor();
      final m = ((hours - h) * 60).round();
      routeTime = "~${h}h${m > 0 ? '$m' : ''}";
    }

    return Container(
      key: ValueKey(t.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bandeau statut verrouillé
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.adjust_rounded, color: Colors.cyanAccent, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "CIBLE VERROUILLÉE · CAP $cardinal ${bearing.round()}°",
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _selectedTournament = null),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Titre et catégorie
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.category,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Détails : Club, Ville, Distance, Temps
          Row(
            children: [
              const Icon(CupertinoIcons.location_solid, color: AppColors.coral, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  "${t.location} (${t.club})",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                "📍 $km km · 🚗 $routeTime",
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Boutons d'action
          Row(
            children: [
              // Bouton GPS Waze / Maps
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: const Text("GPS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  if (t.latitude != null && t.longitude != null) {
                    _openMaps(t.latitude!, t.longitude!, t.name);
                  }
                },
              ),
              const SizedBox(width: 8),

              // Bouton Voir la fiche tournoi
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text("Voir la fiche tournoi", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TournamentDetailScreen(tournament: t),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final cat = category.toUpperCase();
    if (cat.contains("2000")) return Colors.purpleAccent;
    if (cat.contains("1000") || cat.contains("ITF")) return AppColors.gold;
    if (cat.contains("500")) return Colors.cyanAccent;
    if (cat.contains("250")) return AppColors.coral;
    if (cat.contains("100")) return Colors.greenAccent;
    return AppColors.gold;
  }

  Widget _buildDetectedTournamentsCarousel(List<TournamentModel> tournaments, double centerLat, double centerLng) {
    if (tournaments.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.amberAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "0 tournoi détecté à cette portée · Augmentez le rayon (ex: 200 km, 500 km ou France 🇫🇷)",
                style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "ÉCHOS DÉTECTÉS (${tournaments.length}) · Touchez pour verrouiller",
                    style: TextStyle(
                      color: Colors.cyanAccent.withOpacity(0.9),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                "Classés par distance",
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 98,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: tournaments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final t = tournaments[index];
              final distMeters = (t.latitude != null && t.longitude != null)
                  ? Geolocator.distanceBetween(centerLat, centerLng, t.latitude!, t.longitude!)
                  : 0.0;
              final km = (distMeters / 1000).round();
              final isTarget = (t.referee ?? '').toLowerCase().contains('duglos') ||
                  t.club.toLowerCase().contains('tennis park') ||
                  _searchQuery.isNotEmpty;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  if (_soundEnabled) SoundService.playRacketPop();
                  _lockController.forward(from: 0.0);
                  setState(() => _selectedTournament = t);
                },
                child: Container(
                  width: 255,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isTarget ? const Color(0xFF132238) : const Color(0xFF0F172A).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isTarget ? AppColors.gold : Colors.white.withOpacity(0.2),
                      width: isTarget ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(t.category),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t.category,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "📍 $km km",
                              style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        t.name,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, color: AppColors.coral, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              t.referee ?? t.club,
                              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            t.dateString,
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
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
    );
  }
}

/// Painter du Radar Tactique Militaire 360°
class TacticalRadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseProgress;
  final double rangeKm;
  final double userLat;
  final double userLng;
  final List<TournamentModel> tournaments;
  final TournamentModel? selectedTournament;
  final Function(Map<String, Offset>) onBlipsCalculated;

  TacticalRadarPainter({
    required this.sweepAngle,
    required this.pulseProgress,
    required this.rangeKm,
    required this.userLat,
    required this.userLng,
    required this.tournaments,
    required this.selectedTournament,
    required this.onBlipsCalculated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Fond noir profond du sonar
    final bgPaint = Paint()
      ..color = const Color(0xFF040A17)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Cercles de portée concentriques
    final gridPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const ringFractions = [0.25, 0.50, 0.75, 1.0];
    for (final frac in ringFractions) {
      canvas.drawCircle(center, radius * frac, gridPaint);

      // Label de distance sur le cercle Nord
      final textSpan = TextSpan(
        text: "${(rangeKm * frac).round()} km",
        style: TextStyle(
          color: Colors.cyanAccent.withOpacity(0.4),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(center.dx + 4, center.dy - (radius * frac) - 2));
    }

    // 3. Onde sonar pulsante qui s'étend vers l'extérieur
    final pulseRadius = radius * pulseProgress;
    final pulsePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity((1.0 - pulseProgress) * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // 4. Lignes d'axes cardinaux (N, S, E, W)
    final axisPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axisPaint);

    // Graduations cardinales
    _drawCardinalLabel(canvas, "N", Offset(center.dx, 14));
    _drawCardinalLabel(canvas, "S", Offset(center.dx, size.height - 14));
    _drawCardinalLabel(canvas, "E", Offset(size.width - 14, center.dy));
    _drawCardinalLabel(canvas, "O", Offset(14, center.dy));

    // 5. Faisceau lumineux de balayage (Sweep Beam avec dégradé rotatif)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Rotation du faisceau
    canvas.rotate(sweepAngle);

    final sweepGradient = ui.Gradient.sweep(
      Offset.zero,
      [
        Colors.transparent,
        Colors.cyanAccent.withOpacity(0.0),
        Colors.cyanAccent.withOpacity(0.08),
        Colors.cyanAccent.withOpacity(0.35),
      ],
      [0.0, 0.7, 0.88, 1.0],
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, radius, sweepPaint);

    // Ligne frontale du faisceau
    final linePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.9)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    canvas.drawLine(Offset.zero, Offset(radius, 0), linePaint);

    canvas.restore();

    // 6. Dessin des échos de tournois (Blips)
    final Map<String, Offset> calculatedPositions = {};

    for (final t in tournaments) {
      if (t.latitude == null || t.longitude == null) continue;

      final distMeters = Geolocator.distanceBetween(userLat, userLng, t.latitude!, t.longitude!);
      final distKm = distMeters / 1000.0;
      if (distKm > rangeKm) continue;

      // Distance proportionnelle sur le rayon
      final r = (distKm / rangeKm) * (radius * 0.92);

      // Calcul du cap (angle depuis le Nord)
      final bearingRad = _calcBearing(userLat, userLng, t.latitude!, t.longitude!);

      // Coordonnées sur le canvas (Nord = haut = -pi/2)
      final angleOnCanvas = bearingRad - (math.pi / 2);
      final blipX = center.dx + r * math.cos(angleOnCanvas);
      final blipY = center.dy + r * math.sin(angleOnCanvas);
      final blipOffset = Offset(blipX, blipY);

      calculatedPositions[t.id] = blipOffset;

      // Détection du passage du faisceau radar
      final blipAngleNormalized = (bearingRad) % (2 * math.pi);
      final sweepAngleNormalized = (sweepAngle + (math.pi / 2)) % (2 * math.pi);
      double angleDiff = (sweepAngleNormalized - blipAngleNormalized).abs();
      if (angleDiff > math.pi) angleDiff = 2 * math.pi - angleDiff;
      final isSwept = angleDiff < 0.25;

      // Couleur de l'écho selon la catégorie
      Color blipColor;
      final cat = t.category.toUpperCase();
      if (cat.contains('1000') || cat.contains('2000') || cat.contains('ITF') || cat.contains('400')) {
        blipColor = AppColors.gold;
      } else if (cat.contains('500') || cat.contains('250')) {
        blipColor = Colors.cyanAccent;
      } else {
        blipColor = Colors.greenAccent;
      }

      final isSelected = selectedTournament?.id == t.id;

      // Dessin de l'écho
      final dotPaint = Paint()
        ..color = isSelected ? Colors.white : blipColor
        ..style = PaintingStyle.fill;

      // Halo externe
      final glowPaint = Paint()
        ..color = (isSelected ? Colors.white : blipColor).withOpacity(isSwept ? 0.8 : 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSwept ? 8 : 4);

      canvas.drawCircle(blipOffset, isSelected ? 8 : (isSwept ? 7 : 5), glowPaint);
      canvas.drawCircle(blipOffset, isSelected ? 5 : 3.5, dotPaint);

      // Verrouillage de cible tactique si sélectionné (Target Lock Reticle)
      if (isSelected) {
        _drawTargetLock(canvas, blipOffset);
      }
    }

    // Callback pour stocker les positions de hit-test
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onBlipsCalculated(calculatedPositions);
    });

    // 7. Centre Radar : Position Joueur (Point d'origine)
    final userCenterPaint = Paint()
      ..color = AppColors.coral
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, userCenterPaint);

    final userRingPaint = Paint()
      ..color = AppColors.coral.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 10, userRingPaint);

    // 8. Cercle de bordure tactique avec halo cyan
    final borderPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawCardinalLabel(Canvas canvas, String label, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.cyanAccent.withOpacity(0.7),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawTargetLock(Canvas canvas, Offset pos) {
    final reticlePaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    const size = 16.0;
    const corner = 5.0;

    // Coins du carré de ciblage HUD
    // Haut-Gauche
    canvas.drawLine(Offset(pos.dx - size, pos.dy - size), Offset(pos.dx - size + corner, pos.dy - size), reticlePaint);
    canvas.drawLine(Offset(pos.dx - size, pos.dy - size), Offset(pos.dx - size, pos.dy - size + corner), reticlePaint);

    // Haut-Droite
    canvas.drawLine(Offset(pos.dx + size, pos.dy - size), Offset(pos.dx + size - corner, pos.dy - size), reticlePaint);
    canvas.drawLine(Offset(pos.dx + size, pos.dy - size), Offset(pos.dx + size, pos.dy - size + corner), reticlePaint);

    // Bas-Gauche
    canvas.drawLine(Offset(pos.dx - size, pos.dy + size), Offset(pos.dx - size + corner, pos.dy + size), reticlePaint);
    canvas.drawLine(Offset(pos.dx - size, pos.dy + size), Offset(pos.dx - size, pos.dy + size - corner), reticlePaint);

    // Bas-Droite
    canvas.drawLine(Offset(pos.dx + size, pos.dy + size), Offset(pos.dx + size - corner, pos.dy + size), reticlePaint);
    canvas.drawLine(Offset(pos.dx + size, pos.dy + size), Offset(pos.dx + size, pos.dy + size - corner), reticlePaint);

    // Cercle d'acquisition
    canvas.drawCircle(pos, 10, reticlePaint);
  }

  double _calcBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final deltaLambda = (lon2 - lon1) * math.pi / 180.0;

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final bearing = math.atan2(y, x);
    return (bearing + 2 * math.pi) % (2 * math.pi);
  }

  @override
  bool shouldRepaint(covariant TacticalRadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.selectedTournament != selectedTournament ||
        oldDelegate.rangeKm != rangeKm;
  }
}
