import 'package:cloud_firestore/cloud_firestore.dart';

class CourtSchedulePreset {
  final String id;
  final String tournamentId;
  final String name; // e.g. "Répartition 1", "Répartition 2 (Pluie)"
  final int numCourts;
  final List<String> categories; // e.g. ['DH', 'DD']
  final bool isOfficial;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, int> matchCourtAssignments;

  // ⏱️ Horaires, Durées & Pauses JAT
  final int startHour;
  final int startMinute;
  final int rotationDurationMinutes;
  final int lunchBreakDurationMinutes;
  final int lunchBreakAfterRotation;
  final Map<String, String> customRotationTimes; // e.g. "0" -> "09h00 - 10h15"
  final Map<String, int> customMatchRotations; // matchId -> rotIndex
  final Map<String, int> customMatchCourts; // matchId -> courtNumber

  const CourtSchedulePreset({
    required this.id,
    required this.tournamentId,
    required this.name,
    required this.numCourts,
    required this.categories,
    this.isOfficial = false,
    required this.createdAt,
    this.updatedAt,
    this.matchCourtAssignments = const {},
    this.startHour = 9,
    this.startMinute = 0,
    this.rotationDurationMinutes = 75,
    this.lunchBreakDurationMinutes = 0,
    this.lunchBreakAfterRotation = 0,
    this.customRotationTimes = const {},
    this.customMatchRotations = const {},
    this.customMatchCourts = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tournamentId': tournamentId,
      'name': name,
      'numCourts': numCourts,
      'categories': categories,
      'isOfficial': isOfficial,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'matchCourtAssignments': matchCourtAssignments,
      'startHour': startHour,
      'startMinute': startMinute,
      'rotationDurationMinutes': rotationDurationMinutes,
      'lunchBreakDurationMinutes': lunchBreakDurationMinutes,
      'lunchBreakAfterRotation': lunchBreakAfterRotation,
      'customRotationTimes': customRotationTimes,
      'customMatchRotations': customMatchRotations,
      'customMatchCourts': customMatchCourts,
    };
  }

  factory CourtSchedulePreset.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawAssignments = map['matchCourtAssignments'];
    final Map<String, int> assignments = {};
    if (rawAssignments is Map) {
      rawAssignments.forEach((key, value) {
        if (value is num) {
          assignments[key.toString()] = value.toInt();
        } else if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) assignments[key.toString()] = parsed;
        }
      });
    }

    final rawCustomTimes = map['customRotationTimes'];
    final Map<String, String> customTimes = {};
    if (rawCustomTimes is Map) {
      rawCustomTimes.forEach((key, value) {
        if (value != null) customTimes[key.toString()] = value.toString();
      });
    }

    final rawMatchRots = map['customMatchRotations'];
    final Map<String, int> matchRots = {};
    if (rawMatchRots is Map) {
      rawMatchRots.forEach((key, value) {
        if (value is num) {
          matchRots[key.toString()] = value.toInt();
        } else if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) matchRots[key.toString()] = parsed;
        }
      });
    }

    final rawMatchCourts = map['customMatchCourts'];
    final Map<String, int> matchCourts = {};
    if (rawMatchCourts is Map) {
      rawMatchCourts.forEach((key, value) {
        if (value is num) {
          matchCourts[key.toString()] = value.toInt();
        } else if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) matchCourts[key.toString()] = parsed;
        }
      });
    }

    return CourtSchedulePreset(
      id: docId.isNotEmpty ? docId : (map['id']?.toString() ?? ''),
      tournamentId: map['tournamentId']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Répartition',
      numCourts: (map['numCourts'] as num?)?.toInt() ?? 4,
      categories: (map['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['DH', 'DD'],
      isOfficial: map['isOfficial'] == true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      matchCourtAssignments: assignments,
      startHour: (map['startHour'] as num?)?.toInt() ?? 9,
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      rotationDurationMinutes: (map['rotationDurationMinutes'] as num?)?.toInt() ?? 75,
      lunchBreakDurationMinutes: (map['lunchBreakDurationMinutes'] as num?)?.toInt() ?? 0,
      lunchBreakAfterRotation: (map['lunchBreakAfterRotation'] as num?)?.toInt() ?? 0,
      customRotationTimes: customTimes,
      customMatchRotations: matchRots,
      customMatchCourts: matchCourts.isNotEmpty ? matchCourts : assignments,
    );
  }

  CourtSchedulePreset copyWith({
    String? id,
    String? tournamentId,
    String? name,
    int? numCourts,
    List<String>? categories,
    bool? isOfficial,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, int>? matchCourtAssignments,
    int? startHour,
    int? startMinute,
    int? rotationDurationMinutes,
    int? lunchBreakDurationMinutes,
    int? lunchBreakAfterRotation,
    Map<String, String>? customRotationTimes,
    Map<String, int>? customMatchRotations,
    Map<String, int>? customMatchCourts,
  }) {
    return CourtSchedulePreset(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      name: name ?? this.name,
      numCourts: numCourts ?? this.numCourts,
      categories: categories ?? this.categories,
      isOfficial: isOfficial ?? this.isOfficial,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      matchCourtAssignments: matchCourtAssignments ?? this.matchCourtAssignments,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      rotationDurationMinutes: rotationDurationMinutes ?? this.rotationDurationMinutes,
      lunchBreakDurationMinutes: lunchBreakDurationMinutes ?? this.lunchBreakDurationMinutes,
      lunchBreakAfterRotation: lunchBreakAfterRotation ?? this.lunchBreakAfterRotation,
      customRotationTimes: customRotationTimes ?? this.customRotationTimes,
      customMatchRotations: customMatchRotations ?? this.customMatchRotations,
      customMatchCourts: customMatchCourts ?? this.customMatchCourts,
    );
  }
}
