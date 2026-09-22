import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/club.dart';
import '../../models/tournament.dart';
import '../../providers/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/club_invite_dialog.dart';
import 'create_tournament_screen.dart';
import 'publish_announcement_screen.dart';

class PresidentDashboardScreen extends StatefulWidget {
  final ClubModel club;
  
  const PresidentDashboardScreen({super.key, required this.club});

  @override
  State<PresidentDashboardScreen> createState() => _PresidentDashboardScreenState();
}

class _PresidentDashboardScreenState extends State<PresidentDashboardScreen> {
  late String? _bannerUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _bannerUrl = widget.club.bannerUrl;
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Téléchargement du logo en cours... ⏳")),
        );
      }

      final bytes = await pickedFile.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child('club_logos/${widget.club.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();

      // Mettre à jour le club dans Firestore
      await FirebaseFirestore.instance.collection('clubs').doc(widget.club.id).update({
        'bannerUrl': downloadUrl,
      });

      // Mettre à jour l'icône de groupe de la Taverne dans Firestore
      await FirebaseFirestore.instance.collection('chats').doc('club_${widget.club.id}').set({
        'groupIcon': downloadUrl,
      }, SetOptions(merge: true));

      widget.club.bannerUrl = downloadUrl;

      if (mounted) {
        setState(() {
          _bannerUrl = downloadUrl;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Logo du club mis à jour avec succès ! 📸"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la mise à jour : $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showChangePhotoModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141923),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Photo de profil du club",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.photo_library, color: AppColors.coral),
              ),
              title: const Text("Choisir dans la galerie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: AppColors.gold),
              ),
              title: const Text("Prendre une photo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTournament(TournamentModel tournament) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Supprimer le tournoi ?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          "Êtes-vous sûr de vouloir supprimer \"${tournament.name}\" ? Cette action est irréversible.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).delete();
        if (mounted) {
          await context.read<AppState>().loadData();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tournoi supprimé ✓"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur de suppression: $e"), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTournaments = context.watch<AppState>().tournaments;
    final clubTournaments = allTournaments.where((t) {
      final matchClubId = t.clubId != null && t.clubId == widget.club.id;
      final matchName = t.club.isNotEmpty && t.club.toLowerCase().trim() == widget.club.name.toLowerCase().trim();
      return matchClubId || matchName;
    }).toList();

    final displayLocation = (widget.club.location.isEmpty || widget.club.location.toLowerCase().contains('recherche'))
        ? 'France'
        : widget.club.location;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Espace Président", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
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
              color: Colors.black.withValues(alpha: 0.85),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // En-tête Club Showcase
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _showChangePhotoModal,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: AppColors.coral,
                                  backgroundImage: (_bannerUrl != null && _bannerUrl!.startsWith('http'))
                                      ? NetworkImage(_bannerUrl!)
                                      : null,
                                  child: (_bannerUrl == null || !_bannerUrl!.startsWith('http'))
                                      ? const Icon(Icons.sports_tennis, color: Colors.white, size: 30)
                                      : null,
                                ),
                                if (_isUploadingPhoto)
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.5),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 1.5),
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 12, color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.gold, width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.workspace_premium, color: AppColors.gold, size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            "Président 👑",
                                            style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.club.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayLocation,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Statistiques clés du club
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.groups_rounded, color: AppColors.coral, size: 22),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${widget.club.memberIds.length}",
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const Text("Membres", style: TextStyle(color: Colors.white60, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 22),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${clubTournaments.length}",
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const Text("Tournois", style: TextStyle(color: Colors.white60, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                const Text(
                  "ACTIONS RAPIDES",
                  style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),

                _buildActionCard(
                  context,
                  title: "Inviter des Membres & QR Code",
                  subtitle: "Partager sur WhatsApp ou afficher le QR Code officiel du club.",
                  icon: Icons.qr_code_2_rounded,
                  onTap: () => showClubInviteDialog(
                    context,
                    clubId: widget.club.id,
                    clubName: widget.club.name,
                    bannerUrl: _bannerUrl,
                  ),
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: "Changer le Logo du Club",
                  subtitle: "Personnaliser l'image de profil et l'avatar du Chat du club.",
                  icon: Icons.add_a_photo_rounded,
                  onTap: _showChangePhotoModal,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: "Créer un Tournoi",
                  subtitle: "Publier un nouveau tournoi officiel pour le club avec calendrier.",
                  icon: Icons.emoji_events,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CreateTournamentScreen(club: widget.club)));
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: "Faire une Annonce",
                  subtitle: "Diffuser une alerte aux membres et épingler dans le Chat interne.",
                  icon: Icons.campaign,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PublishAnnouncementScreen(club: widget.club)));
                  },
                ),
                const SizedBox(height: 24),

                // Section Tournois du club
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TOURNOIS DU CLUB",
                      style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    Text(
                      "${clubTournaments.length} événement(s)",
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (clubTournaments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.event_busy_rounded, color: Colors.white38, size: 36),
                        const SizedBox(height: 10),
                        const Text(
                          "Aucun tournoi enregistré",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Publiez vos tournois FFT pour attirer les joueurs de la région !",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CreateTournamentScreen(club: widget.club)));
                          },
                          icon: const Icon(Icons.add, color: AppColors.gold, size: 18),
                          label: const Text("Créer un premier tournoi", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else
                  ...clubTournaments.map((t) => _buildTournamentCard(context, t)),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(BuildContext context, TournamentModel tournament) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold, width: 1),
            ),
            child: Text(
              tournament.category.isNotEmpty ? tournament.category : "FFT",
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white60, size: 12),
                    const SizedBox(width: 4),
                    Text(tournament.dateString, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                if (tournament.location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.coral, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          tournament.location,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.gold, size: 20),
                tooltip: "Modifier",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateTournamentScreen(club: widget.club, initialTournament: tournament)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: "Supprimer",
                onPressed: () => _deleteTournament(tournament),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.gold, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

