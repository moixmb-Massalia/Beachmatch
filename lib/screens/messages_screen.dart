import 'dart:async';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  // In-memory cache for user profiles to eliminate FutureBuilder latency
  final Map<String, UserModel> _cachedUsers = {};
  final Set<String> _pendingUserFetches = {};

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim();
        });
      }
    });
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .trim();
  }

  bool _matchesTokens(String text, List<String> tokens) {
    if (tokens.isEmpty) return true;
    final norm = _normalize(text);
    return tokens.every((token) => norm.contains(token));
  }

  UserModel? _resolveUser(String userId, AppState appState) {
    if (_cachedUsers.containsKey(userId)) {
      return _cachedUsers[userId];
    }
    try {
      final player = appState.players.firstWhere((p) => p.id == userId);
      _cachedUsers[userId] = player;
      return player;
    } catch (_) {}

    if (!_pendingUserFetches.contains(userId)) {
      _pendingUserFetches.add(userId);
      FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
        _pendingUserFetches.remove(userId);
        if (doc.exists && doc.data() != null) {
          final user = UserModel.fromMap(doc.data()!, doc.id);
          if (mounted) {
            setState(() {
              _cachedUsers[userId] = user;
            });
          }
        }
      }).catchError((_) {
        _pendingUserFetches.remove(userId);
      });
    }
    return null;
  }

  String _formatChatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    final now = DateTime.now();

    final isToday = now.year == date.year && now.month == date.month && now.day == date.day;
    if (isToday) {
      return DateFormat('HH:mm').format(date);
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day;
    if (isYesterday) {
      return "Hier";
    }

    final difference = now.difference(date);
    if (difference.inDays < 7 && now.weekday > date.weekday) {
      const days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
      return days[date.weekday - 1];
    }

    if (now.year == date.year) {
      return DateFormat('dd/MM').format(date);
    }

    return DateFormat('dd/MM/yy').format(date);
  }

  void _showNewMessageModal(BuildContext context, UserModel currentUser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewMessageModal(currentUser: currentUser),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentUser = appState.currentUser;
    final ChatService chatService = ChatService();

    if (currentUser == null) return const Scaffold(body: Center(child: Text("Non connecté")));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.coral, AppColors.gold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.coral.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => _showNewMessageModal(context, currentUser),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.square_pencil, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Nouveau message",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image Beach Sunset
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
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
                      const SizedBox(height: 10),
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "Rechercher une conversation...",
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                            prefixIcon: const Icon(CupertinoIcons.search, color: Colors.white70, size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white60, size: 18),
                                    onPressed: () {
                                      _debounceTimer?.cancel();
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
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

                      // 1. Filter according to selected tab
                      final chatsByCategory = allChats.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final isGroup = data['isGroup'] == true;
                        if (_selectedFilter == 'clubs') return isGroup;
                        if (_selectedFilter == 'players') return !isGroup;
                        return true;
                      }).toList();

                      // 2. Pre-filter by search query (multi-token & accent-insensitive)
                      final searchTokens = _normalize(_searchQuery).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

                      final filteredChats = chatsByCategory.where((doc) {
                        if (searchTokens.isEmpty) return true;
                        final chatData = doc.data() as Map<String, dynamic>;
                        final isGroup = chatData['isGroup'] == true;
                        final lastMessage = chatData['lastMessage'] as String? ?? "";

                        if (isGroup) {
                          final groupName = chatData['groupName'] as String? ?? "Groupe";
                          return _matchesTokens("$groupName $lastMessage", searchTokens);
                        } else {
                          final users = List<String>.from(chatData['users'] ?? []);
                          final otherUserId = users.firstWhere((id) => id != currentUser.id, orElse: () => currentUser.id);
                          final otherUser = _resolveUser(otherUserId, appState);
                          if (otherUser != null) {
                            return _matchesTokens("${otherUser.displayName} ${otherUser.location} $lastMessage", searchTokens);
                          }
                          return _matchesTokens(lastMessage, searchTokens);
                        }
                      }).toList();

                      if (chatsByCategory.isEmpty) {
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
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.coral.withValues(alpha: 0.2),
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

                      if (filteredChats.isEmpty) {
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
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.coral.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(CupertinoIcons.search, color: AppColors.gold, size: 36),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        "Aucun résultat trouvé",
                                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Aucune discussion ne correspond à '$_searchQuery'.",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          _debounceTimer?.cancel();
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        icon: const Icon(CupertinoIcons.clear, size: 16),
                                        label: const Text("Effacer la recherche"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.coral,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        ),
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
                        itemCount: filteredChats.length,
                        itemBuilder: (context, index) {
                          final chatData = filteredChats[index].data() as Map<String, dynamic>;
                          final isGroup = chatData['isGroup'] == true;
                          final users = List<String>.from(chatData['users'] ?? []);
                          final lastMessage = chatData['lastMessage'] as String? ?? "";
                          final chatId = filteredChats[index].id;
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
                            final otherUser = _resolveUser(otherUserId, appState);
                            if (otherUser != null) {
                              return _buildMessageItem(context, currentUser, otherUser, lastMessage, chatId, lastTimestamp, isUnread);
                            } else {
                              return _buildLoadingMessageItem(lastMessage, lastTimestamp, isUnread);
                            }
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
          color: isSelected ? AppColors.coral : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.coral : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.coral.withValues(alpha: 0.4),
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

  Widget _buildLoadingMessageItem(String lastMessage, Timestamp? lastTimestamp, bool isUnread) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lastMessage.isNotEmpty ? lastMessage : "Discussion...",
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                        maxLines: 1,
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
                color: Colors.redAccent.withValues(alpha: 0.85),
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
                color: isUnread ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUnread ? AppColors.gold.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.16),
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
                            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
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
                                  _formatChatTimestamp(lastTimestamp),
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
                                    color: AppColors.gold.withValues(alpha: 0.2),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8604C).withValues(alpha: 0.35),
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
                color: Colors.redAccent.withValues(alpha: 0.85),
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
                color: isUnread ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUnread ? AppColors.gold.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.16),
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
                                color: Colors.black.withValues(alpha: 0.25),
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
                                  color: AppColors.coral.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
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
                                color: AppColors.gold.withValues(alpha: 0.2),
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
                                _formatChatTimestamp(lastTimestamp),
                                style: TextStyle(
                                  color: isUnread ? AppColors.gold : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
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

class _NewMessageModal extends StatefulWidget {
  final UserModel currentUser;

  const _NewMessageModal({required this.currentUser});

  @override
  State<_NewMessageModal> createState() => _NewMessageModalState();
}

class _NewMessageModalState extends State<_NewMessageModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onFilterChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _filter = val.trim());
    });
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.only(
            top: 12,
            left: 18,
            right: 18,
            bottom: bottomInset > 0 ? bottomInset + 12 : 24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF16253B).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.coral, AppColors.gold]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(CupertinoIcons.square_pencil, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Nouvelle discussion",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Sélectionnez un joueur pour lui écrire",
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white54, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  onChanged: _onFilterChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Rechercher par nom, ville...",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                    prefixIcon: const Icon(CupertinoIcons.search, color: AppColors.coral, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white54, size: 18),
                            onPressed: () {
                              _debounceTimer?.cancel();
                              _searchCtrl.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Stream of users
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.white70)));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final blockedIds = widget.currentUser.blockedUserIds;
                    final tokens = _normalize(_filter).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

                    final users = docs
                        .where((doc) {
                          if (doc.id == widget.currentUser.id) return false;
                          if (blockedIds.contains(doc.id)) return false;
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data == null) return false;
                          return true;
                        })
                        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                        .where((user) {
                          if (tokens.isEmpty) return true;
                          final haystack = _normalize("${user.displayName} ${user.location}");
                          return tokens.every((token) => haystack.contains(token));
                        })
                        .toList();

                    users.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

                    if (users.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.person_badge_minus, color: Colors.white.withValues(alpha: 0.3), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _filter.isNotEmpty ? "Aucun joueur trouvé pour '$_filter'" : "Aucun joueur disponible",
                              style: const TextStyle(color: Colors.white60, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      itemBuilder: (context, index) {
                        final player = users[index];
                        final initial = player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : "?";

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatDetailScreen(otherUser: player)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(colors: [AppColors.coral, AppColors.gold]),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                                  ),
                                  child: ClipOval(
                                    child: player.photoUrl != null && player.photoUrl!.isNotEmpty
                                        ? Image.network(player.photoUrl!, fit: BoxFit.cover)
                                        : Center(
                                            child: Text(
                                              initial,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Name + Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player.displayName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          if (player.level > 0) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: AppColors.gold.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "Niv. ${player.level}",
                                                style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (player.location.isNotEmpty)
                                            Expanded(
                                              child: Text(
                                                player.location,
                                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Action Button
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [AppColors.coral, AppColors.gold]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        "Écrire",
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
