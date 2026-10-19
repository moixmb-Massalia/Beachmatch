class MatchModel {
  final String id;
  final String hostId;
  final String courtId;
  final DateTime scheduledTime;
  final int targetLevel;
  final int maxPlayers;
  final List<String> participantsIds;
  final bool isPrivate;
  final String description;
  final String? pixKey;
  final double? courtCost;

  MatchModel({
    required this.id,
    required this.hostId,
    required this.courtId,
    required this.scheduledTime,
    required this.targetLevel,
    required this.maxPlayers,
    required this.participantsIds,
    this.isPrivate = false,
    this.description = '',
    this.pixKey,
    this.courtCost,
  });

  List<String> get playerIds => participantsIds;
  String get creatorId => hostId;

  factory MatchModel.fromMap(Map<String, dynamic> data, String documentId) {
    DateTime parsedDate = DateTime.now();
    if (data['scheduledTime'] != null) {
      if (data['scheduledTime'] is String) {
        parsedDate = DateTime.parse(data['scheduledTime']);
      } else if (data['scheduledTime'] is DateTime) {
        parsedDate = data['scheduledTime'];
      } else {
        // Assume it's a Timestamp
        parsedDate = data['scheduledTime'].toDate();
      }
    }

    return MatchModel(
      id: documentId,
      hostId: data['hostId'] ?? '',
      courtId: data['courtId'] ?? '',
      scheduledTime: parsedDate,
      targetLevel: data['targetLevel'] ?? 3,
      maxPlayers: data['maxPlayers'] ?? 4,
      participantsIds: List<String>.from(data['participantsIds'] ?? []),
      isPrivate: data['isPrivate'] ?? false,
      description: data['description'] ?? '',
      pixKey: data['pixKey'],
      courtCost: (data['courtCost'] is num) ? (data['courtCost'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'hostId': hostId,
      'courtId': courtId,
      'scheduledTime': scheduledTime,
      'targetLevel': targetLevel,
      'maxPlayers': maxPlayers,
      'participantsIds': participantsIds,
      'isPrivate': isPrivate,
      'description': description,
    };
    if (pixKey != null && pixKey!.isNotEmpty) map['pixKey'] = pixKey;
    if (courtCost != null && courtCost! > 0) map['courtCost'] = courtCost;
    return map;
  }
}

