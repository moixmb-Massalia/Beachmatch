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
  final List<String> blockedUserIds; // Apple UGC Guideline 1.2: Blocked users
  final String? clubId;
  final String? clubName;
  final String? cbtId;
  final String? cbtCategory;
  final String country;
  final bool isAmbassador;
  final String? ambassadorTitle;
  final String? email;

  bool get canReferee => isAdmin || isReferee;
  bool get isBrazilian => country.toUpperCase() == 'BR' || (cbtCategory != null && cbtCategory!.isNotEmpty) || (cbtId != null && cbtId!.isNotEmpty);

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
    this.blockedUserIds = const [],
    this.clubId,
    this.clubName,
    this.cbtId,
    this.cbtCategory,
    this.country = 'FR',
    this.isAmbassador = false,
    this.ambassadorTitle,
    this.email,
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
    List<String>? blockedUserIds,
    String? clubId,
    String? clubName,
    String? cbtId,
    String? cbtCategory,
    String? country,
    bool? isAmbassador,
    String? ambassadorTitle,
    String? email,
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
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      clubId: clubId ?? this.clubId,
      clubName: clubName ?? this.clubName,
      cbtId: cbtId ?? this.cbtId,
      cbtCategory: cbtCategory ?? this.cbtCategory,
      country: country ?? this.country,
      isAmbassador: isAmbassador ?? this.isAmbassador,
      ambassadorTitle: ambassadorTitle ?? this.ambassadorTitle,
      email: email ?? this.email,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      displayName: data['displayName'] ?? data['name'] ?? 'Joueur Inconnu',
      level: () {
        final l = data['level'];
        if (l is int) return l;
        if (l is num) return l.toInt();
        if (l is String) return int.tryParse(l) ?? 3;
        return 3;
      }(),
      eloScore: () {
        final e = data['eloScore'];
        if (e is int) return e;
        if (e is num) return e.toInt();
        if (e is String) return int.tryParse(e) ?? 1500;
        return 1500;
      }(),
      location: data['location']?.toString() ?? 'Non renseigné',
      isPremium: data['isPremium'] == true,
      createdAt: () {
        final c = data['createdAt'];
        if (c is Timestamp) return c.toDate();
        if (c is String) return DateTime.tryParse(c) ?? DateTime.now();
        return DateTime.now();
      }(),
      photoUrl: data['photoUrl']?.toString(),
      licenceNumber: data['licenceNumber']?.toString(),
      hasSeenTutorial: data['hasSeenTutorial'] == true,
      fcmToken: data['fcmToken']?.toString(),
      friendsIds: List<String>.from(data['friendsIds'] ?? []),
      totalMatches: () {
        final tm = data['totalMatches'];
        if (tm is int) return tm;
        if (tm is num) return tm.toInt();
        if (tm is String) return int.tryParse(tm) ?? 0;
        return 0;
      }(),
      ranking: data['ranking']?.toString(),
      isAdmin: data['isAdmin'] == true,
      isReferee: data['isReferee'] == true,
      subscribedCourts: List<String>.from(data['subscribedCourts'] ?? []),
      isLookingForPartner: data['isLookingForPartner'] == true,
      rankingProgression: () {
        final rp = data['rankingProgression'];
        if (rp is int) return rp;
        if (rp is num) return rp.toInt();
        if (rp is String) return int.tryParse(rp);
        return null;
      }(),
      tournamentAlertsEnabled: data['tournamentAlertsEnabled'] ?? false,
      alertRegion: data['alertRegion'],
      preferredPosition: data['preferredPosition'],
      availability: data['availability'],
      isBanned: data['isBanned'] ?? false,
      blockedUserIds: List<String>.from(data['blockedUserIds'] ?? []),
      clubId: data['clubId'],
      clubName: data['clubName'],
      cbtId: data['cbtId'],
      cbtCategory: data['cbtCategory'],
      country: ((data['country'] as String?)?.trim().isNotEmpty == true)
          ? (data['country'] as String).trim().toUpperCase()
          : (((data['cbtCategory'] != null && (data['cbtCategory'] as String).isNotEmpty) ||
              (data['cbtId'] != null && (data['cbtId'] as String).isNotEmpty) ||
              (data['location'] != null && (data['location'] as String).toLowerCase().contains('brasil')))
              ? 'BR'
              : 'FR'),
      isAmbassador: data['isAmbassador'] ?? false,
      ambassadorTitle: data['ambassadorTitle'],
      email: data['email'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'name': displayName,
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
      'blockedUserIds': blockedUserIds,
      if (clubId != null) 'clubId': clubId,
      if (clubName != null) 'clubName': clubName,
      if (cbtId != null) 'cbtId': cbtId,
      if (cbtCategory != null) 'cbtCategory': cbtCategory,
      'country': country,
      'isAmbassador': isAmbassador,
      if (ambassadorTitle != null) 'ambassadorTitle': ambassadorTitle,
      if (email != null) 'email': email,
    };
  }
}
