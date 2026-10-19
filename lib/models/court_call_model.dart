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
    DateTime parsedCalledAt;
    final rawCalled = map['calledAt'];
    if (rawCalled == null) {
      parsedCalledAt = DateTime.now();
    } else if (rawCalled is DateTime) {
      parsedCalledAt = rawCalled;
    } else {
      try {
        final dynamic dyn = rawCalled;
        final toDate = dyn.toDate;
        if (toDate is Function) {
          parsedCalledAt = toDate() as DateTime;
        } else if (rawCalled is String) {
          parsedCalledAt = DateTime.tryParse(rawCalled) ?? DateTime.now();
        } else if (rawCalled is num) {
          parsedCalledAt = DateTime.fromMillisecondsSinceEpoch(rawCalled.toInt());
        } else {
          parsedCalledAt = DateTime.tryParse(rawCalled.toString()) ?? DateTime.now();
        }
      } catch (_) {
        parsedCalledAt = DateTime.now();
      }
    }

    return CourtCallModel(
      id: id,
      tournamentId: map['tournamentId']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      court: map['court'] is int ? map['court'] : (int.tryParse(map['court']?.toString() ?? '') ?? 1),
      roundName: map['roundName']?.toString() ?? '',
      pair1Name: map['pair1Name']?.toString() ?? '',
      pair2Name: map['pair2Name']?.toString() ?? '',
      calledAt: parsedCalledAt,
      isActive: map['isActive'] ?? true,
    );
  }
}
