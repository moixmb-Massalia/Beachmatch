import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
import '../../widgets/tournament_live_scores_card.dart';

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
    final text = "🎾 *Tournoi Beach Tennis : ${tournament.name}* 🏆\n"
        "📍 Lieu : ${tournament.location} (${tournament.club})\n"
        "📅 Dates : ${tournament.dateString}\n"
        "⭐ Catégorie : ${tournament.category}\n"
        "${tournament.price != null && tournament.price!.isNotEmpty ? "💶 Tarif : ${tournament.price}\n" : ""}"
        "${tournament.contactPhone != null && tournament.contactPhone!.isNotEmpty ? "📞 Inscriptions : ${tournament.contactPhone}\n" : ""}"
        "\nRejoins-nous sur BeachMatch pour participer ! 🏖️📲";
    Share.share(text);
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
              try {
                await FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament.id).delete();
                if (mounted) {
                  await context.read<AppState>().loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Tournoi '${widget.tournament.name}' supprimé avec succès !"), backgroundColor: Colors.green),
                  );
                  Navigator.pop(context); // Retour à la liste
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur lors de la suppression: $e"), backgroundColor: Colors.redAccent),
                  );
                }
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
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.75),
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
                      const SizedBox(height: 20),

                      // 🔴 LIVE SCORES EN DIRECT (Jeu par Jeu)
                      TournamentLiveScoresCard(
                        tournament: widget.tournament,
                        isAuthorized: !_isCheckingAuth && _isAuthorized,
                      ),

                      // Dates and Location Card
                      _buildGlassCard(
                        child: Column(
                          children: [
                            _buildInfoRow(CupertinoIcons.calendar, AppLocalizations.of(context)!.tournamentDetailDates, widget.tournament.dateString),
                            if (widget.tournament.address != null) ...[
                              const Divider(color: Colors.white12, height: 24),
                              _buildInfoRow(CupertinoIcons.map_pin_ellipse, AppLocalizations.of(context)!.tournamentDetailAddress, widget.tournament.address!),
                            ],
                            const Divider(color: Colors.white12, height: 24),
                            _buildInfoRow(CupertinoIcons.location, AppLocalizations.of(context)!.tournamentDetailCity, locationWithDistance),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Event Details
                      Text(AppLocalizations.of(context)!.tournamentDetailEventDetails, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildGlassCard(
                        child: Column(
                          children: [
                            if (widget.tournament.scheduleDetails != null) ...[
                              _buildInfoRow(CupertinoIcons.time, AppLocalizations.of(context)!.tournamentDetailEvents, widget.tournament.scheduleDetails!),
                              const Divider(color: Colors.white12, height: 24),
                            ],
                            if (widget.tournament.balls != null) ...[
                              _buildInfoRow(CupertinoIcons.circle_grid_hex, AppLocalizations.of(context)!.tournamentDetailBalls, widget.tournament.balls!),
                              const Divider(color: Colors.white12, height: 24),
                            ],
                            if (widget.tournament.price != null) ...[
                              _buildInfoRow(CupertinoIcons.money_euro_circle, AppLocalizations.of(context)!.tournamentDetailPrice, widget.tournament.price!),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Inscription Details
                      if (widget.tournament.registrationType != null || widget.tournament.referee != null || widget.tournament.contactEmail != null || widget.tournament.contactPhone != null) ...[
                        Text(AppLocalizations.of(context)!.tournamentDetailRegistration, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.tournament.registrationType != null) ...[
                                Text(AppLocalizations.of(context)!.tournamentDetailRegistrationType, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(widget.tournament.registrationType!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                                const Divider(color: Colors.white12, height: 24),
                              ],
                              if (widget.tournament.referee != null) ...[
                                _buildInfoRow(CupertinoIcons.person_solid, AppLocalizations.of(context)!.tournamentDetailReferee, widget.tournament.referee!),
                                const Divider(color: Colors.white12, height: 24),
                              ],
                              if (widget.tournament.contactPhone != null)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(CupertinoIcons.phone_fill, color: Colors.greenAccent),
                                  title: Text(widget.tournament.contactPhone!, style: const TextStyle(color: Colors.white)),
                                  onTap: () {
                                    final phone = widget.tournament.contactPhone!.replaceAll(' ', '');
                                    _launchUrl('tel:$phone');
                                  },
                                ),
                              if (widget.tournament.contactEmail != null)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(CupertinoIcons.mail_solid, color: Colors.blueAccent),
                                  title: Text(widget.tournament.contactEmail!, style: const TextStyle(color: Colors.white)),
                                  onTap: () => _launchUrl('mailto:${widget.tournament.contactEmail}'),
                                ),
                            ],
                          ),
                        ),
                      ],

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
                            backgroundColor: const Color(0xFF25D366).withOpacity(0.1),
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
                            color: AppColors.gold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
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
                                        backgroundColor: Colors.redAccent.withOpacity(0.9),
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

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
}
