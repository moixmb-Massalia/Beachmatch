import 'package:cloud_firestore/cloud_firestore.dart';

class PartnerRequestModel {
  final String id;
  final String tournamentId;
  final String tournamentName;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String fftRank;
  final String draw; // 'DH', 'DD', 'DX'
  final String preferredSide; // 'Gauche ⬅️', 'Droite ➡️', 'Polyvalent 🔄'
  final String goal; // 'Pour la gagne 🏆', 'Compétition & Podiums 🥈', 'Plaisir & Progression 🏖️'
  final String? message;
  final String? phone;
  final DateTime createdAt;
  final String status; // 'OPEN', 'PAIRED', 'CANCELLED'

  PartnerRequestModel({
    required this.id,
    required this.tournamentId,
    required this.tournamentName,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.fftRank = 'Non classé',
    required this.draw,
    required this.preferredSide,
    required this.goal,
    this.message,
    this.phone,
    required this.createdAt,
    this.status = 'OPEN',
  });

  factory PartnerRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PartnerRequestModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      tournamentName: data['tournamentName'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Joueur Solo',
      userPhoto: data['userPhoto'],
      fftRank: data['fftRank'] ?? 'Non classé',
      draw: data['draw'] ?? 'DH',
      preferredSide: data['preferredSide'] ?? 'Polyvalent 🔄',
      goal: data['goal'] ?? 'Compétition & Podiums 🥈',
      message: data['message'],
      phone: data['phone'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'OPEN',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'fftRank': fftRank,
      'draw': draw,
      'preferredSide': preferredSide,
      'goal': goal,
      'message': message,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }
}
