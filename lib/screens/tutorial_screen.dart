import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import 'profile_edit_screen.dart';

class TutorialItem {
  final IconData icon;
  final String tag;
  final String title;
  final String subtitle;
  final List<String> bullets;

  const TutorialItem({
    required this.icon,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });
}

class TutorialScreen extends StatefulWidget {
  final bool isReplay;
  const TutorialScreen({super.key, this.isReplay = false});

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

  List<TutorialItem> _getLocalizedPages(String lang) {
    switch (lang) {
      case 'pt':
        return [
          const TutorialItem(
            icon: Icons.sports_tennis_rounded,
            tag: "👋 BEM-VINDO(A)",
            title: "BeachMatch Brasil ☀️",
            subtitle: "A plataforma oficial dos apaixonados por Beach Tennis",
            bullets: [
              "Bem-vindo(a) ao app definitivo para jogar, competir e evoluir no Beach Tennis.",
              "Encontre quadras e arenas de areia em qualquer cidade do Brasil.",
              "Conecte-se com parceiros do seu nível e organize partidas sem complicação.",
              "Acompanhe o circuito oficial da CBT (Confederação Brasileira de Tênis) e ITF.",
            ],
          ),
          const TutorialItem(
            icon: Icons.home_rounded,
            tag: "ABA 1 · INÍCIO",
            title: "Feed Ao Vivo & Comunidade 🏠",
            subtitle: "Tudo o que acontece no esporte em tempo real",
            bullets: [
              "Status 'Procurando parceiro': Ative para ser chamado para jogos hoje mesmo.",
              "Partidas do dia: Veja os jogos agendados perto de você e peça para entrar.",
              "Atalhos instantâneos: Crie um jogo ou busque novos atletas em 1 toque.",
              "Feed social: Compartilhe fotos, resultados e novidades da sua arena.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.map_fill,
            tag: "ABA 2 · MAPA & ARENAS",
            title: "Arenas & Previsão do Vento 🏖️",
            subtitle: "Centenas de quadras mapeadas no Brasil",
            bullets: [
              "Localização GPS: Florianópolis, Santos, Rio de Janeiro, São Paulo e todo o país.",
              "Filtro inteligente: Quadras públicas gratuitas na praia ou Arenas privadas com iluminação.",
              "Previsão em tempo real: Vento ao vivo (nós / km/h), temperatura e condições marítimas.",
              "Rotas automáticas: Abra a navegação direto no Waze ou Google Maps.",
            ],
          ),
          const TutorialItem(
            icon: Icons.groups_rounded,
            tag: "ABA 3 · PARTIDAS",
            title: "Organize Jogos & Rei da Praia 🎾",
            subtitle: "Jogue mais e esqueça a confusão em grupos",
            bullets: [
              "Crie partidas na sua arena favorita em menos de 10 segundos.",
              "Modo Rei da Praia 👑: Rotação automática de duplas e pontuação de games.",
              "Divisão de custos: Facilitador de cobrança de quadra e bolas via PIX.",
              "Faltou o 4º jogador? O BeachMatch envia um alerta para jogadores do seu nível.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.calendar,
            tag: "ABA 4 · TORNEIOS",
            title: "Torneios CBT, ITF & BeachScore 🏆",
            subtitle: "Do circuito amador ao profissional",
            bullets: [
              "Calendário Oficial: Filtre por PRO, Categoria A, B, C, D e Iniciante.",
              "SOS Parceiro 🚨: Busque uma dupla para jogar torneios ou candidate-se a vagas.",
              "BeachScore ⚖️: Marcador ao vivo na beira da quadra para árbitros e atletas.",
              "Chaves e resultados: Acompanhe os confrontos ponto a ponto em tempo real.",
            ],
          ),
          const TutorialItem(
            icon: Icons.person_rounded,
            tag: "ABA 5 · PERFIL & SUPORTE",
            title: "Seu Perfil de Atleta & Suporte 🇧🇷",
            subtitle: "Sua identidade esportiva e canal direto",
            bullets: [
              "Defina sua Categoria CBT (Iniciante a PRO), ID CBT e sua Arena/Clube oficial.",
              "Histórico de jogos: Acompanhe vitórias, aproveitamento e evolução.",
              "Chat com Suporte Oficial 💬: Fale diretamente com nossa equipe no chat do app para tirar qualquer dúvida.",
              "Convide seus parceiros de treino para espalhar o Beach Tennis!",
            ],
          ),
        ];

      case 'en':
        return [
          const TutorialItem(
            icon: Icons.sports_tennis_rounded,
            tag: "👋 WELCOME",
            title: "Welcome to BeachMatch ☀️",
            subtitle: "The #1 Worldwide Beach Tennis Community",
            bullets: [
              "Welcome to the ultimate app to play, compete, and master Beach Tennis.",
              "Find beach courts and private arenas wherever you travel.",
              "Connect with balanced partners and set up matches in seconds.",
              "Follow official and international ITF tournaments worldwide.",
            ],
          ),
          const TutorialItem(
            icon: Icons.home_rounded,
            tag: "TAB 1 · HOME",
            title: "Daily Feed & Live Action 🏠",
            subtitle: "Everything happening on the sand right now",
            bullets: [
              "'Looking for a Partner' status: Turn it on to receive match invites immediately.",
              "Matches of the Day: See games happening near you and request to join.",
              "Instant shortcuts: Schedule a match or discover nearby players with one tap.",
              "Community feed: Share moments, photos, and club updates.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.map_fill,
            tag: "TAB 2 · MAP & COURTS",
            title: "Beach Courts & Live Wind Forecast 🏖️",
            subtitle: "Hundreds of verified sand spots",
            bullets: [
              "Accurate GPS locator: Discover public beach spots and illuminated official clubs.",
              "Real-time marine forecast: Live wind speed (knots) and weather before heading out.",
              "Turn-by-turn navigation: One-tap route via Waze or Google Maps.",
              "Community reviews: Check court surface quality, nets, and amenities.",
            ],
          ),
          const TutorialItem(
            icon: Icons.groups_rounded,
            tag: "TAB 3 · MATCHES",
            title: "Organize Matches & King of Court 🎾",
            subtitle: "No more messy messaging group chats",
            bullets: [
              "Schedule matches at your preferred court in less than 10 seconds.",
              "King of the Beach mode 👑: Automatic partner rotations and game scoring.",
              "Court fee splitting: Easy payment settlements with your playing group.",
              "Missing a 4th player? BeachMatch alerts matching-level players automatically.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.calendar,
            tag: "TAB 4 · TOURNAMENTS",
            title: "Tournaments & Live BeachScore 🏆",
            subtitle: "From open tournaments to the Pro circuit",
            bullets: [
              "Official Tournaments calendar: Filter by category, rank, and dates.",
              "Partner SOS 🚨: Looking for a teammate? Post a request or apply to existing ones.",
              "BeachScore ⚖️: Court-side live score refereeing with tie-break & stats.",
              "Live brackets: Follow tournament progression point-by-point in real time.",
            ],
          ),
          const TutorialItem(
            icon: Icons.person_rounded,
            tag: "TAB 5 · PROFILE & SUPPORT",
            title: "Your Player Profile & Support 💬",
            subtitle: "Your sports passport and direct line",
            bullets: [
              "Showcase your official level, license ID, and home club arena.",
              "Match history: Track win rate, played games, and rank progression.",
              "Direct Official Support 💬: Message our support team anytime inside the app chat.",
              "Invite your beach tennis buddies to join your matches!",
            ],
          ),
        ];

      case 'es':
        return [
          const TutorialItem(
            icon: Icons.sports_tennis_rounded,
            tag: "👋 BIENVENIDO/A",
            title: "BeachMatch Comunidad ☀️",
            subtitle: "La plataforma definitiva de Beach Tennis",
            bullets: [
              "Bienvenido/a a la app para jugar, competir y evolucionar en el Beach Tennis.",
              "Encuentra pistas públicas y clubes en la arena en cualquier ciudad.",
              "Conecta con jugadores de tu nivel y organiza partidos sin complicaciones.",
              "Sigue torneos oficiales y competiciones internacionales ITF.",
            ],
          ),
          const TutorialItem(
            icon: Icons.home_rounded,
            tag: "PESTAÑA 1 · INICIO",
            title: "Feed en Vivo & Actividades 🏠",
            subtitle: "Todo lo que pasa en la arena al instante",
            bullets: [
              "Estado 'Buscando compañero': Actívalo para recibir invitaciones hoy mismo.",
              "Partidos del día: Descubre los juegos cerca de ti y únete.",
              "Accesos directos: Crea partidos o busca compañeros en 1 clic.",
              "Feed social: Comparte fotos, resultados y novedades de tus pistas.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.map_fill,
            tag: "PESTAÑA 2 · MAPA",
            title: "Mapa de Pistas & Viento en Vivo 🏖️",
            subtitle: "Cientos de pistas en la playa y clubes",
            bullets: [
              "Ubicación GPS precisa: Pistas públicas gratuitas y clubes oficiales iluminados.",
              "Viento y tiempo en directo: Consulta la fuerza del viento (nudos) antes de salir.",
              "Ruta directa: Navegación guiada con Waze o Google Maps en 1 toque.",
              "Comentarios y servicios: Estado de la arena, duchas y redes.",
            ],
          ),
          const TutorialItem(
            icon: Icons.groups_rounded,
            tag: "PESTAÑA 3 · PARTIDOS",
            title: "Organiza Partidos & Rey de la Pista 🎾",
            subtitle: "Olvídate de los líos en grupos de mensajería",
            bullets: [
              "Crea partidas en tu pista favorita en solo 10 segundos.",
              "Modo Rey de la Pista 👑: Rotación automática de parejas y cómputo de juegos.",
              "División de gastos: Facilita el pago del alquiler de pista entre los 4.",
              "¿Falta un 4º jugador? BeachMatch notifica a jugadores compatibles al instante.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.calendar,
            tag: "PESTAÑA 4 · TORNEOS",
            title: "Torneos & Marcador BeachScore 🏆",
            subtitle: "Del circuito amateur al profesional",
            bullets: [
              "Calendario oficial: Filtra por categorías y fechas de competición.",
              "SOS Compañero 🚨: Encuentra pareja para competir en tus torneos.",
              "BeachScore ⚖️: Marcador en vivo a pie de pista para arbitraje punto a punto.",
              "Cuadros en vivo: Sigue los resultados de cada ronda en tiempo real.",
            ],
          ),
          const TutorialItem(
            icon: Icons.person_rounded,
            tag: "PESTAÑA 5 · PERFIL & SOPORTE",
            title: "Perfil de Jugador & Soporte 💬",
            subtitle: "Tu ficha deportiva y ayuda directa",
            bullets: [
              "Configura tu categoría, número de licencia y club habitual.",
              "Historial de juego: Consulta victorias, porcentaje de éxito y progreso.",
              "Chat de Soporte Oficial 💬: Escríbenos en el chat de la app para cualquier duda.",
              "¡Invita a tus compañeros de arena a sumarse al BeachMatch!",
            ],
          ),
        ];

      case 'it':
        return [
          const TutorialItem(
            icon: Icons.sports_tennis_rounded,
            tag: "👋 BENVENUTO/A",
            title: "BeachMatch Italia ☀️",
            subtitle: "La community n°1 di Beach Tennis",
            bullets: [
              "Benvenuto/a nella app definitiva per giocare e competere a Beach Tennis.",
              "Trova campi liberi sulla spiaggia e circoli ufficiali in tutta Italia.",
              "Connettiti con compagni del tuo livello e organizza sfide in pochi secondi.",
              "Segui il calendario tornei FITP e il circuito mondiale ITF.",
            ],
          ),
          const TutorialItem(
            icon: Icons.home_rounded,
            tag: "SCHEDA 1 · HOME",
            title: "Feed Live & Attività 🏠",
            subtitle: "Tutto quello che succede sulla sabbia",
            bullets: [
              "Stato 'Cerca compagno': Attivalo per ricevere inviti alle partite.",
              "Partite del giorno: Scopri le sfide programmate vicino a te.",
              "Scorciatoie rapide: Crea un match o trova giocatori con 1 tocco.",
              "Feed social: Foto, risultati e novità del tuo circolo.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.map_fill,
            tag: "SCHEDA 2 · MAPPA",
            title: "Mappa Campi & Meteo Vento Live 🏖️",
            subtitle: "Centinaia di campi sulla sabbia",
            bullets: [
              "Geolocalizzazione GPS precisa: Campi liberi e circoli attrezzati.",
              "Vento in tempo reale: Controlla la velocità del vento (nodi) prima di andare.",
              "Itinerario diretto con Waze o Google Maps in un clic.",
              "Dettagli campi: Illuminazione, docce e qualità della sabbia.",
            ],
          ),
          const TutorialItem(
            icon: Icons.groups_rounded,
            tag: "SCHEDA 3 · PARTITE",
            title: "Organizza Partite & Re della Spiaggia 🎾",
            subtitle: "Basta con i messaggi infiniti nelle chat di gruppo",
            bullets: [
              "Organizza le tue partite in 10 secondi sul tuo campo preferito.",
              "Modalità Re della Spiaggia 👑: Rotazione automatica delle coppie e calcolo game.",
              "Divisione quote campo facile e immediata tra i 4 partecipanti.",
              "Manca il 4° giocatore? Notifica automatica ai giocatori di pari livello.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.calendar,
            tag: "SCHEDA 4 · TORNEI",
            title: "Tornei FITP, ITF & BeachScore 🏆",
            subtitle: "Dall'amatoriale al circuito Pro",
            bullets: [
              "Calendario ufficiale: Filtra per categorie e date.",
              "SOS Compagno 🚨: Trova un partner di doppio per i prossimi tornei.",
              "BeachScore ⚖️: Segnapunti live a bordo campo con tie-break e statistiche.",
              "Tabelloni live: Segui i risultati dei match punto per punto.",
            ],
          ),
          const TutorialItem(
            icon: Icons.person_rounded,
            tag: "SCHEDA 5 · PROFILO & SUPPORTO",
            title: "Profilo Giocatore & Supporto Ufficiale 💬",
            subtitle: "La tua scheda e assistenza rapida",
            bullets: [
              "Imposta la tua classifica, tessera federale e circolo di allenamento.",
              "Storico match: Vittorie, percentuale di successo e crescita del livello.",
              "Chat con il Supporto Ufficiale 💬: Scrivici quando vuoi per qualsiasi aiuto.",
              "Condividi l'app con i tuoi compagni di spiaggia!",
            ],
          ),
        ];

      case 'fr':
      default:
        return [
          const TutorialItem(
            icon: Icons.sports_tennis_rounded,
            tag: "👋 BIENVENUE",
            title: "BeachMatch France ☀️",
            subtitle: "La plateforme n°1 des passionnés de Beach Tennis",
            bullets: [
              "Bienvenue sur l'application incontournable pour jouer et progresser.",
              "Trouvez tous les terrains sur sable et clubs officiels en France et Outre-Mer.",
              "Connectez-vous avec des partenaires de votre niveau en quelques secondes.",
              "Suivez les tournois homologués FFT (BT 25 à BT 2000) et le circuit ITF.",
            ],
          ),
          const TutorialItem(
            icon: Icons.home_rounded,
            tag: "ONGLET 1 · ACCUEIL",
            title: "Fil d'Actualités & Matchs du Jour 🏠",
            subtitle: "Toute l'effervescence du sable en temps réel",
            bullets: [
              "Statut 'Recherche un partenaire' : Activez-le pour être invité à jouer aujourd'hui.",
              "Matchs du jour : Rejoignez les parties organisées près de chez vous.",
              "Raccourcis instantanés : Créez une partie ou trouvez des joueurs en 1 clic.",
              "Fil communautaire : Partagez vos photos, scores et actus de clubs.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.map_fill,
            tag: "ONGLET 2 · CARTE & SPOTS",
            title: "Carte des Terrains & Météo Vent 🏖️",
            subtitle: "Des centaines de terrains sur le sable",
            bullets: [
              "Localisation GPS précise : Terrains gratuits en bord de mer et clubs éclairés.",
              "Météo marine en direct : Vent en nœuds et température avant de chausser vos chaussettes de plage.",
              "Itinéraire direct vers le spot via Waze ou Google Maps.",
              "Informations complètes : Filets en place, éclairage nocturne et sable.",
            ],
          ),
          const TutorialItem(
            icon: Icons.groups_rounded,
            tag: "ONGLET 3 · MATCHS",
            title: "Organisez vos Matchs & Roi du Terrain 🎾",
            subtitle: "Fini les discussions interminables sur les groupes de messagerie",
            bullets: [
              "Planifiez une partie sur votre spot en 10 secondes chrono.",
              "Mode Roi du Terrain 👑 : Rotation automatique des paires et calcul des jeux.",
              "Partage des frais de location de terrain transparent entre les 4 joueurs.",
              "Il manque un 4ème ? BeachMatch alerte automatiquement les joueurs du même niveau.",
            ],
          ),
          const TutorialItem(
            icon: CupertinoIcons.calendar,
            tag: "ONGLET 4 · TOURNOIS",
            title: "Tournois Homologués & BeachScore 🏆",
            subtitle: "Du BT 25 au circuit professionnel ITF",
            bullets: [
              "Calendrier FFT & ITF : Filtrez par catégorie de tournoi et par région.",
              "SOS Partenaire 🚨 : Trouvez un binôme pour vous inscrire en tournoi.",
              "BeachScore ⚖️ : Feuille de match et arbitrage en direct point par point au filet.",
              "Tableaux en direct : Suivez l'avancement des rencontres en temps réel.",
            ],
          ),
          const TutorialItem(
            icon: Icons.person_rounded,
            tag: "ONGLET 5 · PROFIL & SUPPORT",
            title: "Votre Profil Joueur & Support Officiel 💬",
            subtitle: "Votre passeport sportif et écoute permanente",
            bullets: [
              "Indiquez votre classement FFT officiel, numéro de licence et club habituel.",
              "Statistiques & Historique : Suivez votre ratio de victoires et vos progrès.",
              "Chat Support Officiel 💬 : Écrivez-nous à tout moment dans le chat pour la moindre question.",
              "Partagez l'application avec vos partenaires d'entraînement !",
            ],
          ),
        ];
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeTutorial({bool openProfileEdit = false}) async {
    try {
      if (widget.isReplay) {
        if (mounted) Navigator.of(context).pop();
      } else {
        await context.read<AppState>().markTutorialAsSeen();
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }

      if (openProfileEdit && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
        );
      }
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

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = _detectLanguage(context);
    final pages = _getLocalizedPages(lang);
    final isBrazilian = lang == 'pt';

    final guideTitle = lang == 'pt'
        ? "Tour BeachMatch 🇧🇷"
        : (lang == 'es'
            ? "Guía BeachMatch"
            : (lang == 'it'
                ? "Guida BeachMatch"
                : (lang == 'en' ? "BeachMatch Tour" : "Guide BeachMatch")));

    final skipLabel = widget.isReplay
        ? (lang == 'pt' ? "Fechar" : (lang == 'en' ? "Close" : "Fermer"))
        : (lang == 'pt' ? "Pular" : (lang == 'es' ? "Saltar" : (lang == 'it' ? "Salta" : (lang == 'en' ? "Skip" : "Passer"))));

    final nextLabel = lang == 'pt'
        ? "Avançar"
        : (lang == 'es'
            ? "Siguiente"
            : (lang == 'it' ? "Avanti" : (lang == 'en' ? "Next" : "Suivant")));

    final backLabel = lang == 'pt'
        ? "Voltar"
        : (lang == 'es'
            ? "Volver"
            : (lang == 'it' ? "Indietro" : (lang == 'en' ? "Back" : "Retour")));

    final startLabel = lang == 'pt'
        ? "Começar a Jogar! 🚀"
        : (lang == 'es'
            ? "¡Vamos a Jugar! 🚀"
            : (lang == 'it'
                ? "Inizia a Giocare! 🚀"
                : (lang == 'en' ? "Start Playing! 🚀" : "C'est parti ! 🚀")));

    final configProfileLabel = lang == 'pt'
        ? "Configurar Categoria CBT 🇧🇷"
        : (lang == 'en' ? "Edit Player Profile 🎾" : "Compléter mon Profil 🎾");

    final isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image with dark overlay
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
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
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.78),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar with branding & Skip/Close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sports_tennis, color: AppColors.gold, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              guideTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _completeTutorial(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(widget.isReplay ? Icons.close_rounded : Icons.fast_forward_rounded, size: 16),
                        label: Text(skipLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Glass Icon Container with Glow
                            ClipRRect(
                              borderRadius: BorderRadius.circular(38),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.gold.withValues(alpha: 0.7),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold.withValues(alpha: 0.35),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    page.icon,
                                    size: 46,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Glass Card with Content
                            ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F1B29).withValues(alpha: 0.82),
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        blurRadius: 25,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Tab Tag Badge
                                      Align(
                                        alignment: Alignment.center,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                          ),
                                          child: Text(
                                            page.tag,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Title
                                      Text(
                                        page.title,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),

                                      // Subtitle
                                      Text(
                                        page.subtitle,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.coral,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),

                                      // Bullets
                                      ...page.bullets.map((bullet) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 10.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(top: 3),
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.gold,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  bullet,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    height: 1.42,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
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

                // Indicators & Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
                  child: Column(
                    children: [
                      // Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: _currentPage == index ? 24 : 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? AppColors.gold : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bottom buttons row
                      if (isLastPage) ...[
                        if (isBrazilian) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => _completeTutorial(openProfileEdit: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF009C3B), // Green Brazil
                                foregroundColor: Colors.white,
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.badge_outlined, size: 20),
                              label: Text(
                                configProfileLabel,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => _completeTutorial(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.coral,
                              foregroundColor: Colors.white,
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              startLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            if (_currentPage > 0) ...[
                              SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: _prevPage,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                                  label: Text(backLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () => _nextPage(pages.length),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.coral,
                                    foregroundColor: Colors.white,
                                    elevation: 6,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  label: Text(
                                    nextLabel,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  iconAlignment: IconAlignment.end,
                                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
