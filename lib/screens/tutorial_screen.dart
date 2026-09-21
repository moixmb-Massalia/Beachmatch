import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.sports_tennis_rounded,
      'title': "Bienvenue !",
      'subtitle': "La communauté n°1 du Beach Tennis",
      'description': "Bienvenue sur BeachMatch ! Trouvez des terrains, organisez vos matchs entre passionnés et suivez la compétition officielle."
    },
    {
      'icon': CupertinoIcons.map_fill,
      'title': "Carte & Spots Plage",
      'subtitle': "Terrains gratuits & Clubs",
      'description': "Découvrez les terrains gratuits sur le sable ou les clubs officiels éclairés avec météo marine en temps réel et itinéraires."
    },
    {
      'icon': Icons.groups_rounded,
      'title': "Organisez vos Matchs",
      'subtitle': "Parties amicales & ELO",
      'description': "Créez une partie en sélectionnant votre terrain en un clic, invitez vos partenaires, validez vos scores et progressez dans l'arène."
    },
    {
      'icon': CupertinoIcons.calendar,
      'title': "Tournois Homologués FFT",
      'subtitle': "Du BT 25 au BT 2000",
      'description': "Consultez le calendrier national officiel, lancez un 'SOS Partenaire' pour trouver un binôme et inscrivez votre équipe."
    },
    {
      'icon': Icons.sports_rounded,
      'title': "Live Scoring & Arbitrage",
      'subtitle': "Suivi point par point",
      'description': "Arbitrez facilement vos rencontres au bord du filet : scores en direct, tie-break, super tie-break et statistiques de jeu."
    },
    {
      'icon': Icons.emoji_events_rounded,
      'title': "Classement FFT & Tavernes",
      'subtitle': "3 300+ Joueurs & Clubs",
      'description': "Accédez au classement officiel Ten'Up de tous les licenciés français et échangez dans la Taverne interactive de votre club."
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeTutorial() async {
    try {
      await context.read<AppState>().markTutorialAsSeen();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeTutorial();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.58)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar with Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sports_tennis, color: AppColors.gold, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "BeachMatch Guide",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _completeTutorial,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text("Passer", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                // Carousel Slides
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Glass Icon Container with Glow
                            ClipRRect(
                              borderRadius: BorderRadius.circular(44),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(26),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.gold.withValues(alpha: 0.6),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    page['icon'] as IconData,
                                    size: 58,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Glass Card with Content
                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F1B29).withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 25,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        page['title'] as String,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        page['subtitle'] as String,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.coral,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        page['description'] as String,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          height: 1.5,
                                          color: Colors.white70,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Indicators & Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 7,
                            width: _currentPage == index ? 26 : 7,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? AppColors.gold : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.coral,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: AppColors.coral.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1 ? "C'est parti ! 🚀" : "Suivant",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
