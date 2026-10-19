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
  final String? country;
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
    this.country,
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
      country: data['country'],
      createdAt: () {
        final c = data['createdAt'];
        if (c is Timestamp) return c.toDate();
        if (c is String) return DateTime.tryParse(c) ?? DateTime.now();
        return DateTime.now();
      }(),
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
      'country': country,
      'createdAt': createdAt,
    };
  }

  /// 🏖️ Retourne une photo thématique de Beach Tennis déterministe basée sur le nom du club
  static String getClubPhotoAsset(String name) {
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

  /// Photo d'illustration par défaut de cette instance
  String get defaultPhotoAsset => getClubPhotoAsset(name);
}
