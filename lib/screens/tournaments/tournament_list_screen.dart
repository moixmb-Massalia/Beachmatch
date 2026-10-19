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
import '../../services/sound_service.dart';
import '../../l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';

class TournamentListScreen extends StatefulWidget {
  final bool showHeader;
  const TournamentListScreen({super.key, this.showHeader = true});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  String _selectedCountryFilter = 'FR';
  String _userDetectedCountry = 'FR';
  bool _hasUserManuallyChangedCountry = false;
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

  bool _isTournamentFromCountry(TournamentModel t, String countryCode) {
    if (countryCode == 'ALL') return true;

    final loc = _removeAccents(t.location).toLowerCase();
    final c = _removeAccents(t.country ?? '').toLowerCase();
    final name = _removeAccents(t.name).toLowerCase();

    switch (countryCode) {
      case 'FR':
        final isOther = loc.contains('reunion') || loc.contains('bresil') || loc.contains('brasil') || 
            loc.contains('italie') || loc.contains('italy') || loc.contains('espagne') || loc.contains('spain') || 
            loc.contains('venezuela') || loc.contains('aruba') || loc.contains('martinique') || 
            loc.contains('guadeloupe') || loc.contains('saint-barth') || loc.contains('saint-martin') || 
            c.contains('reunion') || c.contains('bresil') || c.contains('brasil') || c == 'br' || c.contains('italie') || 
            c.contains('espagne') || c.contains('spain') || c.contains('venezuela') || c.contains('aruba') || 
            c.contains('martinique') || c.contains('guadeloupe') || c.contains('saint-barth') || c.contains('saint-martin');
        return !isOther;

      case 'BR':
        return loc.contains('bresil') || loc.contains('brasil') || c.contains('bresil') || c.contains('brasil') || c == 'br' ||
            loc.contains('cuiaba') || loc.contains('sao paulo') || loc.contains('rio') || loc.contains('curitiba') ||
            loc.contains('florianopolis') || loc.contains('porto alegre') || loc.contains('palmas') || loc.contains('fortaleza') ||
            loc.contains('salvador') || loc.contains('ribeirao') || loc.contains('balneario') || loc.contains('santos') ||
            name.contains('brasilia') || name.contains('copacabana') || name.contains('cuiaba') || 
            name.contains('panam') || name.contains('pan-american') || name.contains('cbt') || name.contains('sand series');

      case 'RE':
        return loc.contains('reunion') || c.contains('reunion') || c == 're' ||
            name.contains('brisants') || name.contains('bourbon') || name.contains('tcbsp') || name.contains('beach park');

      case 'ANT':
        return loc.contains('martinique') || loc.contains('guadeloupe') || loc.contains('saint-barth') || loc.contains('saint-martin') ||
            c.contains('martinique') || c.contains('guadeloupe') || c.contains('saint-barth') || c.contains('saint-martin') ||
            name.contains('madiana') || name.contains('fcbt') || name.contains('karibbean') || name.contains('an nou');

      case 'IT':
        return loc.contains('italie') || loc.contains('italy') || c.contains('italie') || c.contains('italy') || c == 'it' ||
            name.contains('cervia') || name.contains('terracina');

      case 'ES':
        return loc.contains('espagne') || loc.contains('spain') || c.contains('espagne') || c.contains('spain') || c == 'es' ||
            name.contains('canaria') || name.contains('barcelona');

      case 'VE':
        return loc.contains('venezuela') || c.contains('venezuela') || c == 've' ||
            name.contains('lecheria') || name.contains('margarita') || name.contains('dracula') ||
            loc.contains('aruba') || c.contains('aruba') || c == 'aw' ||
            name.contains('aruba') || name.contains('bushiri') || name.contains('bta');

      default:
        return true;
    }
  }

