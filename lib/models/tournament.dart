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
  
  // Geocoding cache in-memory & Firestore
  double? latitude;
  double? longitude;

  bool get isPassed {
    if (dateString.isEmpty || dateString == 'Inconnue') return false;
    try {
      String dateToParse = dateString;
      if (dateString.contains('-')) {
        dateToParse = dateString.split('-').last.trim();
      } else if (dateString.contains('au')) {
        dateToParse = dateString.split('au').last.trim();
      }
      final parts = dateToParse.split('/');
      if (parts.length == 3) {
        final date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        final today = DateTime.now();
        final startOfToday = DateTime(today.year, today.month, today.day);
        return startOfToday.isAfter(date.add(const Duration(days: 1)));
      }
    } catch (_) {}
    return false;
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
      price: data['price'] != null ? data['price'].toString() : null,
      scheduleDetails: data['scheduleDetails'],
      country: data['country'],
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
