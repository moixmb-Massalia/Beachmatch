import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';
import '../widgets/beach_weather_widget.dart';
import '../l10n/app_localizations.dart';
import '../widgets/home_radar_card.dart';
import '../widgets/home_tournament_3d_globe.dart';
import '../services/jat_reminder_service.dart';
import '../widgets/home_weekend_ritual_card.dart';
import '../widgets/feature_discovery_bubble.dart';
import 'create_match_screen.dart';
import 'profile_screen.dart';
import '../widgets/home_fft_licence_banner.dart';
import 'tutorial_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<List<NewsItemModel>> _newsStream;

  @override
  void initState() {
    super.initState();
    _newsStream = NewsService().getNewsStream();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkJatEveReminder();
    });
  }

  void _checkJatEveReminder() {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return;

    final eveTourney = JatReminderService.findEveTournamentForJat(
      tournaments: appState.tournaments,
      user: user,
    );

    if (eveTourney != null && mounted) {
      JatReminderService.showEveReminderBanner(
        context,
        tournament: eveTourney,
        user: user,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final courts = context.watch<AppState>().courts;
    final pos = context.watch<AppState>().currentPosition;
    final tournaments = context.watch<AppState>().tournaments;

    return Scaffold(
      backgroundColor: const Color(0xFF0F141E),
      body: Stack(
        children: [
          // Immersion Beach Background
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
            child: RefreshIndicator(
              color: AppColors.coral,
              backgroundColor: const Color(0xFF1E2638),
              onRefresh: () async {
                await context.read<AppState>().loadData();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                children: [
                  _buildHeader(user),
                  if (user != null && (user.country.toUpperCase() == 'FR' || user.country.toUpperCase() == 'RE' || user.country.toUpperCase() == 'ANT') && (user.licenceNumber == null || user.licenceNumber!.trim().isEmpty)) ...[
                    const SizedBox(height: 14),
                    const HomeFftLicenceBanner(),
                  ],
                  if (user != null && user.isBrazilian && (user.cbtCategory == null || user.cbtCategory!.isEmpty)) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF007A33),
                            Color(0xFF002776),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Text("🇧🇷", style: TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Bem-vindo(a) ao BeachMatch !",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Faça o tour completo de todos os 5 menus do app.",
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TutorialScreen(isReplay: true)),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: const Color(0xFF0F141E),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Ver Tour", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  FeatureDiscoveryBubble(
                    featureKey: 'home_overview',
                    title: (user?.isBrazilian == true || Localizations.localeOf(context).languageCode == 'pt')
                        ? "Bem-vindo ao BeachMatch !"
                        : (Localizations.localeOf(context).languageCode == 'es'
                            ? "¡Bienvenido a BeachMatch!"
                            : (Localizations.localeOf(context).languageCode == 'it'
                                ? "Benvenuto su BeachMatch!"
                                : (Localizations.localeOf(context).languageCode == 'en'
                                    ? "Welcome to BeachMatch!"
                                    : "Bienvenue sur votre Accueil !"))),
                    message: (user?.isBrazilian == true || Localizations.localeOf(context).languageCode == 'pt')
                        ? "Consulte o clima ao vivo, descubra as quadras e partidas perto de você e conecte-se com seus parceiros em um toque."
                        : (Localizations.localeOf(context).languageCode == 'es'
                            ? "Consulta el clima en vivo, descubre pistas y partidos cerca de ti y únete a tus compañeros con un solo toque."
                            : (Localizations.localeOf(context).languageCode == 'it'
                                ? "Controlla il meteo in tempo reale, scopri i campi e le partite vicino a te e unisciti ai tuoi compagni con un tocco."
                                : (Localizations.localeOf(context).languageCode == 'en'
                                    ? "Check real-time beach weather, discover courts and matches nearby, and team up with your partners in one tap."
                                    : "Consultez la météo des plages en direct, découvrez les parties autour de vous et rejoignez vos partenaires en un clic."))),
                    icon: Icons.wb_sunny_rounded,
                    margin: const EdgeInsets.only(top: 14, bottom: 4),
                  ),
                  const SizedBox(height: 14),
                  HomeRadarCard(user: user, courts: courts),
                  const SizedBox(height: 14),
                  const HomeWeekendRitualCard(),
                  const SizedBox(height: 14),
                  HomeTournament3dGlobe(
                    tournaments: tournaments,
                    user: user,
                    userPosition: pos,
                  ),
                  const SizedBox(height: 24),
                  _buildWeatherCard(user, pos),
                  const SizedBox(height: 24),
                  _buildWorldNewsSection(context),
                  const SizedBox(height: 120), // Bottom nav & FAB space
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 95.0),
        child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.coral.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: "home_create_match_fab",
                  backgroundColor: AppColors.coral,
                  tooltip: AppLocalizations.of(context).homeCreateMatchButton,
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateMatchScreen()));
                  },
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
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
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader(user) {
    return _buildGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 2),
                          image: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) 
                              ? DecorationImage(image: NetworkImage(user.photoUrl!), fit: BoxFit.cover) 
                              : null,
                        ),
                        child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                            ? Center(child: Text((user?.displayName != null && user!.displayName.isNotEmpty) ? user.displayName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)))
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: const BoxDecoration(
                            gradient: AppColors.brandGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_rounded, size: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${AppLocalizations.of(context).homeHeaderGreeting} ${(user != null && user.displayName.isNotEmpty) ? user.displayName.split(' ').first : ''} 🎾",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.gold, size: 12),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                user?.location ?? ((user?.isBrazilian == true) ? 'Brasil' : 'France'),
                                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          const SizedBox(width: 8),
          // Bouton évident "Mon Profil"
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.coral, Color(0xFFF97316)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.coral.withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 4),
                  Text(
                    (user?.isBrazilian == true) ? "Meu Perfil" : "Mon Profil",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(UserModel? user, Position? pos) {
    final (lat, lon) = pos != null
        ? (pos.latitude, pos.longitude)
        : getUserCoordinates(user?.location, isBrazilian: user?.isBrazilian == true);
    return BeachWeatherWidget(
      latitude: lat,
      longitude: lon,
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
                Text(AppLocalizations.of(context).homeNewsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(width: 6),
                const Text("🌍", style: TextStyle(fontSize: 18)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.gold, size: 12),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context).homeDirectNews, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
            stream: _newsStream,
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
    String badgeText = AppLocalizations.of(context).homeNewsBadgeDefault;
    IconData badgeIcon = Icons.newspaper;

    if (item.type == NewsType.live) {
      badgeColor = Colors.redAccent;
      badgeText = AppLocalizations.of(context).homeNewsBadgeLive;
      badgeIcon = Icons.live_tv;
    } else if (item.type == NewsType.tutorial) {
      badgeColor = Colors.greenAccent;
      badgeText = AppLocalizations.of(context).homeNewsBadgeTuto;
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
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
                        cacheWidth: 600,
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
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.85),
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
                      color: badgeColor.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: badgeColor.withValues(alpha: 0.5), blurRadius: 15)
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
              color: const Color(0xFF141923).withValues(alpha: 0.95), // Deep dark solid background for maximum contrast
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
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
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
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
                        item.type == NewsType.live ? AppLocalizations.of(context).homeNewsBtnLive : AppLocalizations.of(context).homeNewsBtnTuto,
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

}
