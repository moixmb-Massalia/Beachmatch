import 'package:cloud_firestore/cloud_firestore.dart';

class ClubPostModel {
  final String id;
  final String clubId;
  final String authorId;
  final String? authorName;
  final String? title;
  final String content;
  final String? imageUrl;
  final bool isAnnouncement;
  final DateTime createdAt;

  ClubPostModel({
    required this.id,
    required this.clubId,
    required this.authorId,
    this.authorName,
    this.title,
    required this.content,
    this.imageUrl,
    this.isAnnouncement = false,
    required this.createdAt,
  });

  factory ClubPostModel.fromMap(Map<String, dynamic> data, String documentId) {
    DateTime date = DateTime.now();
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate) ?? DateTime.now();
    }
    return ClubPostModel(
      id: documentId,
      clubId: data['clubId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] as String?,
      title: data['title'] as String?,
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'] as String?,
      isAnnouncement: data['isAnnouncement'] == true,
      createdAt: date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clubId': clubId,
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'isAnnouncement': isAnnouncement,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
