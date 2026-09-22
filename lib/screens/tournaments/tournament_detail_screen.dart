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
    WhatsAppShareService.shareTournamentInvite(
      tournamentName: tournament.name,
      dates: tournament.dateString,
      location: "${tournament.location} (${tournament.club})",
      category: tournament.category,
      price: tournament.price,
      phone: tournament.contactPhone,
      tournamentId: tournament.id,
    );
  }

  void _confirmDelete() {
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
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
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.gold),
                    tooltip: "Chat du tournoi",
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
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    widget.tournament.category,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  background: const SizedBox.shrink(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tournament.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.location_solid, color: Colors.blueAccent, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.tournament.club,
                              style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 💬 CHAT OFFICIEL DU TOURNOI (Portant le nom exact du tournoi)
                      GestureDetector(
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
                          margin: const EdgeInsets.only(bottom: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1E293B).withValues(alpha: 0.95),
                                const Color(0xFF131F30).withValues(alpha: 0.98),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.2),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.gold, AppColors.goldDark],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gold.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.chat_bubble_rounded, color: Color(0xFF0F172A), size: 24),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.tournament.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            "CHAT",
                                            style: TextStyle(
                                              color: AppColors.gold,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "Sondages, photos, vidéos & échanges joueurs",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 16),
                            ],
                          ),
                        ),
                      ),

                      // 🔴 LIVE SCORES EN DIRECT (Jeu par Jeu)
                      TournamentLiveScoresCard(
                        tournament: widget.tournament,
                        isAuthorized: !_isCheckingAuth && _isAuthorized,
                      ),
                      const SizedBox(height: 16),

                      // 🆘 SOS PARTENAIRE DE TOURNOI
                      _buildPartnerMarketplace(context),
                      const SizedBox(height: 24),

                      // Dates and Location Card
                      _buildGlassCard(
                        child: Column(
                          children: [
                            _buildInfoRow(CupertinoIcons.calendar, AppLocalizations.of(context).tournamentDetailDates, widget.tournament.dateString),
                            if (widget.tournament.address != null) ...[
                              const Divider(color: Colors.white12, height: 24),
                              _buildInfoRow(CupertinoIcons.map_pin_ellipse, AppLocalizations.of(context).tournamentDetailAddress, widget.tournament.address!),
                            ],
                            const Divider(color: Colors.white12, height: 24),
                            _buildInfoRow(CupertinoIcons.location, AppLocalizations.of(context).tournamentDetailCity, locationWithDistance),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🎾 INSTRUCTIONS & COORDONNÉES OFFICIELLES (ULTRA VISIBLE)
                      _buildRegistrationAndContactCard(context),
                      const SizedBox(height: 24),

                      // Event Details
                      Text(AppLocalizations.of(context).tournamentDetailEventDetails, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
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
                            if (widget.tournament.price != null) ...[
                              _buildInfoRow(CupertinoIcons.money_euro_circle, AppLocalizations.of(context).tournamentDetailPrice, widget.tournament.price!),
                            ],
                          ],
                        ),
                      ),

                      // 📤 BOUTON PARTAGE WHATSAPP / AMIS
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF25D366), width: 1.5), // WhatsApp green
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.1),
                          ),
                          icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 20),
                          label: const Text("Partager ce tournoi (WhatsApp / Amis)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: () => _shareTournament(widget.tournament),
                        ),
                      ),

                      // 👑 PRESIDENT / ADMIN MANAGEMENT ACTIONS
                      if (!_isCheckingAuth && _isAuthorized) ...[
                        const SizedBox(height: 24),
                        Container(
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
                                "En tant que Président ou Administrateur, vous pouvez modifier ou annuler cet événement.",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  // Edit button
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
                                  // Delete button
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
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationAndContactCard(BuildContext context) {
    final tournament = widget.tournament;
    final referee = (tournament.referee != null && tournament.referee!.trim().isNotEmpty)
        ? tournament.referee!.trim()
        : "Direction du Tournoi (JAT)";
    final rawPhone = tournament.contactPhone?.trim();
    final hasPhone = rawPhone != null && rawPhone.isNotEmpty;
    final rawEmail = tournament.contactEmail?.trim();
    final hasEmail = rawEmail != null && rawEmail.isNotEmpty;
    final rawUrl = tournament.registrationUrl?.trim();
    final regUrl = (rawUrl != null && rawUrl.isNotEmpty) ? rawUrl : "https://tenup.fft.fr";
    final regType = (tournament.registrationType != null && tournament.registrationType!.trim().isNotEmpty)
        ? tournament.registrationType!.trim()
        : "Inscription par Téléphone, Email ou Ten'Up";

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
                    const Row(
                      children: [
                        Icon(Icons.how_to_reg_rounded, color: AppColors.gold, size: 24),
                        SizedBox(width: 8),
                        Text(
                          "Inscriptions & Contact",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, color: AppColors.gold, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "Officiel",
                            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Carte Juge-Arbitre (JAT)
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
                            const Text(
                              "JUGE-ARBITRE DU TOURNOI (JAT)",
                              style: TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
                          final msg = Uri.encodeComponent("Bonjour, je souhaite m'inscrire au tournoi ${tournament.name} (${tournament.category}) !");
                          _launchUrl("https://wa.me/$clean?text=$msg");
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final subject = Uri.encodeComponent("Inscription Beach Tennis - ${tournament.name}");
                        _launchUrl('mailto:$rawEmail?subject=$subject');
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Bouton Portail Officiel Ten'Up / ITF
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.gold, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: Text(
                      regUrl.contains('itf') ? "Fiche Officielle ITF Beach Tennis" : "Fiche Officielle Ten'Up FFT",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
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
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 16),
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
}

