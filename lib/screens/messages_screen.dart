import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';
import 'clubs/club_detail_screen.dart';
import 'clubs/group_chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _selectedFilter = 'all'; // 'all', 'clubs', 'players'

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppState>().currentUser;
    final ChatService chatService = ChatService();

    if (currentUser == null) return const Scaffold(body: Center(child: Text("Non connecté")));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Image Beach Sunset
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
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
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Glass
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.gold, AppColors.coral]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  "MESSAGES",
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Discussions & Clubs",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Échangez en direct avec vos partenaires et vos clubs",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      // Filter Pills
                      Row(
                        children: [
                          _buildFilterChip("all", "Tous 💬"),
                          const SizedBox(width: 8),
                          _buildFilterChip("clubs", "👥 Clubs"),
                          const SizedBox(width: 8),
                          _buildFilterChip("players", "🎾 Joueurs"),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chat List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: chatService.getRecentChats(currentUser.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.white70)));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                      }

                      final allChats = snapshot.data!.docs.toList();
                      allChats.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTime = aData['lastTimestamp'] as Timestamp?;
                        final bTime = bData['lastTimestamp'] as Timestamp?;
                        if (aTime == null || bTime == null) return 0;
                        return bTime.compareTo(aTime);
                      });

                      // Filter according to selected tab
                      final chats = allChats.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final isGroup = data['isGroup'] == true;
                        if (_selectedFilter == 'clubs') return isGroup;
                        if (_selectedFilter == 'players') return !isGroup;
                        return true;
                      }).toList();

                      if (chats.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.coral.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(CupertinoIcons.chat_bubble_2, color: AppColors.gold, size: 36),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _selectedFilter == 'clubs'
                                            ? "Aucun chat de club actif"
                                            : _selectedFilter == 'players'
                                                ? "Aucun message privé"
                                                : "Aucune conversation",
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Rejoignez un club ou proposez une partie à un joueur pour lancer la discussion !",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chatData = chats[index].data() as Map<String, dynamic>;
                          final isGroup = chatData['isGroup'] == true;
                          final users = List<String>.from(chatData['users'] ?? []);
                          final lastMessage = chatData['lastMessage'] as String? ?? "";
                          final chatId = chats[index].id;
                          final lastTimestamp = chatData['lastTimestamp'] as Timestamp?;
                          final unreadBy = List<String>.from(chatData['unreadBy'] ?? []);
                          final isUnread = unreadBy.contains(currentUser.id);

                          if (isGroup) {
                            final groupName = chatData['groupName'] as String? ?? "Groupe";
                            final groupIcon = chatData['groupIcon'] as String?;
                            final clubId = chatId.replaceFirst('club_', '');
                            return _buildGroupMessageItem(context, currentUser, groupName, groupIcon, lastMessage, clubId, lastTimestamp, isUnread);
                          } else {
                            final otherUserId = users.firstWhere((id) => id != currentUser.id, orElse: () => currentUser.id);
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData || !userSnapshot.data!.exists || userSnapshot.data!.data() == null) {
                                  return const SizedBox.shrink();
                                }
                                final otherUser = UserModel.fromMap(userSnapshot.data!.data() as Map<String, dynamic>, otherUserId);
                                return _buildMessageItem(context, currentUser, otherUser, lastMessage, chatId, lastTimestamp, isUnread);
                              },
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.coral : Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.coral.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    UserModel currentUser,
    UserModel otherUser,
    String lastMessage,
    String chatId,
    Timestamp? lastTimestamp,
    bool isUnread,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Dismissible(
            key: Key(chatId),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF16253B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.coral),
                      SizedBox(width: 8),
                      Text("Supprimer le chat", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: Text(
                    "Voulez-vous supprimer votre conversation avec ${otherUser.displayName} ?",
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
                      child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24.0),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            onDismissed: (direction) {
              ChatService().deleteChat(currentUser.id, otherUser.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Conversation avec ${otherUser.displayName} supprimée."),
                  backgroundColor: const Color(0xFF16253B),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUnread ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUnread ? AppColors.gold.withOpacity(0.6) : Colors.white.withOpacity(0.16),
                  width: isUnread ? 1.5 : 1.0,
                ),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatDetailScreen(otherUser: otherUser)),
                  );
                },
                child: Row(
                  children: [
                    // Avatar with glowing border
                    Stack(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.coral, AppColors.gold],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                          ),
                          child: ClipOval(
                            child: otherUser.photoUrl != null && otherUser.photoUrl!.isNotEmpty
                                ? Image.network(otherUser.photoUrl!, fit: BoxFit.cover)
                                : Center(
                                    child: Text(
                                      otherUser.displayName.isNotEmpty ? otherUser.displayName[0].toUpperCase() : "?",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                  ),
                          ),
                        ),
                        if (isUnread)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Names & Last message
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  otherUser.displayName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (lastTimestamp != null)
                                Text(
                                  DateFormat('HH:mm').format(lastTimestamp.toDate()),
                                  style: TextStyle(
                                    color: isUnread ? AppColors.gold : Colors.white60,
                                    fontSize: 11,
                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (otherUser.level > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Niv. ${otherUser.level}",
                                    style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  lastMessage.isNotEmpty ? lastMessage : "Nouvelle discussion",
                                  style: TextStyle(
                                    color: isUnread ? Colors.white : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  Widget _buildClubAvatar(String groupName, String? groupIcon, {double size = 52}) {
    final photoAsset = _getClubPhotoAsset(groupName);
    final hasValidNetworkUrl = groupIcon != null &&
        groupIcon.trim().isNotEmpty &&
        groupIcon.startsWith('http');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8604C).withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: hasValidNetworkUrl
            ? Image.network(
                groupIcon.trim(),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  photoAsset,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.sports_tennis, color: Colors.white, size: 24),
                  ),
                ),
              )
            : Image.asset(
                photoAsset,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.sports_tennis, color: Colors.white, size: 24),
                ),
              ),
      ),
    );
  }

  Widget _buildGroupMessageItem(
    BuildContext context,
    UserModel currentUser,
    String groupName,
    String? groupIcon,
    String lastMessage,
    String clubId,
    Timestamp? lastTimestamp,
    bool isUnread,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Dismissible(
            key: Key('club_$clubId'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
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
                    "Voulez-vous retirer le chat de '$groupName' de votre boîte de réception ?",
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
                      child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24.0),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            onDismissed: (direction) {
              ChatService().deleteChat(currentUser.id, '', isGroup: true, clubId: clubId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Chat '$groupName' retiré de vos messages."),
                  backgroundColor: const Color(0xFF16253B),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUnread ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUnread ? AppColors.gold.withOpacity(0.6) : Colors.white.withOpacity(0.16),
                  width: isUnread ? 1.5 : 1.0,
                ),
              ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupChatDetailScreen(
                      clubId: clubId,
                      clubName: groupName,
                      clubBannerUrl: groupIcon,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  // Club avatar with chat icon badge
                  Stack(
                    children: [
                      _buildClubAvatar(groupName, groupIcon, size: 52),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFF4A535), Color(0xFFE8604C)]),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.forum_rounded, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Group Title & Last message
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                groupName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Bouton "Voir le club"
                            GestureDetector(
                              onTap: () async {
                                final doc = await FirebaseFirestore.instance.collection('clubs').doc(clubId).get();
                                if (doc.exists && context.mounted) {
                                  final club = ClubModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ClubDetailScreen(club: club)));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.coral.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.coral.withOpacity(0.5)),
                                ),
                                child: const Text(
                                  "Voir le club",
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "CHAT CLUB",
                                style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lastMessage.isNotEmpty ? lastMessage : "Accéder au chat du club",
                                style: TextStyle(
                                  color: isUnread ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (lastTimestamp != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('HH:mm').format(lastTimestamp.toDate()),
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
