import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate a unique chat room ID for two users
  String _getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // Send a message (1-on-1)
  Future<void> sendMessage(String senderId, String receiverId, String text) async {
    final String chatRoomId = _getChatRoomId(senderId, receiverId);
    
    final message = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Update the recent chat doc for the inbox view FIRST
    await _firestore.collection('chats').doc(chatRoomId).set({
      'users': [senderId, receiverId],
      'isGroup': false,
      'lastMessage': text,
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
  Future<void> sendGroupMessage(String clubId, String senderId, String senderName, String text, String clubName, String? clubBannerUrl, {String? imageUrl, String? audioUrl, Map<String, dynamic>? poll}) async {
    final String chatRoomId = 'club_$clubId';
    
    final message = {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (poll != null) 'poll': poll,
    };

    String lastMsg = text;
    if (imageUrl != null) lastMsg = "📷 Photo";
    if (audioUrl != null) lastMsg = "🎙️ Message vocal";
    if (poll != null) lastMsg = "📊 Sondage: ${poll['question']}";

    // Update the recent chat doc
    await _firestore.collection('chats').doc(chatRoomId).set({
      'isGroup': true,
      'groupName': clubName,
      'groupIcon': clubBannerUrl,
      'lastMessage': lastMsg,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': FieldValue.arrayUnion([senderId]), // Ensure sender is in users array
    }, SetOptions(merge: true));

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(message);
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
        .where('users', arrayContains: userId)
        .where('unreadBy', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get stream of messages
  Stream<QuerySnapshot> getMessages(String userId1, String userId2, {bool isGroup = false, String? clubId}) {
    final String chatRoomId = isGroup ? 'club_$clubId' : _getChatRoomId(userId1, userId2);
    
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

  // Delete chat conversation
  Future<void> deleteChat(String userId1, String userId2, {bool isGroup = false, String? clubId}) async {
    final String chatRoomId = isGroup ? 'club_$clubId' : _getChatRoomId(userId1, userId2);
    
    if (isGroup) {
       // On ne supprime pas le groupe, on retire l'utilisateur
       await _firestore.collection('chats').doc(chatRoomId).update({
         'users': FieldValue.arrayRemove([userId1])
       });
    } else {
      await _firestore.collection('chats').doc(chatRoomId).delete();
    }
  }

  // Join a Club Group Chat
  Future<void> joinClubChat(String userId, String clubId, String clubName, String? clubBannerUrl) async {
    final String chatRoomId = 'club_$clubId';
    await _firestore.collection('chats').doc(chatRoomId).set({
      'isGroup': true,
      'groupName': clubName,
      'groupIcon': clubBannerUrl,
      'users': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  // Leave a Club Group Chat
  Future<void> leaveClubChat(String userId, String clubId) async {
    final String chatRoomId = 'club_$clubId';
    await _firestore.collection('chats').doc(chatRoomId).update({
      'users': FieldValue.arrayRemove([userId]),
    });
  }

  // Mark group chat as read
  Future<void> markGroupAsRead(String userId, String clubId) async {
    final String chatRoomId = 'club_$clubId';
    await _firestore.collection('chats').doc(chatRoomId).set({
      'unreadBy': FieldValue.arrayRemove([userId]),
    }, SetOptions(merge: true));
  }
}
