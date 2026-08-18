import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final int level;
  final int eloScore;
  final String location;
  final bool isPremium;
  final DateTime createdAt;
  final String? photoUrl; // Added for Phase 11
  final String? licenceNumber;
  final bool hasSeenTutorial;
  final String? fcmToken;
  final List<String> friendsIds;
  final int totalMatches;
  final String? ranking;
  final bool isAdmin; // Admin access
  final List<String> subscribedCourts;
  final bool isLookingForPartner;
  final int? rankingProgression; // Progression du classement (+ ou -)
  
  // Nouveaux champs pour le Radar à tournois (Sniper)
  final bool tournamentAlertsEnabled;
  final String? alertRegion;
  
  // Préférences de jeu
  final String? preferredPosition;
  final String? availability;
  final bool isBanned;
  final bool isReferee;

  bool get canReferee => isAdmin || isReferee;

  UserModel({
    required this.id,
    required this.displayName,
    required this.level,
    required this.eloScore,
    required this.location,
    required this.isPremium,
    required this.createdAt,
    this.photoUrl,
    this.licenceNumber,
    this.hasSeenTutorial = false,
    this.fcmToken,
    this.friendsIds = const [],
    this.totalMatches = 0,
    this.ranking,
    this.isAdmin = false,
    this.isReferee = false,
    this.subscribedCourts = const [],
    this.isLookingForPartner = false,
    this.rankingProgression,
    this.tournamentAlertsEnabled = false,
    this.alertRegion,
    this.preferredPosition,
    this.availability,
    this.isBanned = false,
  });

  UserModel copyWith({
    String? id,
    String? displayName,
    int? level,
    int? eloScore,
    String? location,
    bool? isPremium,
    DateTime? createdAt,
    String? photoUrl,
    String? licenceNumber,
    bool? hasSeenTutorial,
    String? fcmToken,
    List<String>? friendsIds,
    int? totalMatches,
    String? ranking,
    bool? isAdmin,
    List<String>? subscribedCourts,
    bool? isLookingForPartner,
    int? rankingProgression,
    bool? tournamentAlertsEnabled,
    String? alertRegion,
    String? preferredPosition,
    String? availability,
    bool? isBanned,
    bool? isReferee,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      level: level ?? this.level,
      eloScore: eloScore ?? this.eloScore,
      location: location ?? this.location,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
      licenceNumber: licenceNumber ?? this.licenceNumber,
      hasSeenTutorial: hasSeenTutorial ?? this.hasSeenTutorial,
      fcmToken: fcmToken ?? this.fcmToken,
      friendsIds: friendsIds ?? this.friendsIds,
      totalMatches: totalMatches ?? this.totalMatches,
      ranking: ranking ?? this.ranking,
      isAdmin: isAdmin ?? this.isAdmin,
      isReferee: isReferee ?? this.isReferee,
      subscribedCourts: subscribedCourts ?? this.subscribedCourts,
      isLookingForPartner: isLookingForPartner ?? this.isLookingForPartner,
      rankingProgression: rankingProgression ?? this.rankingProgression,
      tournamentAlertsEnabled: tournamentAlertsEnabled ?? this.tournamentAlertsEnabled,
      alertRegion: alertRegion ?? this.alertRegion,
      preferredPosition: preferredPosition ?? this.preferredPosition,
      availability: availability ?? this.availability,
      isBanned: isBanned ?? this.isBanned,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      displayName: data['displayName'] ?? 'Joueur Inconnu',
      level: data['level'] ?? 3,
      eloScore: data['eloScore'] ?? 1500,
      location: data['location'] ?? 'Non renseigné',
      isPremium: data['isPremium'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: data['photoUrl'],
      licenceNumber: data['licenceNumber'],
      hasSeenTutorial: data['hasSeenTutorial'] ?? false,
      fcmToken: data['fcmToken'],
      friendsIds: List<String>.from(data['friendsIds'] ?? []),
      totalMatches: data['totalMatches'] ?? 0,
      ranking: data['ranking'],
      isAdmin: data['isAdmin'] ?? false,
      isReferee: data['isReferee'] ?? false,
      subscribedCourts: List<String>.from(data['subscribedCourts'] ?? []),
      isLookingForPartner: data['isLookingForPartner'] ?? false,
      rankingProgression: data['rankingProgression'],
      tournamentAlertsEnabled: data['tournamentAlertsEnabled'] ?? false,
      alertRegion: data['alertRegion'],
      preferredPosition: data['preferredPosition'],
      availability: data['availability'],
      isBanned: data['isBanned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'level': level,
      'eloScore': eloScore,
      'location': location,
      'isPremium': isPremium,
      'createdAt': createdAt,
      'photoUrl': photoUrl,
      'licenceNumber': licenceNumber,
      'hasSeenTutorial': hasSeenTutorial,
      'fcmToken': fcmToken,
      'friendsIds': friendsIds,
      'totalMatches': totalMatches,
      'ranking': ranking,
      'isAdmin': isAdmin,
      'isReferee': isReferee,
      'subscribedCourts': subscribedCourts,
      'isLookingForPartner': isLookingForPartner,
      'rankingProgression': rankingProgression,
      'tournamentAlertsEnabled': tournamentAlertsEnabled,
      'alertRegion': alertRegion,
      'preferredPosition': preferredPosition,
      'availability': availability,
      'isBanned': isBanned,
    };
  }
}
