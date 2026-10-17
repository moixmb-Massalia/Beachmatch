import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tournament.dart';
import '../../models/club.dart';
import '../../providers/app_state.dart';
import '../clubs/create_tournament_screen.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
import '../../widgets/tournament_live_scores_card.dart';
import '../../models/partner_request.dart';
import '../../services/whatsapp_share_service.dart';
import 'tournament_chat_screen.dart';
import 'tournament_bracket_screen.dart';
import '../../widgets/court_schedule_presets_dialog.dart';
import '../public_profile_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final TournamentModel tournament;

  const TournamentDetailScreen({super.key, required this.tournament});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  bool _isAuthorized = false;
  bool _isCheckingAuth = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    final appUser = context.read<AppState>().currentUser;
    if (appUser?.isAdmin == true) {
      if (mounted) setState(() { _isAuthorized = true; _isCheckingAuth = false; });
      return;
    }

    final authEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim();
    if (authEmail != null && authEmail.isNotEmpty) {
      // SuperAdmin absolu : accès partout sur tous les tournois
      if (authEmail == 'moixmb@gmail.com') {
        if (mounted) setState(() { _isAuthorized = true; _isCheckingAuth = false; });
        return;
      }

      // btvarois@gmail.com : accès UNIQUEMENT aux tournois de son propre club (Beach Tennis Varois) ou à Toulon
      if (authEmail == 'btvarois@gmail.com') {
        final clubLower = widget.tournament.club.toLowerCase().trim();
        final locLower = widget.tournament.location.toLowerCase().trim();
        final nameLower = widget.tournament.name.toLowerCase().trim();
        if (clubLower.contains('varois') || locLower.contains('toulon') || nameLower.contains('toulon')) {
          if (mounted) setState(() { _isAuthorized = true; _isCheckingAuth = false; });
          return;
        }
      }

      // massalbrice@gmail.com : JAT Marana Beach Tennis & Furiani
      if (authEmail == 'massalbrice@gmail.com') {
        final clubLower = widget.tournament.club.toLowerCase().trim();
        final locLower = widget.tournament.location.toLowerCase().trim();
        final nameLower = widget.tournament.name.toLowerCase().trim();
        if (clubLower.contains('marana') || locLower.contains('furiani') || nameLower.contains('marana') || nameLower.contains('furiani') || nameLower.contains('corse')) {
          if (mounted) setState(() { _isAuthorized = true; _isCheckingAuth = false; });
          return;
        }
      }

      // Juge-Arbitre (JAT) officiel assigné au tournoi (par email)
      final jatEmail = widget.tournament.contactEmail?.toLowerCase().trim();
      if (jatEmail != null && jatEmail.isNotEmpty && authEmail == jatEmail) {
        if (mounted) setState(() { _isAuthorized = true; _isCheckingAuth = false; });
        return;
      }

      // Vérifier si le nom du profil connecté correspond au JAT officiel
      final refereeRaw = (widget.tournament.referee ?? '').toLowerCase().replaceAll('(jat)', '').replaceAll('(jae2)', '').replaceAll('(jae1)', '').trim();
      final appUserName = (appUser?.displayName ?? '').toLowerCase().trim();
      final authDisplayName = (FirebaseAuth.instance.currentUser?.displayName ?? '').toLowerCase().trim();
      if (refereeRaw.length >= 4) {
        if ((appUserName.length >= 4 && (refereeRaw.contains(appUserName) || appUserName.contains(refereeRaw))) ||
            (authDisplayName.length >= 4 && (refereeRaw.contains(authDisplayName) || authDisplayName.contains(refereeRaw)))) {
          if (mounted) setState(() { _isAuthorized = true; _isCheckingAuth = false; });
          return;
        }
      }

      try {
        final query = await FirebaseFirestore.instance
            .collection('clubs')
            .where('presidentEmails', arrayContains: authEmail)
            .get();

        for (var doc in query.docs) {
          final clubName = doc.data()['name']?.toString().toLowerCase().trim();
          if (clubName == widget.tournament.club.toLowerCase().trim()) {
            if (mounted) setState(() { _isAuthorized = true; _isCheckingAuth = false; });
            return;
          }
        }
      } catch (e) {
        debugPrint("Error checking auth: $e");
      }
    }

    if (mounted) setState(() { _isAuthorized = false; _isCheckingAuth = false; });
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
    }
  }

  void _shareTournament(TournamentModel tournament) {
    final user = context.read<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || (tournament.country ?? '').toUpperCase() == 'BR';
    WhatsAppShareService.shareTournamentInvite(
      tournamentName: tournament.name,
      dates: tournament.dateString,
      location: "${tournament.location} (${tournament.club})",
      category: tournament.category,
      price: tournament.price,
      phone: tournament.contactPhone,
      tournamentId: tournament.id,
      isBrazilian: isBr,
    );
  }

  void _confirmDelete() {
    final currentEmail = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim();
    if (currentEmail != 'moixmb@gmail.com') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Action réservée à l'administrateur principal (moixmb@gmail.com)."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141923),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text("Supprimer le tournoi ?", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          "Êtes-vous sûr de vouloir supprimer définitivement le tournoi '${widget.tournament.name}' ?",
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              final appState = context.read<AppState>();
              try {
                await FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament.id).delete();
                await appState.loadData();
                messenger.showSnackBar(
                  SnackBar(content: Text("Tournoi '${widget.tournament.name}' supprimé avec succès !"), backgroundColor: Colors.green),
                );
                nav.pop(); // Retour à la liste
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text("Erreur lors de la suppression: $e"), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  void _showCourtScheduleConfigDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CourtSchedulePresetsDialog(
        tournament: widget.tournament,
        isAuthorized: _isAuthorized,
      ),
    );
  }

  Future<void> _openEditScreen() async {
    ClubModel? clubToUse;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('clubs')
          .where('name', isEqualTo: widget.tournament.club)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        clubToUse = ClubModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
      }
    } catch (_) {}

    clubToUse ??= ClubModel(
      id: 'temp',
      name: widget.tournament.club,
      description: '',
      adminId: '',
      memberIds: [],
      location: widget.tournament.location,
      createdAt: DateTime.now(),
    );

    if (!mounted) return;

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTournamentScreen(club: clubToUse!, initialTournament: widget.tournament),
      ),
    );

    if (res == true && mounted) {
      Navigator.pop(context); // Pop back so list refreshes
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPos = context.read<AppState>().currentPosition;

    String locationWithDistance = widget.tournament.location;
    if (userPos != null && widget.tournament.latitude != null && widget.tournament.longitude != null && widget.tournament.latitude != 0.0 && widget.tournament.longitude != 0.0) {
      final distanceInMeters = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        widget.tournament.latitude!,
        widget.tournament.longitude!,
      );
      final km = (distanceInMeters / 1000).round();
      if (km > 0) {
        locationWithDistance = "${widget.tournament.location} (📍 $km km)";
      }
    }

    // Calcul dynamique de l'état temporel & compte à rebours
    String countdownText = "Bientôt";
    Color countdownColor = const Color(0xFF38BDF8);
    final start = widget.tournament.startDate;
    final end = widget.tournament.endDate ?? start;
    final now = DateTime.now();

    if (widget.tournament.isPassed) {
      countdownText = "Terminé";
      countdownColor = Colors.white54;
    } else if (start != null && end != null && now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))) {
      countdownText = "En direct 🔴";
      countdownColor = const Color(0xFFEF4444);
    } else if (start != null) {
      final diffDays = start.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diffDays == 0) {
        countdownText = "Aujourd'hui !";
        countdownColor = const Color(0xFF10B981);
      } else if (diffDays == 1) {
        countdownText = "Demain !";
        countdownColor = AppColors.gold;
      } else if (diffDays > 1) {
        countdownText = "J-$diffDays";
        countdownColor = AppColors.gold;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D14),
      bottomNavigationBar: _buildStickyBottomBar(context),
      body: Stack(
        children: [
          // Fond Signature Sunset / Aerial
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
                    Colors.black.withValues(alpha: 0.45),
                    const Color(0xFF090D14).withValues(alpha: 0.90),
                    const Color(0xFF090D14),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Contenu principal avec AppBar Immersive
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 170.0,
                pinned: true,
                backgroundColor: const Color(0xFF090D14),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  tooltip: "Retour",
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.tournament.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (!_isCheckingAuth && _isAuthorized) ...[
                    if ((FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim() == 'moixmb@gmail.com')
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                        tooltip: "Supprimer le tournoi",
                        onPressed: () => _confirmDeleteTournament(context),
                      ),
                    IconButton(
                      icon: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold, size: 22),
                      tooltip: "Gestion Tournoi",
                      onPressed: () => _showAdminManagementModal(context),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                    tooltip: "Partager sur WhatsApp",
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _shareTournament(widget.tournament);
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/beach_sunset_players_1785052273648.jpg',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF090D14).withValues(alpha: 0.8),
                              const Color(0xFF090D14),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.tournament.category,
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                widget.tournament.dateString,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Profil Instagram Hero Block
                    _buildInstagramHeroHeader(context, locationWithDistance, countdownText, countdownColor),

                    // 1.bis Bannière Reconnaissance JAT (Confirmation 1-Tap)
                    if (!_isCheckingAuth && !_isAuthorized)
                      _buildJatClaimCard(context),

                    // 2. TabBar Instagram (Segmentation - Loi de Hick)
                    _buildInstagramTabBar(),

                    // 3. Contenu de l'onglet sélectionné
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildCurrentTabContent(context, locationWithDistance),
                      ),
                    ),

                    // Espacement pour ne pas être masqué par la bottom bar
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🌟 HERO BLOCK STYLE INSTAGRAM
  Widget _buildInstagramHeroHeader(
    BuildContext context,
    String locationWithDistance,
    String countdownText,
    Color countdownColor,
  ) {
    final category = widget.tournament.category;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne Profil : Avatar Story Ring + Titre + Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar avec Instagram Story Ring
              Container(
                width: 70,
                height: 70,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF59E0B), // Gold
                      Color(0xFFEF4444), // Coral
                      Color(0xFFEC4899), // Pink
                      Color(0xFF8B5CF6), // Purple
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFEF4444),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0F172A),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 20),
                        const SizedBox(height: 1),
                        Text(
                          category.replaceAll(' ', ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Informations Principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.tournament.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Badge Officiel FFT / ITF
                        const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 18),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.location_solid, color: Colors.blueAccent, size: 13),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.tournament.club,
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locationWithDistance,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bandeau Métriques Sociales (Preuve Sociale)
          _buildSocialMetricsBar(countdownText, countdownColor),

          const SizedBox(height: 14),

          // Barre d'Actions Rapides Profil Instagram
          _buildQuickActionBar(context),
        ],
      ),
    );
  }

  /// 📊 BANDEAU MÉTRIQUES SOCIALES (Instagram Stats Bar)
  /// 📊 BANDEAU MÉTRIQUES SOCIALES (Coup d'envoi · Tableaux · Tarif)
  Widget _buildSocialMetricsBar(String countdownText, Color countdownColor) {
    final price = widget.tournament.price != null && widget.tournament.price!.isNotEmpty
        ? widget.tournament.price!
        : "NC";
    final isBr = (widget.tournament.country ?? '').toUpperCase() == 'BR' ||
        context.read<AppState>().currentUser?.isBrazilian == true;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildMetricItem(isBr ? "Início" : "Coup d'envoi", countdownText, Icons.timer_outlined, countdownColor),
          _buildMetricDivider(),
          _buildFormatsMetricItem(isBr),
          _buildMetricDivider(),
          _buildMetricItem(isBr ? "Inscrição" : "Tarif", price, Icons.payments_outlined, AppColors.coral),
        ],
      ),
    );
  }

  Widget _buildFormatsMetricItem(bool isBr) {
    final formats = widget.tournament.formats;
    if (formats.isEmpty) {
      return _buildMetricItem(isBr ? "Chaves" : "Tableau", isBr ? "Duplas" : "Double", Icons.groups_rounded, const Color(0xFF34D399));
    }

    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.groups_rounded, size: 11, color: Color(0xFF34D399)),
              const SizedBox(width: 3),
              Text(
                formats.length > 1 ? (isBr ? "Chaves (${formats.length})" : "Tableaux (${formats.length})") : (isBr ? "Chave" : "Tableau"),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: formats.map((fmt) {
                Color badgeBg;
                Color badgeText;
                if (fmt == 'DH') {
                  badgeBg = const Color(0xFF38BDF8).withValues(alpha: 0.2);
                  badgeText = const Color(0xFF38BDF8);
                } else if (fmt == 'DD') {
                  badgeBg = AppColors.coral.withValues(alpha: 0.2);
                  badgeText = AppColors.coral;
                } else if (fmt == 'DX') {
                  badgeBg = const Color(0xFF34D399).withValues(alpha: 0.2);
                  badgeText = const Color(0xFF34D399);
                } else {
                  badgeBg = Colors.white.withValues(alpha: 0.15);
                  badgeText = Colors.white;
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeText.withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: Text(
                    fmt,
                    style: TextStyle(
                      color: badgeText,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// ⚡ BARRE D'ACTIONS RAPIDES PROFIL INSTAGRAM
  Widget _buildQuickActionBar(BuildContext context) {
    return Row(
      children: [
        // Action 1 : S'inscrire (Gros CTA)
        Expanded(
          flex: 4,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008069), // Vert officiel WhatsApp / Action
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            icon: const Icon(Icons.how_to_reg_rounded, size: 17),
            label: Text(
              ((widget.tournament.country ?? '').toUpperCase() == 'BR' || context.read<AppState>().currentUser?.isBrazilian == true) ? "Inscrições" : "S'inscrire",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () => _showContactJATModal(context),
          ),
        ),
        const SizedBox(width: 8),

        // Action 2 : Salon du Tournoi
        Expanded(
          flex: 3,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
              side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.forum_rounded, size: 16, color: Color(0xFF818CF8)),
            label: Text(
              ((widget.tournament.country ?? '').toUpperCase() == 'BR' || context.read<AppState>().currentUser?.isBrazilian == true) ? "Chat / Resenha" : "Salon",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentChatScreen(tournament: widget.tournament),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),

        // Action 3 : Partage WhatsApp
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.5), width: 1.2),
          ),
          child: IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 19),
            tooltip: "Partager sur WhatsApp",
            onPressed: () {
              HapticFeedback.lightImpact();
              _shareTournament(widget.tournament);
            },
          ),
        ),
      ],
    );
  }

  /// 📑 SÉLECTEUR D'ONGLETS INSTAGRAM (LOI DE HICK)
  Widget _buildInstagramTabBar() {
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || (widget.tournament.country ?? '').toUpperCase() == 'BR';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _buildTabItem(0, Icons.info_outline_rounded, isBr ? "Infos" : "Infos"),
          _buildTabItem(1, Icons.account_tree_rounded, isBr ? "Chaves" : "Tableaux"),
          _buildTabItem(2, Icons.chat_bubble_outline_rounded, isBr ? "Resenha" : "Salon"),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTabIndex = index);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : Colors.white60,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔄 GESTIONNAIRE DU CONTENU DE L'ONGLET ACTIF
  Widget _buildCurrentTabContent(BuildContext context, String locationWithDistance) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildInfosTab(context, locationWithDistance);
      case 1:
        return _buildCompetitionTab(context);
      case 2:
        return _buildChatTab(context);
      default:
        return _buildInfosTab(context, locationWithDistance);
    }
  }

  /// 📋 ONGLET 1 : INFOS & INSCRIPTIONS
  Widget _buildInfosTab(BuildContext context, String locationWithDistance) {
    return Column(
      key: const ValueKey('tab_infos'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Bannière d'urgence (FOMO)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.alarm_on_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "INSCRIPTIONS OUVERTES",
                      style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Pensez à contacter le JAT pour valider l'inscription de votre paire avant la clôture officielle.",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Carte Inscription & Contact JAT Officiel
        _buildRegistrationAndContactCard(context),
        const SizedBox(height: 18),

        // 3. Carte Dates & Localisation
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(CupertinoIcons.calendar, AppLocalizations.of(context).tournamentDetailDates, widget.tournament.dateString),
              if (widget.tournament.address != null) ...[
                const Divider(color: Colors.white12, height: 24),
                _buildInfoRow(CupertinoIcons.map_pin_ellipse, AppLocalizations.of(context).tournamentDetailAddress, widget.tournament.address!),
              ],
              const Divider(color: Colors.white12, height: 24),
              _buildInfoRow(CupertinoIcons.location, AppLocalizations.of(context).tournamentDetailCity, locationWithDistance),
              const SizedBox(height: 14),
              // Bouton Itinéraire GPS
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.08),
                  ),
                  icon: const Icon(CupertinoIcons.map_pin_ellipse, size: 16, color: Colors.blueAccent),
                  label: const Text("Itinéraire GPS (Google Maps / Waze)", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final query = Uri.encodeComponent(
                      widget.tournament.address != null && widget.tournament.address!.isNotEmpty
                          ? "${widget.tournament.address}, ${widget.tournament.location}"
                          : "${widget.tournament.club}, ${widget.tournament.location}",
                    );
                    _launchUrl("https://www.google.com/maps/search/?api=1&query=$query");
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 4. Spécifications du Tournoi (Balles, Prix, Formats)
        Text(
          AppLocalizations.of(context).tournamentDetailEventDetails,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(
            children: [
              if (widget.tournament.scheduleDetails != null) ...[
                _buildInfoRow(CupertinoIcons.time, AppLocalizations.of(context).tournamentDetailEvents, widget.tournament.scheduleDetails!),
                const Divider(color: Colors.white12, height: 24),
              ],
              if (widget.tournament.balls != null) ...[
                _buildInfoRow(CupertinoIcons.circle_grid_hex, AppLocalizations.of(context).tournamentDetailBalls, widget.tournament.balls!),
                const Divider(color: Colors.white12, height: 24),
              ],
              _buildInfoRow(
                CupertinoIcons.money_euro_circle,
                AppLocalizations.of(context).tournamentDetailPrice,
                widget.tournament.price != null && widget.tournament.price!.isNotEmpty
                    ? widget.tournament.price!
                    : "NC",
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 5. Bouton Partager WhatsApp
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.1),
            ),
            icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 20),
            label: const Text("Partager ce tournoi (WhatsApp / Amis)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: () => _shareTournament(widget.tournament),
          ),
        ),
      ],
    );
  }

  Widget _buildJatClaimCard(BuildContext context) {
    final referee = widget.tournament.referee;
    final displayName = referee != null && referee.trim().isNotEmpty ? referee : "Juge-Arbitre (JAT)";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.22),
            const Color(0xFF1E293B).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sports_score_rounded, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Espace Juge-Arbitre (JAT)",
                  style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 12),
                ),
                Text(
                  "Arbitre référent : $displayName",
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              setState(() => _isAuthorized = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("👑 Bienvenue $displayName ! Vos accès JAT sont activés."),
                  backgroundColor: AppColors.gold,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              "C'est moi",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTournament(BuildContext context) async {
    final currentEmail = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim();
    if (currentEmail != 'moixmb@gmail.com') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Action réservée à l'administrateur principal (moixmb@gmail.com)."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Supprimer ce tournoi ?",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          "Êtes-vous sûr de vouloir supprimer définitivement le tournoi \"${widget.tournament.name}\" ?\n\nCette action effacera également les tableaux et les résultats associés.",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament.id).delete();
        if (mounted) {
          appState.loadTournaments();
          nav.pop();
          messenger.showSnackBar(
            const SnackBar(
              content: Text("🗑️ Tournoi supprimé avec succès"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text("Erreur lors de la suppression : $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// 🏆 ONGLET 2 : TABLEAUX & SCORES
  Widget _buildCompetitionTab(BuildContext context) {
    return Column(
      key: const ValueKey('tab_competition'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Arbre & Tableau Officiel FFT
        _buildTournamentBracketHeroCard(context),
        const SizedBox(height: 16),

        // 2. Live Scores en direct jeu par jeu
        TournamentLiveScoresCard(
          tournament: widget.tournament,
          isAuthorized: !_isCheckingAuth && _isAuthorized,
        ),
        const SizedBox(height: 16),

        // 3. Panneau JAT / Administration si autorisé
        if (!_isCheckingAuth && _isAuthorized) ...[
          _buildAdminControlsCard(context),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// 💬 ONGLET 3 : SALON & AMBIANCE DU TOURNOI
  Widget _buildChatTab(BuildContext context) {
    return Column(
      key: const ValueKey('tab_chat'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTournamentChatHeroCard(context),
        const SizedBox(height: 16),
        _buildPartnerMarketplace(context),
        const SizedBox(height: 16),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.photo_library_rounded, color: AppColors.gold, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Photos & Ambiance du Tournoi",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Partagez vos photos sur le sable, vos victoires et les temps forts du tournoi directement dans le salon !",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: const Text("Ouvrir le Salon de Discussion", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TournamentChatScreen(tournament: widget.tournament),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 👑 CARTE D'ADMINISTRATION & GESTION JAT
  Widget _buildAdminControlsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Text("Gestion Officielle du Tournoi", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "En tant que JAT, Président ou Administrateur, vous pouvez piloter les matches et modifier l'événement.",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
              icon: const Icon(Icons.account_tree_rounded, size: 20),
              label: Text(
                _isAuthorized ? "Gérer le Tableau (JAT)" : "Voir le Tableau Officiel",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentBracketScreen(
                    tournament: widget.tournament,
                    isAuthorized: _isAuthorized,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.gold, width: 1.5),
                backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.stadium_rounded, size: 20),
              label: const Text(
                "📅 Répartition des Terrains & Rotations",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _showCourtScheduleConfigDialog,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text("Modifier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _openEditScreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text("Supprimer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _confirmDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ⚓ STICKY BOTTOM BAR PERSISTANTE (ANCRAGE & CALL-TO-ACTION)
  Widget _buildStickyBottomBar(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || (widget.tournament.country ?? '').toUpperCase() == 'BR';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Tarif & Dates
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tournament.price != null && widget.tournament.price!.isNotEmpty
                        ? widget.tournament.price!
                        : (isBr ? "Inscrição oficial" : "Inscription officielle"),
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 15.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.tournament.dateString,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Bouton d'Action Express
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008069), // Vert officiel WhatsApp / Action
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
              ),
              icon: const Icon(Icons.how_to_reg_rounded, size: 18),
              label: Text(
                isBr ? "Inscrições" : "S'inscrire",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              onPressed: () => _showContactJATModal(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 📲 MODALE 1-CLIC CONTACT & INSCRIPTION JAT
  void _showContactJATModal(BuildContext context) {
    HapticFeedback.mediumImpact();
    final tournament = widget.tournament;
    final isBr = (tournament.country ?? '').toUpperCase() == 'BR' || 
        context.read<AppState>().currentUser?.isBrazilian == true;
    final referee = (tournament.referee != null && tournament.referee!.trim().isNotEmpty)
        ? tournament.referee!.trim()
        : (isBr ? "Árbitro Geral / CBT" : "Direction du Tournoi (JAT)");
    final rawPhone = tournament.contactPhone?.trim();
    final hasPhone = rawPhone != null && rawPhone.isNotEmpty;
    final rawEmail = tournament.contactEmail?.trim();
    final hasEmail = rawEmail != null && rawEmail.isNotEmpty;
    final rawUrl = tournament.registrationUrl?.trim();
    final regUrl = (rawUrl != null && rawUrl.isNotEmpty) ? rawUrl : (isBr ? "https://www.cbtenis.com.br/beach-tennis" : "https://tenup.fft.fr");
    final regType = (tournament.registrationType != null && tournament.registrationType!.trim().isNotEmpty)
        ? tournament.registrationType!.trim()
        : (isBr ? "Inscrições via WhatsApp, Telefone ou Portal CBT" : "Inscription par Téléphone, WhatsApp ou Ten'Up");

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.how_to_reg_rounded, color: AppColors.gold, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBr ? "Inscrições & Contato do Árbitro" : "Inscriptions & Contact JAT",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          referee,
                          style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  regType,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 18),
              if (hasPhone) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 20),
                  label: Text(
                    isBr ? "Falar no WhatsApp com o Árbitro" : "Écrire sur WhatsApp au JAT",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openJATWhatsApp(rawPhone, tournament);
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7A3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                  label: Text(
                    isBr ? "Ligar ($rawPhone)" : "Appeler ($rawPhone)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final phone = rawPhone.replaceAll(' ', '');
                    _launchUrl('tel:$phone');
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (hasEmail) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.mail_rounded, size: 20, color: Colors.lightBlueAccent),
                  label: Text(
                    isBr ? "Enviar Email ($rawEmail)" : "Envoyer un Email ($rawEmail)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openJATEmail(rawEmail, tournament, rawPhone);
                  },
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.open_in_browser_rounded, size: 20, color: AppColors.gold),
                label: Text(
                  isBr ? "Portal de Inscrições Online (CBT / Oficial)" : "Portail d'Inscription en Ligne (Ten'Up)",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _launchUrl(regUrl);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// ⚙️ MODALE ACTIONS ADMINISTRATEUR / JAT
  void _showAdminManagementModal(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const Row(
                children: [
                  Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold, size: 22),
                  SizedBox(width: 10),
                  Text(
                    "Gestion Officielle du Tournoi",
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.account_tree_rounded, size: 20),
                label: Text(
                  _isAuthorized ? "Gérer le Tableau (JAT)" : "Voir le Tableau Officiel",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TournamentBracketScreen(
                        tournament: widget.tournament,
                        isAuthorized: _isAuthorized,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.gold, width: 1.5),
                  backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.stadium_rounded, size: 20),
                label: const Text(
                  "📅 Répartition des Terrains & Rotations",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCourtScheduleConfigDialog();
                },
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final isSuperAdmin = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim() == 'moixmb@gmail.com';
                  if (!isSuperAdmin) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text("Modifier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openEditScreen();
                        },
                      ),
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text("Modifier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openEditScreen();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text("Supprimer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDelete();
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openJATWhatsApp(String rawPhone, TournamentModel tournament) {
    HapticFeedback.lightImpact();
    var clean = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('0') && clean.length == 10) {
      clean = '33${clean.substring(1)}';
    }
    final cLower = (tournament.country ?? '').toLowerCase();
    final isBr = (cLower.contains('br') || rawPhone.startsWith('+55'));
    final isVe = (cLower.contains('venezuela') || cLower.contains('vénézuela') || rawPhone.startsWith('+58'));
    final isIt = (cLower.contains('italie') || cLower.contains('italy') || rawPhone.startsWith('+39'));
    final isAruba = (cLower.contains('aruba') || rawPhone.startsWith('+297'));

    final String msgText;
    if (isBr) {
      msgText = "Olá! Gostaria de me inscrever no torneio ${tournament.name} (${tournament.category})!";
    } else if (isVe || isAruba) {
      msgText = "¡Hola! Quisiera inscribirme en el torneo ${tournament.name} (${tournament.category})!";
    } else if (isIt) {
      msgText = "Ciao! Vorrei iscrivermi al torneo ${tournament.name} (${tournament.category})!";
    } else {
      msgText = "Bonjour, je souhaite m'inscrire au tournoi ${tournament.name} (${tournament.category}) !";
    }
    _launchUrl("https://wa.me/$clean?text=${Uri.encodeComponent(msgText)}");
  }

  void _openJATEmail(String rawEmail, TournamentModel tournament, String? rawPhone) {
    HapticFeedback.lightImpact();
    final cLower = (tournament.country ?? '').toLowerCase();
    final isBr = (cLower.contains('br') || (rawPhone != null && rawPhone.startsWith('+55')));
    final isVe = (cLower.contains('venezuela') || (rawPhone != null && rawPhone.startsWith('+58')));
    final isIt = (cLower.contains('italie') || cLower.contains('italy') || (rawPhone != null && rawPhone.startsWith('+39')));
    final isAruba = (cLower.contains('aruba') || (rawPhone != null && rawPhone.startsWith('+297')));

    final String subject;
    if (isBr) {
      subject = "Inscrição Beach Tennis - ${tournament.name}";
    } else if (isVe || isAruba) {
      subject = "Inscripción Beach Tennis - ${tournament.name}";
    } else if (isIt) {
      subject = "Iscrizione Beach Tennis - ${tournament.name}";
    } else {
      subject = "Inscription Beach Tennis - ${tournament.name}";
    }
    _launchUrl('mailto:$rawEmail?subject=${Uri.encodeComponent(subject)}');
  }

  Widget _buildRegistrationAndContactCard(BuildContext context) {
    final tournament = widget.tournament;
    final isBr = (tournament.country ?? '').toUpperCase() == 'BR' || 
        context.read<AppState>().currentUser?.isBrazilian == true;
    final referee = (tournament.referee != null && tournament.referee!.trim().isNotEmpty)
        ? tournament.referee!.trim()
        : (isBr ? "Árbitro Geral / CBT" : "Direction du Tournoi (JAT)");
    final rawPhone = tournament.contactPhone?.trim();
    final hasPhone = rawPhone != null && rawPhone.isNotEmpty;
    final rawEmail = tournament.contactEmail?.trim();
    final hasEmail = rawEmail != null && rawEmail.isNotEmpty;
    final rawUrl = tournament.registrationUrl?.trim();
    final regUrl = (rawUrl != null && rawUrl.isNotEmpty) ? rawUrl : (isBr ? "https://www.cbtenis.com.br/beach-tennis" : "https://tenup.fft.fr");
    final regType = (tournament.registrationType != null && tournament.registrationType!.trim().isNotEmpty)
        ? tournament.registrationType!.trim()
        : (isBr ? "Inscrição por Telefone, WhatsApp ou Portal CBT" : "Inscription par Téléphone, Email ou Ten'Up");

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131F33), Color(0xFF1A2B46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec badge Officiel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.how_to_reg_rounded, color: AppColors.gold, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          isBr ? "Inscrições & Contato" : "Inscriptions & Contact",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: AppColors.gold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isBr ? "Oficial" : "Officiel",
                            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Carte Juge-Arbitre (JAT / CBT)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sports_tennis_rounded, color: AppColors.gold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBr ? "ÁRBITRO GERAL DO TORNEIO (CBT)" : "JUGE-ARBITRE DU TOURNOI (JAT)",
                              style: const TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              referee,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Modalités d'inscription
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.white60, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          regType,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Boutons d'Action Rapide pour Contacter / S'inscrire
                if (hasPhone) ...[
                  Row(
                    children: [
                      // Bouton Appel
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E7A3E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 19),
                          label: Text(
                            rawPhone,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            final phone = rawPhone.replaceAll(' ', '');
                            _launchUrl('tel:$phone');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bouton WhatsApp
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          var clean = rawPhone.replaceAll(RegExp(r'\D'), '');
                          if (clean.startsWith('0') && clean.length == 10) {
                            clean = '33${clean.substring(1)}';
                          }
                          final cLower = (tournament.country ?? '').toLowerCase();
                          final isBr = (cLower.contains('br') || rawPhone.startsWith('+55'));
                          final isVe = (cLower.contains('venezuela') || cLower.contains('vénézuela') || rawPhone.startsWith('+58'));
                          final isIt = (cLower.contains('italie') || cLower.contains('italy') || rawPhone.startsWith('+39'));
                          final isAruba = (cLower.contains('aruba') || rawPhone.startsWith('+297'));

                          final String msgText;
                          if (isBr) {
                            msgText = "Olá! Gostaria de me inscrever no torneio ${tournament.name} (${tournament.category})!";
                          } else if (isVe || isAruba) {
                            msgText = "¡Hola! Quisiera inscribirme en el torneo ${tournament.name} (${tournament.category})!";
                          } else if (isIt) {
                            msgText = "Ciao! Vorrei iscrivermi al torneo ${tournament.name} (${tournament.category})!";
                          } else {
                            msgText = "Bonjour, je souhaite m'inscrire au tournoi ${tournament.name} (${tournament.category}) !";
                          }
                          _launchUrl("https://wa.me/$clean?text=${Uri.encodeComponent(msgText)}");
                        },
                        child: const Icon(Icons.chat_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                if (hasEmail) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                        ),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.mail_rounded, size: 19, color: Colors.lightBlueAccent),
                      label: Text(
                        rawEmail,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final cLower = (tournament.country ?? '').toLowerCase();
                        final isBr = (cLower.contains('br') || (rawPhone != null && rawPhone.startsWith('+55')));
                        final isVe = (cLower.contains('venezuela') || (rawPhone != null && rawPhone.startsWith('+58')));
                        final isIt = (cLower.contains('italie') || cLower.contains('italy') || (rawPhone != null && rawPhone.startsWith('+39')));
                        final isAruba = (cLower.contains('aruba') || (rawPhone != null && rawPhone.startsWith('+297')));

                        final String subject;
                        if (isBr) {
                          subject = "Inscrição Beach Tennis - ${tournament.name}";
                        } else if (isVe || isAruba) {
                          subject = "Inscripción Beach Tennis - ${tournament.name}";
                        } else if (isIt) {
                          subject = "Iscrizione Beach Tennis - ${tournament.name}";
                        } else {
                          subject = "Inscription Beach Tennis - ${tournament.name}";
                        }
                        _launchUrl('mailto:$rawEmail?subject=${Uri.encodeComponent(subject)}');
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Bouton Portail Officiel Ten'Up / ITF / CBT / FVT / FITP / Aruba
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                      side: const BorderSide(color: AppColors.gold, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.gold),
                    label: Text(
                      regUrl.contains('itf')
                          ? "Fiche Officielle ITF Beach Tennis"
                          : (regUrl.contains('arubabeachtennisopen')
                              ? "Portal Oficial Aruba Open 🌴"
                              : (regUrl.contains('cbt') || regUrl.contains('cbtenis')
                                  ? (isBr ? "Portal Oficial de Inscrições CBT 🇧🇷" : "Ficha Oficial CBT Tênis")
                                  : (regUrl.contains('fvt') || regUrl.contains('tenis-integrado')
                                      ? "Portal Oficial FVT Tenis Playa"
                                      : (regUrl.contains('fitp')
                                          ? "Scheda Ufficiale FITP Beach Tennis"
                                          : (isBr ? "Portal Oficial CBT Beach Tennis 🇧🇷" : "Fiche Officielle Ten'Up FFT"))))),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _launchUrl(regUrl);
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

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🆘 =========================================================================
  // 🆘 SOS PARTENAIRE DE TOURNOI (MATCHMAKING DOUBLE)
  // 🆘 =========================================================================
  Widget _buildPartnerMarketplace(BuildContext context) {
    final currentUser = context.read<AppState>().currentUser;
    final currentUserId = currentUser?.id ?? FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournament_partner_requests')
          .where('tournamentId', isEqualTo: widget.tournament.id)
          .snapshots(),
      builder: (context, snapshot) {
        List<PartnerRequestModel> requests = [];
        if (snapshot.hasData) {
          requests = snapshot.data!.docs
              .map((doc) => PartnerRequestModel.fromFirestore(doc))
              .where((r) => r.status.toUpperCase() == 'OPEN' || r.status.isEmpty)
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        PartnerRequestModel? myRequest;
        if (currentUserId != null) {
          for (final r in requests) {
            if (r.userId == currentUserId) {
              myRequest = r;
              break;
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text("🆘", style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      "SOS Partenaire",
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: requests.isNotEmpty ? AppColors.gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: requests.isNotEmpty ? AppColors.gold : Colors.white24,
                    ),
                  ),
                  child: Text(
                    "${requests.length} SOS en attente",
                    style: TextStyle(
                      color: requests.isNotEmpty ? AppColors.gold : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Vous cherchez un binôme pour ce tournoi ? Publiez votre SOS Partenaire ou contactez un joueur disponible !",
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Bouton Action Dépôt Annonce
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: myRequest != null ? const Color(0xFF1E293B) : AppColors.gold,
                  foregroundColor: myRequest != null ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: myRequest != null ? const BorderSide(color: AppColors.gold, width: 1.5) : BorderSide.none,
                  ),
                  elevation: 4,
                ),
                icon: Icon(myRequest != null ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded, size: 20),
                label: Text(
                  myRequest != null ? "Modifier mon SOS Partenaire" : "➕ Publier mon SOS Partenaire",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                onPressed: () => _showCreatePartnerRequestSheet(myRequest),
              ),
            ),

            if (requests.isEmpty)
              _buildGlassCard(
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Icon(Icons.sports_tennis_rounded, color: Colors.white38, size: 36),
                        SizedBox(height: 8),
                        Text(
                          "Aucun SOS Partenaire pour le moment",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Soyez le premier à publier un SOS Partenaire pour trouver votre binôme rapidement !",
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...requests.map((r) => _buildPartnerRequestCard(r, r.userId == currentUserId)),
          ],
        );
      },
    );
  }

  Widget _buildPartnerRequestCard(PartnerRequestModel req, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isMe ? const Color(0xFF1F3554) : const Color(0xFF162032),
            const Color(0xFF121B2A),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe ? AppColors.gold.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
          width: isMe ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => PublicProfileScreen.open(
                  context,
                  userId: req.userId,
                  displayName: req.userName,
                  photoUrl: req.userPhoto,
                  ranking: req.fftRank,
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.coral,
                  backgroundImage: (req.userPhoto != null && req.userPhoto!.isNotEmpty)
                      ? NetworkImage(req.userPhoto!)
                      : null,
                  child: (req.userPhoto == null || req.userPhoto!.isEmpty)
                      ? Text(
                          req.userName.isNotEmpty ? req.userName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => PublicProfileScreen.open(
                    context,
                    userId: req.userId,
                    displayName: req.userName,
                    photoUrl: req.userPhoto,
                    ranking: req.fftRank,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              req.userName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text("Moi", style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "🏅 Classement : ${req.fftRank}",
                        style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badges Côté + Tableau + Objectif
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge(req.draw, const Color(0xFF3B82F6)),
              _buildBadge(req.preferredSide, const Color(0xFF10B981)),
              _buildBadge(req.goal, const Color(0xFFF59E0B)),
            ],
          ),

          if (req.message != null && req.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "« ${req.message} »",
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 10),

          if (isMe)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text("Supprimer", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _deletePartnerRequest(req.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text("Partager WhatsApp", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      WhatsAppShareService.shareTournamentPartnerRequest(
                        tournamentName: widget.tournament.name,
                        tournamentDates: widget.tournament.dateString,
                        location: "${widget.tournament.location} (${widget.tournament.club})",
                        category: widget.tournament.category,
                        playerName: req.userName,
                        fftRank: req.fftRank,
                        preferredSide: req.preferredSide,
                        draw: req.draw,
                        goal: req.goal,
                        tournamentId: widget.tournament.id,
                      );
                    },
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.handshake_rounded, size: 18),
                    label: const Text("Proposer de faire équipe", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => _proposeTeamUp(req),
                  ),
                ),
                if (req.phone != null && req.phone!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.2),
                      side: const BorderSide(color: Color(0xFF25D366)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
                    tooltip: "Contacter sur WhatsApp",
                    onPressed: () {
                      final cleanPhone = req.phone!.replaceAll(RegExp(r'\D'), '');
                      final msg = Uri.encodeComponent("Salut ${req.userName}, j'ai vu ton annonce sur BeachMatch pour le tournoi ${widget.tournament.name} ! Es-tu toujours dispo pour faire la paire ?");
                      _launchUrl("https://wa.me/$cleanPhone?text=$msg");
                    },
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onSelected) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.gold : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showCreatePartnerRequestSheet([PartnerRequestModel? existing]) {
    final appUser = context.read<AppState>().currentUser;
    final currentUserId = appUser?.id ?? FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez vous connecter pour déposer une annonce.")),
      );
      return;
    }

    String selectedDraw = existing?.draw ?? 'DH';
    String selectedSide = existing?.preferredSide ?? 'Gauche ⬅️';
    String selectedGoal = existing?.goal ?? 'Compétition & Podiums 🥈';
    final messageCtrl = TextEditingController(text: existing?.message ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final fftRank = (appUser?.ranking != null && appUser!.ranking!.isNotEmpty)
        ? appUser.ranking!
        : (appUser?.level != null ? "Niveau ${appUser!.level}" : 'NC');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                      children: [
                        const Icon(Icons.group_add_rounded, color: AppColors.gold, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          existing != null ? "Modifier mon SOS Partenaire" : "🆘 Déposer un SOS Partenaire",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Pour ${widget.tournament.name}",
                      style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 18),

                    // Tableau
                    const Text("Tableau visé :", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChoiceChip("DH · Messieurs", selectedDraw == 'DH', () => setModalState(() => selectedDraw = 'DH')),
                        const SizedBox(width: 8),
                        _buildChoiceChip("DD · Dames", selectedDraw == 'DD', () => setModalState(() => selectedDraw = 'DD')),
                        const SizedBox(width: 8),
                        _buildChoiceChip("DX · Mixte", selectedDraw == 'DX', () => setModalState(() => selectedDraw = 'DX')),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Côté préféré
                    const Text("Côté de jeu préféré :", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildChoiceChip("Gauche ⬅️", selectedSide == 'Gauche ⬅️', () => setModalState(() => selectedSide = 'Gauche ⬅️')),
                        _buildChoiceChip("Droite ➡️", selectedSide == 'Droite ➡️', () => setModalState(() => selectedSide = 'Droite ➡️')),
                        _buildChoiceChip("Polyvalent 🔄", selectedSide == 'Polyvalent 🔄', () => setModalState(() => selectedSide = 'Polyvalent 🔄')),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Objectif
                    const Text("Objectif :", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChoiceChip("Pour la gagne 🏆", selectedGoal == 'Pour la gagne 🏆', () => setModalState(() => selectedGoal = 'Pour la gagne 🏆')),
                        _buildChoiceChip("Podiums 🥈", selectedGoal == 'Compétition & Podiums 🥈', () => setModalState(() => selectedGoal = 'Compétition & Podiums 🥈')),
                        _buildChoiceChip("Plaisir 🏖️", selectedGoal == 'Plaisir & Progression 🏖️', () => setModalState(() => selectedGoal = 'Plaisir & Progression 🏖️')),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Message
                    const Text("Précisions (disponibilité, style de jeu...) :", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Ex: Dispo dès samedi matin, smash puissant...",
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),

                    // Téléphone / WhatsApp
                    const Text("Téléphone ou WhatsApp (optionnel) :", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Ex: 06 12 34 56 78",
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.phone_rounded, color: Colors.white54, size: 18),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Bouton Valider
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final reqId = existing?.id ?? FirebaseFirestore.instance.collection('tournament_partner_requests').doc().id;
                          final reqModel = PartnerRequestModel(
                            id: reqId,
                            tournamentId: widget.tournament.id,
                            tournamentName: widget.tournament.name,
                            userId: currentUserId,
                            userName: appUser?.displayName ?? 'Joueur BeachMatch',
                            userPhoto: appUser?.photoUrl,
                            fftRank: fftRank,
                            draw: selectedDraw,
                            preferredSide: selectedSide,
                            goal: selectedGoal,
                            message: messageCtrl.text.trim().isNotEmpty ? messageCtrl.text.trim() : null,
                            phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                            createdAt: DateTime.now(),
                            status: 'OPEN',
                          );

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await FirebaseFirestore.instance
                                .collection('tournament_partner_requests')
                                .doc(reqId)
                                .set(reqModel.toMap());

                            if (mounted) {
                              _showPartnerRequestCreatedDialog(reqModel);
                            }
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text("Erreur d'enregistrement : $e"), backgroundColor: Colors.redAccent),
                            );
                          }
                        },
                        child: Text(
                          existing != null ? "Enregistrer les modifications" : "Publier mon SOS Partenaire",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPartnerRequestCreatedDialog(PartnerRequestModel req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16253B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 28),
            SizedBox(width: 8),
            Text("SOS Partenaire en ligne !", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Votre SOS Partenaire est immédiatement visible par toute la communauté sur la fiche du tournoi.",
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text("Partager sur WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: () {
                Navigator.pop(ctx);
                WhatsAppShareService.shareTournamentPartnerRequest(
                  tournamentName: widget.tournament.name,
                  tournamentDates: widget.tournament.dateString,
                  location: "${widget.tournament.location} (${widget.tournament.club})",
                  category: widget.tournament.category,
                  playerName: req.userName,
                  fftRank: req.fftRank,
                  preferredSide: req.preferredSide,
                  draw: req.draw,
                  goal: req.goal,
                  tournamentId: widget.tournament.id,
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Plus tard", style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePartnerRequest(String id) async {
    try {
      await FirebaseFirestore.instance.collection('tournament_partner_requests').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("SOS Partenaire retiré avec succès.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
    }
  }

  void _proposeTeamUp(PartnerRequestModel req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16253B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.handshake_rounded, color: AppColors.gold, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text("Faire équipe avec ${req.userName} ?", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tu souhaites proposer à ${req.userName} de former la paire pour ${widget.tournament.name} (${req.draw}) ?",
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_rounded, size: 18),
              label: const Text("Consulter sa fiche profil", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () {
                Navigator.pop(ctx);
                PublicProfileScreen.open(
                  context,
                  userId: req.userId,
                  displayName: req.userName,
                  photoUrl: req.userPhoto,
                  ranking: req.fftRank,
                );
              },
            ),
            const SizedBox(height: 8),
            if (req.phone != null && req.phone!.isNotEmpty) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text("Lui écrire sur WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  Navigator.pop(ctx);
                  final cleanPhone = req.phone!.replaceAll(RegExp(r'\D'), '');
                  final msg = Uri.encodeComponent("Salut ${req.userName}, j'ai vu ton annonce sur BeachMatch pour le tournoi ${widget.tournament.name} ! Es-tu toujours dispo pour faire la paire ?");
                  _launchUrl("https://wa.me/$cleanPhone?text=$msg");
                },
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.coral),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.send_rounded, color: AppColors.coral, size: 18),
              label: const Text("Envoyer une proposition BeachMatch", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () {
                final currentUser = context.read<AppState>().currentUser;
                final senderId = currentUser?.id ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                final senderName = currentUser?.displayName ?? 'Un joueur';

                FirebaseFirestore.instance.collection('partner_proposals').add({
                  'targetUserId': req.userId,
                  'senderId': senderId,
                  'senderName': senderName,
                  'tournamentId': widget.tournament.id,
                  'tournamentName': widget.tournament.name,
                  'draw': req.draw,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Demande d'association envoyée à ${req.userName} !"),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentChatHeroCard(BuildContext context) {
    final chatRoomId = 'tournament_${widget.tournament.id}';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(chatRoomId).snapshots(),
      builder: (context, snapshot) {
        final chatData = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>? ?? {}
            : <String, dynamic>{};
        final lastMessage = (chatData['lastMessage'] as String?)?.trim();
        final users = (chatData['users'] as List?)?.cast<String>() ?? [];
        final participantCount = users.length;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TournamentChatScreen(tournament: widget.tournament),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E1B4B), // Deep electric indigo
                  Color(0xFF0F172A), // Dark slate navy
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF818CF8).withValues(alpha: 0.7),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rangée 1 : Icône avec badge en ligne + Titre & Tags
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.forum_rounded, color: Colors.white, size: 24),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981), // Green live
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF0F172A), width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.8),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.circle, color: Color(0xFF10B981), size: 6),
                                          SizedBox(width: 4),
                                          Text(
                                            "SALON OFFICIEL EN DIRECT",
                                            style: TextStyle(
                                              color: Color(0xFF34D399),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (participantCount > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 10),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$participantCount",
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  "Chat & Salon des Joueurs",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFA5B4FC), size: 14),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Rangée 2 : Aperçu du dernier message ou invitation
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              lastMessage != null && lastMessage.isNotEmpty
                                  ? Icons.chat_bubble_outline_rounded
                                  : Icons.waving_hand_rounded,
                              size: 15,
                              color: lastMessage != null && lastMessage.isNotEmpty
                                  ? AppColors.gold
                                  : const Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lastMessage != null && lastMessage.isNotEmpty
                                    ? "« $lastMessage »"
                                    : "Discutez avec les organisateurs et les joueurs du tournoi !",
                                style: TextStyle(
                                  color: lastMessage != null && lastMessage.isNotEmpty
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontStyle: lastMessage != null && lastMessage.isNotEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  fontWeight: lastMessage != null && lastMessage.isNotEmpty
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Rangée 3 : Badges de fonctionnalités rapides
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildChatFeatureTag("📊 Sondages", const Color(0xFF6366F1)),
                            const SizedBox(width: 6),
                            _buildChatFeatureTag("📸 Photos & Vidéos", const Color(0xFFEC4899)),
                            const SizedBox(width: 6),
                            _buildChatFeatureTag("🤝 Partenaire SOS", AppColors.coral),
                            const SizedBox(width: 6),
                            _buildChatFeatureTag("📢 Annonces", AppColors.gold),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Rangée 4 : Bouton d'action étincelant (Call To Action)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mark_chat_unread_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              "Rejoindre le Chat du Tournoi",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatFeatureTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTournamentBracketHeroCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('brackets')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        int pairsCount = 0;
        bool isGenerated = false;
        String status = 'draft';

        for (final doc in docs) {
          final data = doc.data();
          final pairs = (data['pairs'] as List?) ?? [];
          pairsCount += pairs.length;
          final mainMatches = (data['mainMatches'] as List?) ?? [];
          final pools = (data['pools'] as List?) ?? [];
          if (mainMatches.isNotEmpty || pools.isNotEmpty) {
            isGenerated = true;
          }
          final docStatus = data['status']?.toString() ?? 'draft';
          if (docStatus == 'finished') {
            status = 'finished';
          } else if (docStatus == 'in_progress' && status != 'finished') {
            status = 'in_progress';
          }
        }

        String statusLabel = "TABLEAU OFFICIEL FFT";
        Color statusColor = AppColors.gold;
        String desc = "Consultez l'arbre, les têtes de série et les résultats des matches";

        if (status == 'finished') {
          statusLabel = "TOURNOI TERMINÉ";
          statusColor = const Color(0xFF10B981);
          desc = "Résultats officiels et palmarès final du tournoi";
        } else if (isGenerated || status == 'in_progress') {
          statusLabel = "TABLEAU EN DIRECT";
          statusColor = AppColors.coral;
          desc = "$pairsCount paires en lice • Scores des matches en temps réel";
        } else if (pairsCount > 0) {
          statusLabel = "INSCRIPTIONS EN COURS";
          statusColor = AppColors.gold;
          desc = "$pairsCount paires inscrites • Tirage officiel à venir";
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TournamentBracketScreen(
                  tournament: widget.tournament,
                  isAuthorized: !_isCheckingAuth && _isAuthorized,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E293B), // Deep navy
                  Color(0xFF0F172A), // Dark slate
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.6),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.gold, Color(0xFFEAB308)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.account_tree_rounded, color: Colors.black, size: 26),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.circle, color: statusColor, size: 6),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusLabel,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isCheckingAuth && _isAuthorized) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                                        ),
                                        child: const Text(
                                          "JAT",
                                          style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  "Tableau de la Compétition",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                desc,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
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
          ),
        );
      },
    );
  }
}

