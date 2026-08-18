class CourtModel {
  final String id;
  final String name;
  final String city;
  final String country;
  final double latitude;
  final double longitude;
  final bool isFree;
  final bool hasLights;
  final bool hasShowers;
  final String accessType; // 'BEACH_FREE', 'PUBLIC_FREE', 'RENTAL', 'CLUB_ONLY'
  final bool hasNet; // true = filet en place, false = amener son kit
  final int courtCount;
  final bool hasBar;
  final String? priceInfo;
  final String? bookingContact;
  final String? description;

  CourtModel({
    required this.id,
    required this.name,
    this.city = '',
    this.country = 'France',
    required this.latitude,
    required this.longitude,
    required this.isFree,
    required this.hasLights,
    required this.hasShowers,
    this.accessType = 'BEACH_FREE',
    this.hasNet = true,
    this.courtCount = 2,
    this.hasBar = false,
    this.priceInfo,
    this.bookingContact,
    this.description,
  });

  factory CourtModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CourtModel(
      id: documentId,
      name: data['name'] ?? 'Terrain inconnu',
      city: data['city'] ?? '',
      country: data['country'] ?? 'France',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      isFree: data['isFree'] ?? true,
      hasLights: data['hasLights'] ?? data['hasLighting'] ?? false,
      hasShowers: data['hasShowers'] ?? false,
      accessType: data['accessType'] ?? (data['isFree'] == false ? 'RENTAL' : 'BEACH_FREE'),
      hasNet: data['hasNet'] ?? true,
      courtCount: data['courtCount'] ?? 2,
      hasBar: data['hasBar'] ?? false,
      priceInfo: data['priceInfo'],
      bookingContact: data['bookingContact'],
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'isFree': isFree,
      'hasLights': hasLights,
      'hasShowers': hasShowers,
      'accessType': accessType,
      'hasNet': hasNet,
      'courtCount': courtCount,
      'hasBar': hasBar,
      if (priceInfo != null) 'priceInfo': priceInfo,
      if (bookingContact != null) 'bookingContact': bookingContact,
      if (description != null) 'description': description,
    };
  }
}
