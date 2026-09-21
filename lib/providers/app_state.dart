import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/tournament.dart';

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
  AppState() {
    _determinePosition();
    // Chargement immédiat et résilient des tournois et terrains dès l'instanciation
    loadTournaments(notify: false);
    _loadCourtsInternal();

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      try {
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists && userDoc.data() != null) {
            _currentUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
            if (_currentUser != null && _currentUser!.isBanned) {
              await FirebaseAuth.instance.signOut();
              _currentUser = null;
              _isLoading = false;
              notifyListeners();
              return;
            }
            if (!kIsWeb) {
              await _updateFCMToken();
            }
          }
          await loadData();
        } else {
          _currentUser = null;
          _isLoading = false;
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Erreur authStateChanges: $e");
      }
    });
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition();
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur geolocator: $e");
    }
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
  bool _isLoadingTournaments = false;
  bool get isLoadingTournaments => _isLoadingTournaments;

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
      await googleSignIn.signOut().catchError((_) => null); // Force account picker safely
      
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
      debugPrint("Erreur de connexion : $e");
      rethrow; // Rethrow to let the UI know it failed
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return isNewUser;
  }

  Future<bool> loginWithApple() async {
    _isLoading = true;
    notifyListeners();
    bool isNewUser = false;

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);
        final userDoc = await userRef.get();

        if (!userDoc.exists) {
          isNewUser = true;
          String displayName = "Joueur Apple";
          if (appleCredential.givenName != null || appleCredential.familyName != null) {
            displayName = "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}".trim();
            if (displayName.isEmpty) displayName = "Joueur Apple";
          }
          _currentUser = UserModel(
            id: userCredential.user!.uid,
            displayName: displayName,
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
          if (userCredential.user!.email == 'moixmb@gmail.com') {
            _currentUser = _currentUser!.copyWith(isAdmin: true);
            FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).update({'isAdmin': true});
          }
        }

        await _updateFCMToken();
        await loadData();
      }
      return isNewUser;
    } catch (e) {
      debugPrint("Erreur de connexion Apple : $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      debugPrint("Erreur d'inscription : ${e.code}");
      throw translateAuthError(e.code);
    } catch (e) {
      debugPrint("Erreur d'inscription : $e");
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
        final user = userCredential.user!;
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDoc = await userRef.get();
        
        if (!userDoc.exists || userDoc.data() == null) {
          isNewUser = true;
          _currentUser = UserModel(
            id: user.uid,
            displayName: user.displayName ?? "Nouveau Joueur",
            level: 1,
            eloScore: 0,
            location: _currentPosition != null ? "Ma Position" : "Non définie",
            isPremium: false,
            createdAt: DateTime.now(),
            isAdmin: user.email == 'moixmb@gmail.com',
          );
        } else {
          _currentUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
          if (_currentUser != null && _currentUser!.isBanned) {
            await FirebaseAuth.instance.signOut();
            _currentUser = null;
            throw "Votre compte a été banni.";
          }
          // Override if this is the admin account, in case it was created before this feature
          if (user.email == 'moixmb@gmail.com' && _currentUser != null) {
            _currentUser = _currentUser!.copyWith(isAdmin: true);
            // Save it back silently
            FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isAdmin': true});
          }
        }
        if (!kIsWeb) {
          await _updateFCMToken();
        }
        await loadData();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Erreur de connexion par email : ${e.code}");
      throw translateAuthError(e.code);
    } catch (e) {
      debugPrint("Erreur de connexion par email : $e");
      if (e is String) rethrow;
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
    final userData = _currentUser!.toMap();
    userData['searchTokens'] = _generateSearchTokens(pseudo, licenceNumber);
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).set(userData);
    await loadData();
  }
  
  Future<void> _updateFCMToken() async {
    if (kIsWeb || _currentUser == null) return;
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
      debugPrint("Erreur FCM Token: $e");
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
    
    final searchTokens = _generateSearchTokens(displayName, licenceNumber);

    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).set({
      'displayName': displayName,
      'location': location,
      'level': level,
      'searchTokens': searchTokens,
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

  // --- Apple UGC Guideline 1.2: Block / Unblock Users ---
  Future<void> blockUser(String targetUserId) async {
    if (_currentUser == null || targetUserId.isEmpty) return;
    if (_currentUser!.blockedUserIds.contains(targetUserId)) return;

    final updatedBlocked = List<String>.from(_currentUser!.blockedUserIds)..add(targetUserId);
    _currentUser = _currentUser!.copyWith(blockedUserIds: updatedBlocked);
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).update({
        'blockedUserIds': FieldValue.arrayUnion([targetUserId]),
      });
    } catch (e) {
      debugPrint("Erreur blockUser: $e");
    }
  }

  Future<void> unblockUser(String targetUserId) async {
    if (_currentUser == null || targetUserId.isEmpty) return;
    if (!_currentUser!.blockedUserIds.contains(targetUserId)) return;

    final updatedBlocked = List<String>.from(_currentUser!.blockedUserIds)..remove(targetUserId);
    _currentUser = _currentUser!.copyWith(blockedUserIds: updatedBlocked);
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).update({
        'blockedUserIds': FieldValue.arrayRemove([targetUserId]),
      });
    } catch (e) {
      debugPrint("Erreur unblockUser: $e");
    }
  }

  bool isUserBlocked(String userId) {
    return _currentUser?.blockedUserIds.contains(userId) ?? false;
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
  Future<void> loadTournaments({bool notify = true}) async {
    _isLoadingTournaments = true;
    if (notify) notifyListeners();

    try {
      final tournamentsSnapshot = await FirebaseFirestore.instance
          .collection('tournaments')
          .limit(300)
          .get()
          .timeout(const Duration(seconds: 12));

      final List<TournamentModel> list = [];
      for (var doc in tournamentsSnapshot.docs) {
        try {
          list.add(TournamentModel.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint("Erreur parsing tournoi ${doc.id}: $e");
        }
      }
      if (list.isNotEmpty) {
        _tournaments = list;
      }
    } catch (e) {
      debugPrint("Erreur chargement tournois: $e");
      // Fallback offline cache
      try {
        final cacheSnapshot = await FirebaseFirestore.instance
            .collection('tournaments')
            .get(const GetOptions(source: Source.cache));
        if (cacheSnapshot.docs.isNotEmpty) {
          final List<TournamentModel> cacheList = [];
          for (var doc in cacheSnapshot.docs) {
            try {
              cacheList.add(TournamentModel.fromMap(doc.data(), doc.id));
            } catch (_) {}
          }
          if (cacheList.isNotEmpty) {
            _tournaments = cacheList;
          }
        }
      } catch (_) {}
    } finally {
      _isLoadingTournaments = false;
      notifyListeners();
    }
  }

  Future<void> _loadCourtsInternal() async {
    try {
      final courtSnapshot = await FirebaseFirestore.instance
          .collection('courts')
          .get()
          .timeout(const Duration(seconds: 10));
      _courts = courtSnapshot.docs.map((doc) => CourtModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint("Erreur chargement terrains: $e");
    }
  }

  Future<void> _loadPlayersInternal() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(500)
          .get()
          .timeout(const Duration(seconds: 10));
      _players = usersSnapshot.docs
          .where((doc) => doc.id != _currentUser?.id)
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint("Erreur chargement joueurs: $e");
    }
  }

  Future<void> _loadMatchesInternal() async {
    try {
      final matchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .limit(60)
          .get()
          .timeout(const Duration(seconds: 10));
      _matches = matchesSnapshot.docs.map((doc) => MatchModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint("Erreur chargement matchs: $e");
    }
  }

  void _syncUserRankingWithFFT() async {
    if (_currentUser == null || _currentUser!.licenceNumber == null || _currentUser!.licenceNumber!.isEmpty) return;
    final cleanLic = _currentUser!.licenceNumber!.replaceAll(RegExp(r'\D'), '');
    if (cleanLic.isEmpty) return;
    try {
      final fftDoc = await FirebaseFirestore.instance.collection('fft_rankings').doc(cleanLic).get();
      if (fftDoc.exists && fftDoc.data() != null) {
        final fftData = fftDoc.data()!;
        final officialRank = (fftData['level'] ?? fftData['ranking'] ?? fftData['rank'])?.toString();
        if (officialRank != null && officialRank.isNotEmpty && officialRank != _currentUser!.ranking) {
          _currentUser = _currentUser!.copyWith(ranking: officialRank);
          await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).update({'ranking': officialRank});
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> loadData() async {
    // 1. Chargement parallèle ultra-rapide et résilient
    await Future.wait([
      loadTournaments(notify: false),
      _loadCourtsInternal(),
      _loadPlayersInternal(),
      _loadMatchesInternal(),
    ]);
    notifyListeners();

    // 2. Synchronisation profil & FFT en arrière-plan sans bloquer l'UI
    if (_currentUser != null) {
      _syncUserRankingWithFFT();
    }
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

  // --- Filters ---
  String _selectedCourtFilter = 'ALL';
  String get selectedCourtFilter => _selectedCourtFilter;
  String _selectedCourtCountry = 'ALL';
  String get selectedCourtCountry => _selectedCourtCountry;
  bool _courtFilterHasNet = false;
  bool get courtFilterHasNet => _courtFilterHasNet;
  bool _courtFilterHasLights = false;
  bool get courtFilterHasLights => _courtFilterHasLights;

  void setCourtFilter(String filter) {
    _selectedCourtFilter = filter;
    notifyListeners();
  }

  void setCourtCountry(String country) {
    _selectedCourtCountry = country;
    notifyListeners();
  }

  void toggleCourtNetFilter() {
    _courtFilterHasNet = !_courtFilterHasNet;
    notifyListeners();
  }

  void toggleCourtLightsFilter() {
    _courtFilterHasLights = !_courtFilterHasLights;
    notifyListeners();
  }

  void resetCourtFilters() {
    _selectedCourtFilter = 'ALL';
    _selectedCourtCountry = 'ALL';
    _courtFilterHasNet = false;
    _courtFilterHasLights = false;
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
        if (c.accessType != 'BEACH_FREE') return false;
      } else if (_selectedCourtFilter == 'CLUB_FACILITY') {
        if (c.accessType != 'CLUB_ONLY' && c.accessType != 'RENTAL' && c.accessType != 'PUBLIC_FREE') return false;
      } else if (_selectedCourtFilter == 'RENTAL') {
        if (c.accessType != 'RENTAL') return false;
      } else if (_selectedCourtFilter == 'CLUB_ONLY') {
        if (c.accessType != 'CLUB_ONLY') return false;
      }
      
      // Feature filters
      if (_courtFilterHasNet && !c.hasNet) return false;
      if (_courtFilterHasLights && !c.hasLights) return false;

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

  String _normalizeSearch(String s) {
    return s.toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .trim();
  }

  List<String> _generateSearchTokens(String name, String? licence) {
    final tokens = <String>{};
    final normName = _normalizeSearch(name);
    final normLic = licence != null ? _normalizeSearch(licence).replaceAll(' ', '') : '';

    if (normName.isNotEmpty) {
      final parts = normName.split(RegExp(r'[\s\-]+'));
      for (var part in parts) {
        if (part.length >= 2) {
          for (int i = 2; i <= part.length && i <= 15; i++) {
            tokens.add(part.substring(0, i));
          }
        }
      }
      for (int i = 2; i <= normName.length && i <= 15; i++) {
        tokens.add(normName.substring(0, i));
      }
    }

    if (normLic.isNotEmpty) {
      for (int i = 3; i <= normLic.length && i <= 12; i++) {
        tokens.add(normLic.substring(0, i));
      }
    }

    return tokens.take(100).toList();
  }

  int _parseRankInt(dynamic val) {
    if (val == null) return 99999;
    if (val is int) return val;
    final s = val.toString().replaceAll(RegExp(r'\D'), '');
    return int.tryParse(s) ?? 99999;
  }

  void updatePlayerSearch(String query) {
    _playerSearchQuery = query;
    notifyListeners();
    
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      searchFFTPlayers(query);
    });
  }

  Future<void> searchFFTPlayers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) {
      _fftSearchResults = [];
      _isSearchingFFT = false;
      notifyListeners();
      return;
    }

    _isSearchingFFT = true;
    notifyListeners();

    try {
      final Map<String, Map<String, dynamic>> resultMap = {};
      void addCandidate(Map<String, dynamic> data, String docId) {
        final fName = (data['firstName'] ?? '').toString().trim();
        final lName = (data['lastName'] ?? '').toString().trim();
        final rawName = (data['name'] ?? '$fName $lName').toString().trim();
        final nameKey = _normalizeSearch(rawName);
        final lic = (data['licenceNumber'] ?? '').toString().trim();

        if (nameKey.isNotEmpty && resultMap.containsKey(nameKey)) {
          final existing = resultMap[nameKey]!;
          final existingLic = (existing['licenceNumber'] ?? '').toString().trim();
          if (existingLic.isEmpty && lic.isNotEmpty) {
            resultMap[nameKey] = data;
          }
          return;
        }

        final key = nameKey.isNotEmpty ? nameKey : (lic.isNotEmpty ? lic : docId);
        resultMap[key] = data;
      }

      final normalizedQuery = _normalizeSearch(cleanQuery);
      final tokens = normalizedQuery.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
      final digits = cleanQuery.replaceAll(RegExp(r'\D'), '');

      // 1. Recherche par numéro de licence si chiffres présents
      if (digits.length >= 3) {
        final licenceDoc = await FirebaseFirestore.instance.collection('fft_rankings').doc(digits).get();
        if (licenceDoc.exists && licenceDoc.data() != null) {
          addCandidate(Map<String, dynamic>.from(licenceDoc.data()!), digits);
        }

        final licenceSnap = await FirebaseFirestore.instance
            .collection('fft_rankings')
            .where('searchTokens', arrayContains: digits)
            .limit(30)
            .get();
        for (var doc in licenceSnap.docs) {
          addCandidate(Map<String, dynamic>.from(doc.data()), doc.id);
        }
      }

      // 2. Recherche rapide indexée par searchTokens (insensible aux accents et à la casse)
      for (var token in tokens) {
        final tokenSnap = await FirebaseFirestore.instance
            .collection('fft_rankings')
            .where('searchTokens', arrayContains: token)
            .limit(80)
            .get();
        for (var doc in tokenSnap.docs) {
          addCandidate(Map<String, dynamic>.from(doc.data()), doc.id);
        }
      }

      // 3. Fallback direct par préfixes majuscules & TitleCase si peu de résultats
      if (resultMap.length < 10) {
        final upperQ = cleanQuery.toUpperCase();
        final titleQ = cleanQuery[0].toUpperCase() + cleanQuery.substring(1).toLowerCase();

        final snapshots = await Future.wait([
          FirebaseFirestore.instance
              .collection('fft_rankings')
              .where('lastName', isGreaterThanOrEqualTo: upperQ)
              .where('lastName', isLessThanOrEqualTo: '$upperQ\uf8ff')
              .limit(30)
              .get(),
          FirebaseFirestore.instance
              .collection('fft_rankings')
              .where('firstName', isGreaterThanOrEqualTo: upperQ)
              .where('firstName', isLessThanOrEqualTo: '$upperQ\uf8ff')
              .limit(30)
              .get(),
          FirebaseFirestore.instance
              .collection('fft_rankings')
              .where('firstName', isGreaterThanOrEqualTo: titleQ)
              .where('firstName', isLessThanOrEqualTo: '$titleQ\uf8ff')
              .limit(30)
              .get(),
          FirebaseFirestore.instance
              .collection('fft_rankings')
              .where('lastName', isGreaterThanOrEqualTo: titleQ)
              .where('lastName', isLessThanOrEqualTo: '$titleQ\uf8ff')
              .limit(30)
              .get(),
        ]);

        for (var snap in snapshots) {
          for (var doc in snap.docs) {
            addCandidate(Map<String, dynamic>.from(doc.data()), doc.id);
          }
        }
      }

      // 4. Filtrage multi-tokens en mémoire
      List<Map<String, dynamic>> filtered = resultMap.values.where((data) {
        if (tokens.isEmpty) return true;
        final fName = _normalizeSearch((data['firstName'] ?? '').toString());
        final lName = _normalizeSearch((data['lastName'] ?? '').toString());
        final fullName = _normalizeSearch((data['name'] ?? '$fName $lName').toString());
        final club = _normalizeSearch((data['club'] ?? '').toString());
        final lic = (data['licenceNumber'] ?? '').toString();

        return tokens.every((tok) =>
            fullName.contains(tok) ||
            fName.contains(tok) ||
            lName.contains(tok) ||
            club.contains(tok) ||
            lic.contains(tok));
      }).toList();

      // 5. Tri intelligent : correspondance exacte d'abord, puis par meilleur classement FFT
      filtered.sort((a, b) {
        final aLic = (a['licenceNumber'] ?? '').toString();
        final bLic = (b['licenceNumber'] ?? '').toString();
        final aExactLic = aLic == cleanQuery;
        final bExactLic = bLic == cleanQuery;
        if (aExactLic && !bExactLic) return -1;
        if (!aExactLic && bExactLic) return 1;

        final rankA = _parseRankInt(a['rank'] ?? a['level']);
        final rankB = _parseRankInt(b['rank'] ?? b['level']);
        return rankA.compareTo(rankB);
      });

      _fftSearchResults = filtered.take(60).toList();
    } catch (e) {
      debugPrint("Erreur recherche FFT : $e");
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
      debugPrint("Erreur mise à jour recherche partenaire: $e");
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
      debugPrint("Erreur mise à jour abonnements terrains: $e");
    }
  }
}
