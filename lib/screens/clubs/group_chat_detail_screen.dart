import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/app_state.dart';
import '../../services/chat_service.dart';
import '../../theme/colors.dart';
import '../../models/user.dart';
import '../../widgets/club_invite_dialog.dart';
import '../public_profile_screen.dart';

class GroupChatDetailScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String? clubBannerUrl;

  const GroupChatDetailScreen({
    super.key, 
    required this.clubId,
    required this.clubName,
    this.clubBannerUrl,
  });

  @override
  State<GroupChatDetailScreen> createState() => _GroupChatDetailScreenState();
}

class _GroupChatDetailScreenState extends State<GroupChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isSending = false;
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  void _sendMessage(UserModel currentUser) async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _chatService.sendGroupMessage(
        widget.clubId, 
        currentUser.id,
        currentUser.displayName, 
        _controller.text.trim(),
        widget.clubName,
        widget.clubBannerUrl,
      );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'envoi.")));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage(UserModel currentUser) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() => _isSending = true);
    try {
      final file = File(pickedFile.path);
      final ext = pickedFile.name.split('.').last;
      final fileName = '${const Uuid().v4()}.$ext';
      final ref = FirebaseStorage.instance.ref().child('chats/${widget.clubId}/$fileName');
      
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      await _chatService.sendGroupMessage(
        widget.clubId, 
        currentUser.id,
        currentUser.displayName, 
        "",
        widget.clubName,
        widget.clubBannerUrl,
        imageUrl: downloadUrl,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur d'envoi de l'image.")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _openUserProfile(String userId) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.coral)));
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (mounted) Navigator.pop(context); 
      
      if (doc.exists && doc.data() != null) {
        final user = UserModel.fromMap(doc.data()!, doc.id);
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(player: user)));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible de charger le profil.")));
      }
    }
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

  void _confirmDeleteChat(BuildContext context, UserModel currentUser) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16253B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.coral),
            SizedBox(width: 8),
            Text("Supprimer la discussion", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Voulez-vous retirer le chat de '${widget.clubName}' de votre boîte de réception ?",
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _chatService.deleteChat(currentUser.id, '', isGroup: true, clubId: widget.clubId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Chat '${widget.clubName}' retiré de vos messages."),
                    backgroundColor: const Color(0xFF16253B),
                  ),
                );
              }
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppState>().currentUser;
    if (currentUser == null) return const Scaffold();

    final photoAsset = _getClubPhotoAsset(widget.clubName);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
              ),
              child: ClipOval(
                child: (widget.clubBannerUrl != null && widget.clubBannerUrl!.trim().isNotEmpty && widget.clubBannerUrl!.startsWith('http'))
                    ? Image.network(
                        widget.clubBannerUrl!.trim(),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          photoAsset,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.sports_tennis, color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    : Image.asset(
                        photoAsset,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.sports_tennis, color: Colors.white, size: 20),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Chat interne du club", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(widget.clubName, style: const TextStyle(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded, color: Colors.white),
            tooltip: "Inviter des joueurs",
            onPressed: () => showClubInviteDialog(
              context,
              clubId: widget.clubId,
              clubName: widget.clubName,
              bannerUrl: widget.clubBannerUrl,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF16253B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'invite') {
                showClubInviteDialog(
                  context,
                  clubId: widget.clubId,
                  clubName: widget.clubName,
                  bannerUrl: widget.clubBannerUrl,
                );
              } else if (value == 'delete') {
                _confirmDeleteChat(context, currentUser);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.group_add_rounded, color: AppColors.gold, size: 20),
                    SizedBox(width: 10),
                    Text("Inviter des joueurs", style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text("Supprimer la discussion", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Bandeau Annonce Épinglée par le Président
          _buildPinnedAnnouncementBanner(currentUser),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(currentUser.id, '', isGroup: true, clubId: widget.clubId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                }
                
                final messages = snapshot.data?.docs.reversed.toList() ?? [];
                
                if (messages.isEmpty) {
                  return const Center(child: Text("Bienvenue dans le Chat interne du club !\nSoyez le premier à envoyer un message.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, height: 1.5)));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final messageId = messages[index].id;
                    final isMe = data['senderId'] == currentUser.id;
                    final senderName = data['senderName'] ?? "Joueur Inconnu";
                    
                    return _buildMessageBubble(data, messageId, isMe, senderName, currentUser.id);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(currentUser),
        ],
      ),
    );
  }

  Widget _buildPinnedAnnouncementBanner(UserModel currentUser) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc('club_${widget.clubId}').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final chatData = snapshot.data!.data() as Map<String, dynamic>?;
        if (chatData == null) return const SizedBox.shrink();
        
        final pinned = chatData['pinnedAnnouncement'] as Map<String, dynamic>?;
        if (pinned == null || pinned['isPinned'] != true) return const SizedBox.shrink();

        final title = pinned['title'] as String? ?? "Annonce";
        final content = pinned['content'] as String? ?? "";
        final authorName = pinned['authorName'] as String? ?? "Président";

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF4A535).withOpacity(0.22),
                const Color(0xFFE8604C).withOpacity(0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.push_pin_rounded, color: AppColors.gold, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Row(
                          children: [
                            const Icon(Icons.campaign_rounded, color: AppColors.gold),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                            const SizedBox(height: 14),
                            Text("Publié par $authorName", style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Fermer", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        content,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Bouton Désépingler
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                tooltip: "Désépingler",
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('chats').doc('club_${widget.clubId}').set({
                    'pinnedAnnouncement': {
                      'isPinned': false,
                    }
                  }, SetOptions(merge: true));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Annonce désépinglée")),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildMessageBubble(Map<String, dynamic> data, String messageId, bool isMe, String senderName, String currentUserId) {
    final text = data['text'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final poll = data['poll'] as Map<String, dynamic>?;
    final timestamp = data['timestamp'] as Timestamp?;
    final timeStr = timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';

    if (poll != null) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                GestureDetector(
                  onTap: () => _openUserProfile(data['senderId'] ?? ''),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                    child: Text(senderName, style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  ),
                ),
              _buildPollWidget(poll, messageId, currentUserId, isMe, timeStr),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              GestureDetector(
                onTap: () => _openUserProfile(data['senderId'] ?? ''),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                  child: Text(senderName, style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.coral : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                  bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(imageUrl, width: 200, fit: BoxFit.cover),
                      ),
                    ),
                  if (data['audioUrl'] != null)
                    _buildAudioWidget(data['audioUrl'] as String, isMe),
                  if (text.isNotEmpty)
                    Text(text, style: TextStyle(color: isMe ? Colors.white : AppColors.textMain, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(timeStr, style: TextStyle(color: isMe ? Colors.white70 : AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(UserModel currentUser) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_isRecording)
              const Expanded(child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("🎙️ Enregistrement en cours...", style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold)),
              ))
            else ...[
              IconButton(
                icon: const Icon(Icons.add_photo_alternate, color: AppColors.primary),
                onPressed: _isSending ? null : () => _pickAndSendImage(currentUser),
              ),
              IconButton(
                icon: const Icon(Icons.poll, color: AppColors.primary),
                onPressed: _isSending ? null : () => _showPollDialog(currentUser),
              ),
              Expanded(
                child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: AppColors.textMain),
                  decoration: InputDecoration(
                    hintText: "Écrire dans le groupe...",
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ),
            ],
            const SizedBox(width: 12),
            GestureDetector(
              onLongPress: _isSending ? null : () => _startRecording(),
              onLongPressEnd: _isSending ? null : (details) => _stopRecordingAndSend(currentUser),
              onTap: _isSending || _isRecording ? null : () => _sendMessage(currentUser),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : AppColors.coral,
                  shape: BoxShape.circle,
                ),
                child: _isSending 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isRecording ? Icons.mic : Icons.send, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollWidget(Map<String, dynamic> poll, String messageId, String currentUserId, bool isMe, String timeStr) {
    final question = poll['question'] as String;
    final options = List<String>.from(poll['options'] ?? []);
    final votes = Map<String, dynamic>.from(poll['votes'] ?? {});

    // Compter les votes
    final optionCounts = List<int>.filled(options.length, 0);
    int totalVotes = 0;
    votes.forEach((userId, optionIndex) {
      final idx = optionIndex is int ? optionIndex : int.tryParse(optionIndex.toString()) ?? -1;
      if (idx >= 0 && idx < options.length) {
        optionCounts[idx]++;
        totalVotes++;
      }
    });

    final hasVoted = votes.containsKey(currentUserId);
    final myVoteRaw = hasVoted ? votes[currentUserId] : -1;
    final myVote = myVoteRaw is int ? myVoteRaw : int.tryParse(myVoteRaw.toString()) ?? -1;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
          bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête vert foncé authentique style WhatsApp (#008069 / #075E54)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFE6F5F2),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.poll_rounded, color: Color(0xFF008069), size: 20),
                const SizedBox(width: 8),
                const Text(
                  "SONDAGE",
                  style: TextStyle(
                    color: Color(0xFF008069),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF008069).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$totalVotes vote${totalVotes > 1 ? 's' : ''}",
                    style: const TextStyle(color: Color(0xFF008069), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isMe || Provider.of<AppState>(context, listen: false).currentUser?.isAdmin == true) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF008069), size: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _showEditPollDialog(messageId, poll);
                      } else if (action == 'delete') {
                        _confirmDeletePoll(messageId);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, color: Color(0xFF008069), size: 18),
                            SizedBox(width: 10),
                            Text("Modifier le sondage", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                            SizedBox(width: 10),
                            Text("Supprimer le sondage", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Question du sondage
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              question,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.3,
              ),
            ),
          ),
          // Options de vote
          ...List.generate(options.length, (index) {
            final count = optionCounts[index];
            final percent = totalVotes > 0 ? count / totalVotes : 0.0;
            final isMyVote = myVote == index;
            final percentLabel = "${(percent * 100).round()}%";

            return InkWell(
              onTap: () => _votePoll(messageId, index, currentUserId),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Indicateur de vote (Cercle vert foncé avec check si coché)
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isMyVote ? const Color(0xFF008069) : Colors.transparent,
                            border: Border.all(
                              color: isMyVote ? const Color(0xFF008069) : const Color(0xFFCBD5E1),
                              width: 2,
                            ),
                          ),
                          child: isMyVote
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            options[index],
                            style: TextStyle(
                              color: isMyVote ? const Color(0xFF0F172A) : const Color(0xFF334155),
                              fontWeight: isMyVote ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasVoted)
                          Text(
                            percentLabel,
                            style: TextStyle(
                              color: isMyVote ? const Color(0xFF008069) : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Barre de progression
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: hasVoted ? percent : 0.0,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMyVote ? const Color(0xFF008069) : const Color(0xFF94A3B8),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Bas de carte (Action + Heure)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasVoted ? "Appuyez pour changer" : "Appuyez pour voter",
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontStyle: FontStyle.italic),
                ),
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _votePoll(String messageId, int optionIndex, String currentUserId) async {
    final chatRoomId = 'club_${widget.clubId}';
    final msgRef = FirebaseFirestore.instance.collection('chats').doc(chatRoomId).collection('messages').doc(messageId);
    
    await msgRef.set({
      'poll': {
        'votes': {
          currentUserId: optionIndex
        }
      }
    }, SetOptions(merge: true));
  }

  void _showPollDialog(UserModel currentUser) {
    final TextEditingController questionCtrl = TextEditingController();
    final List<TextEditingController> optionsCtrls = [TextEditingController(), TextEditingController()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barre grise pour fermer
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Titre Modal
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F5F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.poll_rounded, color: Color(0xFF008069), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Nouveau Sondage",
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Champ Question
                    const Text(
                      "Question",
                      style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: questionCtrl,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                      decoration: InputDecoration(
                        hintText: "Posez votre question...",
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF008069), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Options
                    const Text(
                      "Options",
                      style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(optionsCtrls.length, (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: TextField(
                        controller: optionsCtrls[index],
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.radio_button_unchecked, size: 18, color: Color(0xFF94A3B8)),
                          hintText: "Option ${index + 1}",
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF008069), width: 1.5),
                          ),
                        ),
                      ),
                    )),
                    if (optionsCtrls.length < 6)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              optionsCtrls.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add_circle, color: Color(0xFF008069), size: 20),
                          label: const Text(
                            "Ajouter une option",
                            style: TextStyle(color: Color(0xFF008069), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Bouton Envoyer
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008069),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final question = questionCtrl.text.trim();
                        final options = optionsCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                        if (question.isNotEmpty && options.length >= 2) {
                          Navigator.pop(context);
                          _sendPoll(currentUser, question, options);
                        }
                      },
                      child: const Text("Créer le sondage", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _sendPoll(UserModel currentUser, String question, List<String> options) async {
    setState(() => _isSending = true);
    try {
      await _chatService.sendGroupMessage(
        widget.clubId, 
        currentUser.id,
        currentUser.displayName, 
        "",
        widget.clubName,
        widget.clubBannerUrl,
        poll: {
          'question': question,
          'options': options,
          'votes': {},
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur d'envoi du sondage.")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _confirmDeletePoll(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Supprimer le sondage", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text(
          "Êtes-vous sûr de vouloir supprimer définitivement ce sondage ?",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('chats')
                  .doc('club_${widget.clubId}')
                  .collection('messages')
                  .doc(messageId)
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Sondage supprimé")),
                );
              }
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditPollDialog(String messageId, Map<String, dynamic> poll) {
    final questionController = TextEditingController(text: poll['question'] as String? ?? '');
    final List<TextEditingController> optionControllers = (poll['options'] as List<dynamic>? ?? [])
        .map((opt) => TextEditingController(text: opt.toString()))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.edit_rounded, color: Color(0xFF008069)),
                SizedBox(width: 8),
                Text("Modifier le sondage", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Question", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: questionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("Options", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    ...List.generate(optionControllers.length, (idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: optionControllers[idx],
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.08),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            if (optionControllers.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    optionControllers.removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    if (optionControllers.length < 8)
                      TextButton.icon(
                        icon: const Icon(Icons.add, color: Color(0xFF008069), size: 18),
                        label: const Text("Ajouter une option", style: TextStyle(color: Color(0xFF008069), fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          setDialogState(() {
                            optionControllers.add(TextEditingController());
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008069),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final newQuestion = questionController.text.trim();
                  final newOptions = optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

                  if (newQuestion.isEmpty || newOptions.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Une question et au moins 2 options sont nécessaires.")),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('chats')
                      .doc('club_${widget.clubId}')
                      .collection('messages')
                      .doc(messageId)
                      .update({
                    'poll.question': newQuestion,
                    'poll.options': newOptions,
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Sondage modifié avec succès ! ✨"), backgroundColor: Color(0xFF008069)),
                    );
                  }
                },
                child: const Text("Enregistrer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // AUDIO RECORDING LOGIC
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      print("Erreur d'enregistrement: $e");
    }
  }

  Future<void> _stopRecordingAndSend(UserModel currentUser) async {
    try {
      final String? path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        setState(() => _isSending = true);
        final file = File(path);
        final fileName = '${const Uuid().v4()}.m4a';
        final ref = FirebaseStorage.instance.ref().child('chats/${widget.clubId}/$fileName');
        
        await ref.putFile(file);
        final downloadUrl = await ref.getDownloadURL();

        await _chatService.sendGroupMessage(
          widget.clubId, 
          currentUser.id,
          currentUser.displayName, 
          "",
          widget.clubName,
          widget.clubBannerUrl,
          audioUrl: downloadUrl,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur d'envoi du message vocal.")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildAudioWidget(String audioUrl, bool isMe) {
    return _AudioBubble(audioUrl: audioUrl, isMe: isMe);
  }
}

class _AudioBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const _AudioBubble({required this.audioUrl, required this.isMe});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: widget.isMe ? null : Border.all(color: AppColors.surfaceAlt),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(widget.audioUrl));
              }
            },
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: widget.isMe ? Colors.white : AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 2,
              ),
              child: Slider(
                value: _position.inMilliseconds.toDouble(),
                max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                activeColor: widget.isMe ? Colors.white : AppColors.primary,
                inactiveColor: widget.isMe ? Colors.white30 : AppColors.surfaceAlt,
                onChanged: (value) {
                  _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
