import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/tournament.dart';
import '../../models/user.dart';
import '../../providers/app_state.dart';
import '../../services/chat_service.dart';
import '../../theme/colors.dart';
import '../../widgets/chat_enhancements.dart';
import '../public_profile_screen.dart';

class TournamentChatScreen extends StatefulWidget {
  final TournamentModel tournament;

  const TournamentChatScreen({super.key, required this.tournament});

  @override
  State<TournamentChatScreen> createState() => _TournamentChatScreenState();
}

class _TournamentChatScreenState extends State<TournamentChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isSending = false;
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final user = context.read<AppState>().currentUser;
        if (user != null) {
          _chatService.joinTournamentChat(user.id, widget.tournament.id, widget.tournament.name);
        }
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage(UserModel currentUser) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final reply = _replyingTo;
    setState(() {
      _isSending = true;
      _replyingTo = null;
    });
    _textController.clear();

    try {
      await _chatService.sendTournamentMessage(
        widget.tournament.id,
        currentUser.id,
        currentUser.displayName,
        text,
        widget.tournament.name,
        replyTo: reply,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de l'envoi du message.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendMedia({required bool isVideo, required UserModel currentUser}) async {
    final picker = ImagePicker();
    XFile? pickedFile;

    if (isVideo) {
      pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
    } else {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
    }

    if (pickedFile == null) return;

    setState(() => _isSending = true);
    try {
      final file = File(pickedFile.path);
      final ext = pickedFile.name.split('.').last;
      final fileName = '${const Uuid().v4()}.$ext';
      final folder = isVideo ? 'videos' : 'photos';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chats/tournament_${widget.tournament.id}/$folder/$fileName');

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      await _chatService.sendTournamentMessage(
        widget.tournament.id,
        currentUser.id,
        currentUser.displayName,
        "",
        widget.tournament.name,
        imageUrl: isVideo ? null : downloadUrl,
        videoUrl: isVideo ? downloadUrl : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'envoi du média : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMediaPickerOptions(BuildContext context, UserModel currentUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF16253B).withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: AppColors.coral, size: 22),
                  ),
                  title: const Text("Partager des photos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Podium, matchs, moments forts du tournoi", style: TextStyle(color: Colors.white60, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendMedia(isVideo: false, currentUser: currentUser);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.video_camera_solid, color: AppColors.gold, size: 22),
                  ),
                  title: const Text("Partager une vidéo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Balles de match, smashs, ambiance", style: TextStyle(color: Colors.white60, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendMedia(isVideo: true, currentUser: currentUser);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPollDialog(UserModel currentUser) {
    final questionController = TextEditingController();
    final option1Controller = TextEditingController(text: "Présent ! 🎾");
    final option2Controller = TextEditingController(text: "Pas dispo");
    final option3Controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16253B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.poll_rounded, color: AppColors.gold),
            SizedBox(width: 8),
            Text("Créer un sondage", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Question du sondage",
                  labelStyle: TextStyle(color: AppColors.gold),
                  hintText: "Ex: Qui participe à la consolante ?",
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: option1Controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Option 1",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: option2Controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Option 2",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: option3Controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Option 3 (facultative)",
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final q = questionController.text.trim();
              final o1 = option1Controller.text.trim();
              final o2 = option2Controller.text.trim();
              final o3 = option3Controller.text.trim();

              if (q.isEmpty || o1.isEmpty || o2.isEmpty) return;
              Navigator.pop(ctx);

              final options = [o1, o2];
              if (o3.isNotEmpty) options.add(o3);

              final pollData = {
                'question': q,
                'options': options,
                'votes': {},
                'createdAt': FieldValue.serverTimestamp(),
              };

              await _chatService.sendTournamentMessage(
                widget.tournament.id,
                currentUser.id,
                currentUser.displayName,
                "",
                widget.tournament.name,
                poll: pollData,
              );
            },
            child: const Text("Publier", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _votePoll(String messageId, int optionIndex, String currentUserId) async {
    HapticFeedback.selectionClick();
    final chatRoomId = _chatService.getTournamentChatRoomId(widget.tournament.id);
    final docRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    final snap = await docRef.get();
    if (!snap.exists) return;

    final poll = Map<String, dynamic>.from(snap.data()?['poll'] ?? {});
    final votes = Map<String, dynamic>.from(poll['votes'] ?? {});

    votes[currentUserId] = optionIndex;
    poll['votes'] = votes;

    await docRef.update({'poll': poll});
  }

  Future<void> _saveOrShareImage(BuildContext context, String imageUrl) async {
    HapticFeedback.mediumImpact();
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text("Préparation de la photo..."),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      final response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;

      final tempDir = await getTemporaryDirectory();
      final fileName = 'BeachMatch_${widget.tournament.category}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Ouvrir la feuille de partage officielle iOS / Android
      // Permet d'enregistrer dans Photos / Pellicule en 1 clic ou d'envoyer par WhatsApp
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: "Photo du tournoi ${widget.tournament.name} (${widget.tournament.category}) sur BeachMatch 🎾",
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Prêt ! Vous pouvez l'enregistrer dans vos photos ou l'envoyer."),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'enregistrement : $e")),
        );
      }
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.black.withValues(alpha: 0.92)),
            ),
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: AppColors.gold));
                  },
                ),
              ),
            ),
            // Barre d'actions supérieure avec Enregistrer / Partager
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white70, size: 30),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        "Enregistrer / Sauvegarder",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      onPressed: () => _saveOrShareImage(context, imageUrl),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUserProfile(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null && mounted) {
        final user = UserModel.fromMap(doc.data()!, doc.id);
        Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(player: user)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppState>().currentUser;
    if (currentUser == null) return const Scaffold();

    final chatRoomId = _chatService.getTournamentChatRoomId(widget.tournament.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Arrière-plan
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
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                _buildInfoBanner(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getTournamentMessages(widget.tournament.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.gold));
                      }

                      final messages = snapshot.data?.docs.reversed.toList() ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.forum_rounded, color: AppColors.gold, size: 36),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Bienvenue sur le chat du tournoi ${widget.tournament.name} ! 🏆",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        "Posez vos questions sur les horaires, lancez des sondages et partagez vos photos de matchs !",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final doc = messages[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final messageId = doc.id;
                          final isMe = data['senderId'] == currentUser.id;
                          final senderName = data['senderName'] ?? "Joueur";

                          return _buildMessageItem(data, messageId, isMe, senderName, currentUser.id, chatRoomId);
                        },
                      );
                    },
                  ),
                ),
                _buildInputBar(currentUser),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.gold, AppColors.goldDark]),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.emoji_events_rounded, color: Color(0xFF0F172A), size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.tournament.name,
                              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.tournament.category,
                              style: const TextStyle(color: AppColors.gold, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${widget.tournament.club} · ${widget.tournament.location}",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.photo_library_rounded, color: AppColors.gold, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Partagez vos photos & vidéos ! Appuyez sur une image pour l'enregistrer sur votre téléphone.",
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(
    Map<String, dynamic> data,
    String messageId,
    bool isMe,
    String senderName,
    String currentUserId,
    String chatRoomId,
  ) {
    final text = data['text'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final videoUrl = data['videoUrl'] as String?;
    final poll = data['poll'] as Map<String, dynamic>?;
    final timestamp = data['timestamp'] as Timestamp?;
    final timeStr = timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';
    final replyTo = data['replyTo'] as Map<String, dynamic>?;
    final reactions = data['reactions'] as Map<String, dynamic>?;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              GestureDetector(
                onTap: () => _openUserProfile(data['senderId'] ?? ''),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    senderName,
                    style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Sondage ou Bulle Standard
            if (poll != null)
              _buildPollCard(poll, messageId, currentUserId, isMe, timeStr)
            else
              GestureDetector(
                onLongPress: () {
                  ChatMessageActionsModal.show(
                    context,
                    text: text,
                    senderName: isMe ? 'Vous' : senderName,
                    isMe: isMe,
                    onReactionSelected: (emoji) {
                      _chatService.toggleReaction(
                        chatRoomId: chatRoomId,
                        messageId: messageId,
                        userId: currentUserId,
                        emoji: emoji,
                      );
                    },
                    onReply: () {
                      setState(() {
                        _replyingTo = {
                          'id': messageId,
                          'senderName': isMe ? 'Vous' : senderName,
                          'text': text.isNotEmpty ? text : (imageUrl != null ? '📷 Photo' : '🎥 Vidéo'),
                        };
                      });
                    },
                    onDelete: () {
                      _chatService.deleteMessage(chatRoomId, messageId);
                    },
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [AppColors.coral, Color(0xFFFF7A59)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18).copyWith(
                      bottomRight: isMe ? const Radius.circular(3) : const Radius.circular(18),
                      bottomLeft: !isMe ? const Radius.circular(3) : const Radius.circular(18),
                    ),
                    border: isMe ? null : Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (replyTo != null)
                        QuotedMessagePreview(replyTo: replyTo, isMe: isMe),

                      // Image
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => _showFullScreenImage(context, imageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Image.network(
                                  imageUrl,
                                  width: 230,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, child, prog) => prog == null
                                      ? child
                                      : Container(
                                          width: 230,
                                          height: 160,
                                          color: Colors.black26,
                                          child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                        ),
                                ),
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.download_rounded, color: Colors.white, size: 12),
                                        SizedBox(width: 3),
                                        Text("Enregistrer", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (text.isNotEmpty) const SizedBox(height: 6),
                      ],

                      // Vidéo
                      if (videoUrl != null && videoUrl.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse(videoUrl)),
                          child: Container(
                            width: 230,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.play_circle_fill_rounded, color: AppColors.gold, size: 36),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("🎥 Vidéo du tournoi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text("Appuyer pour lire", style: TextStyle(color: Colors.white60, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (text.isNotEmpty) const SizedBox(height: 6),
                      ],

                      // Texte
                      if (text.isNotEmpty)
                        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35)),

                      // Timestamp & Double Coche
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Réactions Emojis sous la bulle
            ChatReactionsRow(
              reactions: reactions,
              currentUserId: currentUserId,
              isMe: isMe,
              onReactionTapped: (emoji) {
                _chatService.toggleReaction(
                  chatRoomId: chatRoomId,
                  messageId: messageId,
                  userId: currentUserId,
                  emoji: emoji,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll, String messageId, String currentUserId, bool isMe, String timeStr) {
    final question = poll['question'] as String? ?? 'Sondage';
    final options = List<String>.from(poll['options'] ?? []);
    final votes = Map<String, dynamic>.from(poll['votes'] ?? {});

    final optionCounts = List<int>.filled(options.length, 0);
    int totalVotes = 0;
    votes.forEach((userId, optionIndex) {
      final idx = optionIndex is int ? optionIndex : int.tryParse(optionIndex.toString()) ?? -1;
      if (idx >= 0 && idx < options.length) {
        optionCounts[idx]++;
        totalVotes++;
      }
    });

    final myVoteRaw = votes[currentUserId];
    final myVote = myVoteRaw is int ? myVoteRaw : int.tryParse(myVoteRaw.toString()) ?? -1;

    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomRight: isMe ? const Radius.circular(3) : const Radius.circular(16),
          bottomLeft: !isMe ? const Radius.circular(3) : const Radius.circular(16),
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.poll_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: 6),
                const Text("SONDAGE DU TOURNOI", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 11)),
                const Spacer(),
                Text("$totalVotes vote${totalVotes > 1 ? 's' : ''}", style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Text(question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
          ),
          ...List.generate(options.length, (index) {
            final count = optionCounts[index];
            final percent = totalVotes > 0 ? count / totalVotes : 0.0;
            final isMyVote = myVote == index;

            return InkWell(
              onTap: () => _votePoll(messageId, index, currentUserId),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isMyVote ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isMyVote ? AppColors.gold : Colors.white38,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            options[index],
                            style: TextStyle(
                              color: isMyVote ? Colors.white : Colors.white70,
                              fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          "${(percent * 100).round()}% ($count)",
                          style: TextStyle(color: isMyVote ? AppColors.gold : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(isMyVote ? AppColors.gold : AppColors.coral),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(UserModel currentUser) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: ActiveReplyBanner(
                replyTo: _replyingTo!,
                onCancel: () => setState(() => _replyingTo = null),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Row(
                  children: [
                    // Bouton Photos & Vidéos
                    IconButton(
                      icon: const Icon(CupertinoIcons.camera_fill, color: AppColors.gold, size: 21),
                      tooltip: "Partager photo ou vidéo",
                      onPressed: _isSending ? null : () => _showMediaPickerOptions(context, currentUser),
                    ),
                    // Bouton Sondage
                    IconButton(
                      icon: const Icon(Icons.poll_rounded, color: AppColors.coral, size: 21),
                      tooltip: "Lancer un sondage",
                      onPressed: _isSending ? null : () => _showPollDialog(currentUser),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5),
                        decoration: const InputDecoration(
                          hintText: "Message du tournoi...",
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 13.5),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(currentUser),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _isSending ? null : () => _sendMessage(currentUser),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.gold, AppColors.goldDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _isSending
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Icon(CupertinoIcons.arrow_up, color: Color(0xFF0F172A), size: 21),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
