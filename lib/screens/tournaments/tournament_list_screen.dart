import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/colors.dart';
import '../../models/tournament.dart';
import 'tournament_detail_screen.dart';
import 'tournament_radar_screen.dart';
import 'beach_score_hub_screen.dart';
import '../../services/sound_service.dart';
import '../../l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/feature_discovery_bubble.dart';

class TournamentListScreen extends StatefulWidget {
  final bool showHeader;
  const TournamentListScreen({super.key, this.showHeader = true});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  String _selectedCountryFilter = 'ALL';
  String _selectedCategoryFilter = 'ALL';
  String _selectedDistanceFilter = 'ALL';
  String _selectedFormatFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  Position? _currentPosition;
  bool _isLocating = false;

  String _removeAccents(String str) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }
  
  final List<Map<String, String>> _distanceFilters = [
    {'id': 'ALL', 'label': 'Toutes distances 📍'},
    {'id': '20', 'label': '< 20 km'},
    {'id': '50', 'label': '< 50 km'},
    {'id': '100', 'label': '< 100 km'},
    {'id': '200', 'label': '< 200 km'},
  ];

  final List<Map<String, String>> _countryFilters = [
    {'id': 'ALL', 'label': 'Tous pays 🌍'},
    {'id': 'FR', 'label': 'Métropole 🇫🇷'},
    {'id': 'RE', 'label': 'La Réunion 🇷🇪'},
    {'id': 'ANT', 'label': 'Antilles 🌴'},
    {'id': 'IT', 'label': 'Italie 🇮🇹'},
    {'id': 'ES', 'label': 'Espagne 🇪🇸'},
    {'id': 'BR', 'label': 'Brésil 🇧🇷'},
  ];

  final List<Map<String, String>> _formatFilters = [
    {'id': 'ALL', 'label': 'Tous formats 🎾'},
    {'id': 'DH', 'label': 'Double Hommes (DH)'},
    {'id': 'DD', 'label': 'Double Dames (DD)'},
    {'id': 'DX', 'label': 'Double Mixte (DX)'},
    {'id': 'Jeunes', 'label': 'Jeunes (U14-U18)'},
  ];

  final List<Map<String, String>> _categoryFilters = [
    {'id': 'ALL', 'label': 'Toutes catégories 🏆'},
    {'id': 'Sand Series 🌟', 'label': 'Sand Series 🌟'},
    {'id': 'BT 2000 / 400', 'label': 'BT 2000 / 400'},
    {'id': 'BT 1000', 'label': 'BT 1000'},
    {'id': 'BT 500', 'label': 'BT 500'},
    {'id': 'BT 250', 'label': 'BT 250'},
    {'id': 'BT 100 / 25', 'label': 'BT 100 / 25'},
    {'id': 'Terminés', 'label': 'Terminés 🏁'},
  ];

  @override
  void initState() {
    super.initState();
    _initUserLocation();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _searchQuery = _removeAccents(_searchController.text.trim()).toLowerCase();
          });
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.tournaments.isEmpty) {
        appState.loadTournaments();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

  Future<void> _handleDistanceFilter(String filterId) async {
    setState(() => _selectedDistanceFilter = filterId);
    if (filterId != 'ALL') {
      final pos = _currentPosition ?? context.read<AppState>().currentPosition;
      if (pos == null) {
        setState(() => _isLocating = true);
        try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) throw Exception("Location services disabled.");
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) throw Exception("Location denied.");
          }
          if (permission == LocationPermission.deniedForever) throw Exception("Location denied forever.");
          final currentPos = await Geolocator.getCurrentPosition();
          if (mounted) setState(() => _currentPosition = currentPos);
        } catch (_) {
          if (mounted) {
            setState(() => _selectedDistanceFilter = 'ALL');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Activez la géolocalisation pour filtrer par distance.")),
            );
          }
        } finally {
          if (mounted) {
            if (_currentPosition == null) {
              setState(() => _selectedDistanceFilter = 'ALL');
            }
            setState(() => _isLocating = false);
          }
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

      // Filter by Distance
      if (_selectedDistanceFilter != 'ALL') {
        final userPos = _currentPosition ?? context.read<AppState>().currentPosition;
        if (userPos == null || t.latitude == null || t.longitude == null) return false;
        final maxKm = double.tryParse(_selectedDistanceFilter) ?? 100.0;
        final distance = Geolocator.distanceBetween(
          userPos.latitude, 
          userPos.longitude, 
          t.latitude!, 
          t.longitude!
        );
        if (distance > maxKm * 1000) return false;
      }

      // Filter by Country / Region
      if (_selectedCountryFilter == 'FR') {
        final loc = t.location.toLowerCase();
        final c = (t.country ?? '').toLowerCase();
        final isOther = loc.contains('réunion') || loc.contains('reunion') || loc.contains('brésil') || loc.contains('brasil') || loc.contains('italie') || loc.contains('italy') || loc.contains('espagne') || loc.contains('spain') || loc.contains('martinique') || loc.contains('guadeloupe') || loc.contains('saint-barth') || loc.contains('saint-martin') || c.contains('réunion') || c.contains('brésil') || c.contains('italie') || c.contains('espagne') || c.contains('martinique') || c.contains('guadeloupe') || c.contains('saint-barth') || c.contains('saint-martin');
        if (isOther) return false;
      } else if (_selectedCountryFilter == 'RE') {
        final loc = t.location.toLowerCase();
        final c = (t.country ?? '').toLowerCase();
        final name = t.name.toLowerCase();
        if (!loc.contains('réunion') && !loc.contains('reunion') && !c.contains('réunion') && !name.contains('brisants') && !name.contains('bourbon') && !name.contains('tcbsp') && !name.contains('beach park')) return false;
      } else if (_selectedCountryFilter == 'ANT') {
        final loc = t.location.toLowerCase();
        final c = (t.country ?? '').toLowerCase();
        final name = t.name.toLowerCase();
        final isAnt = loc.contains('martinique') || loc.contains('guadeloupe') || loc.contains('saint-barth') || loc.contains('saint-martin') || c.contains('martinique') || c.contains('guadeloupe') || c.contains('saint-barth') || c.contains('saint-martin') || name.contains('madiana') || name.contains('fcbt') || name.contains('karibbean') || name.contains('an nou');
        if (!isAnt) return false;
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

      // Filter by Format (DH, DD, DX, Jeunes)
      if (_selectedFormatFilter != 'ALL') {
        if (!t.formats.contains(_selectedFormatFilter)) {
          final nameUpper = t.name.toUpperCase();
          final catUpper = t.category.toUpperCase();
          if (_selectedFormatFilter == 'DX' && (nameUpper.contains('MIXTE') || nameUpper.contains(' DX') || catUpper.contains('MIXTE'))) {
            // match
          } else if (_selectedFormatFilter == 'DH' && (nameUpper.contains('HOMMES') || nameUpper.contains(' DH') || nameUpper.contains('DM') || catUpper.contains('HOMMES'))) {
            // match
          } else if (_selectedFormatFilter == 'DD' && (nameUpper.contains('DAMES') || nameUpper.contains(' DD') || nameUpper.contains('DF') || catUpper.contains('DAMES'))) {
            // match
          } else if (_selectedFormatFilter == 'Jeunes' && (nameUpper.contains('JEUNES') || catUpper.contains('JEUNES') || nameUpper.contains('U14') || nameUpper.contains('U18'))) {
            // match
          } else {
            return false;
          }
        }
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
          final has100 = RegExp(r'\b100(?!\d)\b').hasMatch(t.category);
          final has50 = RegExp(r'\b50(?!\d)\b').hasMatch(t.category);
          final has25 = RegExp(r'\b25(?!\d)\b').hasMatch(t.category);
          if (!has100 && !has50 && !has25) return false;
        } else {
          final regex = RegExp(_selectedCategoryFilter + r'(?!\d)');
          if (!regex.hasMatch(t.category)) return false;
        }
      }

      // Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final tokens = _searchQuery.split(RegExp(r'\s+')).where((tok) => tok.isNotEmpty).toList();
        final nameNorm = _removeAccents(t.name).toLowerCase();
        final locNorm = _removeAccents(t.location).toLowerCase();
        final clubNorm = _removeAccents(t.club).toLowerCase();
        final catNorm = _removeAccents(t.category).toLowerCase();
        final countryNorm = _removeAccents(t.country ?? '').toLowerCase();

        final matches = tokens.every((tok) =>
            nameNorm.contains(tok) ||
            locNorm.contains(tok) ||
            clubNorm.contains(tok) ||
            catNorm.contains(tok) ||
            countryNorm.contains(tok));
        if (!matches) return false;
      }

      return true;
    }).toList();
    
    // Sort logic : If nearby / distance filter selected, sort by closest distance, otherwise by date
    final userPos = _currentPosition ?? context.read<AppState>().currentPosition;
    if (_selectedDistanceFilter != 'ALL' && userPos != null) {
      filteredTournaments.sort((a, b) {
        if (a.latitude == null || a.longitude == null) return 1;
        if (b.latitude == null || b.longitude == null) return -1;
        final distA = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, a.latitude!, a.longitude!);
        final distB = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, b.latitude!, b.longitude!);
        return distA.compareTo(distB);
      });
    } else {
      filteredTournaments.sort((a, b) {
        final dateA = a.startDate ?? DateTime(2099);
        final dateB = b.startDate ?? DateTime(2099);
        
        if (_selectedCategoryFilter == 'Terminés') {
          final cmp = dateB.compareTo(dateA);
          if (cmp != 0) return cmp;
          return a.name.compareTo(b.name);
        }
        final cmp = dateA.compareTo(dateB);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_court_aerial_1785052250131.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                if (widget.showHeader)
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
                              Text(AppLocalizations.of(context).tournamentListTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                              Text(
                                AppLocalizations.of(context).tournamentListCount(filteredTournaments.length), 
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.radar, color: AppColors.coral, size: 28),
                          tooltip: "Radar 360°",
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const TournamentRadarScreen()));
                          },
                        ),
                      ],
                    ),
                  ),

                const FeatureDiscoveryBubble(
                  featureKey: 'tournaments_guide',
                  title: "Guide des Compétitions FFT",
                  message: "Filtrez par catégorie (BT 25 à BT 2000), trouvez un partenaire via 'SOS Partenaire' ou suivez les scores en direct sur BeachScore Live !",
                  icon: Icons.emoji_events_rounded,
                  margin: EdgeInsets.fromLTRB(20, 4, 20, 10),
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
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.4),
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
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Rechercher une ville, club, catégorie...",
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
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

                // 🎛️ BARRE DE MENUS DÉROULANTS (Distance, Pays, Format DH/DD/DX, Catégorie)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Column(
                    children: [
                      // Rangée 1 : Distance + Pays
                      Row(
                        children: [
                          _buildDropdownCard<String>(
                            value: _selectedDistanceFilter,
                            icon: Icons.near_me_rounded,
                            isActive: _selectedDistanceFilter != 'ALL',
                            items: _distanceFilters.map((f) {
                              return DropdownMenuItem<String>(
                                value: f['id']!,
                                child: Text(
                                  f['label']!,
                                  style: TextStyle(
                                    color: _selectedDistanceFilter == f['id'] ? AppColors.gold : Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: _selectedDistanceFilter == f['id'] ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _handleDistanceFilter(val);
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildDropdownCard<String>(
                            value: _selectedCountryFilter,
                            icon: Icons.public_rounded,
                            isActive: _selectedCountryFilter != 'ALL',
                            items: _countryFilters.map((f) {
                              return DropdownMenuItem<String>(
                                value: f['id']!,
                                child: Text(
                                  f['label']!,
                                  style: TextStyle(
                                    color: _selectedCountryFilter == f['id'] ? AppColors.gold : Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: _selectedCountryFilter == f['id'] ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCountryFilter = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Rangée 2 : Format (DH/DD/DX/Jeunes) + Catégorie
                      Row(
                        children: [
                          _buildDropdownCard<String>(
                            value: _selectedFormatFilter,
                            icon: Icons.sports_tennis_rounded,
                            isActive: _selectedFormatFilter != 'ALL',
                            items: _formatFilters.map((f) {
                              return DropdownMenuItem<String>(
                                value: f['id']!,
                                child: Text(
                                  f['label']!,
                                  style: TextStyle(
                                    color: _selectedFormatFilter == f['id'] ? AppColors.gold : Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: _selectedFormatFilter == f['id'] ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedFormatFilter = val);
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildDropdownCard<String>(
                            value: _selectedCategoryFilter,
                            icon: Icons.emoji_events_rounded,
                            isActive: _selectedCategoryFilter != 'ALL',
                            items: _categoryFilters.map((f) {
                              return DropdownMenuItem<String>(
                                value: f['id']!,
                                child: Text(
                                  f['label']!,
                                  style: TextStyle(
                                    color: _selectedCategoryFilter == f['id'] ? AppColors.gold : Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: _selectedCategoryFilter == f['id'] ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategoryFilter = val);
                            },
                          ),
                        ],
                      ),
                      // Bouton Réinitialiser si un filtre est actif
                      if (_selectedDistanceFilter != 'ALL' ||
                          _selectedCountryFilter != 'ALL' ||
                          _selectedFormatFilter != 'ALL' ||
                          _selectedCategoryFilter != 'ALL') ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedDistanceFilter = 'ALL';
                                  _selectedCountryFilter = 'ALL';
                                  _selectedFormatFilter = 'ALL';
                                  _selectedCategoryFilter = 'ALL';
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.coral.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.restart_alt_rounded, color: AppColors.coral, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      "Réinitialiser les filtres",
                                      style: TextStyle(
                                        color: AppColors.coral,
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
                      ],
                    ],
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
                      await context.read<AppState>().loadTournaments();
                      if (mounted) setState(() {});
                    },
                    child: filteredTournaments.isEmpty 
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            if (context.watch<AppState>().isLoadingTournaments)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(color: AppColors.gold),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Chargement des tournois officiels...",
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.emoji_events_outlined, size: 48, color: Colors.white.withValues(alpha: 0.4)),
                                      const SizedBox(height: 12),
                                      Text(
                                        AppLocalizations.of(context).tournamentListEmpty,
                                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _selectedCountryFilter = 'ALL';
                                            _selectedCategoryFilter = 'Toutes 🏆';
                                            _searchController.clear();
                                          });
                                          context.read<AppState>().loadTournaments();
                                        },
                                        icon: const Icon(Icons.refresh, size: 18, color: Colors.black),
                                        label: const Text("Réinitialiser / Actualiser", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.gold,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 100),
                          itemCount: filteredTournaments.length,
                          itemBuilder: (context, index) {
                            final tournament = filteredTournaments[index];
                            final showHeader = _shouldShowMonthHeader(index, filteredTournaments);
                            if (showHeader && tournament.startDate != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMonthHeader(_getMonthHeaderLabel(tournament.startDate!)),
                                  _buildTournamentCard(context, tournament),
                                ],
                              );
                            }
                            return _buildTournamentCard(context, tournament);
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

  bool _shouldShowMonthHeader(int index, List<TournamentModel> list) {
    if (_selectedCountryFilter == 'NEARBY') return false;
    final current = list[index].startDate;
    if (current == null) return false;
    if (index == 0) return true;
    final previous = list[index - 1].startDate;
    if (previous == null) return true;
    return current.month != previous.month || current.year != previous.year;
  }

  String _getMonthHeaderLabel(DateTime dt) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  Widget _buildMonthHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppColors.gold, size: 14),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.15),
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
    final nameLower = tournament.name.toLowerCase();
    if (locLower.contains('italie') || locLower.contains('italy') || countryLower.contains('italie') || locLower.contains('cervia') || locLower.contains('terracina')) {
      flag = '🇮🇹';
    } else if (locLower.contains('espagne') || locLower.contains('spain') || countryLower.contains('espagne') || locLower.contains('canaria') || locLower.contains('barcelona')) {
      flag = '🇪🇸';
    } else if (locLower.contains('brésil') || locLower.contains('brasil') || countryLower.contains('brésil') || countryLower.contains('brazil') || locLower.contains('copacabana') || locLower.contains('brasilia')) {
      flag = '🇧🇷';
    } else if (locLower.contains('saint-martin') || locLower.contains('st martin') || locLower.contains('orientale') || locLower.contains('guadeloupe') || locLower.contains('martinique')) {
      flag = '🌴';
    } else if (locLower.contains('nouméa') || locLower.contains('noumea')) {
      flag = '🇳🇨';
    } else if (locLower.contains('reunion') || locLower.contains('réunion') || locLower.contains('clotilde') || locLower.contains('paul') || nameLower.contains('brisants')) {
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
              color: tournament.isPassed ? Colors.grey.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: tournament.isPassed ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.2), 
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
                  color: AppColors.coral.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
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
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(flag, style: const TextStyle(fontSize: 10)),
                          ),
                        ],
                        if (tournament.formats.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          ...tournament.formats.map((fmt) {
                            return Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: fmt == 'DX'
                                    ? Colors.teal.withValues(alpha: 0.25)
                                    : (fmt == 'DD'
                                        ? Colors.pinkAccent.withValues(alpha: 0.25)
                                        : Colors.blueAccent.withValues(alpha: 0.25)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: fmt == 'DX'
                                      ? Colors.tealAccent.withValues(alpha: 0.6)
                                      : (fmt == 'DD'
                                          ? Colors.pinkAccent.withValues(alpha: 0.6)
                                          : Colors.lightBlueAccent.withValues(alpha: 0.6)),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                fmt,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }),
                        ],
                        const Spacer(),
                        if (distanceText != null && !tournament.isPassed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1),
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
                    if (tournament.contactPhone != null && tournament.contactPhone!.isNotEmpty && !tournament.isPassed)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.how_to_reg_rounded, color: AppColors.gold, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              "Inscriptions & Contact JAT dispos",
                              style: TextStyle(color: AppColors.gold.withValues(alpha: 0.9), fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
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

  Widget _buildDropdownCard<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
    required bool isActive,
  }) {
    return Expanded(
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.gold : Colors.white.withValues(alpha: 0.22),
            width: isActive ? 1.4 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 6,
                  )
                ]
              : null,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            dropdownColor: const Color(0xFF0F172A),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isActive ? AppColors.gold : Colors.white70,
              size: 18,
            ),
            style: TextStyle(
              color: isActive ? AppColors.gold : Colors.white,
              fontSize: 11.5,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
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