  String _detectUserCountryFromProfileOrDevice() {
    // 1. Profil utilisateur (s'il est renseigné dans le compte BeachMatch)
    try {
      final user = context.read<AppState>().currentUser;
      if (user != null) {
        if (user.isBrazilian || user.country.toUpperCase() == 'BR') return 'BR';
        if (user.country.toUpperCase() == 'RE') return 'RE';
        if (user.country.toUpperCase() == 'IT') return 'IT';
        if (user.country.toUpperCase() == 'ES') return 'ES';
        if (user.location.trim().isNotEmpty) {
          final loc = _removeAccents(user.location).toLowerCase();
          if (loc.contains('bresil') || loc.contains('brasil') || loc.contains('cuiaba') || loc.contains('sao paulo') || loc.contains('rio') || loc.contains('curitiba') || loc.contains('florianopolis') || loc.contains('palmas') || loc.contains('fortaleza') || loc.contains('brasilia') || loc.contains('salvador')) {
            return 'BR';
          }
          if (loc.contains('reunion')) return 'RE';
          if (loc.contains('italie') || loc.contains('italy') || loc.contains('italia')) return 'IT';
          if (loc.contains('espagne') || loc.contains('spain') || loc.contains('espana')) return 'ES';
          if (loc.contains('martinique') || loc.contains('guadeloupe') || loc.contains('saint-barth') || loc.contains('saint-martin')) return 'ANT';
          if (loc.contains('aruba') || loc.contains('venezuela')) return 'VE';
          if (loc.contains('france') || loc.contains('paris') || loc.contains('marseille') || loc.contains('nice') || loc.contains('lyon') || loc.contains('bordeaux') || loc.contains('toulouse')) {
            return 'FR';
          }
        }
      }
    } catch (_) {}

    // 2. Paramètres régionaux et langue du smartphone (sans GPS)
    try {
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      final countryCode = (locale.countryCode ?? '').toUpperCase();
      final lang = locale.languageCode.toLowerCase();

      if (countryCode == 'BR' || lang == 'pt') return 'BR';
      if (countryCode == 'RE') return 'RE';
      if (countryCode == 'IT' || lang == 'it') return 'IT';
      if (countryCode == 'ES' || lang == 'es') return 'ES';
      if (countryCode == 'AW' || countryCode == 'VE') return 'VE';
      if (countryCode == 'FR' || lang == 'fr') return 'FR';
    } catch (_) {}

    // 3. Fuseau horaire du smartphone
    try {
      final offset = DateTime.now().timeZoneOffset.inHours;
      if (offset >= -4 && offset <= -2) return 'BR';
      if (offset == 4) return 'RE';
    } catch (_) {}

    return 'FR';
  }

  String _detectCountryFromPosition(Position pos) {
    if (pos.latitude >= -22.0 && pos.latitude <= -20.0 && pos.longitude >= 55.0 && pos.longitude <= 56.5) {
      return 'RE';
    }
    if (pos.latitude >= -34.0 && pos.latitude <= 6.0 && pos.longitude >= -74.0 && pos.longitude <= -34.0) {
      return 'BR';
    }
    if (pos.latitude >= 35.5 && pos.latitude <= 47.5 && pos.longitude >= 6.5 && pos.longitude <= 19.0) {
      return 'IT';
    }
    if (pos.latitude >= 36.0 && pos.latitude <= 44.0 && pos.longitude >= -9.5 && pos.longitude <= 3.5) {
      return 'ES';
    }
    if (pos.latitude >= 14.0 && pos.latitude <= 18.5 && pos.longitude >= -63.5 && pos.longitude <= -60.5) {
      return 'ANT';
    }
    if (pos.latitude >= 41.0 && pos.latitude <= 51.5 && pos.longitude >= -5.5 && pos.longitude <= 10.0) {
      return 'FR';
    }
    return 'FR';
  }
  
  List<Map<String, String>> _getDistanceFilters(bool isBr) => [
    {'id': 'ALL', 'label': isBr ? 'Todas as distâncias 📍' : 'Toutes distances 📍'},
    {'id': '20', 'label': '< 20 km'},
    {'id': '50', 'label': '< 50 km'},
    {'id': '100', 'label': '< 100 km'},
    {'id': '200', 'label': '< 200 km'},
  ];

  List<Map<String, String>> _getCountryFilters(bool isBr) => [
    {'id': 'ALL', 'label': isBr ? 'Todos os países 🌍' : 'Tous pays 🌍'},
    {'id': 'BR', 'label': isBr ? 'Brasil 🇧🇷' : 'Brésil 🇧🇷'},
    {'id': 'FR', 'label': isBr ? 'França 🇫🇷' : 'Métropole 🇫🇷'},
    {'id': 'RE', 'label': isBr ? 'Ilha Reunião 🇷🇪' : 'La Réunion 🇷🇪'},
    {'id': 'ANT', 'label': isBr ? 'Antilhas 🌴' : 'Antilles 🌴'},
    {'id': 'IT', 'label': isBr ? 'Itália 🇮🇹' : 'Italie 🇮🇹'},
    {'id': 'ES', 'label': isBr ? 'Espanha 🇪🇸' : 'Espagne 🇪🇸'},
    {'id': 'VE', 'label': 'Venezuela & Aruba 🇻🇪'},
  ];

