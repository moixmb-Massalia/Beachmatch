import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/tournament.dart';
import '../models/user.dart';
import '../theme/colors.dart';
import '../screens/tournaments/tournament_detail_screen.dart';

/// Carrousel 3D Orbital / Cylindrique qui pivote sur place au centre de l'accueil
/// Chaque tournoi passe l'un derrière l'autre avec un effet globe / mappemonde 3D
/// Met automatiquement en avant les tournois les plus proches géographiquement de l'utilisateur (Ville, Pays, Région)
class HomeTournament3dGlobe extends StatefulWidget {
  final List<TournamentModel> tournaments;
  final UserModel? user;
  final Position? userPosition;

  const HomeTournament3dGlobe({
    super.key,
    required this.tournaments,
    this.user,
    this.userPosition,
  });

  @override
  State<HomeTournament3dGlobe> createState() => _HomeTournament3dGlobeState();
}

class _HomeTournament3dGlobeState extends State<HomeTournament3dGlobe> {
  late PageController _pageController;
  double _currentPage = 0.0;
  Timer? _autoRotateTimer;
  bool _isUserInteracting = false;
  static const int _loopFactor = 1000;

  List<TournamentModel> _sortedTournaments = [];
  final Map<String, double> _geoScores = {};

  @override
  void initState() {
    super.initState();
    _prepareTournaments();
    final initialPage = _getInitialVirtualPage();
    _currentPage = initialPage.toDouble();
    _pageController = PageController(
      initialPage: initialPage,
      viewportFraction: 0.84,
    );

    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? _currentPage;
        });
      }
    });

    _startAutoRotation();
  }

  String _detectUserCountry() {
    if (widget.userPosition != null) {
      final pos = widget.userPosition!;
      if (pos.latitude >= -22.0 && pos.latitude <= -20.0 && pos.longitude >= 55.0 && pos.longitude <= 56.5) return 'RE';
      if (pos.latitude >= -34.0 && pos.latitude <= 6.0 && pos.longitude >= -74.0 && pos.longitude <= -34.0) return 'BR';
      if (pos.latitude >= 35.5 && pos.latitude <= 47.5 && pos.longitude >= 6.5 && pos.longitude <= 19.0) return 'IT';
      if (pos.latitude >= 36.0 && pos.latitude <= 44.0 && pos.longitude >= -9.5 && pos.longitude <= 3.5) return 'ES';
      if (pos.latitude >= 14.0 && pos.latitude <= 18.5 && pos.longitude >= -63.5 && pos.longitude <= -60.5) return 'ANT';
      if (pos.latitude >= 41.0 && pos.latitude <= 51.5 && pos.longitude >= -5.5 && pos.longitude <= 10.0) return 'FR';
    }

    if (widget.user != null) {
      if (widget.user!.isBrazilian || widget.user!.country.toUpperCase() == 'BR') return 'BR';
      if (widget.user!.country.toUpperCase() == 'RE') return 'RE';
      if (widget.user!.country.toUpperCase() == 'IT') return 'IT';
      if (widget.user!.country.toUpperCase() == 'ES') return 'ES';
      if (widget.user!.location.isNotEmpty) {
        final loc = widget.user!.location.toLowerCase();
        if (loc.contains('reunion') || loc.contains('réunion')) return 'RE';
        if (loc.contains('bresil') || loc.contains('brasil') || loc.contains('fortaleza') || loc.contains('sao paulo') || loc.contains('cuiaba') || loc.contains('curitiba') || loc.contains('ceara')) return 'BR';
        if (loc.contains('italie') || loc.contains('italy') || loc.contains('italia')) return 'IT';
        if (loc.contains('espagne') || loc.contains('spain')) return 'ES';
        if (loc.contains('martinique') || loc.contains('guadeloupe') || loc.contains('saint-martin')) return 'ANT';
        if (loc.contains('venezuela') || loc.contains('aruba')) return 'VE';
        return 'FR';
      }
    }

    // 3. Paramètres régionaux et langue du smartphone (Play Store / Système)
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

    // 4. Fuseau horaire du smartphone
    try {
      final offset = DateTime.now().timeZoneOffset.inHours;
      if (offset >= -4 && offset <= -2) return 'BR';
      if (offset == 4) return 'RE';
    } catch (_) {}

    return 'FR';
  }

  double _computeGeoScore(TournamentModel t, String userCountry, String userCityLower) {
    double score = 0.0;

    // 1. Proximité GPS précise si coordonnées présentes
    if (widget.userPosition != null && t.latitude != null && t.longitude != null) {
      final distKm = Geolocator.distanceBetween(
        widget.userPosition!.latitude,
        widget.userPosition!.longitude,
        t.latitude!,
        t.longitude!,
      ) / 1000.0;

      if (distKm <= 35) {
        score += 1500.0;
      } else if (distKm <= 80) {
        score += 1100.0;
      } else if (distKm <= 180) {
        score += 750.0;
      } else if (distKm <= 350) {
        score += 450.0;
      }
    }

    // 2. Même ville que l'utilisateur
    final tCityLower = t.city.toLowerCase();
    if (userCityLower.isNotEmpty && (tCityLower.contains(userCityLower) || userCityLower.contains(tCityLower))) {
      score += 1200.0;
    }

    // 3. Même pays / territoire
    final flag = _getFlagForTournament(t);
    if ((userCountry == 'FR' && flag == '🇫🇷') ||
        (userCountry == 'RE' && flag == '🇷🇪') ||
        (userCountry == 'BR' && flag == '🇧🇷') ||
        (userCountry == 'IT' && flag == '🇮🇹') ||
        (userCountry == 'ES' && flag == '🇪🇸') ||
        (userCountry == 'ANT' && flag == '🌴') ||
        (userCountry == 'VE' && (flag == '🇻🇪' || flag == '🇦🇼'))) {
      score += 600.0;
    }

    // 4. Prestige du tournoi
    final cat = t.category.toUpperCase();
    if (cat.contains('2000') || cat.contains('WORLD') || cat.contains('SAND SERIES')) {
      score += 200.0;
    } else if (cat.contains('1000')) {
      score += 150.0;
    } else if (cat.contains('500')) {
      score += 80.0;
    }

    return score;
  }

  void _prepareTournaments() {
    // Ne retenir STRICTEMENT que les tournois à venir (exclure tous les tournois passés ou terminés)
    final list = widget.tournaments.where((t) => !t.isPassed).toList();
    final userCountry = _detectUserCountry();
    final userCity = (widget.user?.location ?? '').split(',').first.trim().toLowerCase();

    _geoScores.clear();
    for (final t in list) {
      _geoScores[t.id] = _computeGeoScore(t, userCountry, userCity);
    }

    list.sort((a, b) {
      final scoreA = _geoScores[a.id] ?? 0.0;
      final scoreB = _geoScores[b.id] ?? 0.0;

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // Score de proximité géographique en premier !
      }

      final dateA = a.startDate ?? DateTime(2099);
      final dateB = b.startDate ?? DateTime(2099);
      return dateA.compareTo(dateB);
    });

    _sortedTournaments = list;
  }

  int _getInitialVirtualPage() {
    if (_sortedTournaments.isEmpty) return 0;
    final middle = (_sortedTournaments.length * _loopFactor) ~/ 2;
    return middle - (middle % _sortedTournaments.length);
  }

  void _startAutoRotation() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _isUserInteracting || _sortedTournaments.length <= 1) return;
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _pauseAutoRotation() {
    _isUserInteracting = true;
    _autoRotateTimer?.cancel();
  }

  void _resumeAutoRotationAfterDelay() {
    _isUserInteracting = false;
    _autoRotateTimer?.cancel();
    _autoRotateTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_isUserInteracting) {
        _startAutoRotation();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeTournament3dGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tournaments != widget.tournaments ||
        oldWidget.user != widget.user ||
        oldWidget.userPosition != widget.userPosition) {
      setState(() {
        _prepareTournaments();
      });
    }
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String _getFlagForTournament(TournamentModel t) {
    final loc = t.location.toLowerCase();
    final country = (t.country ?? '').toLowerCase();
    final name = t.name.toLowerCase();

    if (loc.contains('italie') || loc.contains('italy') || country.contains('italie') || country == 'it' || loc.contains('cervia') || loc.contains('terracina')) {
      return '🇮🇹';
    } else if (loc.contains('espagne') || loc.contains('spain') || country.contains('espagne') || country == 'es' || loc.contains('canaria') || loc.contains('barcelona')) {
      return '🇪🇸';
    } else if (country == 'br' ||
        loc.contains('brésil') ||
        loc.contains('brasil') ||
        loc.contains('brazil') ||
        country.contains('brésil') ||
        country.contains('brazil') ||
        country.contains('brasil') ||
        loc.contains('copacabana') ||
        loc.contains('brasilia') ||
        loc.contains('cuiabá') ||
        loc.contains('cuiaba') ||
        loc.contains('santos') ||
        loc.contains('curitiba') ||
        loc.contains('são paulo') ||
        loc.contains('sao paulo') ||
        loc.contains('rio de janeiro') ||
        loc.contains('fortaleza') ||
        loc.contains('palmas') ||
        loc.contains('salvador') ||
        loc.contains('campinas') ||
        loc.contains('belo horizonte') ||
        loc.contains('porto alegre') ||
        loc.contains('vitória') ||
        loc.contains('vitoria') ||
        name.contains('cbt')) {
      return '🇧🇷';
    } else if (loc.contains('venezuela') || loc.contains('vénézuela') || country.contains('venezuela') || country == 've' || loc.contains('lecheria') || loc.contains('margarita') || loc.contains('puerto cabello')) {
      return '🇻🇪';
    } else if (loc.contains('aruba') || country.contains('aruba') || country == 'aw' || loc.contains('bushiri') || name.contains('aruba')) {
      return '🇦🇼';
    } else if (loc.contains('saint-martin') || loc.contains('st martin') || loc.contains('guadeloupe') || loc.contains('martinique')) {
      return '🌴';
    } else if (loc.contains('nouméa') || loc.contains('noumea')) {
      return '🇳🇨';
    } else if (loc.contains('reunion') || loc.contains('réunion') || loc.contains('brisants') || loc.contains('clotilde') || name.contains('brisants')) {
      return '🇷🇪';
    }
    return '🇫🇷';
  }

  Color _getCategoryBadgeColor(String category) {
    final cat = category.toUpperCase();
    if (cat.contains('2000') || cat.contains('WORLD') || cat.contains('CHAMPIONSHIP')) {
      return const Color(0xFFFF4500); // Orange feu
    } else if (cat.contains('1000') || cat.contains('SUPER')) {
      return AppColors.gold;
    } else if (cat.contains('500')) {
      return const Color(0xFF00C6FF); // Cyan
    } else if (cat.contains('250')) {
      return const Color(0xFF00E676); // Vert menthe
    } else if (cat.contains('100')) {
      return const Color(0xFFAB47BC); // Violet
    }
    return AppColors.coral;
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedTournaments.isEmpty) {
      return _buildEmptyTournamentsCard();
    }

    final totalTournaments = _sortedTournaments.length;
    final activeIndex = (_currentPage.round()) % totalTournaments;
    final isBr = widget.user?.isBrazilian == true ||
        widget.user?.country.toUpperCase() == 'BR' ||
        _detectUserCountry() == 'BR' ||
        WidgetsBinding.instance.platformDispatcher.locale.languageCode.toLowerCase() == 'pt';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec titre et commandes de rotation 3D
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                    ),
                    child: const Icon(Icons.public, color: AppColors.gold, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBr ? "Torneios & Chaves" : "Tournois & Tableaux",
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        isBr ? "Personalizado para sua região & Mundo 🌍" : "Personnalisé selon votre région & Monde 🌍",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Boutons flèches de rotation orbitale manuelle
              Row(
                children: [
                  _buildNavCircleButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () {
                      _pauseAutoRotation();
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                      _resumeAutoRotationAfterDelay();
                    },
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      "${(activeIndex % totalTournaments) + 1}/$totalTournaments",
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildNavCircleButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () {
                      _pauseAutoRotation();
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                      _resumeAutoRotationAfterDelay();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Zone 3D Orbital Globe
        SizedBox(
          height: 303,
          child: Listener(
            onPointerDown: (_) => _pauseAutoRotation(),
            onPointerUp: (_) => _resumeAutoRotationAfterDelay(),
            onPointerCancel: (_) => _resumeAutoRotationAfterDelay(),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _sortedTournaments.length * _loopFactor,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, virtualIndex) {
                final realIndex = virtualIndex % _sortedTournaments.length;
                final tournament = _sortedTournaments[realIndex];
                final geoScore = _geoScores[tournament.id] ?? 0.0;
                final isLocal = geoScore >= 500.0;

                // Calcul de l'offset 3D par rapport à la page active
                final diff = virtualIndex - _currentPage;

                // Si la carte est trop éloignée, on optimise le rendu
                if (diff.abs() > 2.5) {
                  return const SizedBox.shrink();
                }

                // Transformations 3D Orbitales :
                // 1. Rotation sur l'axe Y pour donner l'effet globe/cylindre
                // 2. Contre-translation en X pour que le carrousel reste sur place au centre
                // 3. Translation en Z pour faire reculer les cartes latérales derrière la carte centrale
                // 4. Mise à l'échelle (scale) et opacité progressive
                final angleY = diff * 0.42; // radians de rotation
                final translationX = -diff * 42.0; // resserrement vers le centre
                final translationZ = -diff.abs() * 105.0; // profondeur vers l'arrière
                final scale = (1.0 - (diff.abs() * 0.12)).clamp(0.72, 1.0);
                final opacity = (1.0 - (diff.abs() * 0.35)).clamp(0.20, 1.0);

                final matrix = Matrix4.identity()
                  ..setEntry(3, 2, 0.0013) // Perspective 3D réaliste
                  ..multiply(Matrix4.translationValues(translationX, 0.0, translationZ))
                  ..multiply(Matrix4.rotationY(angleY))
                  ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));

                final isCenter = diff.abs() < 0.45;

                return Center(
                  child: Transform(
                    transform: matrix,
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: opacity,
                      child: GestureDetector(
                        onTap: () {
                          if (isCenter) {
                            // Clic sur le tournoi central -> Direction fiche détaillée et tableaux
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TournamentDetailScreen(tournament: tournament),
                              ),
                            );
                          } else {
                            // Clic sur un tournoi latéral -> Le faire pivoter au premier plan
                            _pauseAutoRotation();
                            _pageController.animateToPage(
                              virtualIndex,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOutCubic,
                            );
                            _resumeAutoRotationAfterDelay();
                          }
                        },
                        child: _buildOrbitalCard(tournament, isCenter, isLocal),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Mini barre de progression d'orbite
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_outlined, size: 13, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  isBr
                      ? "Arraste para girar a órbita · Destaques da sua região"
                      : "Glissez pour tourner l'orbite · En tête : votre région",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavCircleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildOrbitalCard(TournamentModel tournament, bool isCenter, bool isLocal) {
    final isBr = widget.user?.isBrazilian == true ||
        widget.user?.country.toUpperCase() == 'BR' ||
        _detectUserCountry() == 'BR' ||
        WidgetsBinding.instance.platformDispatcher.locale.languageCode.toLowerCase() == 'pt';
    final flag = _getFlagForTournament(tournament);
    final badgeColor = _getCategoryBadgeColor(tournament.category);

    return Container(
      width: 352,
      height: 286,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: isCenter
            ? [
                BoxShadow(
                  color: (isLocal ? AppColors.coral : AppColors.gold).withValues(alpha: 0.35),
                  blurRadius: 22,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCenter
                    ? [
                        const Color(0xFF1E2638).withValues(alpha: 0.95),
                        const Color(0xFF131926).withValues(alpha: 0.90),
                      ]
                    : [
                        const Color(0xFF1E2638).withValues(alpha: 0.85),
                        const Color(0xFF131926).withValues(alpha: 0.80),
                      ],
              ),
              border: Border.all(
                color: isCenter
                    ? (isLocal ? AppColors.coral : AppColors.gold).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.25),
                width: isCenter ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rangée du haut : Catégorie badge & Drapeau & Statut (Local / Ouvert / Terminé)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: badgeColor, width: 1.2),
                          ),
                          child: Text(
                            tournament.category.isNotEmpty ? tournament.category : (isBr ? "TORNEIO" : "TOURNOI"),
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          flag,
                          style: const TextStyle(fontSize: 18),
                        ),
                        if (isLocal) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.coral, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 10, color: AppColors.coral),
                                const SizedBox(width: 2),
                                Text(
                                  isBr ? "Perto" : "Proche",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, color: Color(0xFF00E676), size: 11),
                          const SizedBox(width: 2),
                          Text(
                            isBr ? "ABERTO" : "OUVERT",
                            style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Nom du tournoi
                Text(
                  tournament.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17.0,
                    height: 1.2,
                  ),
                ),

                // Informations lieu et date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.coral),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tournament.city.isNotEmpty ? tournament.city : tournament.club,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.calendar_month, size: 13, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tournament.dateString.isNotEmpty ? tournament.dateString : (isBr ? "Datas a confirmar" : "Dates à confirmer"),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Formats DH / DD / DX et Bouton d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Capsules compactes des catégories
                    Row(
                      children: _buildCompactFormatChips(tournament.formats),
                    ),
                    // Bouton Voir Tableaux
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCenter
                              ? (isLocal ? [AppColors.coral, const Color(0xFFF97316)] : [AppColors.gold, AppColors.coral])
                              : [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isCenter
                            ? [
                                BoxShadow(
                                  color: (isLocal ? AppColors.coral : AppColors.gold).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 13,
                            color: isCenter ? Colors.black87 : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isBr ? "Chaves" : "Tableaux",
                            style: TextStyle(
                              color: isCenter ? Colors.black87 : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: isCenter ? Colors.black87 : Colors.white,
                          ),
                        ],
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

  List<Widget> _buildCompactFormatChips(List<String> formats) {
    if (formats.isEmpty) {
      return [
        _formatChip("DH"),
        const SizedBox(width: 4),
        _formatChip("DD"),
      ];
    }
    final compact = <String>[];
    for (final f in formats) {
      final upper = f.toUpperCase();
      if (upper == 'DH' || upper == 'DM' || upper.contains('DOUBLE HOMME') || upper.contains('HOMME') || upper.contains('MESSIEURS')) {
        if (!compact.contains('DH')) compact.add('DH');
      } else if (upper == 'DD' || upper == 'DF' || upper.contains('DOUBLE DAME') || upper.contains('DAME') || upper.contains('FEMME')) {
        if (!compact.contains('DD')) compact.add('DD');
      } else if (upper == 'DX' || upper.contains('MIXTE')) {
        if (!compact.contains('DX')) compact.add('DX');
      } else if (upper.contains('JEUNE') || upper.contains('U1')) {
        if (!compact.contains('Jeunes')) compact.add('Jeunes');
      } else if (compact.length < 3) {
        compact.add(upper.length > 3 ? upper.substring(0, 2) : upper);
      }
    }
    if (compact.isEmpty) compact.addAll(['DH', 'DD']);

    return compact.take(3).map((code) => Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: _formatChip(code),
    )).toList();
  }

  Widget _formatChip(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyTournamentsCard() {
    final isBr = widget.user?.isBrazilian == true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.public, color: AppColors.gold, size: 36),
            const SizedBox(height: 8),
            Text(
              isBr ? "Carregando torneios oficiais..." : "Chargement des tournois officiels...",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
