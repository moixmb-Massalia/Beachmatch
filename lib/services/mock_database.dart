import '../models/user.dart';
import '../models/court.dart';
import '../models/match.dart';

/// Service fictif pour simuler Firebase (Firestore) en attendant
/// la vraie connexion au cloud.
class MockDatabaseService {
  
  // Faux utilisateur connecté
  Future<UserModel> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return UserModel(
      id: 'user_123',
      displayName: 'Alexandre Martin',
      level: 3,
      eloScore: 1250,
      location: 'Nice, France',
      isPremium: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  // Faux terrains
  Future<List<CourtModel>> getNearbyCourts() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      CourtModel(
        id: 'court_1',
        name: 'Plage des Anglais - Terrain 1',
        latitude: 43.6961,
        longitude: 7.2717,
        isFree: true,
        hasLights: true,
        hasShowers: true,
      ),
      CourtModel(
        id: 'court_2',
        name: 'Plage du Centenaire',
        latitude: 43.6950,
        longitude: 7.2650,
        isFree: true,
        hasLights: false,
        hasShowers: false,
      ),
    ];
  }

  // Faux matchs
  Future<List<MatchModel>> getAvailableMatches() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      MatchModel(
        id: 'match_1',
        hostId: 'user_456', // Sofia R.
        courtId: 'court_1',
        scheduledTime: DateTime.now().add(const Duration(hours: 4)),
        targetLevel: 4,
        maxPlayers: 4,
        participantsIds: ['user_456', 'user_789'],
      ),
    ];
  }
}
