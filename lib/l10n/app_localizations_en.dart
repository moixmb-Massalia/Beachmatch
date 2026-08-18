// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BeachMatch';

  @override
  String get navHome => 'Home';

  @override
  String get navCourts => 'Courts';

  @override
  String get navPlayers => 'Players';

  @override
  String get navTournaments => 'Tourneys';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profile';

  @override
  String homeHeaderLevel(int level) {
    return 'Lvl. $level';
  }

  @override
  String get homeHeaderSeason => 'SEASON 2026';

  @override
  String get homeHeaderTitle => 'Beach Tennis Club';

  @override
  String get homeHeaderSubtitle => 'Find a court and partners in 1 click';

  @override
  String homeWeatherSunny(int temp) {
    return '$temp°C · Sunny';
  }

  @override
  String homeWeatherWindSand(int wind) {
    return 'Wind ${wind}km/h · Hot sand 🏖️';
  }

  @override
  String get homeWeatherPerfect => 'Perfect';

  @override
  String get homeDirectNews => 'LIVE & NEWS';

  @override
  String get homeMatchOnSand => 'SAND MATCH';

  @override
  String homeMatchPlayersInfo(int current, int max) {
    return '$current/$max Players';
  }

  @override
  String homeMatchRequiredLevel(int level) {
    return 'Lvl. $level';
  }

  @override
  String get homeMatchTapDetails => 'Tap to see details';

  @override
  String get homeMatchCancel => 'Cancel';

  @override
  String get homeMatchQuit => 'Quit';

  @override
  String get homeMatchFull => 'Full';

  @override
  String get homeMatchJoin => 'Join';

  @override
  String get homeDialogCancelTitle => 'Cancel Game';

  @override
  String get homeDialogCancelContent =>
      'Are you sure you want to cancel this game?';

  @override
  String get homeDialogNoKeep => 'No, keep';

  @override
  String get homeDialogYesCancel => 'Yes, cancel';

  @override
  String get homeManagePlayersTitle => 'Manage Players';

  @override
  String get homeManagePlayersEmpty =>
      'No other player has joined this game yet.';

  @override
  String homeManagePlayersRemoved(String name) {
    return '$name was removed from the game.';
  }

  @override
  String homeMatchDetailsRequiredLevel(int level) {
    return 'Required Level: $level';
  }

  @override
  String homeMatchDetailsWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Wind: $wind km/h ($dir)';
  }

  @override
  String homeMatchDetailsPlayersRegistered(int current, int max) {
    return '$current / $max Registered Players';
  }

  @override
  String get homeMatchDetailsHost => 'HOST';

  @override
  String homeMatchDetailsPlayerStats(int level, int score) {
    return 'Level $level · $score pts';
  }

  @override
  String get homeMatchDetailsCancelGame => 'Cancel my game';

  @override
  String get homeMatchDetailsQuitGame => 'Quit game';

  @override
  String get homeMatchDetailsJoinGame => 'Join game';

  @override
  String get homeMatchDetailsFull => 'Full';

  @override
  String get homeMatchesTitle => 'Upcoming Matches';

  @override
  String get homeMatchesLive => 'Live';

  @override
  String get homeEmptyStateTitle => 'The sand awaits you!';

  @override
  String get homeEmptyStateSubtitle =>
      'Be the first to organize a Beach Tennis game in your area.';

  @override
  String get homeCreateMatchButton => 'Create a match';

  @override
  String get homeFabCreate => 'Create a game';

  @override
  String get homeHeaderGreeting => 'Hello';

  @override
  String get homeNewsTitle => 'BEACH TENNIS WORLD';

  @override
  String get homeNewsBadgeDefault => 'NEWS';

  @override
  String get homeNewsBadgeLive => 'LIVE 🔴';

  @override
  String get homeNewsBadgeTuto => 'TUTORIAL 🎓';

  @override
  String get homeNewsBtnLive => 'WATCH LIVE 🔴';

  @override
  String get homeNewsBtnTuto => 'START VIDEO TUTORIAL 🎬';

  @override
  String homeMatchShareMessage(String date, int level, String id) {
    return 'Join me for some Beach Tennis on $date! \nTarget level: $level\nDownload BeachMatch to join my game: https://beachmatch.app/match/$id';
  }

  @override
  String get homeMatchShareTooltip => 'Share';

  @override
  String get homeMatchManageTooltip => 'Manage players';

  @override
  String get mapSearchError =>
      'City not found. Try to be more specific (e.g. Miami, USA).';

  @override
  String mapSearchGenericError(String error) {
    return 'Search error: $error';
  }

  @override
  String get mapAddCourtBtn => 'Add a court';

  @override
  String get mapFindCourtTitle => 'Find a court';

  @override
  String mapCourtsCount(int count) {
    return '$count Courts';
  }

  @override
  String mapSearchCityPrompt(String query) {
    return 'Search \"$query\"';
  }

  @override
  String get mapSearchCitySub => 'Move map to this city';

  @override
  String get mapCourtFree => 'Free Access';

  @override
  String get mapCourtPaid => 'Paid Court / Club';

  @override
  String mapWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Wind: $wind km/h ($dir)';
  }

  @override
  String get mapLostFoundBtn => 'Lost & Found';

  @override
  String mapLostFoundCount(int count) {
    return '$count item(s) reported here';
  }

  @override
  String get mapSubscribeBtn => 'Subscribe to matches';

  @override
  String get mapSubscribedBtn => 'Subscribed to alerts';

  @override
  String get mapSubscribeSub => 'Get notified when a match is created here.';

  @override
  String get mapAdminDeleteCourtBtn => 'Delete this court (Admin)';

  @override
  String get mapAdminDeleteTitle => 'Confirm deletion';

  @override
  String mapAdminDeleteContent(String name) {
    return 'Are you sure you want to delete the court \'$name\'?';
  }

  @override
  String get mapBtnCancel => 'Cancel';

  @override
  String get mapBtnDelete => 'Delete';

  @override
  String get mapBtnClose => 'Close';

  @override
  String get mapLostFoundTitle => 'Lost & Found';

  @override
  String get mapLostFoundEmpty => 'No items reported on this court.';

  @override
  String get mapLostBadge => 'LOST';

  @override
  String get mapFoundBadge => 'FOUND';

  @override
  String get mapLostDeclareBtn => 'I lost an item';

  @override
  String get mapFoundDeclareBtn => 'Item found';

  @override
  String get mapDeclareLostTitle => 'Report a lost item';

  @override
  String get mapDeclareFoundTitle => 'Report a found item';

  @override
  String mapDeclareOnCourt(String name) {
    return 'On court: $name';
  }

  @override
  String get mapDeclareSuccess => 'Announcement published!';

  @override
  String get mapDeclarePublishBtn => 'Publish announcement';

  @override
  String get mapProposeCourtTitle => 'Propose a Court';

  @override
  String get mapProposeCourtSuccess => 'Thank you! The court has been added.';

  @override
  String get mapProposeCourtBtn => 'Add court';

  @override
  String get tournamentListTitle => 'Official Calendar';

  @override
  String tournamentListCount(int count) {
    return '$count Tournaments';
  }

  @override
  String get tournamentListEmpty => 'No tournaments found for this filter.';

  @override
  String get tournamentFilterAll => 'All';

  @override
  String get tournamentDetailEventDetails => 'Event Details';

  @override
  String get tournamentDetailDates => 'Dates';

  @override
  String get tournamentDetailAddress => 'Address';

  @override
  String get tournamentDetailCity => 'City';

  @override
  String get tournamentDetailEvents => 'Events';

  @override
  String get tournamentDetailBalls => 'Balls';

  @override
  String get tournamentDetailPrice => 'Price';

  @override
  String get tournamentDetailCategory => 'Category';

  @override
  String get tournamentDetailRegistration => 'Registration & Contact';

  @override
  String get tournamentDetailRegistrationType => 'Registration Type:';

  @override
  String get tournamentDetailReferee => 'Referee';

  @override
  String get profileTitle => 'My Profile';

  @override
  String get profileCityUnknown => 'City not set';

  @override
  String profileLevel(int level) {
    return '🏅 LEVEL $level · COMPETITOR';
  }

  @override
  String profileRanking(String ranking) {
    return '🎾 Beach Tennis Ranking: $ranking';
  }

  @override
  String get profileMatchesPlayed => 'Matches Played';

  @override
  String get profileFftRanking => 'FFT RANKING';

  @override
  String get profileAdminPanelTitle => 'Admin Panel';

  @override
  String get profileAdminPanelSub => 'Manage YouTube videos and live news.';

  @override
  String get profileAdminPanelBtn => 'Open Panel 👑';

  @override
  String get profileRadarTitle => 'Tournament Radar (Sniper)';

  @override
  String profileRadarActivated(String region) {
    return 'Radar activated for region: $region';
  }

  @override
  String get profileRadarError => 'Error activating radar';

  @override
  String get profileRadarSub =>
      'Get an instant push notification when a tournament is announced in your region to be the first to register.';

  @override
  String get profileRadarRegion => 'Monitored region: ';

  @override
  String get profileRadarEditRegion => 'Edit region';

  @override
  String get profileRadarRegionHint => 'Enter a city or region...';

  @override
  String get profileBtnCancel => 'Cancel';

  @override
  String get profileBtnValidate => 'Validate';

  @override
  String get profilePreferencesTitle => 'Game Preferences';

  @override
  String get profilePrefPosition => 'Preferred position';

  @override
  String get profilePrefNotSet => 'Not set';

  @override
  String get profilePrefAvailability => 'Availability';

  @override
  String get profileLegalTitle => 'Legal';

  @override
  String get profilePrivacy => 'Privacy Policy';

  @override
  String get profileTerms => 'Terms of Service';

  @override
  String get profileAccountManagement => 'Account Management';

  @override
  String get profileLogout => 'Log out';

  @override
  String get profileDeleteAccount => 'Delete my account';

  @override
  String get profileDeleteAccountConfirmTitle => 'Delete account';

  @override
  String get profileDeleteAccountConfirmSub =>
      'This action is irreversible. Your profile, matches, and messages will be permanently deleted.';

  @override
  String get profileBtnDelete => 'Delete';

  @override
  String get rankingFirst => '1st';

  @override
  String rankingNth(int num) {
    return '${num}th';
  }

  @override
  String profileEditPhotoError(String error) {
    return 'Selection error: $error';
  }

  @override
  String get profileEditPhotoDeleted =>
      'Profile photo deleted (click Save to confirm).';

  @override
  String get profileEditPhotoTitle => 'Profile Photo';

  @override
  String get profileEditPhotoGallery => 'Choose from gallery';

  @override
  String get profileEditPhotoCamera => 'Take a picture';

  @override
  String get profileEditPhotoRemove => 'Remove current photo';

  @override
  String get profileEditLicenceSuccess =>
      'FFT License validated! Ranking updated.';

  @override
  String get profileEditLicenceNotFound =>
      'License not found in official ranking.';

  @override
  String profileEditLicenceError(String error) {
    return 'Connection error: $error';
  }

  @override
  String profileEditSaveError(String error) {
    return 'Error: $error';
  }

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get profileEditName => 'First and Last Name';

  @override
  String get profileEditLicence => 'License Number (Optional)';

  @override
  String get profileEditVerifyBtn => 'Verify';

  @override
  String get profileEditCity => 'City or Region';

  @override
  String get profileEditFft => 'FFT Ranking (e.g., 3/6, Unranked...)';

  @override
  String get profileEditLevel => 'Level';

  @override
  String profileEditLevelBtn(int level) {
    return 'Lvl $level';
  }

  @override
  String get profileEditPosition => 'Preferred Position';

  @override
  String get profileEditPosLeft => 'Left';

  @override
  String get profileEditPosRight => 'Right';

  @override
  String get profileEditPosAny => 'Any';

  @override
  String get profileEditSelect => 'Select';

  @override
  String get profileEditAvailability => 'Availability';

  @override
  String get profileEditAvailEvening => 'Evenings & Weekends';

  @override
  String get profileEditAvailWeek => 'Weekdays';

  @override
  String get profileEditAvailAll => 'Anytime';

  @override
  String get profileEditAvailVar => 'Variable';

  @override
  String get profileEditLookingForPartner => 'Looking for a Partner';

  @override
  String get profileEditLookingForPartnerSub =>
      'Appear in Beach Tinder to find a partner at your level.';

  @override
  String get profileEditSaveBtn => 'Save';

  @override
  String get mapDeclareLostHint =>
      'Ex: I left my pink Oakley sunglasses on the bench...';

  @override
  String get mapDeclareFoundHint => 'Ex: I found an MBB cover near net 3...';
}
