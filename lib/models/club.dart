import 'package:cloud_firestore/cloud_firestore.dart';

class ClubModel {
  final String id;
  final String name;
  final String description;
  final String adminId;
  final List<String> memberIds;
  final List<String> presidentEmails; // Liste des emails des présidents
  String? logoUrl;
  String? bannerUrl;
  final String location;
  final DateTime createdAt;

  ClubModel({
    required this.id,
    required this.name,
    required this.description,
    required this.adminId,
    required this.memberIds,
    this.presidentEmails = const [],
    this.logoUrl,
    this.bannerUrl,
    required this.location,
    required this.createdAt,
  });

  factory ClubModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ClubModel(
      id: documentId,
      name: data['name'] ?? 'Club Inconnu',
      description: data['description'] ?? '',
      adminId: data['adminId'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      presidentEmails: List<String>.from(data['presidentEmails'] ?? []),
      logoUrl: data['logoUrl'],
      bannerUrl: data['bannerUrl'],
      location: data['location'] ?? 'France',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'adminId': adminId,
      'memberIds': memberIds,
      'presidentEmails': presidentEmails,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'location': location,
      'createdAt': createdAt,
    };
  }
}
