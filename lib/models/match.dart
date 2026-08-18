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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'courtId': courtId,
      'scheduledTime': scheduledTime,
      'targetLevel': targetLevel,
      'maxPlayers': maxPlayers,
      'participantsIds': participantsIds,
      'isPrivate': isPrivate,
      'description': description,
    };
  }
}

