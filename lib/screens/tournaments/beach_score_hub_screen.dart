import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/colors.dart';
import '../../services/sound_service.dart';

/// 🏆 Écran Officiel BeachScore World Tour
/// Cycle de vie dynamique 100% temporel :
/// - ⏳ Programme (À Venir) : Matchs futurs uniquement. Disparaissent automatiquement dès que l'horaire est dépassé.
/// - 🔴 En Direct & Vidéos : Matchs en cours avec flux vidéo officiel (YouTube ITF / PlayBT / FFT).
/// - 🏆 Résultats & Palmarès : Matchs terminés avec scores certifiés et vainqueurs.
class BeachScoreHubScreen extends StatefulWidget {
  const BeachScoreHubScreen({super.key});

  @override
  State<BeachScoreHubScreen> createState() => _BeachScoreHubScreenState();
}

class _BeachScoreHubScreenState extends State<BeachScoreHubScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  String _selectedCountry = 'ALL'; // 'ALL', 'FR', 'IT', 'BR', 'ES', 'RE'
  String _selectedDraw = 'ALL'; // 'ALL', 'DH', 'DD', 'DX'

  final List<Map<String, String>> _countries = [
    {'id': 'ALL', 'label': '🌍 Tous'},
    {'id': 'FR', 'label': '🇫🇷 France'},
    {'id': 'IT', 'label': '🇮🇹 Italie'},
    {'id': 'BR', 'label': '🇧🇷 Brésil'},
    {'id': 'ES', 'label': '🇪🇸 Espagne'},
    {'id': 'RE', 'label': '🇷🇪 Réunion'},
  ];

  final List<Map<String, String>> _draws = [
    {'id': 'ALL', 'label': 'Tous les Tableaux'},
    {'id': 'DH', 'label': 'DH · Double Hommes 👨‍🦱'},
    {'id': 'DD', 'label': 'DD · Double Dames 👩‍🦰'},
    {'id': 'DX', 'label': 'DX · Double Mixte 🤝'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// ⏱️ Résolution dynamique et infaillible du statut du match basée sur l'horloge réelle
  static String resolveMatchStatus(Map<String, dynamic> m) {
    final explicitStatus = (m['status'] as String? ?? '').toUpperCase();
    if (explicitStatus == 'FINISHED' || m['winner'] != null) {
      return 'FINISHED';
    }

    DateTime? scheduledAt;
    if (m['scheduledAt'] is Timestamp) {
      scheduledAt = (m['scheduledAt'] as Timestamp).toDate();
    } else if (m['date'] != null) {
      final dateStr = m['date'].toString();
      final timeStr = m['time']?.toString() ?? '12:00';
      final cleanTime = timeStr.replaceAll('h', ':').replaceAll(RegExp(r'[^0-9:]'), '');
      try {
        final dateParts = dateStr.split('-');
        final timeParts = cleanTime.contains(':') ? cleanTime.split(':') : ['12', '00'];
        if (dateParts.length == 3) {
          scheduledAt = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            int.parse(timeParts[0]),
            timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
          );
        }
      } catch (_) {}
    }

    if (scheduledAt != null) {
      final now = DateTime.now();
      // Match dans le futur -> Toujours À VENIR
      if (now.isBefore(scheduledAt)) {
        return 'SCHEDULED';
      }
      // Match en cours (dans les 2h30 suivant le coup d'envoi) -> EN DIRECT
      if (now.isAfter(scheduledAt) && now.isBefore(scheduledAt.add(const Duration(hours: 2, minutes: 30)))) {
        return 'LIVE';
      }
      // L'horaire est dépassé depuis plus de 2h30 -> Bascule automatiquement en TERMINÉ
      return 'FINISHED';
    }

    if (explicitStatus == 'LIVE') return 'LIVE';
    return 'SCHEDULED';
  }

  static String formatRound(String? rawRound) {
    if (rawRound == null || rawRound.trim().isEmpty) return 'Match Officiel';
    final r = rawRound.trim().toLowerCase();
    if (r.contains('1/32') || r.contains('r64')) return '1/32 de Finale';
    if (r.contains('1/16') || r.contains('r32')) return '1/16 de Finale';
    if (r.contains('1/8') || r.contains('r16')) return '1/8 de Finale';
    if (r.contains('1/4') || r.contains('qf')) return 'Quart de Finale';
    if (r.contains('1/2') || r.contains('sf')) return 'Demi-Finale';
    if (r.contains('final')) return 'Finale 🏆';
    return rawRound.trim();
  }

  String _formatMatchSchedule(Map<String, dynamic> m) {
    final dateStr = m['date'] as String? ?? '';
    final timeStr = m['time'] as String? ?? '';
    if (dateStr.isEmpty) return timeStr;

    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final matchDay = DateTime(d.year, d.month, d.day);
        final diff = matchDay.difference(today).inDays;

        String prefix;
        if (diff == 0) {
          prefix = "Aujourd'hui";
        } else if (diff == 1) {
          prefix = "Demain";
        } else if (diff > 1 && diff <= 6) {
          const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
          prefix = days[d.weekday - 1];
        } else {
          prefix = "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";
        }

        return timeStr.isNotEmpty ? "$prefix à $timeStr" : prefix;
      }
    } catch (_) {}
    return "$dateStr $timeStr".trim();
  }

  Future<void> _openStream(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "BeachScore World Tour",
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                ),
                Text(
                  "Programme, Lives & Palmarès Officiels",
                  style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
            tooltip: "Actualiser les scores",
            onPressed: () {
              HapticFeedback.mediumImpact();
              SoundService.playRacketPop();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 18),
                      SizedBox(width: 8),
                      Text("Scores et programmes synchronisés !", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  backgroundColor: const Color(0xFF16253B),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.2,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [AppColors.gold, Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.40),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.schedule_rounded, size: 15),
                    text: "Programme",
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.live_tv_rounded, size: 15),
                    text: "En Direct",
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.emoji_events_rounded, size: 15),
                    text: "Résultats",
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Immersion Beach Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0A0F1D).withValues(alpha: 0.88),
            ),
          ),

          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('pro_tournaments').orderBy('order').snapshots(),
              builder: (context, tournamentsSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('pro_matches').limit(60).snapshots(),
                  builder: (context, matchesSnap) {
                    final tournaments = tournamentsSnap.hasData && tournamentsSnap.data!.docs.isNotEmpty
                        ? tournamentsSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList()
                        : <Map<String, dynamic>>[];

                    final allMatches = matchesSnap.hasData && matchesSnap.data!.docs.isNotEmpty
                        ? matchesSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList()
                        : <Map<String, dynamic>>[];

                    // Map des tournois par ID pour enrichir les matchs
                    final tourneyMap = {for (var t in tournaments) (t['id'] as String? ?? ''): t};

                    // Filtrer selon Pays et Tableau
                    final filteredMatches = allMatches.where((m) {
                      final t = tourneyMap[m['tournamentId']] ?? {};
                      final country = (t['countryCode'] as String? ?? '').toUpperCase();
                      if (_selectedCountry != 'ALL' && country != _selectedCountry) return false;

                      final draw = (m['draw'] as String? ?? '').toUpperCase();
                      if (_selectedDraw != 'ALL' && draw != _selectedDraw) return false;

                      return true;
                    }).toList();

                    // Répartition dynamique selon le cycle temporel
                    final scheduledMatches = filteredMatches
                        .where((m) => resolveMatchStatus(m) == 'SCHEDULED')
                        .toList();
                    scheduledMatches.sort((a, b) => (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString()));

                    final liveMatches = filteredMatches
                        .where((m) => resolveMatchStatus(m) == 'LIVE')
                        .toList();

                    final finishedMatches = filteredMatches
                        .where((m) => resolveMatchStatus(m) == 'FINISHED')
                        .toList();
                    finishedMatches.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));

                    return Column(
                      children: [
                        _buildFilterBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // 1. ONGLET PROGRAMME (À VENIR)
                              _buildMatchesList(
                                matches: scheduledMatches,
                                tourneyMap: tourneyMap,
                                emptyIcon: Icons.calendar_today_rounded,
                                emptyTitle: "Aucun match à venir pour ces filtres",
                                emptySubtitle: "Sélectionnez un autre pays ou revenez très vite pour les prochaines affiches !",
                                type: 'SCHEDULED',
                              ),

                              // 2. ONGLET EN DIRECT (LIVES)
                              _buildMatchesList(
                                matches: liveMatches,
                                tourneyMap: tourneyMap,
                                emptyIcon: Icons.tv_off_rounded,
                                emptyTitle: "Aucun match en direct actuellement",
                                emptySubtitle: "Consultez l'onglet Programme pour voir les affiches de ce week-end et les horaires des diffusions officielles !",
                                type: 'LIVE',
                                actionButton: ElevatedButton.icon(
                                  onPressed: () => _tabController.animateTo(0),
                                  icon: const Icon(Icons.schedule_rounded, size: 16),
                                  label: const Text("Voir le Programme des Matchs"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),

                              // 3. ONGLET RÉSULTATS (PALMARÈS)
                              _buildMatchesList(
                                matches: finishedMatches,
                                tourneyMap: tourneyMap,
                                emptyIcon: Icons.emoji_events_outlined,
                                emptyTitle: "Aucun résultat enregistré",
                                emptySubtitle: "Les scores des matchs joués apparaîtront ici dès la validation officielle.",
                                type: 'FINISHED',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 🌍 1ère Rangée : Filtre Pays
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _countries.map((c) {
                final isSelected = _selectedCountry == c['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c['label']!),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCountry = c['id']!),
                    selectedColor: AppColors.gold,
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    side: BorderSide(
                      color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.35),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // 🏆 2ème Rangée : Filtre Tableaux (DH, DD, DX)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _draws.map((d) {
                final isSelected = _selectedDraw == d['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(d['label']!),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedDraw = d['id']!),
                    selectedColor: AppColors.coral,
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    side: BorderSide(
                      color: isSelected ? AppColors.coral : Colors.white.withValues(alpha: 0.25),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 11,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesList({
    required List<Map<String, dynamic>> matches,
    required Map<String, dynamic> tourneyMap,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    required String type,
    Widget? actionButton,
  }) {
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 54, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              if (actionButton != null) ...[
                const SizedBox(height: 20),
                actionButton,
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final m = matches[index];
        final t = tourneyMap[m['tournamentId']] ?? {};
        return _buildMatchCard(m, t, type);
      },
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> m, Map<String, dynamic> t, String type) {
    final countryFlag = (t['countryFlag'] as String?) ?? '🌍';
    final tourneyName = (t['name'] as String?) ?? 'Tournoi International';
    final category = (t['category'] as String?) ?? 'ITF';
    final streamUrl = (m['streamUrl'] as String?) ?? (t['streamUrl'] as String?);
    final court = (m['court'] as String?) ?? 'Court Central';
    final round = formatRound(m['round'] as String?);

    final team1 = (m['team1'] as String?) ?? 'Paire A';
    final team2 = (m['team2'] as String?) ?? 'Paire B';
    final rawWinner = m['winner'] as int?;

    final set1 = m['set1'] as String?;
    final set2 = m['set2'] as String?;
    final set3 = m['set3'] as String?;

    // Extraction et analyse dynamique des scores
    final rawSets = [set1, set2, set3].where((s) => s != null && s.isNotEmpty && s.contains('/')).cast<String>().toList();

    int setsWon1 = 0;
    int setsWon2 = 0;
    final parsedSets = <Map<String, dynamic>>[];

    for (int i = 0; i < rawSets.length; i++) {
      final parts = rawSets[i].split('/');
      final s1 = parts[0].trim();
      final s2 = parts.length > 1 ? parts[1].trim() : '';
      final n1 = int.tryParse(s1) ?? 0;
      final n2 = int.tryParse(s2) ?? 0;

      final s1Won = n1 > n2;
      final s2Won = n2 > n1;

      if (s1Won) setsWon1++;
      if (s2Won) setsWon2++;

      final label = i == 0 ? 'S1' : (i == 1 ? 'S2' : (n1 >= 10 || n2 >= 10 ? 'STB' : 'S3'));
      parsedSets.add({
        'label': label,
        's1': s1,
        's2': s2,
        's1Won': s1Won,
        's2Won': s2Won,
      });
    }

    // Déduction intelligente du vainqueur (si absent de la base de données)
    int? effectiveWinner = rawWinner;
    if (effectiveWinner != 1 && effectiveWinner != 2) {
      if (setsWon1 > setsWon2) {
        effectiveWinner = 1;
      } else if (setsWon2 > setsWon1) {
        effectiveWinner = 2;
      }
    }

    final hasScore = parsedSets.isNotEmpty;
    final winnerName = effectiveWinner == 1 ? team1 : (effectiveWinner == 2 ? team2 : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: type == 'LIVE'
              ? Colors.redAccent.withValues(alpha: 0.8)
              : (type == 'FINISHED'
                  ? AppColors.gold.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.18)),
          width: type == 'LIVE' ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: type == 'LIVE'
                ? Colors.redAccent.withValues(alpha: 0.25)
                : (type == 'FINISHED'
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.3)),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête Tournoi & Tour
                Row(
                  children: [
                    Text(countryFlag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tourneyName,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "$category · $court",
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: type == 'LIVE'
                            ? const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFD32F2F)])
                            : (type == 'FINISHED'
                                ? LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.35), AppColors.gold.withValues(alpha: 0.15)])
                                : LinearGradient(colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.08)])),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: type == 'LIVE'
                              ? Colors.redAccent
                              : (type == 'FINISHED' ? AppColors.gold : Colors.white.withValues(alpha: 0.25)),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        round,
                        style: TextStyle(
                          color: type == 'LIVE'
                              ? Colors.white
                              : (type == 'FINISHED' ? AppColors.gold : Colors.white),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(color: Colors.white12, height: 22),

                // TABLEAU DES SCORES
                if (hasScore) ...[
                  // En-tête colonnes S1, S2, STB
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      ...parsedSets.map((ps) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: SizedBox(
                          width: 36,
                          child: Text(
                            ps['label'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Ligne Équipe 1
                  _buildScoreboardTeamRow(
                    name: team1,
                    isMatchWinner: effectiveWinner == 1,
                    sets: parsedSets.map((ps) => {
                      'score': ps['s1'] as String,
                      'isSetWinner': ps['s1Won'] as bool,
                    }).toList(),
                    isLive: type == 'LIVE',
                  ),
                  const SizedBox(height: 8),

                  // Ligne Équipe 2
                  _buildScoreboardTeamRow(
                    name: team2,
                    isMatchWinner: effectiveWinner == 2,
                    sets: parsedSets.map((ps) => {
                      'score': ps['s2'] as String,
                      'isSetWinner': ps['s2Won'] as bool,
                    }).toList(),
                    isLive: type == 'LIVE',
                  ),
                ] else if (type == 'FINISHED') ...[
                  // Match terminé sans score encore homologué
                  _buildScoreboardTeamRow(
                    name: team1,
                    isMatchWinner: effectiveWinner == 1,
                    sets: const [],
                    isLive: false,
                  ),
                  const SizedBox(height: 8),
                  _buildScoreboardTeamRow(
                    name: team2,
                    isMatchWinner: effectiveWinner == 2,
                    sets: const [],
                    isLive: false,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: AppColors.gold, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Score officiel en cours de validation par le juge-arbitre",
                            style: TextStyle(color: AppColors.gold, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Affiche de match programmé
                  _buildScoreboardTeamRow(
                    name: team1,
                    isMatchWinner: false,
                    sets: const [],
                    isLive: false,
                  ),
                  const SizedBox(height: 8),
                  _buildScoreboardTeamRow(
                    name: team2,
                    isMatchWinner: false,
                    sets: const [],
                    isLive: false,
                  ),
                ],

                // Pied de carte : Horaire ou Statut ou Bouton Vidéo
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (type == 'SCHEDULED')
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 15, color: AppColors.gold),
                          const SizedBox(width: 6),
                          Text(
                            _formatMatchSchedule(m),
                            style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    else if (type == 'LIVE')
                      Row(
                        children: [
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            "EN DIRECT SUR LE COURT",
                            style: TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      )
                    else
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.gold.withValues(alpha: 0.22),
                                AppColors.gold.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.gold),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  winnerName != null
                                      ? "Vainqueur : $winnerName"
                                      : "Score Final Homologué",
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Bouton Direct Vidéo / Replay
                    if (streamUrl != null && streamUrl.isNotEmpty)
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _openStream(streamUrl);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFD32F2F)]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                type == 'LIVE' ? "Direct Vidéo HD" : "Replay HD",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
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

  Widget _buildScoreboardTeamRow({
    required String name,
    required bool isMatchWinner,
    required List<Map<String, dynamic>> sets,
    required bool isLive,
  }) {
    return Row(
      children: [
        if (isMatchWinner)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 13),
          )
        else
          Container(
            margin: const EdgeInsets.only(right: 6),
            width: 21,
            height: 21,
            alignment: Alignment.center,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isMatchWinner ? AppColors.gold : Colors.white,
                    fontSize: 13.5,
                    fontWeight: isMatchWinner ? FontWeight.w900 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMatchWinner)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 0.8),
                  ),
                  child: const Text(
                    "WIN",
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...sets.map((s) {
          final score = s['score'] as String;
          final isSetWinner = s['isSetWinner'] as bool;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _buildVibrantScorePill(
              score: score,
              isSetWinner: isSetWinner,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVibrantScorePill({
    required String score,
    required bool isSetWinner,
  }) {
    return Container(
      width: 36,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: isSetWinner
            ? const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.95),
                  const Color(0xFF1E293B).withValues(alpha: 0.90),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSetWinner
              ? const Color(0xFFFFE066)
              : Colors.white.withValues(alpha: 0.25),
          width: isSetWinner ? 1.5 : 1.0,
        ),
        boxShadow: isSetWinner
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Text(
        score,
        style: TextStyle(
          color: isSetWinner ? Colors.black : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}
