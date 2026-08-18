import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

void showClubInviteDialog(BuildContext context, {required String clubId, required String clubName, String? bannerUrl}) {
  final inviteUrl = "https://beachmatch.app/club?id=$clubId";
  final shareMessage = "🎾 Rejoins le Chat interne de $clubName sur BeachMatch !\n\n"
      "Trouve des partenaires de jeu, vote aux sondages du club, suis nos tournois et discute avec toute la communauté sur le sable 🏖️\n\n"
      "👉 Clique ici pour nous rejoindre : $inviteUrl";

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poignée de fermeture
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_add_rounded, color: AppColors.coral, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Inviter des joueurs",
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          clubName,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Bouton Partager sur WhatsApp (N°1 viral)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008069), // Vert officiel WhatsApp
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble, color: Colors.white),
                label: const Text(
                  "Inviter mon groupe WhatsApp",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () async {
                  final whatsappUrl = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(shareMessage)}");
                  try {
                    if (await canLaunchUrl(whatsappUrl)) {
                      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                    } else {
                      Share.share(shareMessage, subject: "Rejoins $clubName sur BeachMatch");
                    }
                  } catch (_) {
                    Share.share(shareMessage, subject: "Rejoins $clubName sur BeachMatch");
                  }
                },
              ),
              const SizedBox(height: 12),

              // Bouton Partager générique (SMS, Insta, etc.)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.share_rounded, color: AppColors.coral),
                label: const Text(
                  "Partager le lien d'invitation",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  Share.share(shareMessage, subject: "Rejoins $clubName sur BeachMatch");
                },
              ),
              const SizedBox(height: 20),

              // Section QR Code de Terrain
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.coral),
                        SizedBox(width: 8),
                        Text(
                          "QR Code officiel du club",
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: inviteUrl,
                        version: QrVersions.auto,
                        size: 170.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Faites scanner ce QR Code sur le terrain ou imprimez-le pour le club-house !",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bouton Copier le lien
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                label: const Text(
                  "Copier le lien d'invitation",
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inviteUrl));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lien d'invitation copié dans le presse-papier ! 📋")),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
