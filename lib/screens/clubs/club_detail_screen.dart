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
import '../../models/user.dart';
import '../public_profile_screen.dart';
import '../login_screen.dart';

class ClubDetailScreen extends StatefulWidget {
  final ClubModel club;
  
  const ClubDetailScreen({super.key, required this.club});

  static Future<void> open(BuildContext context, String clubId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('clubs').doc(clubId).get();
      if (doc.exists && doc.data() != null && context.mounted) {
        final club = ClubModel.fromMap(doc.data()!, doc.id);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClubDetailScreen(club: club)),
        );
      }
    } catch (e) {
      debugPrint("Erreur ouverture club: $e");
    }
  }

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
                decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.15), shape: BoxShape.circle),
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
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
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
    
    // Villes et Arènes du Brésil 🇧🇷
    if (text.contains('fortaleza') || text.contains('ceará') || text.contains('ceara')) return (-3.7319, -38.5267);
    if (text.contains('são paulo') || text.contains('sao paulo')) return (-23.5505, -46.6333);
    if (text.contains('rio') || text.contains('copacabana') || text.contains('ipanema')) return (-22.9068, -43.1729);
    if (text.contains('cuiabá') || text.contains('cuiaba')) return (-15.6014, -56.0979);
    if (text.contains('brasília') || text.contains('brasilia')) return (-15.7975, -47.8919);
    if (text.contains('santos') || text.contains('gonzaga')) return (-23.9618, -46.3322);
    if (text.contains('curitiba')) return (-25.4284, -49.2733);
    if (text.contains('florianópolis') || text.contains('florianopolis') || text.contains('camboriú') || text.contains('camboriu')) return (-27.5954, -48.5480);
    if (text.contains('salvador')) return (-12.9777, -38.5016);
    if (text.contains('belo horizonte')) return (-19.9245, -43.9352);
    if (text.contains('palmas')) return (-10.1847, -48.3336);
    if (text.contains('porto alegre')) return (-30.0346, -51.2177);
    if (text.contains('bresil') || text.contains('brasil') || text.contains('cbt') || widget.club.country == 'BR') return (-15.7801, -47.9292);

    // France 🇫🇷
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
    if (text.contains('frontignan') || text.contains('sète') || text.contains('sete')) return (43.4494, 3.7546);
    return (43.2965, 5.3698); // Défaut Méditerranée
  }

  String _getClubPhotoAsset(String name) => ClubModel.getClubPhotoAsset(name);

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, double marginBottom = 16}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: EdgeInsets.only(bottom: marginBottom),
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppState>().currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.club.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_tennis, size: 48, color: AppColors.gold),
                const SizedBox(height: 16),
                const Text("Connexion requise", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Connectez-vous pour voir les membres et activités du club.", style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text("Se connecter"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Détection Président / Admin
    final firebaseEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';
    final isAppAdmin = currentUser.isAdmin == true;
    final isPresident = isAppAdmin ||
        (widget.club.adminId.isNotEmpty && widget.club.adminId == currentUser.id) ||
        (firebaseEmail.isNotEmpty && 
            widget.club.presidentEmails.map((e) => e.toLowerCase().trim()).contains(firebaseEmail));
    final canEditPhoto = isPresident;
    final isMember = widget.club.memberIds.contains(currentUser.id);
    final isBrClub = widget.club.country == 'BR' || widget.club.location.toLowerCase().contains('brasil') || widget.club.location.toLowerCase().contains('brésil');
    final displayLocation = (widget.club.location.isEmpty || widget.club.location.toLowerCase().contains('recherche'))
        ? (isBrClub ? "Brasil" : "France")
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
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.50),
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
                      Text(
                        isBrClub ? "Arena Oficial" : "Fiche du Club",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                            backgroundColor: isMember ? Colors.white.withValues(alpha: 0.25) : AppColors.coral,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                          ),
                          onPressed: () => _toggleMembership(currentUser.id),
                          child: Text(
                            isMember ? (isBrClub ? "Membro ✓" : "Membre ✓") : (isBrClub ? "Participar" : "Rejoindre"),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )
                      else if (isPresident)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium, color: AppColors.gold, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                isBrClub ? "Gestor / Dono 👑" : "Président 👑",
                                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
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
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE8604C).withValues(alpha: 0.4),
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
                                                  cacheWidth: 200,
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
                                                cacheWidth: 200,
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
                                          color: Colors.black.withValues(alpha: 0.5),
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
                                                color: Colors.black.withValues(alpha: 0.3),
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
                                    color: AppColors.gold.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.admin_panel_settings, color: AppColors.gold, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(isBrClub ? "Painel do Gestor" : "Espace Président", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text(isBrClub ? "Gerencie sua arena e torneios" : "Gérez votre club et vos tournois", style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                                  child: Text(isBrClub ? "Gerenciar" : "Gérer", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                title: isBrClub ? "Localização" : "Lieu",
                                value: displayLocation,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.group,
                                title: isBrClub ? "Atletas" : "Membres",
                                value: isBrClub
                                    ? "${widget.club.memberIds.length} atleta${widget.club.memberIds.length > 1 ? 's' : ''}"
                                    : "${widget.club.memberIds.length} joueur${widget.club.memberIds.length > 1 ? 's' : ''}",
                                onTap: () => _showMembersBottomSheet(context),
                                subtitleHint: isBrClub ? "Ver atletas →" : "Voir la liste →",
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
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, color: AppColors.gold, size: 18),
                                  const SizedBox(width: 8),
                                  Text(isBrClub ? "Sobre a arena" : "À propos du club", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.club.description.isNotEmpty
                                    ? widget.club.description
                                    : (isBrClub
                                        ? "Bem-vindo à página oficial da arena. Participe para acessar o chat e marcar jogos !"
                                        : "Bienvenue sur la fiche officielle du club. Rejoignez le club pour accéder au Chat interne et participer aux matchs !"),
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
                                  color: AppColors.coral.withValues(alpha: 0.4),
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
                              label: Text(
                                isBrClub ? "Chat & Resenha da Arena" : "Chat interne du club",
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

  Future<List<UserModel>> _fetchClubMembers() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final allKnown = {for (var p in appState.players) p.id: p};
    if (appState.currentUser != null) {
      allKnown[appState.currentUser!.id] = appState.currentUser!;
    }

    final List<UserModel> result = [];
    final List<String> missingIds = [];

    for (final id in widget.club.memberIds) {
      if (allKnown.containsKey(id)) {
        result.add(allKnown[id]!);
      } else {
        missingIds.add(id);
      }
    }

    if (missingIds.isNotEmpty) {
      for (int i = 0; i < missingIds.length; i += 30) {
        final chunk = missingIds.sublist(i, (i + 30 > missingIds.length) ? missingIds.length : i + 30);
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            result.add(UserModel.fromMap(doc.data(), doc.id));
          }
        } catch (e) {
          debugPrint("Erreur chargement membres club: $e");
        }
      }
    }

    // Sort: President first, then by level desc, then displayName
    result.sort((a, b) {
      final aIsAdmin = widget.club.adminId == a.id;
      final bIsAdmin = widget.club.adminId == b.id;
      if (aIsAdmin && !bIsAdmin) return -1;
      if (!aIsAdmin && bIsAdmin) return 1;
      if (b.level != a.level) return b.level.compareTo(a.level);
      return a.displayName.compareTo(b.displayName);
    });

    return result;
  }

  void _showMembersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetContext, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF161F30),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group_rounded, color: AppColors.coral, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Membres de ${widget.club.name}",
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "${widget.club.memberIds.length} joueur${widget.club.memberIds.length > 1 ? 's' : ''} inscrit${widget.club.memberIds.length > 1 ? 's' : ''}",
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: FutureBuilder<List<UserModel>>(
                      future: _fetchClubMembers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                        }
                        final members = snapshot.data ?? [];
                        if (members.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text(
                                "Aucun membre inscrit dans ce club pour l'instant.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white60, fontSize: 14),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: members.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final player = members[index];
                            final bool isClubAdmin = widget.club.adminId == player.id;
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isClubAdmin ? AppColors.gold.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.coral.withValues(alpha: 0.3),
                                      backgroundImage: (player.photoUrl != null && player.photoUrl!.isNotEmpty)
                                          ? NetworkImage(player.photoUrl!)
                                          : null,
                                      child: (player.photoUrl == null || player.photoUrl!.isEmpty)
                                          ? Text(
                                              player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    if (isClubAdmin)
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: AppColors.gold,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.star, size: 10, color: Colors.black),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        player.displayName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isClubAdmin) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                                        ),
                                        child: const Text("Admin 👑", style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "Niv. ${player.level}",
                                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      if (player.isLookingForPartner) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.tealAccent.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            "Cherche part.",
                                            style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => PublicProfileScreen(player: player)),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
    String? subtitleHint,
  }) {
    final card = _buildGlassCard(
      marginBottom: 0,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.3), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 13),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (subtitleHint != null) ...[
            const SizedBox(height: 4),
            Text(subtitleHint, style: const TextStyle(color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}
