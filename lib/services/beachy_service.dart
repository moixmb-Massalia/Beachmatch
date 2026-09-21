/// Modèle d'action rapide associée à une réponse de Beachy
enum BeachyActionType {
  openMap,
  openTournaments,
  openRankings,
  createMatch,
  openProfile,
  none,
}

class BeachyAction {
  final String label;
  final BeachyActionType type;

  const BeachyAction({required this.label, required this.type});
}

class BeachyResponse {
  final String text;
  final BeachyAction? action;

  const BeachyResponse({required this.text, this.action});
}

/// Service autonome d'intelligence et d'arbitrage de Beachy
class BeachyService {
  static final BeachyService _instance = BeachyService._internal();
  factory BeachyService() => _instance;
  BeachyService._internal();

  /// Questions rapides suggérées au démarrage
  static const List<String> quickQuestions = [
    "⚖️ Toucher le filet pendant le point ?",
    "📏 Quelle est la hauteur officielle du filet ?",
    "🎾 Comment créer une partie amicale ?",
    "🏆 Où trouver les tournois homologués FFT ?",
    "🎒 Quelle raquette choisir pour débuter ?",
    "⚡ Comment fonctionne le No-Ad à 40-40 ?",
  ];

  /// Analyse et répond instantanément à n'importe quelle requête
  BeachyResponse answerQuery(String query) {
    final q = _normalize(query);

    // 1. RÈGLE : Toucher le filet
    if (q.contains('filet') && (q.contains('touch') || q.contains('contact') || q.contains('faute'))) {
      if (q.contains('apres') || q.contains('sol') || q.contains('sable') || q.contains('rebond')) {
        return const BeachyResponse(
          text: "⚖️ **Règle officielle FFT / ITF :**\n\n"
              "Si la balle a **déjà touché le sable**, le point est officiellement terminé ! "
              "Tout contact avec le filet intervenant *après* que la balle est morte n'est **PAS compté comme faute**.\n\n"
              "En revanche, si le joueur ou sa raquette touche le filet *pendant* que la balle est encore en jeu, il y a **faute immédiate** et perte du point.",
        );
      }
      return const BeachyResponse(
        text: "⚖️ **Règle FFT / ITF (Toucher de filet) :**\n\n"
            "• **Pendant l'échange :** Tout contact du joueur (corps, vêtements, raquette) avec le filet ou les poteaux est une **faute immédiate** (point pour l'adversaire).\n\n"
            "• **Après la fin du point :** Si la balle a déjà touché le sable adverse, le point est fini : toucher le filet après coup n'est pas pénalisé.",
      );
    }

    // 2. RÈGLE : Hauteur du filet
    if (q.contains('hauteur') && q.contains('filet')) {
      return const BeachyResponse(
        text: "📏 **Hauteur officielle du filet :**\n\n"
            "• **Seniors & Jeunes (U14/U18) :** Exactement **1,70 mètre** sur toute la largeur du terrain (Hommes, Dames et Mixte).\n"
            "• **Moins de 10 ans (U10) :** **1,50 mètre**.\n\n"
            "💡 *Astuce :* La tension du filet doit être constante pour éviter tout affaissement au centre.",
      );
    }

    // 3. RÈGLE : Dimensions du terrain
    if (q.contains('dimension') || q.contains('taille') || (q.contains('terrain') && (q.contains('longueur') || q.contains('largeur') || q.contains('metre')))) {
      return const BeachyResponse(
        text: "📐 **Dimensions officielles du terrain de Beach Tennis :**\n\n"
            "• **Double (le format standard) :** 16 mètres de long sur **8 mètres** de large.\n"
            "• **Simple :** 16 mètres de long sur **4,5 mètres** de large.\n"
            "• **Zone de dégagement :** Au moins 1,5 à 2 mètres de sable libre autour des lignes.",
      );
    }

    // 4. RÈGLE : Service (mordre la ligne, sauter, filet)
    if (q.contains('serv') || q.contains('engagement')) {
      if (q.contains('ligne') || q.contains('mord') || q.contains('saut') || q.contains('pied')) {
        return const BeachyResponse(
          text: "🎾 **Règles du Service (Ligne & Pieds) :**\n\n"
              "1. **Impulsion :** Les pieds doivent être entièrement situés **derrière la ligne de fond** au moment de l'impulsion.\n"
              "2. **Saut vers l'avant :** Vous avez le droit d'atterrir à l'intérieur du terrain, à condition que l'impulsion ait été prise en arrière de la ligne !\n"
              "3. **Un seul service :** Pas de second service au Beach Tennis.\n"
              "4. **Pas de let :** Si la balle touche le filet et retombe dans le camp adverse, le jeu continue.",
        );
      }
      return const BeachyResponse(
        text: "🎾 **Les Fondamentaux du Service :**\n\n"
            "• **1 seul essai :** Pas de deuxième balle de service.\n"
            "• **Pas de Let :** Si la balle effleure le filet et passe, le point continue normalement !\n"
            "• **Placement :** Le serveur peut se placer n'importe où derrière la ligne de fond et servir sur n'importe quel joueur adverse.",
      );
    }

    // 4b. RÈGLE : Type de balles & pression
    if (q.contains('balle') && (q.contains('type') || q.contains('pression') || q.contains('orange') || q.contains('stage'))) {
      return const BeachyResponse(
        text: "🎾 **Balles officielles de Beach Tennis :**\n\n"
            "• **Balles Stage 2 (Orange) :** Balles basse pression officielles homologuées ITF et FFT.\n"
            "• **Vitesse :** 50% plus lentes qu'une balle de tennis standard, adaptées au jeu sans rebond sur sable.\n"
            "• **Ne jamais utiliser :** Des balles de tennis classiques (jaunes standard sous pression), interdites et dangereuses !",
      );
    }

    // 5. RÈGLE : No-Ad et Super Tie-Break
    if (q.contains('no-ad') || q.contains('no ad') || q.contains('40-40') || q.contains('decisif') || q.contains('tie-break') || q.contains('tie break')) {
      return const BeachyResponse(
        text: "⚡ **Comptage des Points : No-Ad & Super Tie-Break**\n\n"
            "• **Le No-Ad à 40-40 :** Il n'y a pas d'avantage ! À 40-40, c'est **point décisif direct** (balle de jeu).\n"
            "• **En Double Mixte :** C'est le joueur du même sexe que le serveur qui doit obligatoirement relancer à 40-40.\n"
            "• **Super Tie-Break (3ème set) :** Se joue en **10 points** avec 2 points d'écart minimum.",
      );
    }

    // 6. RÈGLE : Balle qui touche le corps / raquette
    if (q.contains('corps') || q.contains('cadre') || q.contains('deux fois') || q.contains('double touche')) {
      return const BeachyResponse(
        text: "⚖️ **Contacts particuliers en Beach Tennis :**\n\n"
            "• **Balle touchant le corps :** Faute immédiate si la balle touche le joueur avant de tomber au sol.\n"
            "• **Double touche accidentelle :** Tolérée si elle s'inscrit dans un geste fluide et continu unique.\n"
            "• **Frappe avec le cadre de la raquette :** 100% valable tant que la balle est propulsée dans le camp adverse !",
      );
    }

    // 7. APP : Trouver un terrain
    if (q.contains('trouv') && (q.contains('terrain') || q.contains('spot') || q.contains('plage') || q.contains('carte'))) {
      return const BeachyResponse(
        text: "🏖️ **Trouver un terrain de Beach Tennis :**\n\n"
            "Rends-toi dans l'onglet **Carte (Spots)** en bas de l'écran. Tu peux filtrer en 1 clic entre les **plages libres gratuites** et les **clubs officiels éclairés** avec météo en direct !",
        action: BeachyAction(label: "Ouvrir la Carte 🗺️", type: BeachyActionType.openMap),
      );
    }

    // 8. APP : Tournois FFT
    if (q.contains('tournoi') || q.contains('competition') || q.contains('bt25') || q.contains('bt100') || q.contains('bt250') || q.contains('bt2000')) {
      return const BeachyResponse(
        text: "🏆 **Calendrier National des Tournois FFT :**\n\n"
            "Retrouve tous les tournois homologués en France (du BT 25 au BT 2000), le radar géographique et le bouton **SOS Partenaire** dans l'onglet Compétition.",
        action: BeachyAction(label: "Voir les Tournois 🏆", type: BeachyActionType.openTournaments),
      );
    }

    // 9. APP : Classement FFT Ten'Up
    if (q.contains('classement') || q.contains('tenup') || q.contains('ten up') || q.contains('points fft') || q.contains('rang')) {
      return const BeachyResponse(
        text: "🥇 **Classement Officiel FFT Ten'Up :**\n\n"
            "L'onglet Classement regroupe plus de **3 300 joueurs et joueuses** licenciés en France. Tu peux rechercher n'importe quel partenaire par son nom ou son numéro de licence !",
        action: BeachyAction(label: "Consulter le Classement 🥇", type: BeachyActionType.openRankings),
      );
    }

    // 10. APP : Créer un match
    if (q.contains('creer') || (q.contains('organis') && q.contains('match'))) {
      return const BeachyResponse(
        text: "🎾 **Créer une partie sur BeachMatch :**\n\n"
            "Appuie sur le bouton **'Créer un match'** depuis l'accueil ou choisis directement un terrain sur la carte. Tape simplement la ville ou le club pour auto-remplir le spot et partage l'invitation sur WhatsApp !",
        action: BeachyAction(label: "Créer une Partie 🎾", type: BeachyActionType.createMatch),
      );
    }

    // 11. MATÉRIEL : Choisir sa raquette
    if (q.contains('raquette') || q.contains('materiel') || q.contains('carbone') || q.contains('kevlar') || q.contains('fibre')) {
      return const BeachyResponse(
        text: "🎒 **Bien choisir sa raquette de Beach Tennis :**\n\n"
            "• **Débutant / Intermédiaire :** Privilégiez la **fibre de verre** ou le **Carbone 3K** avec un équilibre neutre ou en manche pour un maximum de tolérance et de contrôle.\n"
            "• **Joueur confirmé :** Le **Carbone 12K ou 15K** apporte une excellente rigidité pour la puissance au smash.\n"
            "• **Épaisseur :** 20 mm pour la maniabilité, 22 mm pour plus de puissance et de confort de frappe.",
      );
    }

    // 12. CONDITIONS : Vent & Météo
    if (q.contains('vent') || q.contains('meteo') || q.contains('rafale')) {
      return const BeachyResponse(
        text: "🌬️ **Jouer avec le vent au Beach Tennis :**\n\n"
            "• **Moins de 15 km/h :** Conditions parfaites, jeu fluide.\n"
            "• **15 à 30 km/h :** Vent modéré. Jouez impérativement plus au centre du terrain et évitez les lobs face au vent.\n"
            "• **Plus de 35 km/h :** Défi physique intense ! Privilégiez les trajectoires tendues et les amorties courtes contre le vent.",
      );
    }

    // 13. SALUTATIONS / GÉNÉRAL
    if (q.contains('bonjour') || q.contains('salut') || q.contains('hello') || q.contains('qui es-tu') || q.contains('qui es tu') || q.contains('aide')) {
      return const BeachyResponse(
        text: "Salut champion ! ☀️ Je suis **Beachy**, ton assistant Beach Tennis officiel sur BeachMatch.\n\n"
            "Je peux t'aider sur :\n"
            "• ⚖️ L'arbitrage et les litiges de règles en match\n"
            "• 🏖️ Trouver des terrains et spots de plage libres\n"
            "• 🏆 T'orienter vers les tournois FFT et classements\n"
            "• 🎾 Te guider dans l'utilisation de l'application\n\n"
            "Pose-moi ta question ou choisis un raccourci ci-dessous !",
      );
    }

    // FALLBACK INTELLIGENT
    return BeachyResponse(
      text: "Je suis là pour t'aider ! 🎾\n\n"
          "Pour ta recherche « *$query* », voici les sujets les plus demandés :\n\n"
          "• **Règles officielles :** Tape *'toucher le filet'*, *'hauteur filet'*, ou *'service'*\n"
          "• **Terrains :** Tape *'trouver un terrain'*\n"
          "• **Tournois & Matchs :** Tape *'tournois'* ou *'créer un match'*\n\n"
          "N'hésite pas à préciser ta question !",
      action: const BeachyAction(label: "Ouvrir la Carte 🗺️", type: BeachyActionType.openMap),
    );
  }

  String _normalize(String input) {
    return input.toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .trim();
  }
}
