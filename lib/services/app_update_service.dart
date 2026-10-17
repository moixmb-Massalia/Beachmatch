import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

class AppUpdateService {
  static bool _isDialogShowing = false;

  /// Vérifie la version actuelle de l'application par rapport à Firestore
  /// et déclenche une mise à jour forcée ou recommandée si nécessaire.
  static Future<void> checkUpdate(BuildContext context, {bool silent = false}) async {
    // Les navigateurs web ont toujours la version la plus récente servie en direct
    if (kIsWeb) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVersion = packageInfo.version;

      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final bool enabled = data['enabled'] ?? true;
      if (!enabled) return;

      final int minRequiredBuild = (data['minRequiredBuild'] as num?)?.toInt() ?? 0;
      final int latestBuild = (data['latestBuild'] as num?)?.toInt() ?? 0;
      final String latestVersionName = data['latestVersionName']?.toString() ?? '';
      final String title = data['title']?.toString() ?? 'Mise à jour requise 🎾';
      final String message = data['message']?.toString() ??
          'Une nouvelle version de BeachMatch est disponible pour assurer le bon déroulement et la synchronisation des tournois.';
      final String playStoreUrl = data['playStoreUrl']?.toString() ??
          'https://play.google.com/store/apps/details?id=com.beachmatch.mobile';
      final String appStoreUrl = data['appStoreUrl']?.toString() ??
          'https://apps.apple.com/app/beachmatch/id6470000000';

      // 1. Mise à jour FORCÉE (Bloquante)
      final bool isForceUpdate = currentBuild < minRequiredBuild || data['forceUpdate'] == true;

      // 2. Mise à jour RECOMMANDÉE (Souple)
      final bool isRecommendedUpdate = currentBuild < latestBuild;

      if (!context.mounted) return;

      if (isForceUpdate) {
        _showUpdateDialog(
          context: context,
          isForced: true,
          title: title,
          message: message,
          currentVersion: currentVersion,
          latestVersion: latestVersionName.isNotEmpty ? latestVersionName : "v$latestBuild",
          playStoreUrl: playStoreUrl,
          appStoreUrl: appStoreUrl,
        );
      } else if (isRecommendedUpdate && !silent) {
        _showUpdateDialog(
          context: context,
          isForced: false,
          title: "Nouvelle version disponible 🚀",
          message: message,
          currentVersion: currentVersion,
          latestVersion: latestVersionName.isNotEmpty ? latestVersionName : "v$latestBuild",
          playStoreUrl: playStoreUrl,
          appStoreUrl: appStoreUrl,
        );
      }
    } catch (e) {
      debugPrint("AppUpdateService error: $e");
    }
  }

  static void _showUpdateDialog({
    required BuildContext context,
    required bool isForced,
    required String title,
    required String message,
    required String currentVersion,
    required String latestVersion,
    required String playStoreUrl,
    required String appStoreUrl,
  }) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: !isForced,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        return PopScope(
          canPop: !isForced,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222D),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isForced ? AppColors.gold : Colors.white24,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isForced ? AppColors.gold : Colors.cyan).withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône avec badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isForced
                            ? [AppColors.gold, const Color(0xFFFF8C00)]
                            : [Colors.cyanAccent, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isForced ? AppColors.gold : Colors.cyanAccent).withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isForced ? Icons.system_update_rounded : Icons.auto_awesome,
                      color: Colors.black87,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Titre
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Badge de version
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Actuelle : v$currentVersion  ➔  Nouvelle : $latestVersion",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message explicatif
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bouton principal d'action (Redirection Store)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _launchStore(playStoreUrl, appStoreUrl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Platform.isIOS ? Icons.apple : Icons.shop_two_rounded,
                            size: 22,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            Platform.isIOS
                                ? "Mettre à jour sur l'App Store"
                                : "Mettre à jour sur le Play Store",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bouton secondaire si NON FORCÉ
                  if (!isForced) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        _isDialogShowing = false;
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        "Plus tard",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  static Future<void> _launchStore(String playStoreUrl, String appStoreUrl) async {
    final String urlString;
    if (Platform.isIOS) {
      urlString = appStoreUrl;
    } else {
      urlString = playStoreUrl;
    }

    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback web direct
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint("Impossible d'ouvrir le store: $e");
    }
  }
}
