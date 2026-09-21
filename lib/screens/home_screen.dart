import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/match.dart';
import '../models/user.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';
import '../widgets/beach_weather_widget.dart';
import '../l10n/app_localizations.dart';
import '../widgets/home_radar_card.dart';
import '../widgets/home_match_card.dart';
import '../widgets/home_weekend_ritual_card.dart';
import '../widgets/feature_discovery_bubble.dart';
import 'create_match_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = "Tous";
  late final Stream<List<NewsItemModel>> _newsStream;

  @override
  void initState() {
    super.initState();
    _newsStream = NewsService().getNewsStream();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final allMatches = context.watch<AppState>().matches;
    final courts = context.watch<AppState>().courts;
    final pos = context.watch<AppState>().currentPosition;
    
    // Application du filtre sur les parties à venir (exclut les matchs terminés d'hier ou plus vieux)
    final now = DateTime.now();
    final activeMatches = allMatches.where((m) => m.scheduledTime.isAfter(now.subtract(const Duration(hours: 3)))).toList();

    List<MatchModel> matches = activeMatches;
    if (_selectedFilter == "Autour de moi") {
      if (pos != null) {
        // Distance réelle GPS <= 40 km
        final nearbyCourtIds = courts.where((c) {
          final distKm = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            c.latitude,
            c.longitude,
          ) / 1000.0;
          return distKm <= 40.0;
        }).map((c) => c.id).toSet();

        matches = activeMatches.where((m) => nearbyCourtIds.contains(m.courtId)).toList();
      } else if (user != null) {
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
                  const FeatureDiscoveryBubble(
                    featureKey: 'home_overview',
                    title: "Bienvenue sur votre Accueil !",
                    message: "Consultez la météo des plages en direct, découvrez les parties autour de vous et rejoignez vos partenaires en un clic.",
                    icon: Icons.wb_sunny_rounded,
                    margin: EdgeInsets.only(top: 14, bottom: 4),
                  ),
                  const SizedBox(height: 14),
                  HomeRadarCard(user: user, courts: courts),
                  const SizedBox(height: 14),
                  const HomeWeekendRitualCard(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context).homeMatchesTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text("${matches.length} ${AppLocalizations.of(context).homeMatchesLive}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ["Tous", "Autour de moi", "Aujourd'hui", "Niveau 1-4", "Niveau 5+"].map((filter) {
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
                            backgroundColor: Colors.black.withValues(alpha: 0.5),
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
                                color: AppColors.gold.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.sports_tennis, size: 64, color: AppColors.gold),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              AppLocalizations.of(context).homeEmptyStateTitle,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context).homeEmptyStateSubtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateMatchScreen()));
                              },
                              icon: const Icon(Icons.add, size: 20),
                              label: Text(AppLocalizations.of(context).homeCreateMatchButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 8,
                                shadowColor: AppColors.gold.withValues(alpha: 0.5),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ...matches.map((m) => HomeMatchCard(user: user, match: m, courts: courts)),
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
      floatingActionButton: matches.isEmpty
          ? null
          : Padding(
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
                        width: 48,
                        height: 48,
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
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                          child: const Icon(Icons.settings, size: 10, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${AppLocalizations.of(context).homeHeaderGreeting} ${(user != null && user.displayName.isNotEmpty) ? user.displayName.split(' ').first : ''} 🎾", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.gold, size: 13),
                            const SizedBox(width: 4),
                            Expanded(child: Text(user?.location ?? 'Nice, France', style: const TextStyle(fontSize: 12, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context).homeHeaderLevel(user?.level ?? 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
        : getUserCoordinates(user?.location);
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
