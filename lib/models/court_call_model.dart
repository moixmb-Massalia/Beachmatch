class CourtCallModel {
  final String id;
  final String tournamentId;
  final String category;
  final int court;
  final String roundName;
  final String pair1Name;
  final String pair2Name;
  final DateTime calledAt;
  final bool isActive;

  const CourtCallModel({
    required this.id,
    required this.tournamentId,
    required this.category,
    required this.court,
    required this.roundName,
    required this.pair1Name,
    required this.pair2Name,
    required this.calledAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tournamentId': tournamentId,
      'category': category,
      'court': court,
      'roundName': roundName,
      'pair1Name': pair1Name,
      'pair2Name': pair2Name,
      'calledAt': calledAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory CourtCallModel.fromMap(Map<String, dynamic> map, String id) {
    return CourtCallModel(
      id: id,
      tournamentId: map['tournamentId'] ?? '',
      category: map['category'] ?? '',
      court: map['court'] is int ? map['court'] : int.tryParse(map['court'].toString()) ?? 1,
      roundName: map['roundName'] ?? '',
      pair1Name: map['pair1Name'] ?? '',
      pair2Name: map['pair2Name'] ?? '',
      calledAt: map['calledAt'] != null
          ? DateTime.tryParse(map['calledAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }
}
