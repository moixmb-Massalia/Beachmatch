// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'BeachMatch';

  @override
  String get navHome => 'Accueil';

  @override
  String get navCourts => 'Terrains';

  @override
  String get navPlayers => 'Joueurs';

  @override
  String get navTournaments => 'Tournois';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profil';

  @override
  String homeHeaderLevel(int level) {
    return 'Niv. $level';
  }

  @override
  String get homeHeaderSeason => 'SAISON 2026';

  @override
  String get homeHeaderTitle => 'Beach Tennis Club';

  @override
  String get homeHeaderSubtitle =>
      'Trouvez un terrain et des partenaires en 1 clic';

  @override
  String homeWeatherSunny(int temp) {
    return '$temp°C · Ensoleillé';
  }

  @override
  String homeWeatherWindSand(int wind) {
    return 'Vent ${wind}km/h · Sable chaud 🏖️';
  }

  @override
  String get homeWeatherPerfect => 'Parfait';

  @override
  String get homeDirectNews => 'DIRECT & ACTUS';

  @override
  String get homeMatchOnSand => 'MATCH SUR SABLE';

  @override
  String homeMatchPlayersInfo(int current, int max) {
    return '$current/$max Joueurs';
  }

  @override
  String homeMatchRequiredLevel(int level) {
    return 'Niv. $level';
  }

  @override
  String get homeMatchTapDetails => 'Tapotez pour voir les détails';

  @override
  String get homeMatchCancel => 'Annuler';

  @override
  String get homeMatchQuit => 'Quitter';

  @override
  String get homeMatchFull => 'Complet';

  @override
  String get homeMatchJoin => 'Rejoindre';

  @override
  String get homeDialogCancelTitle => 'Annuler la partie';

  @override
  String get homeDialogCancelContent =>
      'Êtes-vous sûr de vouloir annuler cette partie ?';

  @override
  String get homeDialogNoKeep => 'Non, garder';

  @override
  String get homeDialogYesCancel => 'Oui, annuler';

  @override
  String get homeManagePlayersTitle => 'Gérer les joueurs';

  @override
  String get homeManagePlayersEmpty =>
      'Aucun autre joueur n\'a encore rejoint cette partie.';

  @override
  String homeManagePlayersRemoved(String name) {
    return '$name a été retiré(e) de la partie.';
  }

  @override
  String homeMatchDetailsRequiredLevel(int level) {
    return 'Niveau requis : $level';
  }

  @override
  String homeMatchDetailsWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Vent: $wind km/h ($dir)';
  }

  @override
  String homeMatchDetailsPlayersRegistered(int current, int max) {
    return '$current / $max Joueurs Inscrits';
  }

  @override
  String get homeMatchDetailsHost => 'HÔTE';

  @override
  String homeMatchDetailsPlayerStats(int level, int score) {
    return 'Niveau $level · $score pts';
  }

  @override
  String get homeMatchDetailsCancelGame => 'Annuler ma partie';

  @override
  String get homeMatchDetailsQuitGame => 'Quitter la partie';

  @override
  String get homeMatchDetailsJoinGame => 'Rejoindre la partie';

  @override
  String get homeMatchDetailsFull => 'Complet';

  @override
  String get homeMatchesTitle => 'Parties à venir';

  @override
  String get homeMatchesLive => 'En direct';

  @override
  String get homeEmptyStateTitle => 'Le sable vous attend !';

  @override
  String get homeEmptyStateSubtitle =>
      'Soyez le premier à organiser une partie de Beach Tennis dans votre région.';

  @override
  String get homeCreateMatchButton => 'Créer un match';

  @override
  String get homeFabCreate => 'Créer une partie';

  @override
  String get homeHeaderGreeting => 'Bonjour';

  @override
  String get homeNewsTitle => 'BEACH TENNIS WORLD';

  @override
  String get homeNewsBadgeDefault => 'ACTU';

  @override
  String get homeNewsBadgeLive => 'EN DIRECT 🔴';

  @override
  String get homeNewsBadgeTuto => 'TUTO 🎓';

  @override
  String get homeNewsBtnLive => 'REGARDER LE DIRECT 🔴';

  @override
  String get homeNewsBtnTuto => 'LANCER LE TUTORIEL VIDÉO 🎬';

  @override
  String homeMatchShareMessage(String date, int level, String id) {
    return 'Rejoins-moi pour un Beach Tennis le $date ! \nNiveau cible: $level\nTélécharge BeachMatch pour rejoindre ma partie : https://beachmatch.app/match/$id';
  }

  @override
  String get homeMatchShareTooltip => 'Partager';

  @override
  String get homeMatchManageTooltip => 'Gérer les joueurs';

  @override
  String get mapSearchError =>
      'Ville introuvable. Essaye de préciser (ex: Marseille, France).';

  @override
  String mapSearchGenericError(String error) {
    return 'Erreur de recherche: $error';
  }

  @override
  String get mapAddCourtBtn => 'Ajouter un terrain';

  @override
  String get mapFindCourtTitle => 'Trouver un terrain';

  @override
  String mapCourtsCount(int count) {
    return '$count Terrains';
  }

  @override
  String mapSearchCityPrompt(String query) {
    return 'Rechercher \"$query\"';
  }

  @override
  String get mapSearchCitySub => 'Déplacer la carte vers cette ville';

  @override
  String get mapCourtFree => 'Accès Libre & Gratuit';

  @override
  String get mapCourtPaid => 'Terrain Payant / Club';

  @override
  String mapWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Vent: $wind km/h ($dir)';
  }

  @override
  String get mapLostFoundBtn => 'Objets Perdus / Trouvés';

  @override
  String mapLostFoundCount(int count) {
    return '$count objet(s) signalé(s) ici';
  }

  @override
  String get mapSubscribeBtn => 'S\'abonner aux matchs';

  @override
  String get mapSubscribedBtn => 'Abonné aux alertes';

  @override
  String get mapSubscribeSub => 'Reçois une notif quand un match s\'y crée.';

  @override
  String get mapAdminDeleteCourtBtn => 'Supprimer ce terrain (Admin)';

  @override
  String get mapAdminDeleteTitle => 'Confirmer la suppression';

  @override
  String mapAdminDeleteContent(String name) {
    return 'Voulez-vous vraiment supprimer le terrain \'$name\' ?';
  }

  @override
  String get mapBtnCancel => 'Annuler';

  @override
  String get mapBtnDelete => 'Supprimer';

  @override
  String get mapBtnClose => 'Fermer';

  @override
  String get mapLostFoundTitle => 'Objets Perdus/Trouvés';

  @override
  String get mapLostFoundEmpty => 'Aucun objet signalé sur ce terrain.';

  @override
  String get mapLostBadge => 'PERDU';

  @override
  String get mapFoundBadge => 'TROUVÉ';

  @override
  String get mapLostDeclareBtn => 'J\'ai perdu un objet';

  @override
  String get mapFoundDeclareBtn => 'Objet trouvé';

  @override
  String get mapDeclareLostTitle => 'Déclarer un objet perdu';

  @override
  String get mapDeclareFoundTitle => 'Déclarer un objet trouvé';

  @override
  String mapDeclareOnCourt(String name) {
    return 'Sur le terrain : $name';
  }

  @override
  String get mapDeclareSuccess => 'Annonce publiée !';

  @override
  String get mapDeclarePublishBtn => 'Publier l\'annonce';

  @override
  String get mapProposeCourtTitle => 'Proposer un Terrain';

  @override
  String get mapProposeCourtSuccess => 'Merci ! Le terrain a été ajouté.';

  @override
  String get mapProposeCourtBtn => 'Ajouter le terrain';

  @override
  String get tournamentListTitle => 'Calendrier Officiel';

  @override
  String tournamentListCount(int count) {
    return '$count Tournois';
  }

  @override
  String get tournamentListEmpty => 'Aucun tournoi trouvé pour ce filtre.';

  @override
  String get tournamentFilterAll => 'Tous';

  @override
  String get tournamentDetailEventDetails => 'Détails de l\'épreuve';

  @override
  String get tournamentDetailDates => 'Dates';

  @override
  String get tournamentDetailAddress => 'Adresse';

  @override
  String get tournamentDetailCity => 'Ville';

  @override
  String get tournamentDetailEvents => 'Épreuves';

  @override
  String get tournamentDetailBalls => 'Balles';

  @override
  String get tournamentDetailPrice => 'Tarif';

  @override
  String get tournamentDetailCategory => 'Catégorie';

  @override
  String get tournamentDetailRegistration => 'Inscription & Contact';

  @override
  String get tournamentDetailRegistrationType => 'Type d\'inscription :';

  @override
  String get tournamentDetailReferee => 'Juge-arbitre';

  @override
  String get profileTitle => 'Mon Profil';

  @override
  String get profileCityUnknown => 'Ville non définie';

  @override
  String profileLevel(int level) {
    return '🏅 NIVEAU $level · COMPÉTITEUR';
  }

  @override
  String profileRanking(String ranking) {
    return '🎾 Classement Beach Tennis : $ranking';
  }

  @override
  String get profileMatchesPlayed => 'Matchs Joués';

  @override
  String get profileFftRanking => 'CLASSEMENT FFT';

  @override
  String get profileAdminPanelTitle => 'Panel Administrateur';

  @override
  String get profileAdminPanelSub =>
      'Gérez les vidéos YouTube et les actualités en direct.';

  @override
  String get profileAdminPanelBtn => 'Ouvrir le Panel 👑';

  @override
  String get profileRadarTitle => 'Radar à Tournois (Sniper)';

  @override
  String profileRadarActivated(String region) {
    return 'Radar activé pour la région : $region';
  }

  @override
  String get profileRadarError => 'Erreur lors de l\'activation du radar';

  @override
  String get profileRadarSub =>
      'Recevez une notification push instantanée dès qu\'un tournoi est annoncé dans votre région pour être le premier inscrit.';

  @override
  String get profileRadarRegion => 'Région surveillée : ';

  @override
  String get profileRadarEditRegion => 'Modifier la région';

  @override
  String get profileRadarRegionHint => 'Saisir une ville ou région...';

  @override
  String get profileBtnCancel => 'Annuler';

  @override
  String get profileBtnValidate => 'Valider';

  @override
  String get profilePreferencesTitle => 'Préférences de Jeu';

  @override
  String get profilePrefPosition => 'Position préférée';

  @override
  String get profilePrefNotSet => 'Non renseigné';

  @override
  String get profilePrefAvailability => 'Disponibilités';

  @override
  String get profileLegalTitle => 'Légal';

  @override
  String get profilePrivacy => 'Politique de Confidentialité';

  @override
  String get profileTerms => 'Conditions Générales';

  @override
  String get profileAccountManagement => 'Gestion du Compte';

  @override
  String get profileLogout => 'Se déconnecter';

  @override
  String get profileDeleteAccount => 'Supprimer mon compte';

  @override
  String get profileDeleteAccountConfirmTitle => 'Supprimer le compte';

  @override
  String get profileDeleteAccountConfirmSub =>
      'Cette action est irréversible. Votre profil, vos matchs et vos messages seront définitivement supprimés.';

  @override
  String get profileBtnDelete => 'Supprimer';

  @override
  String get rankingFirst => '1er';

  @override
  String rankingNth(int num) {
    return '$numème';
  }

  @override
  String profileEditPhotoError(String error) {
    return 'Erreur lors de la sélection : $error';
  }

  @override
  String get profileEditPhotoDeleted =>
      'Photo de profil supprimée (cliquez sur Enregistrer pour valider).';

  @override
  String get profileEditPhotoTitle => 'Photo de profil';

  @override
  String get profileEditPhotoGallery => 'Choisir depuis la galerie';

  @override
  String get profileEditPhotoCamera => 'Prendre une photo avec l\'appareil';

  @override
  String get profileEditPhotoRemove => 'Supprimer la photo actuelle';

  @override
  String get profileEditLicenceSuccess =>
      'Licence FFT validée ! Classement mis à jour.';

  @override
  String get profileEditLicenceNotFound =>
      'Licence introuvable dans le classement officiel.';

  @override
  String profileEditLicenceError(String error) {
    return 'Erreur de connexion : $error';
  }

  @override
  String profileEditSaveError(String error) {
    return 'Erreur: $error';
  }

  @override
  String get profileEditTitle => 'Éditer le profil';

  @override
  String get profileEditName => 'Prénom et Nom';

  @override
  String get profileEditLicence => 'Numéro de licence (Optionnel)';

  @override
  String get profileEditVerifyBtn => 'Vérifier';

  @override
  String get profileEditCity => 'Ville ou Région';

  @override
  String get profileEditFft => 'Classement FFT (ex: 3/6, Non classé...)';

  @override
  String get profileEditLevel => 'Niveau';

  @override
  String profileEditLevelBtn(int level) {
    return 'Niv. $level';
  }

  @override
  String get profileEditPosition => 'Position préférée';

  @override
  String get profileEditPosLeft => 'Gauche';

  @override
  String get profileEditPosRight => 'Droite';

  @override
  String get profileEditPosAny => 'N\'importe';

  @override
  String get profileEditSelect => 'Sélectionner';

  @override
  String get profileEditAvailability => 'Disponibilités';

  @override
  String get profileEditAvailEvening => 'Soirs & Week-ends';

  @override
  String get profileEditAvailWeek => 'En semaine';

  @override
  String get profileEditAvailAll => 'Tout le temps';

  @override
  String get profileEditAvailVar => 'Variable';

  @override
  String get profileEditLookingForPartner => 'Recherche un Binôme';

  @override
  String get profileEditLookingForPartnerSub =>
      'Apparaissez dans le Tinder du Beach pour trouver un partenaire de votre niveau.';

  @override
  String get profileEditSaveBtn => 'Enregistrer';

  @override
  String get mapDeclareLostHint =>
      'Ex: J\'ai oublié mes lunettes roses Oakley sur le banc...';

  @override
  String get mapDeclareFoundHint =>
      'Ex: J\'ai trouvé une housse MBB près du filet 3...';
}
