import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentModel {
  final String id;
  final String name;
  final String club;
  final String location;
  final String dateString;
  final double distance;
  final String category; // e.g., BT250, BT1000
  
  // Nouveaux champs détaillés (optionnels)
  final String? address;
  final String? balls;
  final String? referee;
  final String? contactPhone;
  final String? contactEmail;
  final String? registrationType;
  final String? registrationUrl;
  final String? price;
  final String? scheduleDetails;
  
  final String? country;
  final String? clubId;
  
  // Geocoding cache in-memory & Firestore
  double? latitude;
  double? longitude;

  DateTime? get startDate => _parseDatePart(false);
  DateTime? get endDate => _parseDatePart(true);

  DateTime? _parseDatePart(bool getEnd) {
    if (dateString.isEmpty || dateString == 'Inconnue') return null;
    try {
      String s = dateString.trim();
      if (s.toLowerCase().startsWith('du ')) {
        s = s.substring(3).trim();
      }

      String target = s;
      if (s.toLowerCase().contains(' au ')) {
        final parts = s.split(RegExp(r'\s+au\s+', caseSensitive: false));
        if (parts.length >= 2) {
          target = getEnd ? parts[1].trim() : parts[0].trim();
        }
      } else if (s.contains(' - ')) {
        final parts = s.split(' - ');
        if (parts.length >= 2) {
          target = getEnd ? parts[1].trim() : parts[0].trim();
        }
      }

      // Format DD/MM/YYYY or DD/MM/YY
      final frMatch = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(target);
      if (frMatch != null) {
        final day = int.parse(frMatch.group(1)!);
        final month = int.parse(frMatch.group(2)!);
        var year = int.parse(frMatch.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }

      // Format YYYY-MM-DD
      final isoMatch = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(target);
      if (isoMatch != null) {
        final year = int.parse(isoMatch.group(1)!);
        final month = int.parse(isoMatch.group(2)!);
        final day = int.parse(isoMatch.group(3)!);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  bool get isPassed {
    final end = endDate ?? startDate;
    if (end == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return end.isBefore(today);
  }

  String get city {
    if (location.isNotEmpty) return location.split(',').first.trim();
    if (club.isNotEmpty) return club;
    return 'France';
  }

  TournamentModel({
    required this.id,
    required this.name,
    required this.club,
    required this.location,
    required this.dateString,
    required this.distance,
    required this.category,
    this.address,
    this.balls,
    this.referee,
    this.contactPhone,
    this.contactEmail,
    this.registrationType,
    this.registrationUrl,
    this.price,
    this.scheduleDetails,
    this.country,
    this.clubId,
    this.latitude,
    this.longitude,
  });

  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TournamentModel.fromMap(data, doc.id);
  }

  factory TournamentModel.fromMap(Map<String, dynamic> data, String id) {
    double? lat;
    double? lng;
    if (data['latitude'] != null) {
      if (data['latitude'] is num) {
        lat = (data['latitude'] as num).toDouble();
      } else {
        lat = double.tryParse(data['latitude'].toString());
      }
    }
    if (data['longitude'] != null) {
      if (data['longitude'] is num) {
        lng = (data['longitude'] as num).toDouble();
      } else {
        lng = double.tryParse(data['longitude'].toString());
      }
    }

    double distance = 0.0;
    if (data['distance'] != null) {
      if (data['distance'] is num) {
        distance = (data['distance'] as num).toDouble();
      } else {
        distance = double.tryParse(data['distance'].toString()) ?? 0.0;
      }
    }

    return TournamentModel(
      id: id,
      name: data['name'] ?? data['title'] ?? '',
      club: data['club'] ?? data['clubName'] ?? '',
      location: data['location'] ?? data['city'] ?? '',
      dateString: data['dateString'] ?? (data['startDate'] != null ? '${data['startDate']}' : ''),
      distance: distance,
      category: data['category'] ?? data['level'] ?? '',
      address: data['address'],
      balls: data['balls'],
      referee: data['referee'],
      contactPhone: data['contactPhone'],
      contactEmail: data['contactEmail'],
      registrationType: data['registrationType'],
      registrationUrl: data['registrationUrl'],
      price: data['price']?.toString(),
      scheduleDetails: data['scheduleDetails'],
      country: data['country'],
      clubId: data['clubId'],
      latitude: lat,
      longitude: lng,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'club': club,
      'location': location,
      'dateString': dateString,
      'distance': distance,
      'category': category,
      if (clubId != null) 'clubId': clubId,
      if (address != null) 'address': address,
      if (balls != null) 'balls': balls,
      if (referee != null) 'referee': referee,
      if (contactPhone != null) 'contactPhone': contactPhone,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (registrationType != null) 'registrationType': registrationType,
      if (registrationUrl != null) 'registrationUrl': registrationUrl,
      if (price != null) 'price': price,
      if (scheduleDetails != null) 'scheduleDetails': scheduleDetails,
      if (country != null) 'country': country,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}
