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

  String _detectLanguage(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    if (user != null && (user.isBrazilian || user.country.toUpperCase() == 'BR')) {
      return 'pt';
    }
    if (user != null && user.country.isNotEmpty) {
      final c = user.country.toUpperCase();
      if (c == 'IT') return 'it';
      if (c == 'ES') return 'es';
      if (c == 'FR' || c == 'RE' || c == 'ANT') return 'fr';
    }
    if (appState.currentLocale != null) {
      final code = appState.currentLocale!.languageCode.toLowerCase();
      if (['pt', 'it', 'es', 'fr', 'en'].contains(code)) return code;
    }
    final devLocale = Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    final devLang = devLocale.languageCode.toLowerCase();
    if (['pt', 'it', 'es', 'fr', 'en'].contains(devLang)) return devLang;
    return 'en';
  }

  List<Map<String, dynamic>> _getLocalizedPages(String lang) {
    switch (lang) {
      case 'pt':
        return [
          {
            'icon': Icons.sports_tennis_rounded,
            'title': "Bem-vindo(a) !",
            'subtitle': "A comunidade nº 1 de Beach Tennis",
            'description': "Bem-vindo(a) ao BeachMatch! Encontre arenas de areia, organize partidas com amigos e acompanhe torneios oficiais."
          },
          {
            'icon': CupertinoIcons.map_fill,
            'title': "Mapa & Arenas",
            'subtitle': "Quadras públicas & Arenas privadas",
            'description': "Descubra as melhores arenas de praia, confira a previsão do clima e vento em tempo real e trace sua rota até a quadra."
          },
          {
            'icon': Icons.groups_rounded,
            'title': "Organize seus Jogos",
            'subtitle': "Partidas amigáveis & Desafios",
            'description': "Crie jogos na sua arena favorita em 1 clique, convide parceiros, confirme os placares e evolua na classificação."
          },
          {
            'icon': CupertinoIcons.calendar,
            'title': "Torneios CBT & ITF",
            'subtitle': "Do Circuito Amador ao Profissional",
            'description': "Acompanhe o calendário oficial de torneios, use o 'SOS Parceiro' para achar uma dupla e inscreva sua equipe com facilidade."
          },
          {
            'icon': Icons.sports_rounded,
            'title': "Placar ao Vivo & Arbitragem",
            'subtitle': "Acompanhamento ponto a ponto",
            'description': "Apite ou acompanhe jogos na beira da quadra: placar em tempo real, tie-break, super tie-break e estatísticas completas."
          },
          {
            'icon': Icons.emoji_events_rounded,
            'title': "Ranking & Comunidade",
            'subtitle': "Jogadores & Arenas Oficiais",
            'description': "Consulte o ranking, descubra os melhores atletas do circuito e interaja no chat exclusivo da sua arena."
          },
        ];

      case 'en':
        return [
          {
            'icon': Icons.sports_tennis_rounded,
            'title': "Welcome!",
            'subtitle': "The #1 Beach Tennis Community",
            'description': "Welcome to BeachMatch! Find beach courts and clubs, organize matches with players and follow official competitions."
          },
          {
            'icon': CupertinoIcons.map_fill,
            'title': "Map & Beach Spots",
            'subtitle': "Free Courts & Official Clubs",
            'description': "Discover public sand courts or lighted official clubs with real-time marine weather, wind forecast and GPS routes."
          },
          {
            'icon': Icons.groups_rounded,
            'title': "Organize your Matches",
            'subtitle': "Friendly Games & Challenges",
            'description': "Create a match at your favorite court in one click, invite partners, submit scores and climb the ranks."
          },
          {
            'icon': CupertinoIcons.calendar,
            'title': "Official & ITF Tournaments",
            'subtitle': "From Open to Pro Circuit",
            'description': "Browse the official tournament calendar, send a 'Partner SOS' to find a teammate and register your team."
          },
          {
            'icon': Icons.sports_rounded,
            'title': "Live Scoring & Umpiring",
            'subtitle': "Point-by-point live tracker",
            'description': "Easily referee matches court-side: live scores, tie-break, super tie-break and complete match statistics."
          },
          {
            'icon': Icons.emoji_events_rounded,
            'title': "Rankings & Community",
            'subtitle': "Players & Official Clubs",
            'description': "Access official rankings, discover top beach tennis athletes and chat inside your club's interactive lounge."
          },
        ];

      case 'es':
        return [
          {
            'icon': Icons.sports_tennis_rounded,
            'title': "¡Bienvenido/a!",
            'subtitle': "La comunidad nº 1 de Beach Tennis",
            'description': "¡Bienvenido/a a BeachMatch! Encuentra pistas y clubes, organiza partidos entre apasionados y sigue torneos oficiales."
          },
          {
            'icon': CupertinoIcons.map_fill,
            'title': "Mapa & Pistas de Playa",
            'subtitle': "Pistas gratuitas & Clubes",
            'description': "Descubre pistas en la arena o clubes oficiales con previsión de viento y clima en tiempo real e itinerarios."
          },
          {
            'icon': Icons.groups_rounded,
            'title': "Organiza tus Partidos",
            'subtitle': "Partidas amistosas & Retos",
            'description': "Crea una partida en tu pista favorita en un clic, invita compañeros, valida resultados y sube de nivel."
          },
          {
            'icon': CupertinoIcons.calendar,
            'title': "Torneos Oficiales & ITF",
            'subtitle': "Del circuito amateur al profesional",
            'description': "Consulta el calendario oficial de torneos, lanza un 'SOS Compañero' para formar pareja e inscribe a tu equipo."
          },
          {
            'icon': Icons.sports_rounded,
            'title': "Marcador en Vivo & Arbitraje",
            'subtitle': "Seguimiento punto a punto",
            'description': "Arbitra fácilmente a pie de pista: marcador en directo, tie-break, super tie-break y estadísticas de juego."
          },
          {
            'icon': Icons.emoji_events_rounded,
            'title': "Ranking & Comunidad",
            'subtitle': "Jugadores & Clubes Oficiales",
            'description': "Accede al ranking oficial, descubre a los mejores jugadores y conversa en la taberna interactiva de tu club."
          },
        ];

      case 'it':
        return [
          {
            'icon': Icons.sports_tennis_rounded,
            'title': "Benvenuto/a!",
            'subtitle': "La community n°1 del Beach Tennis",
            'description': "Benvenuto/a su BeachMatch! Trova campi e circoli, organizza partite tra appassionati e segui i tornei ufficiali."
          },
          {
            'icon': CupertinoIcons.map_fill,
            'title': "Mappa & Campi Spiaggia",
            'subtitle': "Campi liberi & Circoli",
            'description': "Scopri i campi sulla sabbia o i circoli con meteo vento in tempo reale e percorsi GPS diretti."
          },
          {
            'icon': Icons.groups_rounded,
            'title': "Organizza le tue Partite",
            'subtitle': "Sfide amichevoli & Tornei",
            'description': "Crea una partita in 1 clic sul tuo campo preferito, invita compagni, valida i punteggi e migliora il livello."
          },
          {
            'icon': CupertinoIcons.calendar,
            'title': "Tornei FITP & ITF",
            'subtitle': "Dall'amatoriale al circuito Pro",
            'description': "Consulta il calendario ufficiale dei tornei, lancia un 'SOS Compagno' per trovare una coppia e iscrivi la tua squadra."
          },
          {
            'icon': Icons.sports_rounded,
            'title': "Live Score & Arbitraggio",
            'subtitle': "Punto per punto in diretta",
            'description': "Arbitra o segui le partite a bordo campo: punteggio in tempo reale, tie-break, super tie-break e statistiche."
          },
          {
            'icon': Icons.emoji_events_rounded,
            'title': "Classifica & Community",
            'subtitle': "Migliaia di Giocatori & Circoli",
            'description': "Consulta le classifiche ufficiali e scambia messaggi nella bacheca interattiva del tuo circolo."
          },
        ];

      case 'fr':
      default:
        return [
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
            'subtitle': "Parties amicales & Défis",
            'description': "Créez une partie en sélectionnant votre terrain en un clic, invitez vos partenaires, validez vos scores et progressez dans l'arène."
          },
          {
            'icon': CupertinoIcons.calendar,
            'title': "Tournois Homologués FFT & ITF",
            'subtitle': "Du BT 25 au circuit Pro",
            'description': "Consultez le calendrier officiel, lancez un 'SOS Partenaire' pour trouver un binôme et inscrivez votre équipe."
          },
          {
            'icon': Icons.sports_rounded,
            'title': "Live Scoring & Arbitrage",
            'subtitle': "Suivi point par point",
            'description': "Arbitrez facilement vos rencontres au bord du filet : scores en direct, tie-break, super tie-break et statistiques de jeu."
          },
          {
            'icon': Icons.emoji_events_rounded,
            'title': "Classement & Tavernes",
            'subtitle': "Joueurs & Clubs Officiels",
            'description': "Accédez au classement officiel de tous les compétiteurs et échangez dans la Taverne interactive de votre club."
          },
        ];
    }
  }

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

  void _nextPage(int totalPages) {
    if (_currentPage < totalPages - 1) {
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
    final lang = _detectLanguage(context);
    final pages = _getLocalizedPages(lang);

    final guideTitle = lang == 'pt'
        ? "BeachMatch Guia"
        : (lang == 'es'
            ? "Guía BeachMatch"
            : (lang == 'it'
                ? "Guida BeachMatch"
                : (lang == 'en' ? "BeachMatch Guide" : "Guide BeachMatch")));

    final skipLabel = lang == 'pt'
        ? "Pular"
        : (lang == 'es'
            ? "Saltar"
            : (lang == 'it' ? "Salta" : (lang == 'en' ? "Skip" : "Passer")));

    final nextLabel = lang == 'pt'
        ? "Próximo"
        : (lang == 'es'
            ? "Siguiente"
            : (lang == 'it' ? "Avanti" : (lang == 'en' ? "Next" : "Suivant")));

    final startLabel = lang == 'pt'
        ? "Vamos lá ! 🚀"
        : (lang == 'es'
            ? "¡Vamos! 🚀"
            : (lang == 'it'
                ? "Cominciamo! 🚀"
                : (lang == 'en' ? "Let's Go! 🚀" : "C'est parti ! 🚀")));

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
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
                            guideTitle,
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
                        child: Text(skipLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final page = pages[index];
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
                          pages.length,
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
                          onPressed: () => _nextPage(pages.length),
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
                            _currentPage == pages.length - 1 ? startLabel : nextLabel,
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