  List<Map<String, String>> _getFormatFilters(bool isBr) => [
    {'id': 'ALL', 'label': isBr ? 'Todos formatos 🎾' : 'Tous formats 🎾'},
    {'id': 'DH', 'label': 'DH'},
    {'id': 'DD', 'label': 'DD'},
    {'id': 'DX', 'label': 'DX'},
    {'id': 'Jeunes', 'label': isBr ? 'Juvenil (Sub-14/18)' : 'Jeunes (U14-U18)'},
  ];

  List<Map<String, String>> _getCategoryFilters(bool isBr) => [
    {'id': 'ALL', 'label': isBr ? 'Todas as categorias 🏆' : 'Toutes catégories 🏆'},
    {'id': 'Sand Series 🌟', 'label': 'Sand Series 🌟'},
    {'id': 'CBT', 'label': 'CBT / Nacional 🇧🇷'},
    {'id': 'BT 2000 / 400', 'label': 'BT 2000 / 400'},
    {'id': 'BT 1000', 'label': 'BT 1000'},
    {'id': 'BT 500', 'label': 'BT 500'},
    {'id': 'BT 250', 'label': 'BT 250'},
    {'id': 'BT 100 / 25', 'label': 'BT 100 / 25'},
    {'id': 'Terminés', 'label': isBr ? 'Encerrados 🏁' : 'Terminés 🏁'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAutoCountryDetection();
      final appState = context.read<AppState>();
      if (appState.tournaments.isEmpty) {
        appState.loadTournaments();
      }
    });
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
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAutoCountryDetection() async {
    // 1. Détection automatique préalable (sans GPS requis : Profil ou smartphone)
    final initialCountry = _detectUserCountryFromProfileOrDevice();
    if (!_hasUserManuallyChangedCountry && mounted) {
      setState(() {
        _userDetectedCountry = initialCountry;
        _selectedCountryFilter = initialCountry;
      });
    }

    // 2. Détection GPS plus précise si disponible
    await _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    try {
      final pos = context.read<AppState>().currentPosition;
      if (pos != null) {
        setState(() => _currentPosition = pos);
        final country = _detectCountryFromPosition(pos);
        if (!_hasUserManuallyChangedCountry && mounted) {
          setState(() {
            _userDetectedCountry = country;
            _selectedCountryFilter = country;
          });
        }
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final currentPos = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() => _currentPosition = currentPos);
          final country = _detectCountryFromPosition(currentPos);
          if (!_hasUserManuallyChangedCountry) {
            setState(() {
              _userDetectedCountry = country;
              _selectedCountryFilter = country;
            });
          }
        }
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
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || _userDetectedCountry == 'BR';
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
      if (_selectedCountryFilter != 'ALL') {
        if (!_isTournamentFromCountry(t, _selectedCountryFilter)) return false;
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
        } else if (_selectedCategoryFilter == 'CBT') {
          if (!t.category.toUpperCase().contains('CBT')) return false;
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
        // Priorité dynamique aux tournois du pays de l'utilisateur (France, Brésil, Réunion, Italie, etc.) si "Tous pays" est sélectionné
        if (_selectedCountryFilter == 'ALL') {
          final isAUserCountry = _isTournamentFromCountry(a, _userDetectedCountry);
          final isBUserCountry = _isTournamentFromCountry(b, _userDetectedCountry);
          if (isAUserCountry && !isBUserCountry) return -1;
          if (!isAUserCountry && isBUserCountry) return 1;
        }

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

                // 🔍 Barre de Recherche Compacte & Bouton Filtres
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF16253B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: isBr ? "Buscar cidade, arena, torneio..." : "Rechercher une ville, club, tournoi...",
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
                      const SizedBox(width: 8),
                      // Bouton Filtres Avancés Modal
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showAdvancedFilterModal(context, isBr);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _hasActiveFilters()
                                ? AppColors.coral.withValues(alpha: 0.3)
                                : const Color(0xFF16253B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _hasActiveFilters() ? AppColors.coral : Colors.white.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: _hasActiveFilters() ? AppColors.coral : Colors.white70,
                                size: 20,
                              ),
                              if (_hasActiveFilters())
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.gold,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 6),

                // 🔽 Menus Déroulants Pays & Catégories (Contraste maximal, aucun ton sur ton gris)
                _buildDropdownFiltersRow(isBr),

                if (_isLocating)
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text(isBr ? "Obtendo localização..." : "Localisation en cours...", style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                                      isBr ? "Carregando torneios oficiais..." : "Chargement des tournois officiels...",
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
                                        label: Text(isBr ? "Redefinir / Atualizar" : "Réinitialiser / Actualiser", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                                  _buildMonthHeader(_getMonthHeaderLabel(tournament.startDate!, isBr: isBr)),
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

  String _getMonthHeaderLabel(DateTime dt, {bool isBr = false}) {
    const monthsFr = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    const monthsPt = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final months = isBr ? monthsPt : monthsFr;
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
    if (locLower.contains('italie') || locLower.contains('italy') || countryLower == 'it' || countryLower.contains('italie') || locLower.contains('cervia') || locLower.contains('terracina')) {
      flag = '🇮🇹';
    } else if (locLower.contains('espagne') || locLower.contains('spain') || countryLower == 'es' || countryLower.contains('espagne') || locLower.contains('canaria') || locLower.contains('barcelona')) {
      flag = '🇪🇸';
    } else if (countryLower == 'br' || countryLower.contains('br') || countryLower.contains('brasil') || countryLower.contains('brazil') || locLower.contains('brésil') || locLower.contains('brasil') || locLower.contains('copacabana') || locLower.contains('brasilia') || locLower.contains('cuiaba') || locLower.contains('fortaleza') || locLower.contains('palmas') || locLower.contains('salvador') || locLower.contains('curitiba') || locLower.contains('ceara') || locLower.contains('belo horizonte') || locLower.contains('porto alegre') || locLower.contains('santos') || locLower.contains('campinas') || locLower.contains('vitoria') || nameLower.contains('cbt')) {
      flag = '🇧🇷';
    } else if (locLower.contains('venezuela') || locLower.contains('vénézuela') || countryLower == 've' || countryLower.contains('venezuela') || locLower.contains('lecheria') || locLower.contains('margarita') || locLower.contains('puerto cabello')) {
      flag = '🇻🇪';
    } else if (locLower.contains('aruba') || countryLower == 'aw' || countryLower.contains('aruba') || locLower.contains('bushiri')) {
      flag = '🇦🇼';
    } else if (locLower.contains('saint-martin') || locLower.contains('st martin') || locLower.contains('orientale') || locLower.contains('guadeloupe') || locLower.contains('martinique')) {
      flag = '🌴';
    } else if (locLower.contains('nouméa') || locLower.contains('noumea')) {
      flag = '🇳🇨';
    } else if (locLower.contains('reunion') || locLower.contains('réunion') || countryLower == 're' || countryLower.contains('reunion') || locLower.contains('clotilde') || locLower.contains('paul') || nameLower.contains('brisants')) {
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
                                  child: Text(tournament.club, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500)),
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
                              (countryLower == 'br' || countryLower.contains('br') || locLower.contains('brasil') || nameLower.contains('cbt'))
                                  ? "Inscrições & Contato do Árbitro"
                                  : "Inscriptions & Contact JAT dispos",
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

  bool _hasActiveFilters() {
    return _selectedDistanceFilter != 'ALL' ||
        _selectedCountryFilter != _userDetectedCountry ||
        _selectedFormatFilter != 'ALL' ||
        _selectedCategoryFilter != 'ALL' ||
        _searchQuery.isNotEmpty;
  }

  void _resetFilters() {
    setState(() {
      _selectedDistanceFilter = 'ALL';
      _selectedCountryFilter = _userDetectedCountry;
      _selectedFormatFilter = 'ALL';
      _selectedCategoryFilter = 'ALL';
      _hasUserManuallyChangedCountry = false;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Widget _buildDropdownFiltersRow(bool isBr) {
    final countryFilters = _getCountryFilters(isBr);
    final categoryFilters = _getCategoryFilters(isBr);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          // 🌍 Menu Déroulant PAYS
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16253B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedCountryFilter != 'ALL' ? AppColors.gold : Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: countryFilters.any((c) => c['id'] == _selectedCountryFilter) ? _selectedCountryFilter : 'ALL',
                  dropdownColor: const Color(0xFF0F172A),
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.gold, size: 22),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  onChanged: (val) {
                    if (val != null) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _hasUserManuallyChangedCountry = true;
                        _selectedCountryFilter = val;
                      });
                    }
                  },
                  items: countryFilters.map((c) {
                    final isSel = c['id'] == _selectedCountryFilter;
                    return DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(
                        c['label']!,
                        style: TextStyle(
                          color: isSel ? AppColors.gold : Colors.white,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 🏆 Menu Déroulant CATÉGORIES / NIVEAUX
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16253B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedCategoryFilter != 'ALL' ? AppColors.coral : Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: categoryFilters.any((c) => c['id'] == _selectedCategoryFilter) ? _selectedCategoryFilter : 'ALL',
                  dropdownColor: const Color(0xFF0F172A),
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.coral, size: 22),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  onChanged: (val) {
                    if (val != null) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategoryFilter = val);
                    }
                  },
                  items: categoryFilters.map((c) {
                    final isSel = c['id'] == _selectedCategoryFilter;
                    return DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(
                        c['label']!,
                        style: TextStyle(
                          color: isSel ? AppColors.coral : Colors.white,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          if (_hasActiveFilters()) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _resetFilters();
              },
              child: Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.coral, width: 1.2),
                ),
                child: const Icon(Icons.restart_alt_rounded, color: AppColors.coral, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAdvancedFilterModal(BuildContext context, bool isBr) {
    final formatFilters = _getFormatFilters(isBr);
    final distanceFilters = _getDistanceFilters(isBr);
    final countryFilters = _getCountryFilters(isBr);
    final categoryFilters = _getCategoryFilters(isBr);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, modalSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isBr ? "Filtros avançados" : "Filtres avancés",
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _selectedDistanceFilter = 'ALL';
                                _selectedCountryFilter = 'ALL';
                                _selectedCategoryFilter = 'ALL';
                                _selectedFormatFilter = 'ALL';
                              });
                              Navigator.pop(ctx);
                            },
                            child: Text(isBr ? "Redefinir" : "Réinitialiser", style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(isBr ? "Formato de jogo" : "Format de jeu", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7.6,
                        children: formatFilters.map((f) {
                          final isSelected = _selectedFormatFilter == f['id'];
                          return ChoiceChip(
                            label: Text(
                              f['label']!,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                                fontSize: 11.9,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              ),
                            ),
                            visualDensity: const VisualDensity(horizontal: -1.0, vertical: -1.0),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 7.6, vertical: 0),
                            selected: isSelected,
                            selectedColor: AppColors.gold,
                            backgroundColor: const Color(0xFF1E293B),
                            side: BorderSide(
                              color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.35),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11.4)),
                            showCheckmark: false,
                            onSelected: (sel) {
                              if (sel) {
                                HapticFeedback.lightImpact();
                                setState(() => _selectedFormatFilter = f['id']!);
                                modalSetState(() {});
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(isBr ? "Distância máxima" : "Distance maximale", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: distanceFilters.map((d) {
                          final isSelected = _selectedDistanceFilter == d['id'];
                          return ChoiceChip(
                            label: Text(
                              d['label']!,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.gold,
                            backgroundColor: const Color(0xFF1E293B),
                            side: BorderSide(
                              color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.35),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            showCheckmark: false,
                            onSelected: (sel) {
                              if (sel) {
                                HapticFeedback.lightImpact();
                                _handleDistanceFilter(d['id']!);
                                modalSetState(() {});
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(isBr ? "Países & Regiões" : "Pays & Régions", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: countryFilters.map((c) {
                          final isSelected = _selectedCountryFilter == c['id'];
                          return ChoiceChip(
                            label: Text(
                              c['label']!,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.gold,
                            backgroundColor: const Color(0xFF1E293B),
                            side: BorderSide(
                              color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.35),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            showCheckmark: false,
                            onSelected: (sel) {
                              if (sel) {
                                HapticFeedback.lightImpact();
                                setState(() => _selectedCountryFilter = c['id']!);
                                modalSetState(() {});
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(isBr ? "Categoria do Torneio" : "Catégorie de Tournoi", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: categoryFilters.map((cat) {
                          final isSelected = _selectedCategoryFilter == cat['id'];
                          return ChoiceChip(
                            label: Text(
                              cat['label']!,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.gold,
                            backgroundColor: const Color(0xFF1E293B),
                            side: BorderSide(
                              color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.35),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            showCheckmark: false,
                            onSelected: (sel) {
                              if (sel) {
                                HapticFeedback.lightImpact();
                                setState(() => _selectedCategoryFilter = cat['id']!);
                                modalSetState(() {});
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.coral,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(isBr ? "Aplicar filtros" : "Appliquer les filtres", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
