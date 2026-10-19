import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 🔔 Service de rappels & alertes de matchs BeachScore
/// Déclenche une alerte exactement 1 MINUTE avant le coup d'envoi d'un match star !
class MatchReminderService {
  static const String _prefKey = 'reminded_match_ids';

  /// Vérifie si un rappel est configuré pour ce match
  static Future<bool> isReminderSet(String matchId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      return list.contains(matchId);
    } catch (_) {
      return false;
    }
  }

  /// Récupère la liste de tous les IDs de matchs sous rappel
  static Future<Set<String>> getRemindedMatchIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Active ou désactive le rappel à 1 minute du coup d'envoi
  static Future<bool> toggleReminder({
    required String matchId,
    required Map<String, dynamic> match,
    required Map<String, dynamic> tournament,
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      final alreadySet = list.contains(matchId);

      if (alreadySet) {
        list.remove(matchId);
        await prefs.setStringList(_prefKey, list);

        try {
          final docRef = FirebaseFirestore.instance.collection('match_reminders').doc('${matchId}_${userId ?? "anon"}');
          await docRef.delete();
        } catch (_) {}

        return false; // Rappel désactivé
      } else {
        list.add(matchId);
        await prefs.setStringList(_prefKey, list);

        // Calcul exact de l'heure du match et de l'alerte à 1 MINUTE AVANT
        DateTime matchTime = DateTime.now().add(const Duration(hours: 1));
        final dateStr = match['date']?.toString();
        final timeStr = match['time']?.toString() ?? '12:00';
        if (dateStr != null && dateStr.contains('-')) {
          try {
            final dp = dateStr.split('-');
            final tp = timeStr.replaceAll('h', ':').replaceAll(RegExp(r'[^0-9:]'), '').split(':');
            matchTime = DateTime(
              int.parse(dp[0]),
              int.parse(dp[1]),
              int.parse(dp[2]),
              int.parse(tp[0]),
              tp.length > 1 ? int.parse(tp[1]) : 0,
            );
          } catch (_) {}
        }

        // Exactement 1 minute avant le coup d'envoi !
        final alertTime = matchTime.subtract(const Duration(minutes: 1));

        // Enregistrement dans Firestore pour déclenchement push
        try {
          await FirebaseFirestore.instance.collection('match_reminders').doc('${matchId}_${userId ?? "anon"}').set({
            'matchId': matchId,
            'userId': userId ?? 'anonymous',
            'team1': match['team1'] ?? 'Paire 1',
            'team2': match['team2'] ?? 'Paire 2',
            'tournamentName': tournament['name'] ?? 'Tournoi Pro',
            'round': match['round'] ?? 'Match Officiel',
            'court': match['court'] ?? 'Court Central',
            'scheduledAt': Timestamp.fromDate(matchTime),
            'alertAt': Timestamp.fromDate(alertTime),
            'alertOffsetMinutes': 1, // Alerte à 1 minute du début !
            'streamUrl': match['streamUrl'] ?? tournament['youtubeChannel'],
            'status': 'PENDING',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Erreur enregistrement Firestore reminder: $e');
        }

        return true; // Rappel activé
      }
    } catch (e) {
      debugPrint('Erreur toggleReminder: $e');
      return false;
    }
  }
}
