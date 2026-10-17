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
    );
  }
}
