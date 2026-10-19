import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tournament.dart';
import '../models/user.dart';
import '../models/tournament_bracket_model.dart';
import '../screens/tournaments/jat_draw_ceremony_screen.dart';
import '../theme/colors.dart';

/// 🔔 Service de rappel pour les Juges-Arbitres (JAT)
/// Envoie et affiche une alerte prioritaire la veille du tournoi (J-1)
/// pour inviter le JAT à vérifier les paires et finaliser le tirage au sort officiel.
class JatReminderService {
  static const String _prefDismissedPrefix = 'jat_eve_reminder_dismissed_';

  /// Vérifie si l'utilisateur est le JAT associé à ce tournoi
  static bool isUserRefereeForTournament(UserModel? user, TournamentModel tournament) {
    if (user == null) return false;
    // L'utilisateur doit impérativement être accrédité JAT ou Admin dans la base de données
    if (!user.isReferee && !user.isAdmin) return false;

    final refereeName = (tournament.referee ?? '').trim().toLowerCase();
    if (refereeName.isEmpty) return false;

    final userName = user.displayName.trim().toLowerCase();

    // 1. Correspondance exacte ou partielle par Nom / Prénom
    if (userName.isNotEmpty) {
      if (refereeName == userName) return true;

      // Comparaison des mots (ex: "Thomas Laurent" vs "Laurent Thomas")
      final userWords = userName.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
      final refWords = refereeName.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
      if (userWords.isNotEmpty && refWords.isNotEmpty) {
        final matches = userWords.where((w) => refWords.any((rw) => rw.contains(w) || w.contains(rw)));
        if (matches.length >= 2 || (userWords.length == 1 && matches.isNotEmpty)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Détermine si la date d'aujourd'hui est la veille du tournoi (J-1)
  static bool isTournamentEve(TournamentModel tournament) {
    final start = tournament.startDate;
    if (start == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tourneyDay = DateTime(start.year, start.month, start.day);

    final diffDays = tourneyDay.difference(today).inDays;
    return diffDays == 1; // Exactement la veille !
  }

  /// Enregistre une notification J-1 dans Firestore pour archivage et push
  static Future<void> scheduleEveNotificationInFirestore({
    required UserModel user,
    required TournamentModel tournament,
  }) async {
    try {
      final docId = 'eve_${tournament.id}_${user.id}';
      final ref = FirebaseFirestore.instance.collection('jat_notifications').doc(docId);
      
      await ref.set({
        'id': docId,
        'tournamentId': tournament.id,
        'tournamentName': tournament.name,
        'userId': user.id,
        'refereeName': tournament.referee ?? user.displayName,
        'type': 'JAT_EVE_REMINDER',
        'title': '⏰ Tournoi demain : ${tournament.name}',
        'message': 'Bonjour ${user.displayName.split(' ').first} ! Votre tournoi débute demain. Pensez à vérifier vos paires et finaliser votre tirage au sort sur BeachMatch.',
        'scheduledAt': FieldValue.serverTimestamp(),
        'tournamentStartDate': tournament.startDate?.toIso8601String(),
        'isRead': false,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Vérifie si le rappel J-1 a déjà été fermé aujourd'hui par le JAT
  static Future<bool> isReminderDismissed(String tournamentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefDismissedPrefix$tournamentId';
      final dateStr = prefs.getString(key);
      if (dateStr == null) return false;

      final savedDate = DateTime.tryParse(dateStr);
      if (savedDate == null) return false;

      final now = DateTime.now();
      return savedDate.year == now.year && savedDate.month == now.month && savedDate.day == now.day;
    } catch (_) {
      return false;
    }
  }

  /// Marque le rappel comme vu pour aujourd'hui
  static Future<void> markReminderDismissed(String tournamentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefDismissedPrefix$tournamentId';
      await prefs.setString(key, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Recherche un tournoi à J-1 dont l'utilisateur est le JAT
  static TournamentModel? findEveTournamentForJat({
    required List<TournamentModel> tournaments,
    required UserModel? user,
  }) {
    if (user == null) return null;

    for (final t in tournaments) {
      if (isTournamentEve(t) && isUserRefereeForTournament(user, t)) {
        return t;
      }
    }
    return null;
  }

  /// Affiche la boîte de dialogue ou bannière de rappel la veille du tournoi
  static Future<void> showEveReminderBanner(
    BuildContext context, {
    required TournamentModel tournament,
    required UserModel user,
  }) async {
    final dismissed = await isReminderDismissed(tournament.id);
    if (dismissed || !context.mounted) return;

    // Enregistrement Firestore en tâche de fond
    scheduleEveNotificationInFirestore(user: user, tournament: tournament);

    // Affichage d'une boîte de dialogue stylisée
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: AppColors.gold, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Rappel JAT · J-1",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bonjour ${user.displayName.split(' ').first} 👋",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Votre tournoi "${tournament.name}" débute DEMAIN !',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              "Pensez à vérifier vos paires engagées et à finaliser le tirage au sort officiel sur l'application.",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              markReminderDismissed(tournament.id);
              Navigator.pop(dialogCtx);
            },
            child: const Text("Plus tard", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              markReminderDismissed(tournament.id);
              Navigator.pop(dialogCtx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JatDrawCeremonyScreen(
                    tournament: tournament,
                    initialBracket: TournamentBracket(
                      tournamentId: tournament.id,
                      category: 'double_messieurs',
                      format: 'pools_and_bracket',
                      updatedAt: DateTime.now(),
                    ),
                    categoryKey: 'double_messieurs',
                    categoryLabel: 'DH',
                    onSaveBracket: (_) {},
                  ),
                ),
              );
            },
            icon: const Icon(Icons.casino_rounded, size: 16, color: Colors.black),
            label: const Text(
              "Faire le Tirage",
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
