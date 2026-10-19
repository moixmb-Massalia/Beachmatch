import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../models/user.dart';
import '../providers/app_state.dart';
import '../services/chat_service.dart';
import 'public_profile_screen.dart';
import 'login_screen.dart';
import '../widgets/chat_enhancements.dart';

class ChatDetailScreen extends StatefulWidget {
  final UserModel otherUser;

  const ChatDetailScreen({super.key, required this.otherUser});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isSending = false;
  Map<String, dynamic>? _replyingTo;

  void _sendMessage(String currentUserId) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final reply = _replyingTo;
    setState(() {
      _isSending = true;
      _replyingTo = null;
    });
    _controller.clear();

    try {
      await _chatService.sendMessage(currentUserId, widget.otherUser.id, text, replyTo: reply);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur d'envoi du message.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source, String currentUserId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 75,
    );
    if (pickedFile == null) return;

    setState(() => _isSending = true);
    try {
      final file = File(pickedFile.path);
      final ext = pickedFile.name.split('.').last;
      final fileName = '${const Uuid().v4()}.$ext';
      final chatRoomId = _chatService.getChatRoomId(currentUserId, widget.otherUser.id);
      final ref = FirebaseStorage.instance.ref().child('chats/$chatRoomId/$fileName');

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      await _chatService.sendMessage(
        currentUserId,
        widget.otherUser.id,
        "",
        imageUrl: downloadUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'envoi de l'image : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showImagePickerOptions(BuildContext context, String currentUserId) {
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
                    child: const Icon(CupertinoIcons.camera_fill, color: AppColors.coral, size: 22),
                  ),
                  title: const Text("Prendre une photo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Ouvrir l'appareil photo", style: TextStyle(color: Colors.white60, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.camera, currentUserId);
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
                    child: const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: AppColors.gold, size: 22),
                  ),
                  title: const Text("Choisir dans la galerie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Envoyer une photo de votre pellicule", style: TextStyle(color: Colors.white60, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.gallery, currentUserId);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              child: Container(color: Colors.black.withValues(alpha: 0.9)),
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
                    return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                  },
                ),
              ),
            ),
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppState>().currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F141E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16253B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.otherUser.displayName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.lock_shield, size: 48, color: AppColors.coral),
                const SizedBox(height: 16),
                const Text("Connexion requise", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Veuillez vous connecter pour envoyer des messages.", style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
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

    final initial = widget.otherUser.displayName.isNotEmpty ? widget.otherUser.displayName[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Aerial Beach
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_court_aerial_1785052250131.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          // Dark Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Glassmorphism Top AppBar
                Padding(
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
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => PublicProfileScreen(player: widget.otherUser)),
                                );
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(colors: [AppColors.coral, AppColors.gold]),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                                    ),
                                    child: ClipOval(
                                      child: widget.otherUser.photoUrl != null && widget.otherUser.photoUrl!.isNotEmpty
                                          ? Image.network(widget.otherUser.photoUrl!, fit: BoxFit.cover)
                                          : Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.otherUser.displayName,
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      if (widget.otherUser.level > 0)
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppColors.gold.withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "Niveau ${widget.otherUser.level}",
                                                style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "• Voir profil",
                                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: const Color(0xFF1E293B),
                              onSelected: (value) async {
                                if (value == 'report') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Text("Signaler l'utilisateur", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      content: const Text("Êtes-vous sûr de vouloir signaler ce comportement ? Notre équipe va vérifier cette conversation.", style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler", style: TextStyle(color: Colors.white60))),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Signaler", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirm == true) {
                                    await FirebaseFirestore.instance.collection('reports').add({
                                      'reporterId': currentUser.id,
                                      'reportedUserId': widget.otherUser.id,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Signalement envoyé. Merci.")));
                                    }
                                  }
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Text("Supprimer la conversation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      content: const Text("Êtes-vous sûr de vouloir supprimer cette conversation de votre messagerie ?", style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler", style: TextStyle(color: Colors.white60))),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Supprimer", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirm == true) {
                                    await _chatService.deleteChat(currentUser.id, widget.otherUser.id);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                } else if (value == 'block') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Text("Bloquer cet utilisateur", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      content: const Text("Voulez-vous bloquer cet utilisateur ? Vous ne verrez plus ses messages et il ne pourra plus interagir avec vous.", style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler", style: TextStyle(color: Colors.white60))),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Bloquer", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    if (context.mounted) {
                                      await context.read<AppState>().blockUser(widget.otherUser.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur bloqué.")));
                                      }
                                    }
                                  }
                                } else if (value == 'unblock') {
                                  if (context.mounted) {
                                    await context.read<AppState>().unblockUser(widget.otherUser.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur débloqué.")));
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Row(
                                    children: [
                                      Icon(Icons.flag_rounded, color: Colors.orangeAccent, size: 18),
                                      SizedBox(width: 10),
                                      Text("Signaler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: context.read<AppState>().isUserBlocked(widget.otherUser.id) ? 'unblock' : 'block',
                                  child: Row(
                                    children: [
                                      Icon(
                                        context.read<AppState>().isUserBlocked(widget.otherUser.id) ? Icons.lock_open_rounded : Icons.block_rounded,
                                        color: context.read<AppState>().isUserBlocked(widget.otherUser.id) ? Colors.greenAccent : Colors.redAccent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        context.read<AppState>().isUserBlocked(widget.otherUser.id) ? "Débloquer" : "Bloquer",
                                        style: TextStyle(
                                          color: context.read<AppState>().isUserBlocked(widget.otherUser.id) ? Colors.greenAccent : Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      SizedBox(width: 10),
                                      Text("Supprimer", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Messages Stream
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getMessages(currentUser.id, widget.otherUser.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.white70)));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                      }

                      final messages = snapshot.data?.docs ?? [];

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
                                  child: Text(
                                    "Envoyez le premier message à ${widget.otherUser.displayName} pour organiser une partie ! 🎾",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          // reverse order for chat messages
                          final doc = messages[messages.length - 1 - index];
                          final msg = doc.data() as Map<String, dynamic>;
                          final isMe = msg['senderId'] == currentUser.id;
                          final text = msg['text'] as String? ?? "";
                          final imageUrl = msg['imageUrl'] as String?;
                          final dynamic rawTs = msg['timestamp'];
                          final DateTime? tsDate = rawTs is Timestamp
                              ? rawTs.toDate()
                              : (rawTs is String ? DateTime.tryParse(rawTs) : null);
                          final timeStr = tsDate != null ? DateFormat('HH:mm').format(tsDate) : "";

                          final chatRoomId = _chatService.getChatRoomId(currentUser.id, widget.otherUser.id);
                          final msgReactions = msg['reactions'] is Map ? (msg['reactions'] as Map).cast<String, dynamic>() : null;
                          final msgReplyTo = msg['replyTo'] is Map ? (msg['replyTo'] as Map).cast<String, dynamic>() : null;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onLongPress: () {
                                      ChatMessageActionsModal.show(
                                        context,
                                        text: text,
                                        senderName: isMe ? 'Vous' : widget.otherUser.displayName,
                                        isMe: isMe,
                                        onReactionSelected: (emoji) {
                                          _chatService.toggleReaction(
                                            chatRoomId: chatRoomId,
                                            messageId: doc.id,
                                            userId: currentUser.id,
                                            emoji: emoji,
                                          );
                                        },
                                        onReply: () {
                                          setState(() {
                                            _replyingTo = {
                                              'id': doc.id,
                                              'senderName': isMe ? 'Vous' : widget.otherUser.displayName,
                                              'text': text,
                                            };
                                          });
                                        },
                                        onDelete: () {
                                          _chatService.deleteMessage(chatRoomId, doc.id);
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
                                        border: isMe ? null : Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
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
                                          if (msgReplyTo != null)
                                            QuotedMessagePreview(
                                              replyTo: msgReplyTo,
                                              isMe: isMe,
                                            ),
                                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                            GestureDetector(
                                              onTap: () => _showFullScreenImage(context, imageUrl),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.network(
                                                  imageUrl,
                                                  width: 220,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Container(
                                                      width: 220,
                                                      height: 160,
                                                      color: Colors.black26,
                                                      child: const Center(
                                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (_, __, ___) => Container(
                                                    width: 220,
                                                    height: 100,
                                                    color: Colors.black26,
                                                    child: const Center(
                                                      child: Icon(Icons.broken_image_rounded, color: Colors.white60, size: 32),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (text.isNotEmpty) const SizedBox(height: 6),
                                          ],
                                          if (text.isNotEmpty)
                                            Text(
                                              text,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                height: 1.3,
                                              ),
                                            ),
                                          if (timeStr.isNotEmpty) ...[
                                            const SizedBox(height: 3),
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
                                  ChatReactionsRow(
                                    reactions: msgReactions,
                                    currentUserId: currentUser.id,
                                    isMe: isMe,
                                    onReactionTapped: (emoji) {
                                      _chatService.toggleReaction(
                                        chatRoomId: chatRoomId,
                                        messageId: doc.id,
                                        userId: currentUser.id,
                                        emoji: emoji,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Floating Input Bar Glass or Blocked Banner
                if (context.watch<AppState>().isUserBlocked(widget.otherUser.id))
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.block_rounded, color: Colors.redAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Cet utilisateur est bloqué.",
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.read<AppState>().unblockUser(widget.otherUser.id),
                          child: const Text("Débloquer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(_chatService.getChatRoomId(currentUser.id, widget.otherUser.id))
                        .snapshots(),
                    builder: (context, chatSnap) {
                      final chatData = (chatSnap.hasData && chatSnap.data!.exists)
                          ? chatSnap.data!.data() as Map<String, dynamic>?
                          : null;
                      final isPending = chatData != null && chatData['status'] == 'pending';
                      final isIncomingRequest = isPending && chatData['requestReceiverId'] == currentUser.id;
                      final isOutgoingRequest = isPending && chatData['requestSenderId'] == currentUser.id;

                      if (isIncomingRequest) {
                        return _buildIncomingRequestBottomBar(context, currentUser);
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOutgoingRequest)
                            _buildOutgoingRequestNotice(context),
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
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(CupertinoIcons.camera_fill, color: Colors.white70, size: 22),
                                        onPressed: _isSending ? null : () => _showImagePickerOptions(context, currentUser.id),
                                        tooltip: "Envoyer une photo",
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _controller,
                                          style: const TextStyle(color: Colors.white, fontSize: 15),
                                          decoration: const InputDecoration(
                                            hintText: "Écrire un message...",
                                            hintStyle: TextStyle(color: Colors.white60),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                          ),
                                          onSubmitted: (_) => _sendMessage(currentUser.id),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: _isSending ? null : () => _sendMessage(currentUser.id),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [AppColors.coral, AppColors.gold],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: _isSending
                                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                : const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 22),
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
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingRequestNotice(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.hourglass, color: Colors.amber, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Demande envoyée — En attente que ${widget.otherUser.displayName} accepte votre message.",
              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestBottomBar(BuildContext context, UserModel currentUser) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16253B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.envelope_badge_fill, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "DEMANDE DE MESSAGE",
                      style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
                    ),
                    Text(
                      "${widget.otherUser.displayName} souhaite échanger avec vous",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Consultez son profil avant d'accepter. Si vous refusez, cette discussion sera supprimée.",
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Bouton Profil
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PublicProfileScreen(player: widget.otherUser)),
                  );
                },
                icon: const Icon(CupertinoIcons.person_crop_circle, size: 14, color: Colors.white70),
                label: const Text("Profil", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 8),
              // Bouton Refuser
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF16253B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text("Refuser la demande ?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        content: Text(
                          "Voulez-vous refuser la demande de ${widget.otherUser.displayName} ? Cette discussion sera supprimée.",
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Refuser", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _chatService.rejectMessageRequest(currentUser.id, widget.otherUser.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Demande de ${widget.otherUser.displayName} refusée."),
                            backgroundColor: const Color(0xFF16253B),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(CupertinoIcons.xmark_circle, size: 14, color: Colors.redAccent),
                  label: const Text("Refuser", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bouton Accepter
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _chatService.acceptMessageRequest(currentUser.id, widget.otherUser.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Demande de ${widget.otherUser.displayName} acceptée !"),
                          backgroundColor: const Color(0xFF16253B),
                        ),
                      );
                    }
                  },
                  icon: const Icon(CupertinoIcons.checkmark_alt_circle_fill, size: 14, color: Colors.black),
                  label: const Text("Accepter", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
