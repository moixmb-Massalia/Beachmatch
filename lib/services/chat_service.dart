import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate a unique chat room ID for two users
  String getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  String _getChatRoomId(String userId1, String userId2) => getChatRoomId(userId1, userId2);

  String getClubChatRoomId(String clubId) {
    return clubId.startsWith('club_') ? clubId : 'club_$clubId';
  }

  String _getClubChatRoomId(String clubId) => getClubChatRoomId(clubId);

  String getTournamentChatRoomId(String tournamentId) {
    return tournamentId.startsWith('tournament_') ? tournamentId : 'tournament_$tournamentId';
  }

  // Send a message (1-on-1)
  Future<void> sendMessage(String senderId, String receiverId, String text, {String? imageUrl, Map<String, dynamic>? replyTo}) async {
    final String chatRoomId = _getChatRoomId(senderId, receiverId);
    
    final message = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (replyTo != null) 'replyTo': replyTo,
    };

    final String lastMsg = (imageUrl != null && text.isEmpty) ? "📷 Photo" : text;

    // Update the recent chat doc for the inbox view FIRST
    await _firestore.collection('chats').doc(chatRoomId).set({
      'users': [senderId, receiverId],
      'isGroup': false,
      'lastMessage': lastMsg,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'unreadBy': FieldValue.arrayUnion([receiverId]),
    }, SetOptions(merge: true));

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(message);
  }

  // Send a message to a Club Group Chat
  Future<void> sendGroupMessage(String clubId, String senderId, String senderName, String text, String clubName, String? clubBannerUrl, {String? imageUrl, String? audioUrl, Map<String, dynamic>? poll, Map<String, dynamic>? replyTo}) async {
    final String chatRoomId = _getClubChatRoomId(clubId);
    
    final message = {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (poll != null) 'poll': poll,
      if (replyTo != null) 'replyTo': replyTo,
    };

    String lastMsg = text;
    if (imageUrl != null && text.isEmpty) lastMsg = "📷 Photo";
    if (audioUrl != null) lastMsg = "🎙️ Message vocal";
    if (poll != null) lastMsg = "📊 Sondage: ${poll['question']}";

    // Get current chat doc to find other members for unreadBy
    List<String> unreadMembers = [];
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatRoomId).get();
      if (chatDoc.exists) {
        final existingUsers = List<String>.from(chatDoc.data()?['users'] ?? []);
        unreadMembers = existingUsers.where((u) => u != senderId).toList();
      }
    } catch (_) {}

    // Update the recent chat doc
    await _firestore.collection('chats').doc(chatRoomId).set({
      'isGroup': true,
      'groupName': clubName,
      'groupIcon': clubBannerUrl,
      'lastMessage': lastMsg,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': FieldValue.arrayUnion([senderId]), // Ensure sender is in users array
      if (unreadMembers.isNotEmpty) 'unreadBy': FieldValue.arrayUnion(unreadMembers),
    }, SetOptions(merge: true));

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(message);
  }

  // Send a message to a Tournament Group Chat
  Future<void> sendTournamentMessage(
    String tournamentId,
    String senderId,
    String senderName,
    String text,
    String tournamentName, {
    String? imageUrl,
    String? videoUrl,
    Map<String, dynamic>? poll,
    Map<String, dynamic>? replyTo,
  }) async {
    final String chatRoomId = getTournamentChatRoomId(tournamentId);

    final message = {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (poll != null) 'poll': poll,
      if (replyTo != null) 'replyTo': replyTo,
    };

    String lastMsg = text;
    if (imageUrl != null && text.isEmpty) lastMsg = "📷 Photo";
    if (videoUrl != null && text.isEmpty) lastMsg = "🎥 Vidéo";
    if (poll != null) lastMsg = "📊 Sondage: ${poll['question']}";

    // Update the recent chat doc for tournament
    await _firestore.collection('chats').doc(chatRoomId).set({
      'isGroup': true,
      'isTournament': true,
      'tournamentId': tournamentId,
      'groupName': tournamentName,
      'lastMessage': lastMsg,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': FieldValue.arrayUnion([senderId]),
    }, SetOptions(merge: true));

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(message);
  }

  // Get stream of tournament messages
  Stream<QuerySnapshot> getTournamentMessages(String tournamentId) {
    final String chatRoomId = getTournamentChatRoomId(tournamentId);
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Mark chat as read
  Future<void> markAsRead(String currentUserId, String otherUserId) async {
    final String chatRoomId = _getChatRoomId(currentUserId, otherUserId);
    await _firestore.collection('chats').doc(chatRoomId).set({
      'unreadBy': FieldValue.arrayRemove([currentUserId]),
    }, SetOptions(merge: true));
  }

  // Get stream of unread chats count
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('chats')
        .where('unreadBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get stream of messages
  Stream<QuerySnapshot> getMessages(String userId1, String userId2, {bool isGroup = false, String? clubId}) {
    final String chatRoomId = isGroup ? _getClubChatRoomId(clubId!) : _getChatRoomId(userId1, userId2);
    
    if (!isGroup) {
      markAsRead(userId1, userId2); // auto mark as read when entering conversation
    } else {
      markGroupAsRead(userId1, clubId!);
    }
    
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
  
  // Get stream of recent chats for a user
  Stream<QuerySnapshot> getRecentChats(String userId) {
    return _firestore
        .collection('chats')
        .where('users', arrayContains: userId)
        .snapshots();
  }

  // Delete chat conversation (masquage non-destructif pour l'autre utilisateur)
  Future<void> deleteChat(String userId1, String userId2, {bool isGroup = false, String? clubId, String? tournamentId}) async {
    final String chatRoomId = tournamentId != null
        ? getTournamentChatRoomId(tournamentId)
        : (isGroup 
            ? _getClubChatRoomId(clubId!)
            : _getChatRoomId(userId1, userId2));
    
    try {
      final doc = await _firestore.collection('chats').doc(chatRoomId).get();
      if (!doc.exists) return;
      
      final data = doc.data() ?? {};
      final List<dynamic> users = List.from(data['users'] ?? []);
      users.remove(userId1);

      if (isGroup || tournamentId != null) {
        // Pour un club ou un tournoi, on retire l'utilisateur de la liste
        await _firestore.collection('chats').doc(chatRoomId).update({
          'users': FieldValue.arrayRemove([userId1]),
          'unreadBy': FieldValue.arrayRemove([userId1]),
        });
      } else {
        if (users.isEmpty) {
          // Si les deux utilisateurs ont supprimé la discussion, effacement du document
          await _firestore.collection('chats').doc(chatRoomId).delete();
        } else {
          // L'autre utilisateur conserve la discussion dans sa boîte de réception
          await _firestore.collection('chats').doc(chatRoomId).update({
            'users': FieldValue.arrayRemove([userId1]),
            'unreadBy': FieldValue.arrayRemove([userId1]),
          });
        }
      }
    } catch (_) {
      await _firestore.collection('chats').doc(chatRoomId).update({
        'users': FieldValue.arrayRemove([userId1]),
      }).catchError((_) {});
    }
  }

  // Join a Club Group Chat
  Future<void> joinClubChat(String userId, String clubId, String clubName, String? clubBannerUrl) async {
    final String chatRoomId = _getClubChatRoomId(clubId);
    await _firestore.collection('chats').doc(chatRoomId).set({
      'isGroup': true,
      'groupName': clubName,
      'groupIcon': clubBannerUrl,
      'users': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  // Join a Tournament Group Chat
  Future<void> joinTournamentChat(String userId, String tournamentId, String tournamentName) async {
    final String chatRoomId = getTournamentChatRoomId(tournamentId);
    await _firestore.collection('chats').doc(chatRoomId).set({
      'isGroup': true,
      'isTournament': true,
      'tournamentId': tournamentId,
      'groupName': tournamentName,
      'users': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  // Leave a Club Group Chat
  Future<void> leaveClubChat(String userId, String clubId) async {
    final String chatRoomId = _getClubChatRoomId(clubId);
    await _firestore.collection('chats').doc(chatRoomId).update({
      'users': FieldValue.arrayRemove([userId]),
      'unreadBy': FieldValue.arrayRemove([userId]),
    }).catchError((_) {});
  }

  // Mark group chat as read
  Future<void> markGroupAsRead(String userId, String clubId) async {
    final String chatRoomId = _getClubChatRoomId(clubId);
    await _firestore.collection('chats').doc(chatRoomId).set({
      'unreadBy': FieldValue.arrayRemove([userId]),
    }, SetOptions(merge: true));
  }

  // Supprimer un message individuel
  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // Ajouter ou retirer une réaction emoji sur un message (style WhatsApp)
  Future<void> toggleReaction({
    required String chatRoomId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final msgRef = _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    final snap = await msgRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final List<dynamic> usersForEmoji = List<dynamic>.from(reactions[emoji] ?? []);

    if (usersForEmoji.contains(userId)) {
      usersForEmoji.remove(userId);
      if (usersForEmoji.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = usersForEmoji;
      }
    } else {
      // 1 réaction active par utilisateur par message
      reactions.forEach((k, v) {
        if (v is List) {
          v.remove(userId);
        }
      });
      reactions.removeWhere((k, v) => (v is List) && v.isEmpty);
      usersForEmoji.add(userId);
      reactions[emoji] = usersForEmoji;
    }

    await msgRef.update({'reactions': reactions});
  }
}
