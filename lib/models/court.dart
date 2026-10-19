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
    final lat = (data['latitude'] as num?)?.toDouble() ?? double.tryParse('${data['latitude']}') ?? 0.0;
    final lng = (data['longitude'] as num?)?.toDouble() ?? double.tryParse('${data['longitude']}') ?? 0.0;
    
    String country = (data['country'] ?? '').toString().trim();
    if (country.isEmpty) {
      if (lng < -30 && lat < 10) {
        country = 'Brésil';
      } else if (lat > 35 && lat < 44 && lng > -10 && lng < 5) {
        country = 'Espagne';
      } else if (lat > 36 && lat < 47 && lng > 6 && lng < 19) {
        country = 'Italie';
      } else {
        country = 'France';
      }
    }

    return CourtModel(
      id: documentId,
      name: data['name'] ?? 'Terrain inconnu',
      city: data['city'] ?? '',
      country: country,
      latitude: lat,
      longitude: lng,
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
