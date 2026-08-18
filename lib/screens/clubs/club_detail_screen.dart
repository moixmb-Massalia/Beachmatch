import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/club.dart';
import '../../providers/app_state.dart';
import '../../theme/colors.dart';
import '../../services/chat_service.dart';
import '../../widgets/club_invite_dialog.dart';
import '../../widgets/beach_weather_widget.dart';
import 'group_chat_detail_screen.dart';
import 'president_dashboard_screen.dart';

class ClubDetailScreen extends StatefulWidget {
  final ClubModel club;
  
  const ClubDetailScreen({super.key, required this.club});

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  final ChatService _chatService = ChatService();
  bool _isUploadingPhoto = false;
  String? _currentBannerUrl;

  @override
  void initState() {
    super.initState();
    _currentBannerUrl = widget.club.bannerUrl;
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

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

      setState(() {
        _currentBannerUrl = downloadUrl;
        widget.club.bannerUrl = downloadUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo du club mise à jour avec succès ! 📸")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la mise à jour : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showChangePhotoBottomSheet() {
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
                _pickAndUploadPhoto(ImageSource.gallery);
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
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _toggleMembership(String userId) async {
    final isMember = widget.club.memberIds.contains(userId);
    final clubRef = FirebaseFirestore.instance.collection('clubs').doc(widget.club.id);
    
    if (isMember) {
      await clubRef.update({
        'memberIds': FieldValue.arrayRemove([userId])
      });
      await _chatService.leaveClubChat(userId, widget.club.id);
      setState(() {
        widget.club.memberIds.remove(userId);
      });
    } else {
      await clubRef.update({
        'memberIds': FieldValue.arrayUnion([userId])
      });
      await _chatService.joinClubChat(userId, widget.club.id, widget.club.name, widget.club.bannerUrl);
      setState(() {
        widget.club.memberIds.add(userId);
      });
    }
  }

  (double, double) _getClubCoordinates(String location, String clubName) {
    final text = "$location $clubName".toLowerCase();
    if (text.contains('marseille')) return (43.2965, 5.3698);
    if (text.contains('nice') || text.contains('cannes') || text.contains('antibes')) return (43.7102, 7.2620);
    if (text.contains('bordeaux') || text.contains('arcachon') || text.contains('landes')) return (44.8378, -0.5792);
    if (text.contains('montpellier') || text.contains('palavas') || text.contains('grande motte')) return (43.6108, 3.8767);
    if (text.contains('toulon') || text.contains('hyères') || text.contains('saint-tropez')) return (43.1242, 5.9280);
    if (text.contains('perpignan') || text.contains('canet')) return (42.6886, 2.8948);
    if (text.contains('la rochelle') || text.contains('île de ré') || text.contains('oleron')) return (46.1603, -1.1511);
    if (text.contains('paris') || text.contains('île-de-france')) return (48.8566, 2.3522);
    if (text.contains('rennes') || text.contains('bretagne') || text.contains('saint-malo')) return (48.1173, -1.6778);
    if (text.contains('nantes') || text.contains('baule')) return (47.2184, -1.5536);
    if (text.contains('lyon')) return (45.7640, 4.8357);
    if (text.contains('toulouse')) return (43.6047, 1.4442);
    return (43.2965, 5.3698); // Défaut Méditerranée
  }

  String _getClubPhotoAsset(String name) {
    const beachPhotos = [
      'assets/images/beach_sunset_players_1785052273648.jpg',
      'assets/images/beach_tennis_racket_1785052259397.jpg',
      'assets/images/beach_court_aerial_1785052250131.jpg',
      'assets/images/beach_tennis_ball_1785052281869.jpg',
      'assets/images/hero_beach_tennis_1785051787379.jpg',
    ];
    int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return beachPhotos[hash.abs() % beachPhotos.length];
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, double marginBottom = 16}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: EdgeInsets.only(bottom: marginBottom),
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppState>().currentUser;
    if (currentUser == null) return const Scaffold();

    // Détection Président / Admin
    final firebaseEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';
    final isAppAdmin = currentUser.isAdmin == true;
    final isPresident = firebaseEmail.isNotEmpty && 
        widget.club.presidentEmails.map((e) => e.toLowerCase().trim()).contains(firebaseEmail);
    final canEditPhoto = isAppAdmin || isPresident;
    final isMember = widget.club.memberIds.contains(currentUser.id);
    final displayLocation = (widget.club.location.isEmpty || widget.club.location.toLowerCase().contains('recherche'))
        ? "France"
        : widget.club.location;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background plage & coucher de soleil
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.50),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Fiche du Club",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      // Bouton Partager / QR Code dans l'AppBar
                      IconButton(
                        icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 26),
                        tooltip: "Inviter / QR Code",
                        onPressed: () => showClubInviteDialog(
                          context,
                          clubId: widget.club.id,
                          clubName: widget.club.name,
                          bannerUrl: _currentBannerUrl,
                        ),
                      ),
                      if (!isPresident && !isAppAdmin)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMember ? Colors.white.withOpacity(0.25) : AppColors.coral,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                          ),
                          onPressed: () => _toggleMembership(currentUser.id),
                          child: Text(
                            isMember ? "Membre ✓" : "Rejoindre",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )
                      else if (isPresident)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withOpacity(0.6)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium, color: AppColors.gold, size: 14),
                              SizedBox(width: 4),
                              Text(
                                "Président 👑",
                                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Contenu scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Club (Logo + Nom + Ville)
                        _buildGlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Avatar / Logo du club (Cliquable par le Président / Admin pour changer la photo)
                              GestureDetector(
                                onTap: canEditPhoto ? _showChangePhotoBottomSheet : null,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE8604C).withOpacity(0.4),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          )
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: (_currentBannerUrl != null && _currentBannerUrl!.trim().isNotEmpty && _currentBannerUrl!.startsWith('http'))
                                            ? Image.network(
                                                _currentBannerUrl!.trim(),
                                                width: 84,
                                                height: 84,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Image.asset(
                                                  _getClubPhotoAsset(widget.club.name),
                                                  width: 84,
                                                  height: 84,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(Icons.sports_tennis, color: Colors.white, size: 36),
                                                  ),
                                                ),
                                              )
                                            : Image.asset(
                                                _getClubPhotoAsset(widget.club.name),
                                                width: 84,
                                                height: 84,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Center(
                                                  child: Icon(Icons.sports_tennis, color: Colors.white, size: 36),
                                                ),
                                              ),
                                      ),
                                    ),
                                    if (_isUploadingPhoto)
                                      Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withOpacity(0.5),
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                        ),
                                      ),
                                    if (canEditPhoto && !_isUploadingPhoto)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.coral,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (canEditPhoto)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: GestureDetector(
                                    onTap: _showChangePhotoBottomSheet,
                                    child: const Text(
                                      "Changer la photo",
                                      style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Text(
                                widget.club.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.location_on, color: AppColors.coral, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    displayLocation,
                                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Bouton d'invitation massive (WhatsApp & QR Code)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF008069), // WhatsApp Green
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.group_add_rounded, size: 18),
                                label: const Text(
                                  "Inviter des joueurs (WhatsApp & QR)",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                onPressed: () => showClubInviteDialog(
                                  context,
                                  clubId: widget.club.id,
                                  clubName: widget.club.name,
                                  bannerUrl: _currentBannerUrl,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Espace Président (si Admin ou Président)
                        if (isPresident || isAppAdmin)
                          _buildGlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.admin_panel_settings, color: AppColors.gold, size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Espace Président", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text("Gérez votre club et vos tournois", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => PresidentDashboardScreen(club: widget.club)));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    elevation: 0,
                                  ),
                                  child: const Text("Gérer", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),


                        // Widget Météo & Vent en direct pour le club
                        Builder(
                          builder: (context) {
                            final coords = _getClubCoordinates(displayLocation, widget.club.name);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: BeachWeatherWidget(
                                latitude: coords.$1,
                                longitude: coords.$2,
                              ),
                            );
                          },
                        ),

                        // 2 Cartes : Lieu & Membres
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.location_on,
                                title: "Lieu",
                                value: displayLocation,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.group,
                                title: "Membres",
                                value: "${widget.club.memberIds.length} joueur${widget.club.memberIds.length > 1 ? 's' : ''}",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // À propos du club
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppColors.gold, size: 18),
                                  SizedBox(width: 8),
                                  Text("À propos du club", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.club.description.isNotEmpty
                                    ? widget.club.description
                                    : "Bienvenue sur la fiche officielle du club. Rejoignez le club pour accéder au Chat interne et participer aux matchs !",
                                style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                        // Bouton Chat interne du club
                        if (isMember || isPresident || isAppAdmin) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.coral, Colors.orangeAccent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.coral.withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                              label: const Text(
                                "Chat interne du club",
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => GroupChatDetailScreen(
                                    clubId: widget.club.id,
                                    clubName: widget.club.name,
                                    clubBannerUrl: widget.club.bannerUrl,
                                  )),
                                );
                              },
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
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return _buildGlassCard(
      marginBottom: 0,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
