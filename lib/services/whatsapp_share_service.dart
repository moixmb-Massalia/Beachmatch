import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class WhatsAppShareService {
  /// Partage vers WhatsApp en priorité, avec repli transparent sur la feuille de partage native
  static Future<void> shareToWhatsAppOrNative({
    required String text,
    String? subject,
  }) async {
    final encoded = Uri.encodeComponent(text);
    final whatsappUri = Uri.parse("whatsapp://send?text=$encoded");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Repli Web WhatsApp
    final webWhatsappUri = Uri.parse("https://wa.me/?text=$encoded");
    try {
      if (await canLaunchUrl(webWhatsappUri)) {
        final launched = await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
    } catch (_) {}

    // Repli natif universel (SharePlus)
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
      return;
    } catch (_) {}

    // Repli presse-papiers si aucun share API n'est supporté
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
  }

  /// 🤝 Message viral de recherche de partenaire pour un tournoi
  static Future<void> shareTournamentPartnerRequest({
    required String tournamentName,
    required String tournamentDates,
    required String location,
    required String category,
    required String playerName,
    required String fftRank,
    required String preferredSide,
    required String draw,
    required String goal,
    required String tournamentId,
    bool isBrazilian = false,
  }) async {
    final locLower = location.toLowerCase();
    final isBr = isBrazilian || locLower.contains('brésil') || locLower.contains('brasil') || locLower.contains(', br') || locLower.contains('ceará') || locLower.contains('são paulo') || locLower.contains('cuiabá');

    final text = isBr
        ? "🆘 *PROCURA-SE PARCEIRO(A) DE BEACH TENNIS !* 🏖️\n\n"
          "🏆 *Torneio :* $tournamentName ($category)\n"
          "📅 *Datas :* $tournamentDates\n"
          "📍 *Local :* $location\n\n"
          "👤 *Meu perfil :*\n"
          "• Atleta : $playerName (Categoria CBT : $fftRank)\n"
          "• Lado preferido : $preferredSide\n"
          "• Chave : $draw\n"
          "• Objetivo : $goal\n\n"
          "💬 *Bora jogar juntos ?*\n"
          "👉 Entra no BeachMatch e fecha a dupla comigo : https://beachmatch.app/tournaments?id=$tournamentId"
        : "🆘 *SOS PARTENAIRE BEACH TENNIS !* 🏖️\n\n"
          "🏆 *Tournoi :* $tournamentName ($category)\n"
          "📅 *Dates :* $tournamentDates\n"
          "📍 *Lieu :* $location\n\n"
          "👤 *Mon profil :*\n"
          "• Joueur : $playerName (Classement FFT : $fftRank)\n"
          "• Côté préféré : $preferredSide\n"
          "• Tableau visé : $draw\n"
          "• Objectif : $goal\n\n"
          "💬 *Tu es disponible pour faire équipe avec moi ?*\n"
          "👉 Rejoins-moi directement sur BeachMatch : https://beachmatch.app/tournaments?id=$tournamentId";

    await shareToWhatsAppOrNative(
      text: text,
      subject: isBr ? "Procura-se parceiro(a) para $tournamentName" : "Recherche partenaire pour $tournamentName",
    );
  }

  /// 🏆 Invitation générale à un tournoi
  static Future<void> shareTournamentInvite({
    required String tournamentName,
    required String dates,
    required String location,
    required String category,
    String? price,
    String? phone,
    required String tournamentId,
    bool isBrazilian = false,
  }) async {
    final locLower = location.toLowerCase();
    final isBr = isBrazilian || locLower.contains('brésil') || locLower.contains('brasil') || locLower.contains(', br') || locLower.contains('ceará') || locLower.contains('são paulo') || locLower.contains('cuiabá');

    final text = isBr
        ? "🎾 *TORNEIO DE BEACH TENNIS : $tournamentName* 🏆\n\n"
          "⭐ Categoria : $category\n"
          "📅 Datas : $dates\n"
          "📍 Local : $location\n"
          "${price != null && price.isNotEmpty ? "💲 Inscrição : $price\n" : ""}"
          "${phone != null && phone.isNotEmpty ? "📞 Inscrições : $phone\n" : ""}\n"
          "👉 Veja a chave, os jogos ao vivo e encontre parceiro no BeachMatch :\n"
          "https://beachmatch.app/tournaments?id=$tournamentId"
        : "🎾 *TOURNOI BEACH TENNIS : $tournamentName* 🏆\n\n"
          "⭐ Catégorie : $category\n"
          "📅 Dates : $dates\n"
          "📍 Lieu : $location\n"
          "${price != null && price.isNotEmpty ? "💶 Tarif : $price\n" : ""}"
          "${phone != null && phone.isNotEmpty ? "📞 Inscriptions : $phone\n" : ""}\n"
          "👉 Consultez le tableau, les matchs en direct et trouvez un partenaire sur BeachMatch :\n"
          "https://beachmatch.app/tournaments?id=$tournamentId";

    await shareToWhatsAppOrNative(
      text: text,
      subject: isBr ? "Torneio de Beach Tennis : $tournamentName" : "Tournoi Beach Tennis : $tournamentName",
    );
  }

  /// 🚨 SOS Match Incomplet (Partie amicale où il manque un joueur)
  static Future<void> shareMatchSOS({
    required String matchDate,
    required String courtName,
    required int targetLevel,
    required int currentPlayers,
    required int maxPlayers,
    required String matchId,
    bool isBrazilian = false,
  }) async {
    final remaining = maxPlayers - currentPlayers;
    final courtLower = courtName.toLowerCase();
    final isBr = isBrazilian || courtLower.contains('arena') || courtLower.contains('brasil') || courtLower.contains('brésil') || courtLower.contains('praia');

    final text = isBr
        ? "🚨 *VAGA ABERTA NO BEACH TENNIS : FALTA $remaining JOGADOR${remaining > 1 ? 'ES' : ''} !* 🏖️🎾\n\n"
          "📅 *Quando :* $matchDate\n"
          "📍 *Onde :* $courtName\n"
          "🎯 *Nível :* Nível $targetLevel • ($currentPlayers/$maxPlayers atletas)\n\n"
          "👉 Garanta sua vaga no BeachMatch antes que feche a quadra :\n"
          "https://beachmatch.app/match?id=$matchId"
        : "🚨 *URGENT BEACH TENNIS : RESTE $remaining PLACE${remaining > 1 ? 'S' : ''} !* 🏖️🎾\n\n"
          "📅 *Quand :* $matchDate\n"
          "📍 *Où :* $courtName\n"
          "🎯 *Niveau :* Niveau $targetLevel • ($currentPlayers/$maxPlayers joueurs)\n\n"
          "👉 Prends vite ta place avant que le terrain ne soit complet :\n"
          "https://beachmatch.app/match?id=$matchId";

    await shareToWhatsAppOrNative(
      text: text,
      subject: isBr ? "Partida de Beach Tennis para completar !" : "Partie de Beach Tennis à compléter !",
    );
  }
}
