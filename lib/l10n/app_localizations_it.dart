// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'BeachMatch';

  @override
  String get navHome => 'Home';

  @override
  String get navCourts => 'Campi';

  @override
  String get navPlayers => 'Giocatori';

  @override
  String get navTournaments => 'Tornei';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profilo';

  @override
  String homeHeaderLevel(int level) {
    return 'Liv. $level';
  }

  @override
  String get homeHeaderSeason => 'STAGIONE 2026';

  @override
  String get homeHeaderTitle => 'Beach Tennis Club';

  @override
  String get homeHeaderSubtitle => 'Trova un campo e dei compagni in 1 clic';

  @override
  String homeWeatherSunny(int temp) {
    return '$temp°C · Soleggiato';
  }

  @override
  String homeWeatherWindSand(int wind) {
    return 'Vento ${wind}km/h · Sabbia calda 🏖️';
  }

  @override
  String get homeWeatherPerfect => 'Perfetto';

  @override
  String get homeDirectNews => 'DIRETTA E NEWS';

  @override
  String get homeMatchOnSand => 'PARTITA SU SABBIA';

  @override
  String homeMatchPlayersInfo(int current, int max) {
    return '$current/$max Giocatori';
  }

  @override
  String homeMatchRequiredLevel(int level) {
    return 'Liv. $level';
  }

  @override
  String get homeMatchTapDetails => 'Tocca per vedere i dettagli';

  @override
  String get homeMatchCancel => 'Annulla';

  @override
  String get homeMatchQuit => 'Esci';

  @override
  String get homeMatchFull => 'Completo';

  @override
  String get homeMatchJoin => 'Partecipa';

  @override
  String get homeDialogCancelTitle => 'Annulla la partita';

  @override
  String get homeDialogCancelContent =>
      'Sei sicuro di voler annullare questa partita?';

  @override
  String get homeDialogNoKeep => 'No, mantieni';

  @override
  String get homeDialogYesCancel => 'Sì, annulla';

  @override
  String get homeManagePlayersTitle => 'Gestisci Giocatori';

  @override
  String get homeManagePlayersEmpty =>
      'Nessun altro giocatore si è ancora unito a questa partita.';

  @override
  String homeManagePlayersRemoved(String name) {
    return '$name è stato rimosso dalla partita.';
  }

  @override
  String homeMatchDetailsRequiredLevel(int level) {
    return 'Livello richiesto: $level';
  }

  @override
  String homeMatchDetailsWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Vento: $wind km/h ($dir)';
  }

  @override
  String homeMatchDetailsPlayersRegistered(int current, int max) {
    return '$current / $max Giocatori Iscritti';
  }

  @override
  String get homeMatchDetailsHost => 'HOST';

  @override
  String homeMatchDetailsPlayerStats(int level, int score) {
    return 'Livello $level · $score pt';
  }

  @override
  String get homeMatchDetailsCancelGame => 'Annulla la mia partita';

  @override
  String get homeMatchDetailsQuitGame => 'Esci dalla partita';

  @override
  String get homeMatchDetailsJoinGame => 'Partecipa alla partita';

  @override
  String get homeMatchDetailsFull => 'Completo';

  @override
  String get homeMatchesTitle => 'Prossime partite';

  @override
  String get homeMatchesLive => 'In diretta';

  @override
  String get homeEmptyStateTitle => 'La sabbia ti aspetta!';

  @override
  String get homeEmptyStateSubtitle =>
      'Sii il primo a organizzare una partita di Beach Tennis nella tua zona.';

  @override
  String get homeCreateMatchButton => 'Crea una partita';

  @override
  String get homeFabCreate => 'Crea un gioco';

  @override
  String get homeHeaderGreeting => 'Ciao';

  @override
  String get homeNewsTitle => 'MONDO BEACH TENNIS';

  @override
  String get homeNewsBadgeDefault => 'NOVITÀ';

  @override
  String get homeNewsBadgeLive => 'IN DIRETTA 🔴';

  @override
  String get homeNewsBadgeTuto => 'TUTORIAL 🎓';

  @override
  String get homeNewsBtnLive => 'GUARDA IN DIRETTA 🔴';

  @override
  String get homeNewsBtnTuto => 'AVVIA IL VIDEO TUTORIAL 🎬';

  @override
  String homeMatchShareMessage(String date, int level, String id) {
    return 'Unisciti a me per una partita di Beach Tennis il $date! \nLivello richiesto: $level\nScarica BeachMatch per unirti alla mia partita: https://beachmatch.app/match/$id';
  }

  @override
  String get homeMatchShareTooltip => 'Condividi';

  @override
  String get homeMatchManageTooltip => 'Gestisci giocatori';

  @override
  String get mapSearchError =>
      'Città non trovata. Prova ad essere più specifico (es. Roma, Italia).';

  @override
  String mapSearchGenericError(String error) {
    return 'Errore di ricerca: $error';
  }

  @override
  String get mapAddCourtBtn => 'Aggiungi un campo';

  @override
  String get mapFindCourtTitle => 'Trova un campo';

  @override
  String mapCourtsCount(int count) {
    return '$count Campi';
  }

  @override
  String mapSearchCityPrompt(String query) {
    return 'Cerca \"$query\"';
  }

  @override
  String get mapSearchCitySub => 'Sposta la mappa su questa città';

  @override
  String get mapCourtFree => 'Accesso libero e gratuito';

  @override
  String get mapCourtPaid => 'Campo a pagamento / Club';

  @override
  String mapWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Vento: $wind km/h ($dir)';
  }

  @override
  String get mapLostFoundBtn => 'Oggetti smarriti / Trovati';

  @override
  String mapLostFoundCount(int count) {
    return '$count oggetto/i segnalato/i qui';
  }

  @override
  String get mapSubscribeBtn => 'Iscriviti alle partite';

  @override
  String get mapSubscribedBtn => 'Iscritto agli avvisi';

  @override
  String get mapSubscribeSub =>
      'Ricevi notifiche quando viene creata una partita qui.';

  @override
  String get mapAdminDeleteCourtBtn => 'Elimina questo campo (Admin)';

  @override
  String get mapAdminDeleteTitle => 'Conferma eliminazione';

  @override
  String mapAdminDeleteContent(String name) {
    return 'Sei sicuro di voler eliminare il campo \'$name\'?';
  }

  @override
  String get mapBtnCancel => 'Annulla';

  @override
  String get mapBtnDelete => 'Elimina';

  @override
  String get mapBtnClose => 'Chiudi';

  @override
  String get mapLostFoundTitle => 'Oggetti smarriti / Trovati';

  @override
  String get mapLostFoundEmpty => 'Nessun oggetto segnalato su questo campo.';

  @override
  String get mapLostBadge => 'SMARRITO';

  @override
  String get mapFoundBadge => 'TROVATO';

  @override
  String get mapLostDeclareBtn => 'Ho smarrito un oggetto';

  @override
  String get mapFoundDeclareBtn => 'Oggetto trovato';

  @override
  String get mapDeclareLostTitle => 'Segnala oggetto smarrito';

  @override
  String get mapDeclareFoundTitle => 'Segnala oggetto trovato';

  @override
  String mapDeclareOnCourt(String name) {
    return 'Sul campo: $name';
  }

  @override
  String get mapDeclareSuccess => 'Annuncio pubblicato!';

  @override
  String get mapDeclarePublishBtn => 'Pubblica annuncio';

  @override
  String get mapProposeCourtTitle => 'Proponi un Campo';

  @override
  String get mapProposeCourtSuccess => 'Grazie! Il campo è stato aggiunto.';

  @override
  String get mapProposeCourtBtn => 'Aggiungi campo';

  @override
  String get tournamentListTitle => 'Calendario Ufficiale';

  @override
  String tournamentListCount(int count) {
    return '$count Tornei';
  }

  @override
  String get tournamentListEmpty => 'Nessun torneo trovato per questo filtro.';

  @override
  String get tournamentFilterAll => 'Tutti';

  @override
  String get tournamentDetailEventDetails => 'Dettagli dell\'Evento';

  @override
  String get tournamentDetailDates => 'Date';

  @override
  String get tournamentDetailAddress => 'Indirizzo';

  @override
  String get tournamentDetailCity => 'Città';

  @override
  String get tournamentDetailEvents => 'Eventi';

  @override
  String get tournamentDetailBalls => 'Palline';

  @override
  String get tournamentDetailPrice => 'Prezzo';

  @override
  String get tournamentDetailCategory => 'Categoria';

  @override
  String get tournamentDetailRegistration => 'Iscrizione e Contatti';

  @override
  String get tournamentDetailRegistrationType => 'Tipo di iscrizione:';

  @override
  String get tournamentDetailReferee => 'Arbitro';

  @override
  String get profileTitle => 'Il mio Profilo';

  @override
  String get profileCityUnknown => 'Città non definita';

  @override
  String profileLevel(int level) {
    return '🏅 LIVELLO $level · COMPETITORE';
  }

  @override
  String profileRanking(String ranking) {
    return '🎾 Classifica Beach Tennis: $ranking';
  }

  @override
  String get profileMatchesPlayed => 'Partite Giocate';

  @override
  String get profileFftRanking => 'CLASSIFICA FFT';

  @override
  String get profileAdminPanelTitle => 'Pannello di Amministrazione';

  @override
  String get profileAdminPanelSub =>
      'Gestisci i video di YouTube e le notizie in diretta.';

  @override
  String get profileAdminPanelBtn => 'Apri Pannello 👑';

  @override
  String get profileRadarTitle => 'Radar Tornei (Sniper)';

  @override
  String profileRadarActivated(String region) {
    return 'Radar attivato per la regione: $region';
  }

  @override
  String get profileRadarError => 'Errore durante l\'attivazione del radar';

  @override
  String get profileRadarSub =>
      'Ricevi una notifica push istantanea quando viene annunciato un torneo nella tua regione per essere il primo ad iscriverti.';

  @override
  String get profileRadarRegion => 'Regione monitorata: ';

  @override
  String get profileRadarEditRegion => 'Modifica regione';

  @override
  String get profileRadarRegionHint => 'Inserisci una città o regione...';

  @override
  String get profileBtnCancel => 'Annulla';

  @override
  String get profileBtnValidate => 'Convalida';

  @override
  String get profilePreferencesTitle => 'Preferenze di Gioco';

  @override
  String get profilePrefPosition => 'Posizione preferita';

  @override
  String get profilePrefNotSet => 'Non specificato';

  @override
  String get profilePrefAvailability => 'Disponibilità';

  @override
  String get profileLegalTitle => 'Legale';

  @override
  String get profilePrivacy => 'Informativa sulla Privacy';

  @override
  String get profileTerms => 'Termini di Servizio';

  @override
  String get profileAccountManagement => 'Gestione Account';

  @override
  String get profileLogout => 'Disconnetti';

  @override
  String get profileDeleteAccount => 'Elimina il mio account';

  @override
  String get profileDeleteAccountConfirmTitle => 'Elimina account';

  @override
  String get profileDeleteAccountConfirmSub =>
      'Questa azione è irreversibile. Il tuo profilo, le tue partite e i tuoi messaggi verranno eliminati definitivamente.';

  @override
  String get profileBtnDelete => 'Elimina';

  @override
  String get rankingFirst => '1°';

  @override
  String rankingNth(int num) {
    return '$num°';
  }

  @override
  String profileEditPhotoError(String error) {
    return 'Errore di selezione: $error';
  }

  @override
  String get profileEditPhotoDeleted =>
      'Foto del profilo eliminata (clicca su Salva per confermare).';

  @override
  String get profileEditPhotoTitle => 'Foto del profilo';

  @override
  String get profileEditPhotoGallery => 'Scegli dalla galleria';

  @override
  String get profileEditPhotoCamera => 'Scatta una foto';

  @override
  String get profileEditPhotoRemove => 'Rimuovi foto attuale';

  @override
  String get profileEditLicenceSuccess =>
      'Licenza FFT convalidata! Classifica aggiornata.';

  @override
  String get profileEditLicenceNotFound =>
      'Licenza non trovata nella classifica ufficiale.';

  @override
  String profileEditLicenceError(String error) {
    return 'Errore di connessione: $error';
  }

  @override
  String profileEditSaveError(String error) {
    return 'Errore: $error';
  }

  @override
  String get profileEditTitle => 'Modifica Profilo';

  @override
  String get profileEditName => 'Nome e Cognome';

  @override
  String get profileEditLicence => 'Numero di licenza (Opzionale)';

  @override
  String get profileEditVerifyBtn => 'Verifica';

  @override
  String get profileEditCity => 'Città o Regione';

  @override
  String get profileEditFft => 'Classifica FFT (es. 3/6, Non classificato...)';

  @override
  String get profileEditLevel => 'Livello';

  @override
  String profileEditLevelBtn(int level) {
    return 'Liv. $level';
  }

  @override
  String get profileEditPosition => 'Posizione preferita';

  @override
  String get profileEditPosLeft => 'Sinistra';

  @override
  String get profileEditPosRight => 'Destra';

  @override
  String get profileEditPosAny => 'Qualsiasi';

  @override
  String get profileEditSelect => 'Seleziona';

  @override
  String get profileEditAvailability => 'Disponibilità';

  @override
  String get profileEditAvailEvening => 'Sere e fine settimana';

  @override
  String get profileEditAvailWeek => 'Giorni feriali';

  @override
  String get profileEditAvailAll => 'Sempre';

  @override
  String get profileEditAvailVar => 'Variabile';

  @override
  String get profileEditLookingForPartner => 'Cerco un partner';

  @override
  String get profileEditLookingForPartnerSub =>
      'Appari in Beach Tinder per trovare un partner del tuo livello.';

  @override
  String get profileEditSaveBtn => 'Salva';

  @override
  String get mapDeclareLostHint =>
      'Es: Ho dimenticato i miei occhiali Oakley rosa sulla panchina...';

  @override
  String get mapDeclareFoundHint =>
      'Es: Ho trovato una custodia MBB vicino alla rete 3...';
}
