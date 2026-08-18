import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/club.dart';
import '../../theme/colors.dart';
import '../../widgets/club_invite_dialog.dart';
import 'create_tournament_screen.dart';
import 'publish_announcement_screen.dart';

class PresidentDashboardScreen extends StatelessWidget {
  final ClubModel club;
  
  const PresidentDashboardScreen({super.key, required this.club});

  Future<void> _pickAndUploadPhoto(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (pickedFile == null) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Téléchargement du logo en cours... ⏳")),
        );
      }

      final bytes = await pickedFile.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child('club_logos/${club.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();

      // Mettre à jour le club dans Firestore
      await FirebaseFirestore.instance.collection('clubs').doc(club.id).update({
        'bannerUrl': downloadUrl,
      });

      // Mettre à jour l'icône de groupe de la Taverne dans Firestore
      await FirebaseFirestore.instance.collection('chats').doc('club_${club.id}').set({
        'groupIcon': downloadUrl,
      }, SetOptions(merge: true));

      club.bannerUrl = downloadUrl;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logo du club mis à jour avec succès ! 📸")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la mise à jour : $e")),
        );
      }
    }
  }

  void _showChangePhotoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Photo de profil du club",
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.photo_library, color: AppColors.coral),
              ),
              title: const Text("Choisir dans la galerie", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: const Text("Prendre une photo", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(context, ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.85),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildActionCard(
                  context,
                  title: "Inviter des Membres & QR Code",
                  subtitle: "Partager sur WhatsApp ou afficher le QR Code du club.",
                  icon: Icons.qr_code_2_rounded,
                  onTap: () => showClubInviteDialog(
                    context,
                    clubId: club.id,
                    clubName: club.name,
                    bannerUrl: club.bannerUrl,
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  context,
                  title: "Changer le Logo du Club",
                  subtitle: "Personnaliser l'image de profil et l'avatar du Chat du club.",
                  icon: Icons.add_a_photo_rounded,
                  onTap: () => _showChangePhotoModal(context),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  context,
                  title: "Créer un Tournoi",
                  subtitle: "Publier un nouveau tournoi officiel pour le club.",
                  icon: Icons.emoji_events,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CreateTournamentScreen(club: club)));
                  },
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  context,
                  title: "Faire une Annonce",
                  subtitle: "Diffuser une alerte aux membres et épingler dans le Chat interne.",
                  icon: Icons.campaign,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PublishAnnouncementScreen(club: club)));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.gold, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

