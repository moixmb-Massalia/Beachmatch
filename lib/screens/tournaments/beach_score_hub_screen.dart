import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/colors.dart';
import '../../services/sound_service.dart';
import '../../services/whatsapp_share_service.dart';
import 'quick_scoreboard_screen.dart';

/// 🏆 Écran Officiel BeachScore World Tour Puissance 1000
/// Cycle de vie dynamique 100% temporel & multi-sources :
/// - ⏳ Programme (À Venir) : Matchs futurs avec horaires et courts officiels.
/// - 🔴 En Direct & Vidéos : Matchs en cours avec flux vidéo officiel (PlayBT / ITF / FFT).
/// - 🏆 Résultats & Palmarès : Matchs terminés avec scores certifiés, vainqueurs et stats.
/// - 🌐 Portails Fédéraux : ITF, FFT Ten'Up, FITP, CBT, RFET.
/// - 📺 Chaînes YouTube : @PlayBT, @ITFBeachTennisOfficial, @FFTennis, @SuperTennisTV.
class BeachScoreHubScreen extends StatefulWidget {
  final bool isEmbedded;
  const BeachScoreHubScreen({super.key, this.isEmbedded = false});

  @override
  State<BeachScoreHubScreen> createState() => _BeachScoreHubScreenState();
}

