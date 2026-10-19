import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';

/// Service proactif de détection des pannes et de surveillance en temps réel.
/// Intercepte toutes les erreurs Flutter et Dart (Web & Mobile),
/// élimine les écrans gris sauvages et journalise les anomalies dans Firestore.
class CrashDetectorService {
  static final CrashDetectorService _instance = CrashDetectorService._internal();
  factory CrashDetectorService() => _instance;
  CrashDetectorService._internal();

  static final List<Map<String, dynamic>> _inMemoryRecentErrors = [];
  static final Map<String, DateTime> _lastLoggedTime = {};
  static bool _isInitialized = false;

  /// Liste en mémoire des 20 dernières erreurs capturées (pour l'écran admin)
  static List<Map<String, dynamic>> get recentErrors => List.unmodifiable(_inMemoryRecentErrors);

  /// Initialisation du détecteur de crashs au démarrage de l'application
  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Interception des erreurs de framework Flutter (rendu, widgets, layout)
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      recordError(
        details.exception,
        details.stack,
        context: details.context?.toString(),
        library: details.library,
      );
      if (kDebugMode) {
        originalOnError?.call(details);
      }
    };

    // 2. Interception des erreurs asynchrones non gérées (Futures, Streams)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(error, stack, context: 'Async / Platform Error');
      return true; // Empêche le crash fatal de l'application
    };

    // 3. Remplacement du terrifiant "Écran Gris" Flutter en mode Release
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _buildRecoveryWidget(details);
    };
  }

  /// Enregistre une anomalie dans la base Firestore et en mémoire
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? context,
    String? library,
  }) async {
    final errorString = exception.toString();
    final now = DateTime.now();

    // Anti-Spam : Évite de saturer Firestore si une erreur boucle dans build()
    final errorSignature = "${errorString.split('\n').first}_$context";
    final lastTime = _lastLoggedTime[errorSignature];
    if (lastTime != null && now.difference(lastTime).inSeconds < 15) {
      return;
    }
    _lastLoggedTime[errorSignature] = now;

    final trimmedStack = stack?.toString().split('\n').take(12).join('\n');

    final errorData = {
      'timestamp': FieldValue.serverTimestamp(),
      'clientTime': now.toIso8601String(),
      'error': errorString,
      'stack': trimmedStack,
      'context': context ?? 'Général',
      'library': library,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'version': '1.0.69+169',
      'status': 'NEW',
    };

    // Stockage en mémoire immédiat
    _inMemoryRecentErrors.insert(0, {
      ...errorData,
      'timestamp': now,
    });
    if (_inMemoryRecentErrors.length > 20) {
      _inMemoryRecentErrors.removeLast();
    }

    // Persistance dans Firestore (silencieuse pour ne jamais impacter l'UI)
    try {
      if (FirebaseFirestore.instance.app.options.projectId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('app_crash_reports').add(errorData);
      }
    } catch (e) {
      // Ignorer silencieusement si hors-ligne
    }
  }

  /// Widget élégant de récupération en cas d'erreur inattendue de rendu
  static Widget _buildRecoveryWidget(FlutterErrorDetails details) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 24),
            const SizedBox(height: 6),
            const Text(
              "Affichage momentanément indisponible",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "L'anomalie a été automatiquement transmise pour résolution.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
