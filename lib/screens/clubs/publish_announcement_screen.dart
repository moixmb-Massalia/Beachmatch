import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/club.dart';
import '../../providers/app_state.dart';
import '../../theme/colors.dart';
import '../../services/chat_service.dart';

class PublishAnnouncementScreen extends StatefulWidget {
  final ClubModel club;

  const PublishAnnouncementScreen({super.key, required this.club});

  @override
  State<PublishAnnouncementScreen> createState() => _PublishAnnouncementScreenState();
}

class _PublishAnnouncementScreenState extends State<PublishAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _pinToTavern = true;
  bool _sendPushNotification = true;
  bool _isPublishing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _publishAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = context.read<AppState>().currentUser;
    if (currentUser == null) return;

    setState(() => _isPublishing = true);

    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      final chatRoomId = 'club_${widget.club.id}';

      // 1. Si épinglé, on met à jour le champ pinnedAnnouncement du chat
      if (_pinToTavern) {
        await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).set({
          'pinnedAnnouncement': {
            'title': title,
            'content': content,
            'authorId': currentUser.id,
            'authorName': currentUser.displayName,
            'createdAt': FieldValue.serverTimestamp(),
            'isPinned': true,
          }
        }, SetOptions(merge: true));
      }

      // 2. Poster le message d'annonce officiel dans la Taverne
      final chatService = ChatService();
      final formattedMessage = "📢 ANNONCE OFFICIELLE\n\n📌 $title\n\n$content";
      await chatService.sendGroupMessage(
        widget.club.id,
        currentUser.id,
        "👑 ${currentUser.displayName} (Président)",
        formattedMessage,
        widget.club.name,
        widget.club.bannerUrl,
      );

      // 3. Si notification push cochée, enregistrer l'alerte pour les membres
      if (_sendPushNotification) {
        final notificationsRef = FirebaseFirestore.instance.collection('notifications');
        for (final memberId in widget.club.memberIds) {
          if (memberId != currentUser.id) {
            await notificationsRef.add({
              'userId': memberId,
              'title': "📢 ${widget.club.name} : $title",
              'body': content,
              'type': 'club_announcement',
              'clubId': widget.club.id,
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Annonce diffusée et épinglée dans le Chat interne du club ! 📢✨"),
            backgroundColor: Color(0xFF008069),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la diffusion : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Faire une Annonce",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo plage 100% plein écran
          Image.asset(
            'assets/images/beach_court_aerial_1785052250131.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          // Voile sombre dégradé cinéma intégral
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.60),
                  Colors.black.withOpacity(0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Badge du club
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign_rounded, color: AppColors.gold, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.club.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Text(
                                  "Diffusion officielle aux membres",
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Champ Titre
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Titre de l'annonce",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _titleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Ex : Entraînement de ce soir, Tournoi...",
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? "Veuillez entrer un titre" : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Champ Message
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Message / Consignes",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _contentController,
                            maxLines: 5,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Détaillez votre annonce pour l'ensemble des beacheurs du club...",
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? "Veuillez entrer le contenu de l'annonce" : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Options : Épingler & Push
                    _buildGlassCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Row(
                              children: [
                                Icon(Icons.push_pin_rounded, color: AppColors.gold, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Épingler en haut du Chat interne",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            subtitle: const Text(
                              "Affiche un bandeau d'alerte en haut du chat visible par tous",
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            value: _pinToTavern,
                            activeColor: AppColors.gold,
                            onChanged: (val) => setState(() => _pinToTavern = val),
                          ),
                          const Divider(color: Colors.white12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Row(
                              children: [
                                Icon(Icons.notifications_active_rounded, color: AppColors.coral, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Envoyer une notification Push",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            subtitle: const Text(
                              "Alerter instantanément les téléphones de tous les membres",
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            value: _sendPushNotification,
                            activeColor: AppColors.coral,
                            onChanged: (val) => setState(() => _sendPushNotification = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton de diffusion
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: _isPublishing ? null : _publishAnnouncement,
                      child: _isPublishing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  "Diffuser l'Annonce",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
