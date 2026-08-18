import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/tournament.dart';
import '../services/mock_database.dart';

String translateAuthError(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'Cette adresse email est déjà utilisée.';
    case 'invalid-email':
      return 'Adresse email invalide.';
    case 'operation-not-allowed':
      return 'Opération non autorisée.';
    case 'weak-password':
      return 'Le mot de passe est trop faible.';
    case 'user-disabled':
      return 'Ce compte a été désactivé.';
    case 'user-not-found':
      return 'Aucun compte trouvé avec cet email.';
    case 'wrong-password':
      return 'Mot de passe incorrect.';
    case 'invalid-credential':
      return 'Email ou mot de passe incorrect.';
    default:
      return 'Une erreur est survenue ($code).';
  }
}

class AppState extends ChangeNotifier {
  final MockDatabaseService _db = MockDatabaseService();
  
  AppState() {
    _determinePosition();
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _currentUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
          if (_currentUser!.isBanned) {
            await FirebaseAuth.instance.signOut();
            _currentUser = null;
            _isLoading = false;
            notifyListeners();
            return;
          }
          await _updateFCMToken();
        }
        await loadData();
      } else {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    _currentPosition = await Geolocator.getCurrentPosition();
    notifyListeners();
  }

  Future<void> refreshLocation() async {
    await _determinePosition();
  }

  bool _isLoading = false;
  bool _isJoiningMatch = false;
  String? _error;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;
  
  // Provide a default fallback location (Nice) if GPS is unavailable
  LatLng get mapCenter => _currentPosition != null 
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) 
      : const LatLng(43.6961, 7.2717);

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isJoiningMatch => _isJoiningMatch;
  String? get error => _error;

  List<CourtModel> _courts = [];
  List<CourtModel> get courts => _courts;

  List<MatchModel> _matches = [];
  List<MatchModel> get matches => _matches;

  List<TournamentModel> _tournaments = [];
  List<TournamentModel> get tournaments => _tournaments;

  // Filtres
  bool _filterFree = false;
  bool get filterFree => _filterFree;

  String _playerSearchQuery = "";
  String get playerSearchQuery => _playerSearchQuery;

  // --- Auth ---
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    bool isNewUser = false;
    
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // Force account picker
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw "Connexion Google annulée";
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Sync with Firestore
        final userRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);
        final userDoc = await userRef.get();
        
        if (!userDoc.exists) {
          isNewUser = true;
          // We don't save yet, we let onboarding do it. We just store the partial model in memory.
          _currentUser = UserModel(
            id: userCredential.user!.uid,
            displayName: userCredential.user!.displayName ?? "Nouveau Joueur",
            level: 1,
            eloScore: 0,
            location: _currentPosition != null ? "Ma Position" : "Non définie",
            isPremium: false,
            createdAt: DateTime.now(),
            isAdmin: userCredential.user!.email == 'moixmb@gmail.com',
          );
        } else {
          _currentUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
          if (_currentUser!.isBanned) {
            await FirebaseAuth.instance.signOut();
            _currentUser = null;
            throw "Votre compte a été banni.";
          }
          // Override if this is the admin account, in case it was created before this feature
          if (userCredential.user!.email == 'moixmb@gmail.com') {
            _currentUser = _currentUser!.copyWith(isAdmin: true);
            // Save it back silently
            FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).update({'isAdmin': true});
          }
        }
        
        // Ensure FCM Token is saved on login
        await _updateFCMToken();
        
        await loadData();
      }
    } catch (e) {
      print("Erreur de connexion : $e");
      throw e; // Rethrow to let the UI know it failed
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return isNewUser;
  }

  Future<bool> signUpWithEmail(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(name);
        
        // Prepare memory user for onboarding
        _currentUser = UserModel(
          id: userCredential.user!.uid,
          displayName: name,
          level: 1,
          eloScore: 0,
          location: _currentPosition != null ? "Ma Position" : "Non définie",
          isPremium: false,
          createdAt: DateTime.now(),
          isAdmin: userCredential.user!.email == 'moixmb@gmail.com',
        );
        success = true;
      }
    } on FirebaseAuthException catch (e) {
      print("Erreur d'inscription : ${e.code}");
      throw translateAuthError(e.code);
    } catch (e) {
      print("Erreur d'inscription : $e");
      throw "Une erreur est survenue lors de l'inscription.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> loginWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    bool isNewUser = false;
    
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);
        final userDoc = await userRef.get();
        
        if (!userDoc.exists) {
          isNewUser = true;
          _currentUser = UserModel(
            id: userCredential.user!.uid,
            displayName: userCredential.user!.displayName ?? "Nouveau Joueur",
            level: 1,
            eloScore: 0,
            location: _currentPosition != null ? "Ma Position" : "Non définie",
            isPremium: false,
            createdAt: DateTime.now(),
            isAdmin: userCredential.user!.email == 'moixmb@gmail.com',
          );
        } else {
          _currentUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
          if (_currentUser!.isBanned) {
            await FirebaseAuth.instance.signOut();
            _currentUser = null;
            throw "Votre compte a été banni.";
          }
          // Override if this is the admin account, in case it was created before this feature
          if (userCredential.user!.email == 'moixmb@gmail.com') {
            _currentUser = _currentUser!.copyWith(isAdmin: true);
            // Save it back silently
            FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).update({'isAdmin': true});
          }
        }
        await _updateFCMToken();
        await loadData();
      }
    } on FirebaseAuthException catch (e) {
      print("Erreur de connexion par email : ${e.code}");
      throw translateAuthError(e.code);
    } catch (e) {
      print("Erreur de connexion par email : $e");
      throw "Une erreur est survenue lors de la connexion.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return isNewUser;
  }

  Future<void> completeOnboarding(String pseudo, int level, {String? licenceNumber, int? eloScore, String? ranking}) async {
    if (_currentUser == null) return;
    
    // Update model
    _currentUser = UserModel(
      id: _currentUser!.id,
      displayName: pseudo,
      level: level,
      eloScore: eloScore ?? 0,
      ranking: ranking,
      location: _currentUser!.location,
      isPremium: false,
      createdAt: _currentUser!.createdAt,
      licenceNumber: licenceNumber,
      fcmToken: _currentUser!.fcmToken,
    );
    
    // Save to Firestore
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).set(_currentUser!.toMap());
    await loadData();
  }
  
  Future<void> _updateFCMToken() async {
    if (_currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token != _currentUser!.fcmToken) {
        // Use copyWith to preserve ALL existing fields (especially eloScore and friends)
        _currentUser = _currentUser!.copyWith(fcmToken: token);
        // We only save to Firestore if the user doc already exists (to avoid breaking onboarding)
        final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).get();
        if (doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).set({
            'fcmToken': token
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print("Erreur FCM Token: $e");
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String location,
    required int level,
    String? photoUrl,
    String? licenceNumber,
    String? ranking,
    int? eloScore,
    String? preferredPosition,
    String? availability,
  }) async {
    if (_currentUser == null) return;
    
    _currentUser = _currentUser!.copyWith(
      displayName: displayName,
      location: location,
      level: level,
      photoUrl: photoUrl,
      licenceNumber: licenceNumber,
      ranking: ranking,
      eloScore: eloScore ?? _currentUser!.eloScore,
      preferredPosition: preferredPosition ?? _currentUser!.preferredPosition,
      availability: availability ?? _currentUser!.availability,
    );
    
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).set({
      'displayName': displayName,
      'location': location,
      'level': level,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (licenceNumber != null) 'licenceNumber': licenceNumber,
      if (ranking != null) 'ranking': ranking,
      if (eloScore != null) 'eloScore': eloScore,
      if (preferredPosition != null) 'preferredPosition': preferredPosition,
      if (availability != null) 'availability': availability,
    }, SetOptions(merge: true));
    
    notifyListeners();
  }

  Future<void> updateUserPreferences({
    required bool tournamentAlertsEnabled,
    String? alertRegion,
  }) async {
    if (_currentUser == null) return;
    
    _currentUser = _currentUser!.copyWith(
      tournamentAlertsEnabled: tournamentAlertsEnabled,
      alertRegion: alertRegion ?? _currentUser!.alertRegion,
    );
    
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).set({
      'tournamentAlertsEnabled': tournamentAlertsEnabled,
      if (alertRegion != null) 'alertRegion': alertRegion,
    }, SetOptions(merge: true));
    
    notifyListeners();
  }

  Future<void> updateGamePreferences({
    String? preferredPosition,
    String? availability,
    int? level,
    bool? isLookingForPartner,
  }) async {
    if (_currentUser == null) return;
    
    _currentUser = _currentUser!.copyWith(
      preferredPosition: preferredPosition ?? _currentUser!.preferredPosition,
      availability: availability ?? _currentUser!.availability,
      level: level ?? _currentUser!.level,
      isLookingForPartner: isLookingForPartner ?? _currentUser!.isLookingForPartner,
    );
    
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).set({
      if (preferredPosition != null) 'preferredPosition': preferredPosition,
      if (availability != null) 'availability': availability,
      if (level != null) 'level': level,
      if (isLookingForPartner != null) 'isLookingForPartner': isLookingForPartner,
    }, SetOptions(merge: true));
    
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _isLoading = false;
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    if (_currentUser == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final userId = _currentUser!.id;
      final user = FirebaseAuth.instance.currentUser;
      
      // Delete user document in Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      } catch (_) {}
      
      // Sign out from Google if signed in
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      // Delete Firebase Auth user if active
      if (user != null) {
        await user.delete();
      }
      
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    } finally {
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  List<UserModel> _players = [];
  List<UserModel> get players => _players;

  // --- Password Reset ---
  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw translateAuthError(e.code);
    } catch (e) {
      throw "Erreur lors de l'envoi de l'email : $e";
    }
  }

  // --- Data Loading ---
  Future<void> loadData() async {
    // Inject demo courts if none exist
    await _seedCourtsIfEmpty();
    // Inject tournaments if none exist
    await _seedTournamentsIfEmpty();
    // Run database cleanup (desautel deletion, accate deduplication, elo reset)
    await _cleanDatabase();
    
    // Refresh _currentUser in memory so eloScore reset (0 pts) reflects immediately
    if (_currentUser != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).get();
      if (userDoc.exists) {
        _currentUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
      }
    }
    
    // Read courts from Firestore
    final courtSnapshot = await FirebaseFirestore.instance.collection('courts').get();
    _courts = courtSnapshot.docs.map((doc) => CourtModel.fromMap(doc.data(), doc.id)).toList();
    
    // Read players from Firestore
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    _players = usersSnapshot.docs
        .where((doc) => doc.id != _currentUser?.id) // Exclude current user
        .map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    
    // Read matches from Firestore
    final matchesSnapshot = await FirebaseFirestore.instance.collection('matches').get();
    _matches = matchesSnapshot.docs.map((doc) => MatchModel.fromMap(doc.data(), doc.id)).toList();
    
    // Read tournaments from Firestore
    final tournamentsSnapshot = await FirebaseFirestore.instance.collection('tournaments').get();
    _tournaments = tournamentsSnapshot.docs.map((doc) => TournamentModel.fromMap(doc.data(), doc.id)).toList();
    
    notifyListeners();
  }

  Future<void> markTutorialAsSeen() async {
    if (_currentUser == null) return;
    
    _currentUser = UserModel(
      id: _currentUser!.id,
      displayName: _currentUser!.displayName,
      location: _currentUser!.location,
      level: _currentUser!.level,
      eloScore: 0,
      isPremium: _currentUser!.isPremium,
      createdAt: _currentUser!.createdAt,
      photoUrl: _currentUser!.photoUrl,
      licenceNumber: _currentUser!.licenceNumber,
      hasSeenTutorial: true,
    );
    
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).set({
      'hasSeenTutorial': true,
    }, SetOptions(merge: true));
    
    notifyListeners();
  }

  Future<void> addFriend(String friendId) async {
    if (_currentUser == null) return;
    if (_currentUser!.friendsIds.contains(friendId)) return;

    final updatedFriends = List<String>.from(_currentUser!.friendsIds)..add(friendId);
    
    // Optimistic update
    _currentUser = UserModel(
      id: _currentUser!.id,
      displayName: _currentUser!.displayName,
      location: _currentUser!.location,
      level: _currentUser!.level,
      eloScore: 0,
      isPremium: _currentUser!.isPremium,
      createdAt: _currentUser!.createdAt,
      photoUrl: _currentUser!.photoUrl,
      licenceNumber: _currentUser!.licenceNumber,
      hasSeenTutorial: _currentUser!.hasSeenTutorial,
      fcmToken: _currentUser!.fcmToken,
      friendsIds: updatedFriends,
    );
    notifyListeners();

    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).update({
      'friendsIds': FieldValue.arrayUnion([friendId])
    });
  }

  Future<void> removeFriend(String friendId) async {
    if (_currentUser == null) return;
    if (!_currentUser!.friendsIds.contains(friendId)) return;

    final updatedFriends = List<String>.from(_currentUser!.friendsIds)..remove(friendId);
    
    // Optimistic update
    _currentUser = UserModel(
      id: _currentUser!.id,
      displayName: _currentUser!.displayName,
      location: _currentUser!.location,
      level: _currentUser!.level,
      eloScore: 0,
      isPremium: _currentUser!.isPremium,
      createdAt: _currentUser!.createdAt,
      photoUrl: _currentUser!.photoUrl,
      licenceNumber: _currentUser!.licenceNumber,
      hasSeenTutorial: _currentUser!.hasSeenTutorial,
      fcmToken: _currentUser!.fcmToken,
      friendsIds: updatedFriends,
    );
    notifyListeners();

    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).update({
      'friendsIds': FieldValue.arrayRemove([friendId])
    });
  }
  
  Future<String?> createMatch({
    required String courtId,
    required DateTime scheduledTime,
    required int targetLevel,
    required int maxPlayers,
    List<String>? invitedPlayerIds,
    bool isPrivate = false,
    String description = '',
  }) async {
    if (_currentUser == null) return null;
    
    List<String> participants = [_currentUser!.id];
    if (invitedPlayerIds != null) {
      participants.addAll(invitedPlayerIds);
    }
    
    final newMatch = {
      'hostId': _currentUser!.id,
      'courtId': courtId,
      'scheduledTime': scheduledTime,
      'targetLevel': targetLevel,
      'maxPlayers': maxPlayers,
      'participantsIds': participants,
      'isPrivate': isPrivate,
      'description': description,
    };
    
    final docRef = await FirebaseFirestore.instance.collection('matches').add(newMatch);
    await loadData();
    return docRef.id;
  }
  
  Future<void> joinMatch(String matchId) async {
    if (_currentUser == null || _isJoiningMatch) return;
    
    // Check locally first to avoid unnecessary writes
    final match = _matches.firstWhere((m) => m.id == matchId);
    if (match.participantsIds.contains(_currentUser!.id)) return;
    
    _isJoiningMatch = true;
    notifyListeners();
    
    try {
      await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
        'participantsIds': FieldValue.arrayUnion([_currentUser!.id])
      });
      await loadData();
    } finally {
      _isJoiningMatch = false;
      notifyListeners();
    }
  }

  Future<void> confirmMatch(String matchId, List<String> presentUserIds) async {
    if (_currentUser == null) return;
    
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('confirmMatchScore');
      await callable.call({
        'matchId': matchId,
        'presentUserIds': presentUserIds,
      });

      // Update local state if current user was present
      if (presentUserIds.contains(_currentUser!.id)) {
        _currentUser = _currentUser!.copyWith(eloScore: _currentUser!.eloScore + 40);
        notifyListeners();
      }
    } catch (e) {
      throw "Impossible de valider le match : $e";
    }
  }

  Future<void> leaveMatch(String matchId) async {
    if (_currentUser == null) return;
    
    final matchRef = FirebaseFirestore.instance.collection('matches').doc(matchId);
    await matchRef.update({
      'participantsIds': FieldValue.arrayRemove([_currentUser!.id])
    });
    
    await loadData();
  }
  
  Future<void> cancelMatch(String matchId) async {
    if (_currentUser == null) return;
    final match = _matches.firstWhere((m) => m.id == matchId);
    if (match.hostId != _currentUser!.id) return; // Only host can cancel
    
    // Optimistic update
    _matches.removeWhere((m) => m.id == matchId);
    notifyListeners();

    await FirebaseFirestore.instance.collection('matches').doc(matchId).delete();
  }

  Future<void> kickPlayer(String matchId, String playerId) async {
    if (_currentUser == null) return;
    final matchIndex = _matches.indexWhere((m) => m.id == matchId);
    if (matchIndex == -1) return;
    final match = _matches[matchIndex];
    if (match.hostId != _currentUser!.id) return; // Only host can kick

    final updatedParticipants = List<String>.from(match.participantsIds)..remove(playerId);
    
    // Optimistic update
    _matches[matchIndex] = MatchModel(
      id: match.id,
      hostId: match.hostId,
      courtId: match.courtId,
      scheduledTime: match.scheduledTime,
      targetLevel: match.targetLevel,
      maxPlayers: match.maxPlayers,
      participantsIds: updatedParticipants,
    );
    notifyListeners();

    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'participantsIds': FieldValue.arrayRemove([playerId])
    });
  }
  Future<void> _cleanDatabase() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // 1. Clean courts (delete desautel, deduplicate accate and other duplicates)
      final courtsSnap = await firestore.collection('courts').get();
      final Map<String, String> seenCourtNames = {};
      bool accateFound = false;

      for (var doc in courtsSnap.docs) {
        final data = doc.data();
        final name = (data['name'] as String? ?? '').trim();
        final lowerName = name.toLowerCase();

        if (lowerName.isEmpty) continue;

        // Delete "desautel"
        if (lowerName.contains('desautel')) {
          await firestore.collection('courts').doc(doc.id).delete();
          continue;
        }

        // Delete extra "accate"
        if (lowerName.contains('accate')) {
          if (accateFound) {
            await firestore.collection('courts').doc(doc.id).delete();
            continue;
          } else {
            accateFound = true;
          }
        }

        // Deduplicate exact names
        if (seenCourtNames.containsKey(lowerName)) {
          await firestore.collection('courts').doc(doc.id).delete();
        } else {
          seenCourtNames[lowerName] = doc.id;
        }
      }

      // Note: ELO scores are managed exclusively by the confirmMatchScore Cloud Function.
      // Do NOT reset them here.
    } catch (e) {
      print("Erreur nettoyage BDD: $e");
    }
  }

  Future<void> _seedCourtsIfEmpty() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('courts').limit(1).get().timeout(const Duration(seconds: 5));
      if (snapshot.docs.isEmpty) {
        final initialCourts = [
          {"name": "Plage des Anglais", "latitude": 43.695, "longitude": 7.26, "isFree": true, "hasLighting": true, "hasParking": false},
          {"name": "Club de Cannes", "latitude": 43.5528, "longitude": 7.0174, "isFree": false, "hasLighting": true, "hasParking": true},
          {"name": "Plage de la Salis (Antibes)", "latitude": 43.5765, "longitude": 7.1278, "isFree": true, "hasLighting": false, "hasParking": true},
        ];
        
        for (var court in initialCourts) {
          await FirebaseFirestore.instance.collection('courts').add(court);
        }
      }
    } catch (e) {
      print("Erreur ou Timeout seed courts: $e");
    }
  }

  Future<void> _seedTournamentsIfEmpty() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('tournaments').limit(1).get().timeout(const Duration(seconds: 5));
      if (snapshot.docs.isEmpty) {
        final initialTournaments = [
          {"name": "BT250 Mixte", "club": "BEACH TENNIS MARSEILLE", "location": "MARSEILLE 09", "distance": 2.7, "dateString": "09/08/2026", "category": "BT 250", "address": "18 Chemin Joseph Aiguier, 13009 MARSEILLE 09", "balls": "Beach Tennis Pro", "referee": "Sebastien PIVOT", "contactPhone": "06 48 63 34 31", "contactEmail": "seb.pivot@live.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Mixte Senior"},
          {"name": "BEACH TENNIS PEYPIN BT100", "club": "TENNIS CLUB PEYPIN", "location": "PEYPIN", "distance": 22.6, "dateString": "30/08/2026", "category": "BT 100", "address": "Avenue des Belonnets, 13124 PEYPIN", "balls": "Kuikma Beach Tennis Pro", "referee": "Arnaud CHATELAIN", "contactPhone": "07 88 17 53 32", "contactEmail": "arnaud.chatelain13@gmail.com", "registrationType": "Inscription sur place ou par téléphone. limite à 8 equipes par catégorie", "price": "10,00 €", "scheduleDetails": "Double Dames Senior, Double Messieurs Senior"},
          {"name": "BEACH TENNIS PEYPIN BT250", "club": "TENNIS CLUB PEYPIN", "location": "PEYPIN", "distance": 22.6, "dateString": "22/08/2026 au 23/08/2026", "category": "BT 250", "address": "Avenue des Belonnets, 13124 PEYPIN", "balls": "Kuikma Beach Tennis Pro", "referee": "Arnaud CHATELAIN", "registrationType": "Inscription sur place ou par téléphone.", "price": "10,00 €", "scheduleDetails": "Double Dames, Double Messieurs, Double Mixte. Limité à 8 équipes/catégorie. Repas sur réservation."},
          {"name": "Tournoi beach tennis Pra Loup", "club": "TC PRALOUP - MOLANES", "location": "PRA LOUP", "distance": 159.0, "dateString": "15/08/2026", "category": "BT 250", "address": "pra-loup les molanes, 04400 PRA LOUP", "balls": "Mini", "referee": "Jean-Jacques MARGUERON", "contactPhone": "+33 6 71 47 84 49", "contactEmail": "jean-jacques.margueron@fft.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "10,00 €", "scheduleDetails": "Double Messieurs Senior"},
          {"name": "BT250", "club": "DYNAMIC'SPORT", "location": "Tourrettes-Levens", "distance": 164.9, "dateString": "29/08/2026", "category": "BT 250", "address": "191 Allée Thierry Combe, 06690 Tourrettes-Levens", "balls": "Kuikma Beach Tennis Pro", "referee": "Robin DUVINAGE", "contactPhone": "06 51 16 16 95", "contactEmail": "duvinage.robin@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "15,00 €", "scheduleDetails": "Double Dames, Double Messieurs, Double Mixte. Hommes / Femmes & Mixtes"},
          {"name": "BT 250 adultes", "club": "MONTMEYRAN TC", "location": "MONTMEYRAN", "distance": 178.5, "dateString": "17/08/2026", "category": "BT 250", "address": "stade de la riviere, 26120 MONTMEYRAN", "balls": "Kuikma Beach Tennis Pro", "referee": "Flavien DESPEISSE", "contactPhone": "06 26 40 08 21", "contactEmail": "flaviendespeissepro@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Dames, Double Messieurs. Valeur en lot : 100,00 €"},
          {"name": "BT250 MIXTE AJA", "club": "AUXERRE A.J.", "location": "AUXERRE", "distance": 522.5, "dateString": "01/08/2026", "category": "BT 250", "address": "35, route de Vaux, 89000 AUXERRE", "balls": "Kuikma Beach Tennis Pro", "referee": "Virginie PIERRON", "contactPhone": "06 62 74 31 10", "contactEmail": "v.sylvestre76@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "0,00 €", "scheduleDetails": "Tournoi uniquement sur la matinée. Double Dames Senior BT250, Double Messieurs U14 BT100."},
          {"name": "Festi'Beach Estival", "club": "JOIGNY U.S.", "location": "JOIGNY", "distance": 547.2, "dateString": "08/08/2026 au 09/08/2026", "category": "BT 250", "address": "Bd de Godalming, 89300 JOIGNY", "balls": "Beach Tennis Pro", "referee": "Yann CHANDIVERT", "contactPhone": "06 18 45 00 66", "contactEmail": "ychandivert@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "De 5,00 € à 15,00 €", "scheduleDetails": "Épreuves: U14, U18 (BT100) et Seniors (BT250/BT500). Cash prize pour les BT500 (290€). Repas, buvette, et concert gratuit le samedi soir !"},
          {"name": "BT 2000 Summer BT Tour Arcachon", "club": "ARCACHON TC", "location": "ARCACHON", "distance": 548.0, "dateString": "07/08/2026 au 08/08/2026", "category": "BT 2000", "address": "7 avenue du Parc, 33120 ARCACHON", "balls": "PRO LINE", "referee": "Marion POIDEVIN", "contactPhone": "06 84 96 78 88", "contactEmail": "marion.poidevin@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Dames & Messieurs Seniors (BT2000). Cash prize exceptionnel: 2000€ par catégorie (Vainqueurs: 1000€)."},
          {"name": "BT 500 Summer BT Tour Arcachon", "club": "ARCACHON TC", "location": "ARCACHON", "distance": 548.0, "dateString": "07/08/2026 au 08/08/2026", "category": "BT 500", "address": "7 avenue du Parc, 33120 ARCACHON", "balls": "PRO LINE", "referee": "Marion POIDEVIN", "contactPhone": "06 84 96 78 88", "contactEmail": "marion.poidevin@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Dames & Messieurs Seniors (BT500). Cash prize: 251€ par catégorie (Vainqueurs: 141€)."},
          {"name": "BT 250 Jeunes et BT 100", "club": "ARCACHON TC", "location": "ARCACHON", "distance": 548.0, "dateString": "06/08/2026", "category": "BT 250", "address": "7 avenue du Parc, 33120 ARCACHON", "balls": "PRO LINE", "referee": "Jerome LOPEZ", "contactPhone": "06 38 50 46 25", "contactEmail": "lopez0708@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "10,00 €", "scheduleDetails": "U14 & U18 (BT250 Jeunes), Seniors (BT100). Double Dames et Double Messieurs."},
          {"name": "BT 2000 Summer BT Tour Carcans", "club": "MAUBUISSON TC", "location": "CARCANS", "distance": 557.7, "dateString": "01/08/2026 au 02/08/2026", "category": "BT 2000", "address": "super maubuisson, 33121 CARCANS", "balls": "PRO LINE", "referee": "Clement RICART", "contactPhone": "05 59 01 64 74", "contactEmail": "clementricart@yahoo.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Dames & Messieurs Seniors (BT2000). Cash prize exceptionnel: 2000€ par catégorie (Vainqueurs: 1000€)."},
          {"name": "BT 250 Jeunes et BT 100 - Carcans", "club": "MAUBUISSON TC", "location": "CARCANS", "distance": 557.7, "dateString": "31/07/2026", "category": "BT 250", "address": "super maubuisson, 33121 CARCANS", "balls": "PRO LINE", "referee": "Clement RICART", "contactPhone": "05 59 01 64 74", "contactEmail": "clementricart@yahoo.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "10,00 €", "scheduleDetails": "U14 & U18 (BT250 Jeunes), Seniors (BT100). Double Dames et Double Messieurs."},
          {"name": "BT 500 Summer BT Tour Carcans", "club": "MAUBUISSON TC", "location": "CARCANS", "distance": 557.7, "dateString": "01/08/2026 au 02/08/2026", "category": "BT 500", "address": "super maubuisson, 33121 CARCANS", "balls": "PRO LINE", "referee": "Clement RICART", "contactPhone": "05 59 01 64 74", "contactEmail": "clementricart@yahoo.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Dames & Messieurs Seniors (BT500). Cash prize: 251€ par catégorie (Vainqueurs: 141€)."},
          {"name": "ITF BT 400 - St-Georges-de-Didonne", "club": "ROYAN ATLANTIQUE BEACH TENNIS", "location": "ST GEORGES DE DIDONNE", "distance": 572.4, "dateString": "11/08/2026 au 16/08/2026", "category": "BT 400", "address": "Plage de St Georges de Didonne, 17200 ST GEORGES DE DIDONNE", "balls": "PRO LINE", "referee": "Philippe GROS", "contactPhone": "06 86 70 42 61", "contactEmail": "philippe.gros@fft.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "0,00 €", "scheduleDetails": "Double Dames & Messieurs Seniors (ITF BT 400). Énorme cash prize : 22 500€ par catégorie (Vainqueurs: 11 250€) !"},
          {"name": "BT 2000 Summer BT Tour SGDD", "club": "ROYAN ATLANTIQUE BEACH TENNIS", "location": "ST GEORGES DE DIDONNE", "distance": 572.4, "dateString": "10/08/2026 au 11/08/2026", "category": "BT 2000", "address": "Plage de St Georges de Didonne, 17200 ST GEORGES DE DIDONNE", "balls": "PRO LINE", "referee": "Non renseigné", "registrationType": "Inscription sur place ou par téléphone.", "price": "15,00 € à 20,00 €", "scheduleDetails": "Double Dames & Messieurs Seniors (BT2000) et Double Mixte (BT500). Cash prize de 2000€ pour les catégories BT2000."},
          {"name": "BT 500 Summer BT Tour SGDD", "club": "ROYAN ATLANTIQUE BEACH TENNIS", "location": "ST GEORGES DE DIDONNE", "distance": 572.4, "dateString": "10/08/2026 au 11/08/2026", "category": "BT 500"},
          {"name": "BT 250 J. (ITF U18) et BT100 SGDD", "club": "ROYAN ATLANTIQUE BEACH TENNIS", "location": "ST GEORGES DE DIDONNE", "distance": 572.4, "dateString": "14/08/2026 au 15/08/2026", "category": "BT 250"},
          {"name": "BT250 Seniors - Summer Tour 2026", "club": "ROYAN ATLANTIQUE BEACH TENNIS", "location": "ST GEORGES DE DIDONNE", "distance": 572.4, "dateString": "10/08/2026 au 11/08/2026", "category": "BT 250", "address": "Plage de St Georges de Didonne, 17200 ST GEORGES DE DIDONNE", "balls": "PRO LINE", "referee": "Jerome LOPEZ", "contactPhone": "06 38 50 46 25", "contactEmail": "lopez0708@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "15,00 €", "scheduleDetails": "Double Dames & Messieurs Seniors (BT 250). Valeur en lot : 150€."},
          {"name": "BT500 Seniors - 15ème Open International", "club": "ROYAN ATLANTIQUE BEACH TENNIS", "location": "ST GEORGES DE DIDONNE", "distance": 572.4, "dateString": "14/08/2026 au 15/08/2026", "category": "BT 500", "address": "Plage de St Georges de Didonne, 17200 ST GEORGES DE DIDONNE", "balls": "PRO LINE", "referee": "Jerome LOPEZ", "contactPhone": "06 38 50 46 25", "contactEmail": "lopez0708@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "0,00 €", "scheduleDetails": "Double Dames & Messieurs Seniors (BT 500). Cash prize : 400€ par catégorie (Vainqueurs: 250€)."},
          {"name": "BT250 45+ - 15ème Open International", "club": "ROYAN ATLANTIQUE BEACH TENNIS", "location": "ST GEORGES DE DIDONNE", "distance": 572.4, "dateString": "14/08/2026 au 15/08/2026", "category": "BT 250", "address": "Plage de St Georges de Didonne, 17200 ST GEORGES DE DIDONNE", "balls": "PRO LINE", "referee": "Jerome LOPEZ", "contactPhone": "06 38 50 46 25", "contactEmail": "lopez0708@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "15,00 €", "scheduleDetails": "Double Dames 45 ans & Double Messieurs 45 ans (BT 250 Seniors +)."},
          {"name": "open BT aout Grubfeld1", "club": "TC EPFIG", "location": "SELESTAT", "distance": 581.3, "dateString": "22/08/2026", "category": "BT 250", "address": "Chemin de GRUBWEG, 67600 SELESTAT", "balls": "Kuikma Beach Tennis Pro", "referee": "Manuel FLIEG", "contactPhone": "06 13 13 31 35", "contactEmail": "manu.flieg@wanadoo.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "10,00 €", "scheduleDetails": "Double Messieurs Senior, Double Messieurs 45 ans, Double Mixte. Zone de loisir du Grubfeld de Sélestat, rue des sapins (pour le GPS)."},
          {"name": "open BT aout Grubfeld2", "club": "TC EPFIG", "location": "SELESTAT", "distance": 581.3, "dateString": "25/08/2026", "category": "BT 250", "address": "Chemin de GRUBWEG, 67600 SELESTAT", "balls": "Kuikma Beach Tennis Pro", "referee": "Manuel FLIEG", "contactPhone": "06 13 13 31 35", "contactEmail": "manu.flieg@wanadoo.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "10,00 €", "scheduleDetails": "Double Messieurs Senior, Double Messieurs 45 ans, Double Mixte. Zone de loisir du Grubfeld de Sélestat, rue des sapins (pour le GPS)."},
          {"name": "1er Tournoi BT de Cinq-Mars la Pile", "club": "TC DE CINQ MARS LA PILE", "location": "CINQ MARS LA PILE", "distance": 595.6, "dateString": "29/08/2026 au 30/08/2026", "category": "BT 250", "address": "Camping de Cinq Mars, 37130 CINQ MARS LA PILE", "balls": "Kuikma Beach Tennis Pro", "referee": "Antony DUVAL", "contactPhone": "06 67 98 72 39", "contactEmail": "bourseman@hotmail.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "10,00 €", "scheduleDetails": "Double Messieurs Senior & Double Mixte Senior (BT 25)."},
          {"name": "FFT BT 25 MIXTE DU BEACH PARK", "club": "ASSOCIATION BEACH PARK DIONYSIEN", "location": "STE CLOTILDE", "distance": 8776.1, "dateString": "01/08/2026 au 02/08/2026", "category": "BT 25", "address": "41 bis, rue Gabriel de Kerveguen, 97490 STE CLOTILDE", "balls": "Kuikma Beach Tennis Pro", "referee": "Nancy CADARSI", "contactPhone": "+26 2 69 32 04 23 1", "contactEmail": "nancycadarsi@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Mixte Senior (BT 25). Valeur en lot : 200€."},
          {"name": "FFT BT 250 OVER 45 BEACH PARK", "club": "ASSOCIATION BEACH PARK DIONYSIEN", "location": "STE CLOTILDE", "distance": 8776.1, "dateString": "22/08/2026", "category": "BT 250", "address": "41 bis, rue Gabriel de Kerveguen, 97490 STE CLOTILDE", "balls": "Kuikma Beach Tennis Pro", "referee": "Sébastien FRANCO-GEA", "contactPhone": "06 92 22 46 28", "contactEmail": "sfranco.gea@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Dames 45 ans & Double Messieurs 45 ans (BT 250 Seniors +). Valeur en lot : 200€."},
          {"name": "FFT BT 250 HOMMES DU BEACH PARK", "club": "ASSOCIATION BEACH PARK DIONYSIEN", "location": "STE CLOTILDE", "distance": 8776.1, "dateString": "06/08/2026", "category": "BT 250", "address": "41 bis, rue Gabriel de Kerveguen, 97490 STE CLOTILDE", "balls": "Kuikma Beach Tennis Pro", "referee": "Sabrina LEGROS", "contactPhone": "06 92 66 62 63", "contactEmail": "legrossabrina974@yahoo.fr", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Messieurs Senior (BT 250). Valeur en lot : 200€."},
          {"name": "FFT BT 100 DH/DF/MIXTE DU BEACH PARK", "club": "ASSOCIATION BEACH PARK DIONYSIEN", "location": "STE CLOTILDE", "distance": 8776.1, "dateString": "01/08/2026 au 02/08/2026", "category": "BT 100", "address": "41 bis, rue Gabriel de Kerveguen, 97490 STE CLOTILDE", "balls": "Kuikma Beach Tennis Pro", "referee": "Nancy CADARSI", "contactPhone": "+26 2 69 32 04 23 1", "contactEmail": "nancycadarsi@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Dames, Messieurs et Mixte (BT 100). Valeur en lot : 200€."},
          {"name": "FFT BT 250 FEMMES DU BEACH PARK", "club": "ASSOCIATION BEACH PARK DIONYSIEN", "location": "STE CLOTILDE", "distance": 8776.1, "dateString": "13/08/2026", "category": "BT 250", "address": "41 bis, rue Gabriel de Kerveguen, 97490 STE CLOTILDE", "balls": "Kuikma Beach Tennis Pro", "referee": "Marianne AUBRY", "contactPhone": "06 92 44 49 13", "contactEmail": "aubry.marianne@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Dames Senior (BT 250). Valeur en lot : 200€."},
          {"name": "FFT BT 250 MIXTE DU BEACH PARK", "club": "ASSOCIATION BEACH PARK DIONYSIEN", "location": "STE CLOTILDE", "distance": 8776.1, "dateString": "16/08/2026", "category": "BT 250", "address": "41 bis, rue Gabriel de Kerveguen, 97490 STE CLOTILDE", "balls": "Kuikma Beach Tennis Pro", "referee": "Denis APAVOU", "contactPhone": "+26 2 69 25 82 02 2", "contactEmail": "denis.apavou@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Mixte Senior (BT 250). Valeur en lot : 200€."},
          {"name": "FFT BT250 mixte", "club": "TENNIS CLUB SAINT-PIERRE", "location": "SAINT PIERRE", "distance": 8814.0, "dateString": "08/08/2026 au 09/08/2026", "category": "BT 250", "address": "76 chemin stephen rebecca, 97410 SAINT PIERRE", "balls": "Stage 2", "referee": "Angélique DUPUY", "contactPhone": "06 92 69 55 75", "contactEmail": "angie.legros@gmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Mixte Senior (BT 250). Valeur en lot : 50€."},
          {"name": "FFT BT100", "club": "TENNIS CLUB SAINT-PIERRE", "location": "SAINT PIERRE", "distance": 8814.0, "dateString": "15/08/2026", "category": "BT 100", "address": "76 chemin stephen rebecca, 97410 SAINT PIERRE", "balls": "TIP Beginners", "referee": "Cedric DUPUY", "contactPhone": "06 92 68 32 16", "contactEmail": "didicdupuy@hotmail.com", "registrationType": "Inscription sur place ou par téléphone.", "price": "20,00 €", "scheduleDetails": "Double Messieurs Senior (BT 100)."},
        ];
        
        for (var t in initialTournaments) {
          await FirebaseFirestore.instance.collection('tournaments').add(t);
        }
      }
    } catch (e) {
      print("Erreur ou Timeout seed tournaments: $e");
    }
  }

  // --- Filters ---
  String _selectedCourtFilter = 'ALL';
  String get selectedCourtFilter => _selectedCourtFilter;
  String _selectedCourtCountry = 'ALL';
  String get selectedCourtCountry => _selectedCourtCountry;

  void setCourtFilter(String filter) {
    _selectedCourtFilter = filter;
    notifyListeners();
  }

  void setCourtCountry(String country) {
    _selectedCourtCountry = country;
    notifyListeners();
  }

  void toggleFreeFilter() {
    _filterFree = !_filterFree;
    notifyListeners();
  }

  List<CourtModel> get filteredCourts {
    return _courts.where((c) {
      // Country filter
      if (_selectedCourtCountry == 'FR') {
        if (c.country.toLowerCase() != 'france') return false;
      } else if (_selectedCourtCountry == 'ES') {
        if (!c.country.toLowerCase().contains('espagne') && !c.country.toLowerCase().contains('spain')) return false;
      } else if (_selectedCourtCountry == 'IT') {
        if (!c.country.toLowerCase().contains('italie') && !c.country.toLowerCase().contains('italy')) return false;
      }

      // Access Type filter
      if (_selectedCourtFilter == 'BEACH_FREE') {
        return c.accessType == 'BEACH_FREE';
      } else if (_selectedCourtFilter == 'CLUB_FACILITY') {
        return c.accessType == 'CLUB_ONLY' || c.accessType == 'RENTAL' || c.accessType == 'PUBLIC_FREE';
      } else if (_selectedCourtFilter == 'RENTAL') {
        return c.accessType == 'RENTAL';
      } else if (_selectedCourtFilter == 'CLUB_ONLY') {
        return c.accessType == 'CLUB_ONLY';
      }
      
      if (_filterFree) {
        return c.isFree;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _fftSearchResults = [];
  List<Map<String, dynamic>> get fftSearchResults => _fftSearchResults;
  bool _isSearchingFFT = false;
  bool get isSearchingFFT => _isSearchingFFT;

  Timer? _searchDebounce;

  void updatePlayerSearch(String query) {
    _playerSearchQuery = query;
    notifyListeners();
    
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      searchFFTPlayers(query);
    });
  }

  Future<void> searchFFTPlayers(String query) async {
    if (query.trim().length < 2) {
      _fftSearchResults = [];
      notifyListeners();
      return;
    }

    _isSearchingFFT = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('https://europe-west1-beach-tennis-216f4.cloudfunctions.net/searchPlayers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'data': {'query': query}
        }),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body.containsKey('result') && body['result'] != null) {
          final results = body['result']['results'] as List<dynamic>?;
          if (results != null) {
            _fftSearchResults = results.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      }
    } catch (e) {
      print("Erreur de recherche FFT : $e");
    } finally {
      _isSearchingFFT = false;
      notifyListeners();
    }
  }

  Future<void> toggleLookingForPartner() async {
    if (_currentUser == null) return;
    final newValue = !_currentUser!.isLookingForPartner;
    _currentUser = _currentUser!.copyWith(isLookingForPartner: newValue);
    notifyListeners();
    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).update({
        'isLookingForPartner': newValue,
      });
    } catch (e) {
      print("Erreur mise à jour recherche partenaire: $e");
    }
  }

  Future<void> toggleCourtSubscription(String courtId) async {
    if (_currentUser == null) return;
    
    final currentCourts = List<String>.from(_currentUser!.subscribedCourts);
    final isSubscribed = currentCourts.contains(courtId);
    
    if (isSubscribed) {
      currentCourts.remove(courtId);
      await FirebaseMessaging.instance.unsubscribeFromTopic('court_$courtId');
    } else {
      currentCourts.add(courtId);
      await FirebaseMessaging.instance.subscribeToTopic('court_$courtId');
    }
    
    _currentUser = _currentUser!.copyWith(subscribedCourts: currentCourts);
    notifyListeners();
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).update({
        'subscribedCourts': currentCourts,
      });
    } catch (e) {
      print("Erreur mise à jour abonnements terrains: $e");
    }
  }
}
