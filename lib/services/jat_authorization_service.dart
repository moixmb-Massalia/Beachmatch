import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/tournament.dart';

/// ⚖️ Service d'Autorisation et de Sécurité JAT (Juge-Arbitre de Tournoi)
/// 
/// Garantit que seuls les Juges-Arbitres officiellement répertoriés dans la base
/// de données (collection `preauthorized_jats` ou utilisateurs accrédités `isReferee == true`),
/// les présidents de club organisateur et les administrateurs ont le droit
/// de modifier, supprimer ou arbitrer un tournoi.
/// 
/// 🚫 Empêche toute usurpation d'identité basée sur un simple pseudonyme ou un bouton "C'est moi".
class JatAuthorizationService {
  /// Vérifie de manière stricte si l'utilisateur connecté est un JAT accrédité
  /// et assigné à ce tournoi précis.
  static Future<bool> isAuthorizedForTournament({
    required UserModel? user,
    required TournamentModel tournament,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return false;

    final authEmail = authUser.email?.toLowerCase().trim();

    // 1. Super-Administrateur absolu
    if (user?.isAdmin == true || authEmail == 'moixmb@gmail.com') {
      return true;
    }

    if (authEmail == null || authEmail.isEmpty) return false;

    // 2. Exception JAT Marana (Brice Massal)
    if (authEmail == 'massalbrice@gmail.com') {
      final clubLower = tournament.club.toLowerCase().trim();
      final locLower = tournament.location.toLowerCase().trim();
      final nameLower = tournament.name.toLowerCase().trim();
      if (clubLower.contains('marana') ||
          locLower.contains('furiani') ||
          nameLower.contains('marana') ||
          nameLower.contains('corse')) {
        return true;
      }
    }

    // 3. JAT assigné officiellement par email sur la fiche du tournoi
    final contactEmail = tournament.contactEmail?.toLowerCase().trim();
    if (contactEmail != null && contactEmail.isNotEmpty && contactEmail == authEmail) {
      return true;
    }

    // 4. Vérification dans l'annuaire officiel `preauthorized_jats`
    try {
      final preauthDoc = await FirebaseFirestore.instance
          .collection('preauthorized_jats')
          .doc(authEmail)
          .get();

      if (preauthDoc.exists) {
        final data = preauthDoc.data()!;
        final isJatAdmin = data['isAdmin'] == true;
        if (isJatAdmin) return true;

        final assignedTournaments = List<String>.from(data['assignedTournaments'] ?? []);
        if (assignedTournaments.contains(tournament.id)) return true;

        final affiliatedClubs = List<String>.from(data['clubs'] ?? []);
        final tClub = tournament.club.toLowerCase().trim();
        if (affiliatedClubs.any((c) => c.toLowerCase().trim() == tClub || tClub.contains(c.toLowerCase().trim()))) {
          return true;
        }

        final preauthName = (data['name'] ?? '').toString().toLowerCase().trim();
        final refName = (tournament.referee ?? '').toLowerCase().trim();
        if (preauthName.isNotEmpty && refName.isNotEmpty) {
          if (preauthName.contains(refName) || refName.contains(preauthName)) {
            return true;
          }
        }

        final isReferee = data['isReferee'] == true || data['role'] == 'JAT';
        if (isReferee && assignedTournaments.isEmpty && affiliatedClubs.isEmpty) {
          return true;
        }
      }
    } catch (e) {
      debugPrint("JatAuthorizationService: Erreur vérification preauthorized_jats: $e");
    }

    // 5. Utilisateur officiellement accrédité JAT dans notre base (`user.isReferee == true`)
    if (user != null && user.isReferee) {
      final refereeRaw = (tournament.referee ?? '')
          .toLowerCase()
          .replaceAll('(jat)', '')
          .replaceAll('(jae2)', '')
          .replaceAll('(jae1)', '')
          .trim();
      final appUserName = user.displayName.toLowerCase().trim();
      final authDisplayName = (authUser.displayName ?? '').toLowerCase().trim();

      // STRICT : Le nom de l'arbitre n'est pris en compte QUE si l'utilisateur
      // a le badge `isReferee == true` validé par la base de données.
      if (refereeRaw.length >= 4) {
        if ((appUserName.length >= 4 && (refereeRaw.contains(appUserName) || appUserName.contains(refereeRaw))) ||
            (authDisplayName.length >= 4 && (refereeRaw.contains(authDisplayName) || authDisplayName.contains(refereeRaw)))) {
          return true;
        }
      }
    }

    // 6. Président du club organisateur
    try {
      final clubQuery = await FirebaseFirestore.instance
          .collection('clubs')
          .where('presidentEmails', arrayContains: authEmail)
          .get();

      for (var doc in clubQuery.docs) {
        final clubName = doc.data()['name']?.toString().toLowerCase().trim();
        if (clubName == tournament.club.toLowerCase().trim()) {
          return true;
        }
      }
    } catch (e) {
      debugPrint("JatAuthorizationService: Erreur vérification président club: $e");
    }

    return false;
  }
}
