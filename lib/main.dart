import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'theme/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/match_confirmation_screen.dart';
import 'screens/clubs/club_detail_screen.dart';
import 'screens/tournaments/tournament_detail_screen.dart';
import 'models/club.dart';
import 'models/tournament.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'providers/app_state.dart';
import 'screens/tournaments/beach_score_hub_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  await initializeDateFormatting('fr_FR', null);
  
  try {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      // Ignore if it's a duplicate app error
      if (!e.toString().contains('duplicate')) {
        rethrow;
      }
    }

    // Request notification permissions on mobile only
    if (!kIsWeb) {
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await messaging.subscribeToTopic('beachscore_live');
      } catch (e) {
        debugPrint("Notification init error: $e");
      }
    }

    runApp(
      ChangeNotifierProvider(
        create: (context) => AppState(),
        child: const BeachMatchApp(),
      ),
    );
  } catch (e) {
    debugPrint("Erreur critique au démarrage: $e");
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Erreur au lancement de Firebase:\n$e",
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class BeachMatchApp extends StatefulWidget {
  const BeachMatchApp({super.key});

  @override
  State<BeachMatchApp> createState() => _BeachMatchAppState();
}

class _BeachMatchAppState extends State<BeachMatchApp> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      try {
        // Listen to foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
            debugPrint('Message en premier plan: ${message.notification?.title}');
            final ctx = navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text("${message.notification?.title} : ${message.notification?.body}"),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.gold,
                  action: SnackBarAction(
                    label: "Voir",
                    textColor: Colors.black,
                    onPressed: () => _handleMessageRoute(message),
                  ),
                ),
              );
            }
          }
        });

        // Handle background / terminated messages clicks
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleMessageRoute(message);
        });

        _checkInitialMessage();
        _initDeepLinks();
      } catch (e) {
        debugPrint("Messaging listeners error: $e");
      }
    }
  }

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  void _initDeepLinks() {
    _appLinks = AppLinks();
    
    // Check initial link if app was in cold state (terminated)
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Handle link when app is in warm state (foreground/background)
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      debugPrint("Erreur DeepLink: $err");
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint("Deep link reçu : $uri (path: ${uri.path}, params: ${uri.queryParameters})");

    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'match') {
      final matchId = uri.pathSegments[1];
      debugPrint("Ouverture du match via Deep Link: $matchId");
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lien de match détecté : $matchId")),
        );
      }
    } else if (uri.path.contains('club') || uri.queryParameters.containsKey('id') || uri.queryParameters.containsKey('clubId')) {
      final clubId = uri.queryParameters['id'] ?? uri.queryParameters['clubId'] ?? (uri.pathSegments.length >= 2 ? uri.pathSegments[1] : null);
      if (clubId != null && clubId.isNotEmpty) {
        FirebaseFirestore.instance.collection('clubs').doc(clubId).get().then((doc) {
          if (doc.exists) {
            final club = ClubModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => ClubDetailScreen(club: club)),
            );
          }
        }).catchError((e) {
          debugPrint("Erreur chargement club via deep link: $e");
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageRoute(initialMessage);
    }
  }

  void _handleMessageRoute(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'match_confirmation' && message.data['matchId'] != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => MatchConfirmationScreen(matchId: message.data['matchId']),
        ),
      );
    } else if (type == 'match_joined' || type == 'match_full' || type == 'score_confirmed' || type == 'match_player_left' || type == 'match_reminder' || type == 'new_match') {
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 0)),
      );
    } else if (type == 'new_tournament' || type == 'partner_proposal') {
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 2)),
      );
    } else if (type == 'ranking_update') {
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 2)),
      );
    } else if (type == 'pro_match_live') {
      final streamUrl = message.data['streamUrl'];
      if (streamUrl != null && streamUrl.toString().isNotEmpty) {
        launchUrl(Uri.parse(streamUrl.toString()), mode: LaunchMode.externalApplication);
      } else {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const BeachScoreHubScreen()),
        );
      }
    } else if (type == 'club_announcement' || type == 'club_message') {
      final clubId = message.data['clubId'];
      if (clubId != null && clubId.toString().isNotEmpty) {
        FirebaseFirestore.instance.collection('clubs').doc(clubId.toString()).get().then((doc) {
          if (doc.exists) {
            final club = ClubModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => ClubDetailScreen(club: club)),
            );
          }
        }).catchError((_) {
          _navigateToChat();
        });
      } else {
        _navigateToChat();
      }
    } else if (type == 'tournament_message') {
      final tournamentId = message.data['tournamentId'];
      if (tournamentId != null && tournamentId.toString().isNotEmpty) {
        FirebaseFirestore.instance.collection('tournaments').doc(tournamentId.toString()).get().then((doc) {
          if (doc.exists) {
            final tournament = TournamentModel.fromFirestore(doc);
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: tournament)),
            );
          }
        }).catchError((_) {
          _navigateToChat();
        });
      } else {
        _navigateToChat();
      }
    } else {
      _navigateToChat();
    }
  }

  void _navigateToChat() {
    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'BeachMatch',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('es'),
        Locale('it'),
        Locale('pt'),
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return const Locale('fr');
      },
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.gold,
          surface: AppColors.background,
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          Theme.of(context).textTheme,
        ).apply(
          bodyColor: AppColors.textMain,
          displayColor: AppColors.textMain,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // 📐 Responsive Anti-Débordement : Verrouillage intelligent de l'échelle des textes (0.85x à 1.15x)
        final clampedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedTextScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
