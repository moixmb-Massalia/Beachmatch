import 'package:shared_preferences/shared_preferences.dart';

/// Service gérant la persistance des bulles explicatives contextuelles.
/// Chaque bulle/astuce n'est affichée qu'une seule et unique fois pour l'utilisateur.
class FeatureDiscoveryService {
  static final FeatureDiscoveryService _instance = FeatureDiscoveryService._internal();
  factory FeatureDiscoveryService() => _instance;
  FeatureDiscoveryService._internal();

  static const String _prefix = 'feature_seen_';

  /// Vérifie si la bulle pour cette fonctionnalité doit être affichée (non vue).
  Future<bool> shouldShow(String featureKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool('$_prefix$featureKey') ?? false);
    } catch (_) {
      return false; // En cas d'erreur, ne pas importuner l'utilisateur
    }
  }

  /// Marque la fonctionnalité comme définitivement vue.
  Future<void> markAsSeen(String featureKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix$featureKey', true);
    } catch (_) {
      // Ignorer
    }
  }

  /// Réinitialise l'historique (pour le débogage ou si l'utilisateur le demande explicitement).
  Future<void> resetAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Ignorer
    }
  }
}
