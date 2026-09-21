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
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF0F172A),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.gold,
              indicatorWeight: 3,
              labelColor: AppColors.gold,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.schedule_rounded, size: 16),
                  text: "Programme",
                ),
                Tab(
                  icon: Icon(Icons.live_tv_rounded, size: 16),
                  text: "En Direct",
                ),
                Tab(
                  icon: Icon(Icons.emoji_events_rounded, size: 16),
                  text: "Résultats",
                ),
              ],
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
    final winner = m['winner'] as int?;

    final set1 = m['set1'] as String?;
    final set2 = m['set2'] as String?;
    final set3 = m['set3'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: type == 'LIVE'
              ? Colors.redAccent.withValues(alpha: 0.7)
              : (type == 'FINISHED' ? AppColors.gold.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.15)),
          width: type == 'LIVE' ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: type == 'LIVE' ? Colors.redAccent.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête Tournoi & Tour
                Row(
                  children: [
                    Text(countryFlag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tourneyName,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "$category · $court",
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: type == 'LIVE'
                            ? Colors.redAccent.withValues(alpha: 0.2)
                            : (type == 'FINISHED' ? AppColors.gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        round,
                        style: TextStyle(
                          color: type == 'LIVE' ? Colors.redAccent : (type == 'FINISHED' ? AppColors.gold : Colors.white70),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(color: Colors.white12, height: 20),

                // Tableau des scores (style scoreboard)
                if (set1 != null) ...[
                  // En-tête colonnes
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      _buildSetHeader('S1'),
                      if (set2 != null) const SizedBox(width: 6),
                      if (set2 != null) _buildSetHeader('S2'),
                      if (set3 != null) const SizedBox(width: 6),
                      if (set3 != null) _buildSetHeader('STB'),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                _buildTeamRow(
                  name: team1,
                  isWinner: winner == 1,
                  sets: [
                    if (set1 != null) set1.split('/').first,
                    if (set2 != null) set2.split('/').first,
                    if (set3 != null) set3.split('/').first,
                  ],
                ),
                const SizedBox(height: 6),
                _buildTeamRow(
                  name: team2,
                  isWinner: winner == 2,
                  sets: [
                    if (set1 != null && set1.contains('/')) set1.split('/').last,
                    if (set2 != null && set2.contains('/')) set2.split('/').last,
                    if (set3 != null && set3.contains('/')) set3.split('/').last,
                  ],
                ),

                // Pied de carte : Horaire ou Bouton Streaming
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge Statut
                    if (type == 'SCHEDULED')
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: AppColors.gold),
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
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "EN DIRECT SUR LE COURT",
                            style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    else
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 14, color: Colors.white54),
                          SizedBox(width: 6),
                          Text(
                            "Match Terminé",
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),

                    // Bouton Direct Vidéo (Si stream disponible)
                    if (streamUrl != null && streamUrl.isNotEmpty)
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _openStream(streamUrl);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFD32F2F)]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                "Direct Vidéo HD",
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _buildSetHeader(String label) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTeamRow({
    required String name,
    required bool isWinner,
    List<String> sets = const [],
  }) {
    return Row(
      children: [
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 16),
          )
        else
          const SizedBox(width: 22),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: isWinner ? AppColors.gold : Colors.white,
              fontSize: 14,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...sets.map((score) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Container(
            width: 32,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isWinner
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              score,
              style: TextStyle(
                color: isWinner ? AppColors.gold : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        )),
      ],
    );
  }
}
