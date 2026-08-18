import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt')
  ];

  /// Le titre de l'application
  ///
  /// In fr, this message translates to:
  /// **'BeachMatch'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navCourts.
  ///
  /// In fr, this message translates to:
  /// **'Terrains'**
  String get navCourts;

  /// No description provided for @navPlayers.
  ///
  /// In fr, this message translates to:
  /// **'Joueurs'**
  String get navPlayers;

  /// No description provided for @navTournaments.
  ///
  /// In fr, this message translates to:
  /// **'Tournois'**
  String get navTournaments;

  /// No description provided for @navChat.
  ///
  /// In fr, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @homeHeaderLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niv. {level}'**
  String homeHeaderLevel(int level);

  /// No description provided for @homeHeaderSeason.
  ///
  /// In fr, this message translates to:
  /// **'SAISON 2026'**
  String get homeHeaderSeason;

  /// No description provided for @homeHeaderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Beach Tennis Club'**
  String get homeHeaderTitle;

  /// No description provided for @homeHeaderSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez un terrain et des partenaires en 1 clic'**
  String get homeHeaderSubtitle;

  /// No description provided for @homeWeatherSunny.
  ///
  /// In fr, this message translates to:
  /// **'{temp}°C · Ensoleillé'**
  String homeWeatherSunny(int temp);

  /// No description provided for @homeWeatherWindSand.
  ///
  /// In fr, this message translates to:
  /// **'Vent {wind}km/h · Sable chaud 🏖️'**
  String homeWeatherWindSand(int wind);

  /// No description provided for @homeWeatherPerfect.
  ///
  /// In fr, this message translates to:
  /// **'Parfait'**
  String get homeWeatherPerfect;

  /// No description provided for @homeDirectNews.
  ///
  /// In fr, this message translates to:
  /// **'DIRECT & ACTUS'**
  String get homeDirectNews;

  /// No description provided for @homeMatchOnSand.
  ///
  /// In fr, this message translates to:
  /// **'MATCH SUR SABLE'**
  String get homeMatchOnSand;

  /// No description provided for @homeMatchPlayersInfo.
  ///
  /// In fr, this message translates to:
  /// **'{current}/{max} Joueurs'**
  String homeMatchPlayersInfo(int current, int max);

  /// No description provided for @homeMatchRequiredLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niv. {level}'**
  String homeMatchRequiredLevel(int level);

  /// No description provided for @homeMatchTapDetails.
  ///
  /// In fr, this message translates to:
  /// **'Tapotez pour voir les détails'**
  String get homeMatchTapDetails;

  /// No description provided for @homeMatchCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get homeMatchCancel;

  /// No description provided for @homeMatchQuit.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get homeMatchQuit;

  /// No description provided for @homeMatchFull.
  ///
  /// In fr, this message translates to:
  /// **'Complet'**
  String get homeMatchFull;

  /// No description provided for @homeMatchJoin.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get homeMatchJoin;

  /// No description provided for @homeDialogCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la partie'**
  String get homeDialogCancelTitle;

  /// No description provided for @homeDialogCancelContent.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir annuler cette partie ?'**
  String get homeDialogCancelContent;

  /// No description provided for @homeDialogNoKeep.
  ///
  /// In fr, this message translates to:
  /// **'Non, garder'**
  String get homeDialogNoKeep;

  /// No description provided for @homeDialogYesCancel.
  ///
  /// In fr, this message translates to:
  /// **'Oui, annuler'**
  String get homeDialogYesCancel;

  /// No description provided for @homeManagePlayersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les joueurs'**
  String get homeManagePlayersTitle;

  /// No description provided for @homeManagePlayersEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun autre joueur n\'a encore rejoint cette partie.'**
  String get homeManagePlayersEmpty;

  /// No description provided for @homeManagePlayersRemoved.
  ///
  /// In fr, this message translates to:
  /// **'{name} a été retiré(e) de la partie.'**
  String homeManagePlayersRemoved(String name);

  /// No description provided for @homeMatchDetailsRequiredLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau requis : {level}'**
  String homeMatchDetailsRequiredLevel(int level);

  /// No description provided for @homeMatchDetailsWeatherWind.
  ///
  /// In fr, this message translates to:
  /// **'{temp}°C • Vent: {wind} km/h ({dir})'**
  String homeMatchDetailsWeatherWind(int temp, int wind, String dir);

  /// No description provided for @homeMatchDetailsPlayersRegistered.
  ///
  /// In fr, this message translates to:
  /// **'{current} / {max} Joueurs Inscrits'**
  String homeMatchDetailsPlayersRegistered(int current, int max);

  /// No description provided for @homeMatchDetailsHost.
  ///
  /// In fr, this message translates to:
  /// **'HÔTE'**
  String get homeMatchDetailsHost;

  /// No description provided for @homeMatchDetailsPlayerStats.
  ///
  /// In fr, this message translates to:
  /// **'Niveau {level} · {score} pts'**
  String homeMatchDetailsPlayerStats(int level, int score);

  /// No description provided for @homeMatchDetailsCancelGame.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ma partie'**
  String get homeMatchDetailsCancelGame;

  /// No description provided for @homeMatchDetailsQuitGame.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la partie'**
  String get homeMatchDetailsQuitGame;

  /// No description provided for @homeMatchDetailsJoinGame.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre la partie'**
  String get homeMatchDetailsJoinGame;

  /// No description provided for @homeMatchDetailsFull.
  ///
  /// In fr, this message translates to:
  /// **'Complet'**
  String get homeMatchDetailsFull;

  /// No description provided for @homeMatchesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parties à venir'**
  String get homeMatchesTitle;

  /// No description provided for @homeMatchesLive.
  ///
  /// In fr, this message translates to:
  /// **'En direct'**
  String get homeMatchesLive;

  /// No description provided for @homeEmptyStateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le sable vous attend !'**
  String get homeEmptyStateTitle;

  /// No description provided for @homeEmptyStateSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à organiser une partie de Beach Tennis dans votre région.'**
  String get homeEmptyStateSubtitle;

  /// No description provided for @homeCreateMatchButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer un match'**
  String get homeCreateMatchButton;

  /// No description provided for @homeFabCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer une partie'**
  String get homeFabCreate;

  /// No description provided for @homeHeaderGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get homeHeaderGreeting;

  /// No description provided for @homeNewsTitle.
  ///
  /// In fr, this message translates to:
  /// **'BEACH TENNIS WORLD'**
  String get homeNewsTitle;

  /// No description provided for @homeNewsBadgeDefault.
  ///
  /// In fr, this message translates to:
  /// **'ACTU'**
  String get homeNewsBadgeDefault;

  /// No description provided for @homeNewsBadgeLive.
  ///
  /// In fr, this message translates to:
  /// **'EN DIRECT 🔴'**
  String get homeNewsBadgeLive;

  /// No description provided for @homeNewsBadgeTuto.
  ///
  /// In fr, this message translates to:
  /// **'TUTO 🎓'**
  String get homeNewsBadgeTuto;

  /// No description provided for @homeNewsBtnLive.
  ///
  /// In fr, this message translates to:
  /// **'REGARDER LE DIRECT 🔴'**
  String get homeNewsBtnLive;

  /// No description provided for @homeNewsBtnTuto.
  ///
  /// In fr, this message translates to:
  /// **'LANCER LE TUTORIEL VIDÉO 🎬'**
  String get homeNewsBtnTuto;

  /// No description provided for @homeMatchShareMessage.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins-moi pour un Beach Tennis le {date} ! \nNiveau cible: {level}\nTélécharge BeachMatch pour rejoindre ma partie : https://beachmatch.app/match/{id}'**
  String homeMatchShareMessage(String date, int level, String id);

  /// No description provided for @homeMatchShareTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get homeMatchShareTooltip;

  /// No description provided for @homeMatchManageTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les joueurs'**
  String get homeMatchManageTooltip;

  /// No description provided for @mapSearchError.
  ///
  /// In fr, this message translates to:
  /// **'Ville introuvable. Essaye de préciser (ex: Marseille, France).'**
  String get mapSearchError;

  /// No description provided for @mapSearchGenericError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de recherche: {error}'**
  String mapSearchGenericError(String error);

  /// No description provided for @mapAddCourtBtn.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un terrain'**
  String get mapAddCourtBtn;

  /// No description provided for @mapFindCourtTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trouver un terrain'**
  String get mapFindCourtTitle;

  /// No description provided for @mapCourtsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} Terrains'**
  String mapCourtsCount(int count);

  /// No description provided for @mapSearchCityPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher \"{query}\"'**
  String mapSearchCityPrompt(String query);

  /// No description provided for @mapSearchCitySub.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer la carte vers cette ville'**
  String get mapSearchCitySub;

  /// No description provided for @mapCourtFree.
  ///
  /// In fr, this message translates to:
  /// **'Accès Libre & Gratuit'**
  String get mapCourtFree;

  /// No description provided for @mapCourtPaid.
  ///
  /// In fr, this message translates to:
  /// **'Terrain Payant / Club'**
  String get mapCourtPaid;

  /// No description provided for @mapWeatherWind.
  ///
  /// In fr, this message translates to:
  /// **'{temp}°C • Vent: {wind} km/h ({dir})'**
  String mapWeatherWind(int temp, int wind, String dir);

  /// No description provided for @mapLostFoundBtn.
  ///
  /// In fr, this message translates to:
  /// **'Objets Perdus / Trouvés'**
  String get mapLostFoundBtn;

  /// No description provided for @mapLostFoundCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} objet(s) signalé(s) ici'**
  String mapLostFoundCount(int count);

  /// No description provided for @mapSubscribeBtn.
  ///
  /// In fr, this message translates to:
  /// **'S\'abonner aux matchs'**
  String get mapSubscribeBtn;

  /// No description provided for @mapSubscribedBtn.
  ///
  /// In fr, this message translates to:
  /// **'Abonné aux alertes'**
  String get mapSubscribedBtn;

  /// No description provided for @mapSubscribeSub.
  ///
  /// In fr, this message translates to:
  /// **'Reçois une notif quand un match s\'y crée.'**
  String get mapSubscribeSub;

  /// No description provided for @mapAdminDeleteCourtBtn.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce terrain (Admin)'**
  String get mapAdminDeleteCourtBtn;

  /// No description provided for @mapAdminDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la suppression'**
  String get mapAdminDeleteTitle;

  /// No description provided for @mapAdminDeleteContent.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer le terrain \'{name}\' ?'**
  String mapAdminDeleteContent(String name);

  /// No description provided for @mapBtnCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get mapBtnCancel;

  /// No description provided for @mapBtnDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get mapBtnDelete;

  /// No description provided for @mapBtnClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get mapBtnClose;

  /// No description provided for @mapLostFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Objets Perdus/Trouvés'**
  String get mapLostFoundTitle;

  /// No description provided for @mapLostFoundEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun objet signalé sur ce terrain.'**
  String get mapLostFoundEmpty;

  /// No description provided for @mapLostBadge.
  ///
  /// In fr, this message translates to:
  /// **'PERDU'**
  String get mapLostBadge;

  /// No description provided for @mapFoundBadge.
  ///
  /// In fr, this message translates to:
  /// **'TROUVÉ'**
  String get mapFoundBadge;

  /// No description provided for @mapLostDeclareBtn.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai perdu un objet'**
  String get mapLostDeclareBtn;

  /// No description provided for @mapFoundDeclareBtn.
  ///
  /// In fr, this message translates to:
  /// **'Objet trouvé'**
  String get mapFoundDeclareBtn;

  /// No description provided for @mapDeclareLostTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un objet perdu'**
  String get mapDeclareLostTitle;

  /// No description provided for @mapDeclareFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un objet trouvé'**
  String get mapDeclareFoundTitle;

  /// No description provided for @mapDeclareOnCourt.
  ///
  /// In fr, this message translates to:
  /// **'Sur le terrain : {name}'**
  String mapDeclareOnCourt(String name);

  /// No description provided for @mapDeclareSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Annonce publiée !'**
  String get mapDeclareSuccess;

  /// No description provided for @mapDeclarePublishBtn.
  ///
  /// In fr, this message translates to:
  /// **'Publier l\'annonce'**
  String get mapDeclarePublishBtn;

  /// No description provided for @mapProposeCourtTitle.
  ///
  /// In fr, this message translates to:
  /// **'Proposer un Terrain'**
  String get mapProposeCourtTitle;

  /// No description provided for @mapProposeCourtSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Merci ! Le terrain a été ajouté.'**
  String get mapProposeCourtSuccess;

  /// No description provided for @mapProposeCourtBtn.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le terrain'**
  String get mapProposeCourtBtn;

  /// No description provided for @tournamentListTitle.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier Officiel'**
  String get tournamentListTitle;

  /// No description provided for @tournamentListCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} Tournois'**
  String tournamentListCount(int count);

  /// No description provided for @tournamentListEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun tournoi trouvé pour ce filtre.'**
  String get tournamentListEmpty;

  /// No description provided for @tournamentFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get tournamentFilterAll;

  /// No description provided for @tournamentDetailEventDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails de l\'épreuve'**
  String get tournamentDetailEventDetails;

  /// No description provided for @tournamentDetailDates.
  ///
  /// In fr, this message translates to:
  /// **'Dates'**
  String get tournamentDetailDates;

  /// No description provided for @tournamentDetailAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get tournamentDetailAddress;

  /// No description provided for @tournamentDetailCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get tournamentDetailCity;

  /// No description provided for @tournamentDetailEvents.
  ///
  /// In fr, this message translates to:
  /// **'Épreuves'**
  String get tournamentDetailEvents;

  /// No description provided for @tournamentDetailBalls.
  ///
  /// In fr, this message translates to:
  /// **'Balles'**
  String get tournamentDetailBalls;

  /// No description provided for @tournamentDetailPrice.
  ///
  /// In fr, this message translates to:
  /// **'Tarif'**
  String get tournamentDetailPrice;

  /// No description provided for @tournamentDetailCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get tournamentDetailCategory;

  /// No description provided for @tournamentDetailRegistration.
  ///
  /// In fr, this message translates to:
  /// **'Inscription & Contact'**
  String get tournamentDetailRegistration;

  /// No description provided for @tournamentDetailRegistrationType.
  ///
  /// In fr, this message translates to:
  /// **'Type d\'inscription :'**
  String get tournamentDetailRegistrationType;

  /// No description provided for @tournamentDetailReferee.
  ///
  /// In fr, this message translates to:
  /// **'Juge-arbitre'**
  String get tournamentDetailReferee;

  /// No description provided for @profileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon Profil'**
  String get profileTitle;

  /// No description provided for @profileCityUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Ville non définie'**
  String get profileCityUnknown;

  /// No description provided for @profileLevel.
  ///
  /// In fr, this message translates to:
  /// **'🏅 NIVEAU {level} · COMPÉTITEUR'**
  String profileLevel(int level);

  /// No description provided for @profileRanking.
  ///
  /// In fr, this message translates to:
  /// **'🎾 Classement Beach Tennis : {ranking}'**
  String profileRanking(String ranking);

  /// No description provided for @profileMatchesPlayed.
  ///
  /// In fr, this message translates to:
  /// **'Matchs Joués'**
  String get profileMatchesPlayed;

  /// No description provided for @profileFftRanking.
  ///
  /// In fr, this message translates to:
  /// **'CLASSEMENT FFT'**
  String get profileFftRanking;

  /// No description provided for @profileAdminPanelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Panel Administrateur'**
  String get profileAdminPanelTitle;

  /// No description provided for @profileAdminPanelSub.
  ///
  /// In fr, this message translates to:
  /// **'Gérez les vidéos YouTube et les actualités en direct.'**
  String get profileAdminPanelSub;

  /// No description provided for @profileAdminPanelBtn.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le Panel 👑'**
  String get profileAdminPanelBtn;

  /// No description provided for @profileRadarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Radar à Tournois (Sniper)'**
  String get profileRadarTitle;

  /// No description provided for @profileRadarActivated.
  ///
  /// In fr, this message translates to:
  /// **'Radar activé pour la région : {region}'**
  String profileRadarActivated(String region);

  /// No description provided for @profileRadarError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'activation du radar'**
  String get profileRadarError;

  /// No description provided for @profileRadarSub.
  ///
  /// In fr, this message translates to:
  /// **'Recevez une notification push instantanée dès qu\'un tournoi est annoncé dans votre région pour être le premier inscrit.'**
  String get profileRadarSub;

  /// No description provided for @profileRadarRegion.
  ///
  /// In fr, this message translates to:
  /// **'Région surveillée : '**
  String get profileRadarRegion;

  /// No description provided for @profileRadarEditRegion.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la région'**
  String get profileRadarEditRegion;

  /// No description provided for @profileRadarRegionHint.
  ///
  /// In fr, this message translates to:
  /// **'Saisir une ville ou région...'**
  String get profileRadarRegionHint;

  /// No description provided for @profileBtnCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get profileBtnCancel;

  /// No description provided for @profileBtnValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get profileBtnValidate;

  /// No description provided for @profilePreferencesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Préférences de Jeu'**
  String get profilePreferencesTitle;

  /// No description provided for @profilePrefPosition.
  ///
  /// In fr, this message translates to:
  /// **'Position préférée'**
  String get profilePrefPosition;

  /// No description provided for @profilePrefNotSet.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get profilePrefNotSet;

  /// No description provided for @profilePrefAvailability.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilités'**
  String get profilePrefAvailability;

  /// No description provided for @profileLegalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Légal'**
  String get profileLegalTitle;

  /// No description provided for @profilePrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de Confidentialité'**
  String get profilePrivacy;

  /// No description provided for @profileTerms.
  ///
  /// In fr, this message translates to:
  /// **'Conditions Générales'**
  String get profileTerms;

  /// No description provided for @profileAccountManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion du Compte'**
  String get profileAccountManagement;

  /// No description provided for @profileLogout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get profileLogout;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get profileDeleteAccountConfirmTitle;

  /// No description provided for @profileDeleteAccountConfirmSub.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Votre profil, vos matchs et vos messages seront définitivement supprimés.'**
  String get profileDeleteAccountConfirmSub;

  /// No description provided for @profileBtnDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get profileBtnDelete;

  /// No description provided for @rankingFirst.
  ///
  /// In fr, this message translates to:
  /// **'1er'**
  String get rankingFirst;

  /// No description provided for @rankingNth.
  ///
  /// In fr, this message translates to:
  /// **'{num}ème'**
  String rankingNth(int num);

  /// No description provided for @profileEditPhotoError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sélection : {error}'**
  String profileEditPhotoError(String error);

  /// No description provided for @profileEditPhotoDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil supprimée (cliquez sur Enregistrer pour valider).'**
  String get profileEditPhotoDeleted;

  /// No description provided for @profileEditPhotoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil'**
  String get profileEditPhotoTitle;

  /// No description provided for @profileEditPhotoGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir depuis la galerie'**
  String get profileEditPhotoGallery;

  /// No description provided for @profileEditPhotoCamera.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo avec l\'appareil'**
  String get profileEditPhotoCamera;

  /// No description provided for @profileEditPhotoRemove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo actuelle'**
  String get profileEditPhotoRemove;

  /// No description provided for @profileEditLicenceSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Licence FFT validée ! Classement mis à jour.'**
  String get profileEditLicenceSuccess;

  /// No description provided for @profileEditLicenceNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Licence introuvable dans le classement officiel.'**
  String get profileEditLicenceNotFound;

  /// No description provided for @profileEditLicenceError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion : {error}'**
  String profileEditLicenceError(String error);

  /// No description provided for @profileEditSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String profileEditSaveError(String error);

  /// No description provided for @profileEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Éditer le profil'**
  String get profileEditTitle;

  /// No description provided for @profileEditName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom et Nom'**
  String get profileEditName;

  /// No description provided for @profileEditLicence.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de licence (Optionnel)'**
  String get profileEditLicence;

  /// No description provided for @profileEditVerifyBtn.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get profileEditVerifyBtn;

  /// No description provided for @profileEditCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville ou Région'**
  String get profileEditCity;

  /// No description provided for @profileEditFft.
  ///
  /// In fr, this message translates to:
  /// **'Classement FFT (ex: 3/6, Non classé...)'**
  String get profileEditFft;

  /// No description provided for @profileEditLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau'**
  String get profileEditLevel;

  /// No description provided for @profileEditLevelBtn.
  ///
  /// In fr, this message translates to:
  /// **'Niv. {level}'**
  String profileEditLevelBtn(int level);

  /// No description provided for @profileEditPosition.
  ///
  /// In fr, this message translates to:
  /// **'Position préférée'**
  String get profileEditPosition;

  /// No description provided for @profileEditPosLeft.
  ///
  /// In fr, this message translates to:
  /// **'Gauche'**
  String get profileEditPosLeft;

  /// No description provided for @profileEditPosRight.
  ///
  /// In fr, this message translates to:
  /// **'Droite'**
  String get profileEditPosRight;

  /// No description provided for @profileEditPosAny.
  ///
  /// In fr, this message translates to:
  /// **'N\'importe'**
  String get profileEditPosAny;

  /// No description provided for @profileEditSelect.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner'**
  String get profileEditSelect;

  /// No description provided for @profileEditAvailability.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilités'**
  String get profileEditAvailability;

  /// No description provided for @profileEditAvailEvening.
  ///
  /// In fr, this message translates to:
  /// **'Soirs & Week-ends'**
  String get profileEditAvailEvening;

  /// No description provided for @profileEditAvailWeek.
  ///
  /// In fr, this message translates to:
  /// **'En semaine'**
  String get profileEditAvailWeek;

  /// No description provided for @profileEditAvailAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout le temps'**
  String get profileEditAvailAll;

  /// No description provided for @profileEditAvailVar.
  ///
  /// In fr, this message translates to:
  /// **'Variable'**
  String get profileEditAvailVar;

  /// No description provided for @profileEditLookingForPartner.
  ///
  /// In fr, this message translates to:
  /// **'Recherche un Binôme'**
  String get profileEditLookingForPartner;

  /// No description provided for @profileEditLookingForPartnerSub.
  ///
  /// In fr, this message translates to:
  /// **'Apparaissez dans le Tinder du Beach pour trouver un partenaire de votre niveau.'**
  String get profileEditLookingForPartnerSub;

  /// No description provided for @profileEditSaveBtn.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get profileEditSaveBtn;

  /// No description provided for @mapDeclareLostHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: J\'ai oublié mes lunettes roses Oakley sur le banc...'**
  String get mapDeclareLostHint;

  /// No description provided for @mapDeclareFoundHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: J\'ai trouvé une housse MBB près du filet 3...'**
  String get mapDeclareFoundHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'it', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