class _BeachScoreHubScreenState extends State<BeachScoreHubScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _selectedCategory = 'ALL'; // 'ALL', 'HOMMES', 'FEMMES', 'MIXTES'
  bool _hasAutoSelectedTab = false;

  void _checkAutoTabSelection(int liveCount, int scheduledCount, int finishedCount) {
    if (_hasAutoSelectedTab) return;
    if (liveCount == 0 && scheduledCount == 0 && finishedCount == 0) return;
    _hasAutoSelectedTab = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (liveCount > 0) {
        _tabController.animateTo(1); // En Direct si match live actif
      } else {
        _tabController.animateTo(0); // Par défaut toujours sur Résultats
      }
    });
  }

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

    // Default country filter is ALL to guarantee immediate match visibility on launch
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// ⏱️ Résolution dynamique et infaillible du statut du match basée sur l'horloge réelle
  static String resolveMatchStatus(Map<String, dynamic> m) {
    final explicitStatus = (m['status'] as String? ?? '').toUpperCase();
    if (explicitStatus == 'LIVE') return 'LIVE';

    // 🏆 Tout match avec un score valide ou un vainqueur désigné est TOUJOURS TERMINÉ
    final rawScore = (m['score']?.toString() ?? '').trim();
    final hasValidScore = rawScore.isNotEmpty &&
        rawScore != 'None' &&
        rawScore != 'null' &&
        !rawScore.toUpperCase().contains('EXEMPT') &&
        !rawScore.toUpperCase().contains('BYE');
    final hasValidSets = (m['set1'] != null && m['set1'].toString().trim().isNotEmpty && m['set1'].toString() != 'None');
    if (explicitStatus == 'FINISHED' || m['winner'] != null || hasValidScore || hasValidSets) {
      return 'FINISHED';
    }

    if (explicitStatus == 'SCHEDULED') return 'SCHEDULED';

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

    return 'SCHEDULED';
  }

  static String formatRound(String? rawRound, {bool isBr = false}) {
    if (rawRound == null || rawRound.trim().isEmpty) return isBr ? 'Partida Oficial' : 'Match Officiel';
    final r = rawRound.trim().toLowerCase();
    if (r.contains('1/32') || r.contains('r64') || r.contains('32e') || r.contains('32ème')) {
      return isBr ? '1/32 de Final' : '1/32 de Finale';
    }
    if (r.contains('1/16') || r.contains('r32') || r.contains('16e') || r.contains('16ème')) {
      return isBr ? '1/16 de Final' : '1/16 de Finale';
    }
    if (r.contains('1/8') || r.contains('r16') || r.contains('huitième') || r.contains('oitava')) {
      return isBr ? 'Oitavas de Final' : '1/8 de Finale';
    }
    if (r.contains('1/4') || r.contains('qf') || r.contains('quart')) {
      return isBr ? 'Quartas de Final' : 'Quart de Finale';
    }
    if (r.contains('1/2') || r.contains('sf') || r.contains('demi') || r.contains('semi')) {
      return isBr ? 'Semifinal' : 'Demi-Finale';
    }
    if (r.contains('3e') || r.contains('petite') || r.contains('terceiro')) {
      return isBr ? '3º Lugar' : '3e Place';
    }
    if (r.contains('poule') || r.contains('grupo') || r.contains('pool')) {
      return isBr ? 'Fase de Grupos' : 'Poules';
    }
    // Ne qualifier de "Finale" que si le libellé ne contient pas de préfixe de tour intermédiaire
    if (r == 'final' || r == 'finale' || r == 'final 🏆' || r == 'finale 🏆' || r.startsWith('final') || r.startsWith('finale')) {
      return isBr ? 'Final' : 'Finale';
    }
    return rawRound.trim();
  }

  String _formatMatchSchedule(Map<String, dynamic> m, {bool isBr = false}) {
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
          prefix = isBr ? "Hoje" : "Aujourd'hui";
        } else if (diff == 1) {
          prefix = isBr ? "Amanhã" : "Demain";
        } else if (diff > 1 && diff <= 6) {
          final days = isBr
              ? ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo']
              : ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
          prefix = days[d.weekday - 1];
        } else {
          prefix = "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";
        }

        return timeStr.isNotEmpty ? (isBr ? "$prefix às $timeStr" : "$prefix à $timeStr") : prefix;
      }
    } catch (_) {}
    return "$dateStr $timeStr".trim();
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _shareMatch(Map<String, dynamic> m, Map<String, dynamic> t) {
    HapticFeedback.lightImpact();
    final isBr = context.read<AppState>().currentUser?.isBrazilian == true;
    final tourneyName = (t['name'] as String?) ?? (isBr ? 'Torneio de Beach Tennis' : 'Tournoi Beach Tennis');
    final city = (t['city'] as String?) ?? '';
    final round = formatRound(m['round'] as String?, isBr: isBr);
    final team1 = (m['team1'] as String?) ?? (isBr ? 'Dupla 1' : 'Paire 1');
    final team2 = (m['team2'] as String?) ?? (isBr ? 'Dupla 2' : 'Paire 2');
    final score = (m['score'] as String?) ?? '';
    final date = _formatMatchSchedule(m, isBr: isBr);

    final buffer = StringBuffer();
    buffer.writeln(isBr ? "🎾 *BeachScore Oficial* 🏖️" : "🎾 *BeachScore Officiel* 🏖️");
    buffer.writeln("🏆 *$tourneyName* ${city.isNotEmpty ? '($city)' : ''}");
    buffer.writeln("📍 $round");
    buffer.writeln("");
    buffer.writeln("⚡ *$team1* vs *$team2*");
    if (score.isNotEmpty) {
      buffer.writeln(isBr ? "📊 *Placar confirmado :* $score" : "📊 *Score certifié :* $score");
    } else {
      buffer.writeln(isBr ? "⏰ *Início :* $date" : "⏰ *Coup d'envoi :* $date");
    }
    buffer.writeln("");
    buffer.writeln(isBr ? "📲 Acompanhe todos os placares ao vivo no BeachMatch !" : "📲 Retrouve tous les scores en direct sur BeachMatch !");

    WhatsAppShareService.shareToWhatsAppOrNative(
      text: buffer.toString(),
      subject: "Score Beach Tennis : $tourneyName",
    );
  }

  /// 🌐 Modale Complète : Portails Fédéraux & Chaînes Officielles YouTube
  void _showFederationsAndChannelsSheet(BuildContext context) {
    final isBr = context.read<AppState>().currentUser?.isBrazilian == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.language_rounded, color: AppColors.gold, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBr ? "Portais & Canais Oficiais" : "Portails & Chaînes Officielles",
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            isBr 
                                ? "Todos os canais oficiais do Beach Tennis mundial" 
                                : "Tous les canaux officiels du Beach Tennis mondial",
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      isBr ? "🌐 SITES DAS FEDERAÇÕES OFICIAIS" : "🌐 SITES DES FÉDÉRATIONS OFFICIELLES",
                      style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 12),
                    _buildPortalTile(
                      flag: "🌍",
                      title: "ITF Beach Tennis World Tour",
                      subtitle: "Classements mondiaux, calendrier officiel & règlements",
                      url: "https://www.itftennis.com/en/itf-tours/beach-tennis-tour/",
                      accentColor: Colors.blueAccent,
                    ),
                    _buildPortalTile(
                      flag: "🇫🇷",
                      title: "FFT Ten'Up (France & Outre-mer)",
                      subtitle: "Tournois BT 2000 / BT 1000 et classements nationaux",
                      url: "https://tenup.fft.fr",
                      accentColor: Colors.redAccent,
                    ),
                    _buildPortalTile(
                      flag: "🇮🇹",
                      title: "FITP Beach Tennis (Italie)",
                      subtitle: "Circuit italien, championnats d'Italie & calendrier FITP",
                      url: "https://www.federtennis.it/beach-tennis",
                      accentColor: Colors.greenAccent,
                    ),
                    _buildPortalTile(
                      flag: "🇧🇷",
                      title: "CBT Beach Tennis (Brésil)",
                      subtitle: "Circuito Brasileiro, Sand Series Brésil & classements CBT",
                      url: "https://www.cbtenis.com.br",
                      accentColor: Colors.amberAccent,
                    ),
                    _buildPortalTile(
                      flag: "🇪🇸",
                      title: "RFET Tenis Playa (Espagne)",
                      subtitle: "Circuito Nacional MAPFRE et championnats d'Espagne",
                      url: "https://www.rfet.es",
                      accentColor: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isBr 
                          ? "📺 CANAIS OFICIAIS YOUTUBE (AO VIVO & REPLAYS HD)" 
                          : "📺 CHAÎNES OFFICIELLES YOUTUBE (LIVES & REPLAYS HD)",
                      style: const TextStyle(color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 12),
                    _buildPortalTile(
                      icon: Icons.play_circle_fill_rounded,
                      title: "PlayBT Brasil",
                      subtitle: "N°1 mondial des directs, Sand Series & tournois majeurs",
                      url: "https://www.youtube.com/@PlayBT",
                      accentColor: Colors.redAccent,
                    ),
                    _buildPortalTile(
                      icon: Icons.live_tv_rounded,
                      title: "ITF Beach Tennis Official",
                      subtitle: "Finales mondiales, résumés officiels & highlights",
                      url: "https://www.youtube.com/@ITFBeachTennisOfficial",
                      accentColor: Colors.redAccent,
                    ),
                    _buildPortalTile(
                      icon: Icons.tv_rounded,
                      title: "FFTennis TV",
                      subtitle: "Championnats de France, Open de Palavas & BT 2000",
                      url: "https://www.youtube.com/@FFTennis",
                      accentColor: Colors.blueAccent,
                    ),
                    _buildPortalTile(
                      icon: Icons.videocam_rounded,
                      title: "SuperTennis TV (Italie)",
                      subtitle: "Diffusions des tournois majeurs italiens & AIBT",
                      url: "https://www.youtube.com/@SuperTennisTV",
                      accentColor: Colors.greenAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortalTile({
    String? flag,
    IconData? icon,
    required String title,
    required String subtitle,
    required String url,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.4)),
          ),
          child: flag != null
              ? Text(flag, style: const TextStyle(fontSize: 20))
              : Icon(icon ?? Icons.link_rounded, color: accentColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
        onTap: () {
          HapticFeedback.selectionClick();
          _openUrl(url);
        },
      ),
    );
  }

  void _triggerRefresh() {
    final isBr = context.read<AppState>().currentUser?.isBrazilian == true;
    HapticFeedback.mediumImpact();
    SoundService.playRacketPop();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 18),
            const SizedBox(width: 8),
            Text(
              isBr ? "Placares e programação sincronizados !" : "Scores et programmes synchronisés !",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16253B),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildEmbeddedHeader({int? scheduledCount, int? liveCount, int? finishedCount}) {
    final isBr = context.watch<AppState>().currentUser?.isBrazilian == true;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF3B30),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isBr ? "BEACHSCORE PRO" : "BEACHSCORE PRO",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // 🎾 BOUTON MARQUEUR DE SCORE INTERACTIF
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuickScoreboardScreen()),
                  );
                },
                icon: const Icon(Icons.sports_tennis_rounded, size: 14, color: Colors.black),
                label: Text(
                  isBr ? "Marcar Jogo" : "Marqueur Score",
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.language_rounded, color: Colors.white70, size: 20),
                tooltip: isBr ? "Portais & Canais Oficiais" : "Portails & Chaînes Officielles",
                onPressed: () => _showFederationsAndChannelsSheet(context),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.refresh_rounded, color: AppColors.gold, size: 20),
                tooltip: isBr ? "Atualizar" : "Actualiser",
                onPressed: _triggerRefresh,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSubTabBar(
            scheduledCount: scheduledCount,
            liveCount: liveCount,
            finishedCount: finishedCount,
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabBar({int? scheduledCount, int? liveCount, int? finishedCount}) {
    final isBr = context.watch<AppState>().currentUser?.isBrazilian == true;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white24,
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
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        tabs: [
          Tab(
            icon: const Icon(Icons.emoji_events_rounded, size: 15),
            text: isBr
                ? (finishedCount != null ? "Resultados ($finishedCount)" : "Resultados")
                : (finishedCount != null ? "Résultats ($finishedCount)" : "Résultats"),
            iconMargin: const EdgeInsets.only(bottom: 2),
          ),
          Tab(
            icon: const Icon(Icons.live_tv_rounded, size: 15),
            text: isBr
                ? (liveCount != null ? "Ao Vivo ($liveCount)" : "Ao Vivo")
                : (liveCount != null ? "En Direct ($liveCount)" : "En Direct"),
            iconMargin: const EdgeInsets.only(bottom: 2),
          ),
          Tab(
            icon: const Icon(Icons.schedule_rounded, size: 15),
            text: isBr
                ? (scheduledCount != null ? "Programação ($scheduledCount)" : "Programação")
                : (scheduledCount != null ? "Programme ($scheduledCount)" : "Programme"),
            iconMargin: const EdgeInsets.only(bottom: 2),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Stack(
      children: [
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
            stream: FirebaseFirestore.instance.collection('pro_tournaments').snapshots(),
            builder: (context, tournamentsSnap) {
              if (tournamentsSnap.connectionState == ConnectionState.waiting && !tournamentsSnap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.gold));
              }
              return _buildInnerMatchesStream(tournamentsSnap);
            },
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

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
            icon: const Icon(Icons.sports_tennis_rounded, color: AppColors.gold),
            tooltip: "Marqueur de Score / Placar",
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuickScoreboardScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.language_rounded, color: Colors.white70),
            tooltip: "Portails & Chaînes Officielles",
            onPressed: () => _showFederationsAndChannelsSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
            tooltip: "Actualiser les scores",
            onPressed: _triggerRefresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _buildSubTabBar(),
          ),
        ),
      ),
      body: bodyContent,
    );
  }

  Widget _buildInnerMatchesStream(AsyncSnapshot<QuerySnapshot> tournamentsSnap) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pro_matches').limit(100).snapshots(),
      builder: (context, matchesSnap) {
        if (matchesSnap.connectionState == ConnectionState.waiting && !matchesSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }

        final tournaments = tournamentsSnap.hasData && tournamentsSnap.data!.docs.isNotEmpty
            ? tournamentsSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList()
            : <Map<String, dynamic>>[];
        tournaments.sort((a, b) {
          final ordA = (a['order'] as num?)?.toInt() ?? 99;
          final ordB = (b['order'] as num?)?.toInt() ?? 99;
          return ordA.compareTo(ordB);
        });

        final allMatches = matchesSnap.hasData && matchesSnap.data!.docs.isNotEmpty
            ? matchesSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList()
            : <Map<String, dynamic>>[];

        final tourneyMap = {for (var t in tournaments) (t['id']?.toString() ?? ''): t};

        final filteredMatches = allMatches.where((m) {
          final team1 = (m['team1']?.toString() ?? '').trim();
          final team2 = (m['team2']?.toString() ?? '').trim();
          if (team1.isEmpty || team2.isEmpty) return false;
          if (team1.contains('Équipe 1') || team2.contains('Équipe 2')) return false;
          if (team1.contains('Vainqueur') || team2.contains('Vainqueur')) return false;
          if (team1.toUpperCase().contains('EXEMPT') || team2.toUpperCase().contains('EXEMPT')) return false;
          if (team1.toUpperCase().contains('BYE') || team2.toUpperCase().contains('BYE')) return false;

          // 🎾 Filtre par Catégorie Simplifié (Tous, Hommes, Femmes, Mixtes)
          final draw = (m['draw']?.toString() ?? '').toUpperCase();
          final gender = (m['gender']?.toString() ?? '').toUpperCase();
          if (_selectedCategory == 'HOMMES') {
            if (gender != 'M' && draw != 'DH' && draw != 'DM') return false;
          } else if (_selectedCategory == 'FEMMES') {
            if (gender != 'F' && draw != 'DD' && draw != 'DF') return false;
          } else if (_selectedCategory == 'MIXTES') {
            if (gender != 'X' && draw != 'DX') return false;
          }

          final t = tourneyMap[m['tournamentId']] ?? {};
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final team1Low = team1.toLowerCase();
            final team2Low = team2.toLowerCase();
            final tourneyName = (t['name']?.toString() ?? '').toLowerCase();
            final city = (t['city']?.toString() ?? '').toLowerCase();
            final category = (t['category']?.toString() ?? '').toLowerCase();
            if (!team1Low.contains(q) &&
                !team2Low.contains(q) &&
                !tourneyName.contains(q) &&
                !city.contains(q) &&
                !category.contains(q)) {
              return false;
            }
          }

          return true;
        }).toList();

        // 🏆 1. RÉSULTATS HOMOLOGUÉS : UN MATCH TERMINÉ DOIT OBLIGATOIREMENT AVOIR UN VRAI SCORE !
        final finishedMatches = filteredMatches.where((m) {
          final status = resolveMatchStatus(m);
          String s = (m['score']?.toString() ?? '').trim();
          if ((s.isEmpty || s == 'None' || s == 'null') && m['set1'] != null && m['set1'].toString().trim().isNotEmpty) {
            final s1 = m['set1'].toString().trim();
            final s2 = m['set2']?.toString().trim() ?? '';
            final s3 = m['set3']?.toString().trim() ?? '';
            s = [s1, s2, s3].where((x) => x.isNotEmpty && x != 'None').join(' ');
          }
          return status == 'FINISHED' && s.isNotEmpty && s != 'None' && s != 'null' && !s.toUpperCase().contains('EXEMPT');
        }).toList();
        finishedMatches.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));

        // 🔴 2. MATCHS EN DIRECT
        final liveMatches = filteredMatches
            .where((m) => resolveMatchStatus(m) == 'LIVE')
            .toList();

        // 📅 3. PROGRAMME (MATCHS À VENIR)
        final scheduledMatches = filteredMatches
            .where((m) => resolveMatchStatus(m) == 'SCHEDULED')
            .toList();
        scheduledMatches.sort((a, b) => (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString()));

        _checkAutoTabSelection(liveMatches.length, scheduledMatches.length, finishedMatches.length);

        final isBr = Provider.of<AppState>(context, listen: false).currentUser?.isBrazilian ?? false;

        return Column(
          children: [
            if (widget.isEmbedded)
              _buildEmbeddedHeader(
                scheduledCount: scheduledMatches.length,
                liveCount: liveMatches.length,
                finishedCount: finishedMatches.length,
              ),
            _buildFilterBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // TAB 0 : RÉSULTATS HOMOLOGUÉS AVEC SCORES RÉELS
                  _buildMatchesList(
                    matches: finishedMatches,
                    tourneyMap: tourneyMap,
                    emptyIcon: Icons.emoji_events_outlined,
                    emptyTitle: isBr
                        ? "Nenhum resultado registrado para esta categoria"
                        : "Aucun résultat pour cette sélection",
                    emptySubtitle: isBr
                        ? "Selecione 'Todos' ou faça outra busca !"
                        : "Sélectionnez 'Tous les Résultats' ou modifiez votre recherche !",
                    type: 'FINISHED',
                  ),
                  // TAB 1 : EN DIRECT (LIVE)
                  _buildMatchesList(
                    matches: liveMatches,
                    tourneyMap: tourneyMap,
                    emptyIcon: Icons.tv_off_rounded,
                    emptyTitle: isBr
                        ? "Nenhum jogo ao vivo no momento"
                        : "Aucun match en direct actuellement",
                    emptySubtitle: isBr
                        ? "Consulte a aba Resultados para os placares homologados !"
                        : "Consultez l'onglet Résultats pour les scores homologués !",
                    type: 'LIVE',
                    actionButton: ElevatedButton.icon(
                      onPressed: () => _tabController.animateTo(0),
                      icon: const Icon(Icons.emoji_events_rounded, size: 16),
                      label: Text(isBr
                          ? "Ver Resultados Homologados"
                          : "Voir les Résultats Homologués"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  // TAB 2 : PROGRAMME (SCHEDULED)
                  _buildMatchesList(
                    matches: scheduledMatches,
                    tourneyMap: tourneyMap,
                    emptyIcon: Icons.calendar_today_rounded,
                    emptyTitle: isBr
                        ? "Nenhum jogo programado para estes filtros"
                        : "Aucun match à venir pour ces critères",
                    emptySubtitle: isBr
                        ? "Altere a categoria ou busque por outro torneio !"
                        : "Modifiez votre recherche ou sélectionnez une autre catégorie !",
                    type: 'SCHEDULED',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildFilterBar() {
    final isBr = context.watch<AppState>().currentUser?.isBrazilian == true;
    final categories = [
      {'id': 'ALL', 'label': isBr ? '🌍 Todos' : '🌍 Tous les Résultats'},
      {'id': 'HOMMES', 'label': isBr ? '🎾 Masculino (DM)' : '🎾 Hommes (DM)'},
      {'id': 'FEMMES', 'label': isBr ? '🌸 Feminino (DF)' : '🌸 Femmes (DF)'},
      {'id': 'MIXTES', 'label': isBr ? '⚡ Mistas (DX)' : '⚡ Mixtes (DX)'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 🔍 Barre de Recherche Simplifiée & Haute Lisibilité (Joueur, Ville, Tournoi)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF16253B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155), width: 1.2),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: isBr
                      ? "Buscar atleta (Baran, Diaz, Mola...), cidade ou torneio..."
                      : "Rechercher joueur (Gianotti, Diaz, Mateos...), ville ou tournoi...",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 🎾 Rangée Unique de Filtres par Catégorie (Tous, Hommes, Femmes, Mixtes)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat['label']!),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat['id']!),
                    selectedColor: AppColors.gold,
                    backgroundColor: const Color(0xFF1E293B),
                    side: BorderSide(
                      color: isSelected ? AppColors.gold : const Color(0xFF475569),
                      width: isSelected ? 1.6 : 1.2,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // 🌐 Raccourcis Sources Officielles (ITF, CBT, JATs)
          _buildOfficialSourcesShortcuts(),
        ],
      ),
    );
  }

  Widget _buildOfficialSourcesShortcuts() {
    final isBr = context.watch<AppState>().currentUser?.isBrazilian == true;
    final sources = [
      {
        'label': '🌍 ITF World Tour',
        'url': 'https://www.itftennis.com/en/itf-tours/beach-tennis-tour/',
        'color': const Color(0xFF2563EB),
      },
      {
        'label': '🇧🇷 CBT Brasil',
        'url': 'https://tenisintegrado.com.br',
        'color': const Color(0xFFEAB308),
      },
      {
        'label': '📺 PlayBT Ao Vivo',
        'url': 'https://www.youtube.com/@PlayBT',
        'color': const Color(0xFFEF4444),
      },
      {
        'label': '🇫🇷 FFT Ten\'Up',
        'url': 'https://tenup.fft.fr',
        'color': const Color(0xFF3B82F6),
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  isBr ? "Fontes :" : "Sources :",
                  style: const TextStyle(color: AppColors.gold, fontSize: 11.5, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          ...sources.map((s) {
            final label = s['label'] as String;
            final url = s['url'] as String;
            final color = s['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => _openUrl(url),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.7), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_new_rounded, size: 11, color: color),
                    ],
                  ),
                ),
              ),
            );
          }),
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
    final countryFlag = (t['countryFlag'] as String?) ?? (t['flag'] as String?) ?? '🌍';
    final tourneyName = (t['name'] as String?) ?? 'Tournoi International';
    final city = (t['city'] as String?) ?? '';
    final venue = (t['venue'] as String?) ?? '';
    final category = (t['category'] as String?) ?? 'ITF';
    final officialSource = (t['officialSource'] as String?) ?? (t['source'] as String?) ?? 'ITF Beach Tennis World Tour';
    final officialUrl = (t['officialUrl'] as String?) ?? '';
    // Vidéo directe pour les matchs en direct (si flux direct actif)
    final liveStreamUrl = (m['streamUrl'] as String?) ?? (t['streamUrl'] as String?);

    // Replay HD précis pour les matchs terminés (uniquement lien vidéo spécifique, pas une chaîne générale)
    final rawReplay = (m['replayUrl']?.toString()) ?? (m['videoUrl']?.toString()) ?? (m['streamUrl']?.toString());
    final bool isSpecificVideo = rawReplay != null &&
        rawReplay.isNotEmpty &&
        (rawReplay.contains('watch?v=') || rawReplay.contains('youtu.be/') || rawReplay.contains('/video/') || rawReplay.endsWith('.mp4'));
    final isBr = Provider.of<AppState>(context, listen: false).currentUser?.isBrazilian == true;
    final specificReplayUrl = isSpecificVideo ? rawReplay : null;
    final court = (m['court']?.toString()) ?? (isBr ? 'Quadra Central' : 'Court Central');
    final round = formatRound(m['round']?.toString(), isBr: isBr);
    final stats = m['stats'] is Map ? (m['stats'] as Map).cast<String, dynamic>() : null;

    final team1 = (m['team1']?.toString()) ?? 'Paire A';
    final team2 = (m['team2']?.toString()) ?? 'Paire B';
    final rawWinner = (m['winner'] as num?)?.toInt() ?? int.tryParse(m['winner']?.toString() ?? '');

    final set1 = m['set1']?.toString();
    final set2 = m['set2']?.toString();
    final set3 = m['set3']?.toString();

    // Extraction et analyse dynamique des scores
    List<String> rawSets = [set1, set2, set3]
        .where((s) => s != null && s.trim().isNotEmpty)
        .cast<String>()
        .toList();

    // Si pas de sets ou s'ils ne contiennent aucun délimiteur / ou -, regarder m['score']
    if (rawSets.isEmpty || !rawSets.any((s) => s.contains('/') || s.contains('-'))) {
      final generalScore = (m['score'] as String? ?? '').trim();
      if (generalScore.isNotEmpty) {
        rawSets = generalScore
            .split(RegExp(r'[,;\s]+'))
            .where((s) => s.contains('-') || s.contains('/'))
            .toList();
      }
    }

    int setsWon1 = 0;
    int setsWon2 = 0;
    final parsedSets = <Map<String, dynamic>>[];

    for (int i = 0; i < rawSets.length; i++) {
      final s = rawSets[i].trim();
      final delimiter = s.contains('/') ? '/' : (s.contains('-') ? '-' : null);
      if (delimiter == null) continue;
      final parts = s.split(delimiter);
      if (parts.isEmpty) continue;
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
        color: const Color(0xFF141D30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: type == 'LIVE'
              ? const Color(0xFFFF3B30)
              : (type == 'FINISHED'
                  ? AppColors.gold
                  : const Color(0xFF38BDF8)),
          width: type == 'LIVE' ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: type == 'LIVE'
                ? const Color(0xFFFF3B30).withValues(alpha: 0.35)
                : (type == 'FINISHED'
                    ? AppColors.gold.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.5)),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête Tournoi & Tour
            Row(
              children: [
                Text(countryFlag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tourneyName,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${city.isNotEmpty ? '$city · ' : ''}$category · $court",
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (officialSource.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 0.7),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded, size: 9, color: AppColors.gold),
                                  const SizedBox(width: 3),
                                  Text(
                                    officialSource,
                                    style: const TextStyle(color: AppColors.gold, fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            if (officialUrl.isNotEmpty)
                              InkWell(
                                onTap: () => _openUrl(officialUrl),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Fiche officielle",
                                      style: TextStyle(color: Colors.lightBlueAccent, fontSize: 10, decoration: TextDecoration.underline),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.open_in_new_rounded, size: 10, color: Colors.lightBlueAccent),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
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

                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 13, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue,
                          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const Divider(color: Colors.white12, height: 20),

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
                            ps['label']?.toString() ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
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
                      'score': ps['s1']?.toString() ?? '',
                      'isSetWinner': ps['s1Won'] == true,
                    }).toList(),
                    isLive: type == 'LIVE',
                  ),
                  const SizedBox(height: 8),

                  // Ligne Équipe 2
                  _buildScoreboardTeamRow(
                    name: team2,
                    isMatchWinner: effectiveWinner == 2,
                    sets: parsedSets.map((ps) => {
                      'score': ps['s2']?.toString() ?? '',
                      'isSetWinner': ps['s2Won'] == true,
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
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, color: AppColors.gold, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isBr ? "Placar oficial em validação pelo árbitro geral" : "Score officiel en cours de validation par le juge-arbitre",
                            style: const TextStyle(color: AppColors.gold, fontSize: 11.5, fontWeight: FontWeight.bold),
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

                // 📊 Statistiques de match (si disponibles)
                if (stats != null && stats.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (stats['duration'] != null) ...[
                          const Icon(Icons.timer_outlined, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(stats['duration'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 10),
                        ],
                        if (stats['aces'] != null) ...[
                          const Icon(Icons.flash_on_rounded, size: 12, color: AppColors.gold),
                          const SizedBox(width: 4),
                          Text("Aces: ${stats['aces']}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 10),
                        ],
                        if (stats['breakPoints'] != null) ...[
                          const Icon(Icons.sports_tennis_rounded, size: 12, color: AppColors.coral),
                          const SizedBox(width: 4),
                          Text("Breaks: ${stats['breakPoints']}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                ],

                // Pied de carte : Horaire/Statut + Actions (Vidéo, Fédé, Partage)
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
                            _formatMatchSchedule(m, isBr: isBr),
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
                          Text(
                            isBr ? "AO VIVO NA QUADRA" : "EN DIRECT SUR LE COURT",
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.w900),
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
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  winnerName != null
                                      ? (isBr ? "Vencedores : $winnerName" : "Vainqueur : $winnerName")
                                      : (isBr ? "Placar Confirmado" : "Score Certifié"),
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

                    // Actions rapides : Direct HD (si match en direct), Replay HD (si match terminé avec vidéo précise), Partager WhatsApp
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔴 1. Bouton Vidéo Direct (UNIQUEMENT pour match en cours avec flux direct)
                        if (type == 'LIVE' && liveStreamUrl != null && liveStreamUrl.isNotEmpty) ...[
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _openUrl(liveStreamUrl);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFD32F2F)]),
                                borderRadius: BorderRadius.circular(8),
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
                                  const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    isBr ? "Ao Vivo HD" : "Direct HD",
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // 🎬 2. Bouton Replay HD (UNIQUEMENT pour match terminé avec résumé vidéo précis)
                        if (type == 'FINISHED' && specificReplayUrl != null && specificReplayUrl.isNotEmpty) ...[
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _openUrl(specificReplayUrl);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.lightBlueAccent.withValues(alpha: 0.3),
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
                                    "Replay HD",
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // 📤 3. Bouton Partager 1-Clic WhatsApp
                        InkWell(
                          onTap: () => _shareMatch(m, t),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.5)),
                            ),
                            child: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 15),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
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
                    fontSize: 14.5,
                    fontWeight: isMatchWinner ? FontWeight.w900 : FontWeight.w700,
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
                    color: AppColors.gold.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.gold, width: 1.0),
                  ),
                  child: const Text(
                    "WIN",
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...sets.map((s) {
          final score = s['score']?.toString() ?? '';
          final isSetWinner = s['isSetWinner'] == true;
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
      width: 38,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: isSetWinner
            ? const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSetWinner
              ? const Color(0xFFFFF080)
              : Colors.white54,
          width: isSetWinner ? 1.5 : 1.2,
        ),
        boxShadow: isSetWinner
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Text(
        score,
        style: TextStyle(
          color: isSetWinner ? Colors.black : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}
