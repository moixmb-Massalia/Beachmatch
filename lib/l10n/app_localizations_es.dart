// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'BeachMatch';

  @override
  String get navHome => 'Inicio';

  @override
  String get navCourts => 'Pistas';

  @override
  String get navPlayers => 'Jugadores';

  @override
  String get navTournaments => 'Torneos';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Perfil';

  @override
  String homeHeaderLevel(int level) {
    return 'Niv. $level';
  }

  @override
  String get homeHeaderSeason => 'TEMPORADA 2026';

  @override
  String get homeHeaderTitle => 'Beach Tennis Club';

  @override
  String get homeHeaderSubtitle => 'Encuentra una pista y compañeros en 1 clic';

  @override
  String homeWeatherSunny(int temp) {
    return '$temp°C · Soleado';
  }

  @override
  String homeWeatherWindSand(int wind) {
    return 'Viento ${wind}km/h · Arena caliente 🏖️';
  }

  @override
  String get homeWeatherPerfect => 'Perfecto';

  @override
  String get homeDirectNews => 'DIRECTO Y NOTICIAS';

  @override
  String get homeMatchOnSand => 'PARTIDO EN ARENA';

  @override
  String homeMatchPlayersInfo(int current, int max) {
    return '$current/$max Jugadores';
  }

  @override
  String homeMatchRequiredLevel(int level) {
    return 'Niv. $level';
  }

  @override
  String get homeMatchTapDetails => 'Toca para ver los detalles';

  @override
  String get homeMatchCancel => 'Cancelar';

  @override
  String get homeMatchQuit => 'Salir';

  @override
  String get homeMatchFull => 'Completo';

  @override
  String get homeMatchJoin => 'Unirse';

  @override
  String get homeDialogCancelTitle => 'Cancelar el partido';

  @override
  String get homeDialogCancelContent =>
      '¿Estás seguro de que quieres cancelar este partido?';

  @override
  String get homeDialogNoKeep => 'No, mantener';

  @override
  String get homeDialogYesCancel => 'Sí, cancelar';

  @override
  String get homeManagePlayersTitle => 'Gestionar Jugadores';

  @override
  String get homeManagePlayersEmpty =>
      'Ningún otro jugador se ha unido a este partido todavía.';

  @override
  String homeManagePlayersRemoved(String name) {
    return '$name ha sido eliminado del partido.';
  }

  @override
  String homeMatchDetailsRequiredLevel(int level) {
    return 'Nivel requerido: $level';
  }

  @override
  String homeMatchDetailsWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Viento: $wind km/h ($dir)';
  }

  @override
  String homeMatchDetailsPlayersRegistered(int current, int max) {
    return '$current / $max Jugadores Inscritos';
  }

  @override
  String get homeMatchDetailsHost => 'ANFITRIÓN';

  @override
  String homeMatchDetailsPlayerStats(int level, int score) {
    return 'Nivel $level · $score pts';
  }

  @override
  String get homeMatchDetailsCancelGame => 'Cancelar mi partido';

  @override
  String get homeMatchDetailsQuitGame => 'Salir del partido';

  @override
  String get homeMatchDetailsJoinGame => 'Unirse al partido';

  @override
  String get homeMatchDetailsFull => 'Completo';

  @override
  String get homeMatchesTitle => 'Próximos partidos';

  @override
  String get homeMatchesLive => 'En vivo';

  @override
  String get homeEmptyStateTitle => '¡La arena te espera!';

  @override
  String get homeEmptyStateSubtitle =>
      'Sé el primero en organizar un partido de Beach Tennis en tu zona.';

  @override
  String get homeCreateMatchButton => 'Crear un partido';

  @override
  String get homeFabCreate => 'Crear un juego';

  @override
  String get homeHeaderGreeting => 'Hola';

  @override
  String get homeNewsTitle => 'MUNDO BEACH TENNIS';

  @override
  String get homeNewsBadgeDefault => 'NOTICIA';

  @override
  String get homeNewsBadgeLive => 'EN VIVO 🔴';

  @override
  String get homeNewsBadgeTuto => 'TUTORIAL 🎓';

  @override
  String get homeNewsBtnLive => 'VER EN VIVO 🔴';

  @override
  String get homeNewsBtnTuto => 'INICIAR TUTORIAL EN VIDEO 🎬';

  @override
  String homeMatchShareMessage(String date, int level, String id) {
    return '¡Únete a mí para jugar Beach Tennis el $date! \nNivel objetivo: $level\nDescarga BeachMatch para unirte a mi partido: https://beachmatch.app/match/$id';
  }

  @override
  String get homeMatchShareTooltip => 'Compartir';

  @override
  String get homeMatchManageTooltip => 'Gestionar jugadores';

  @override
  String get mapSearchError =>
      'Ciudad no encontrada. Intenta ser más específico (ej. Valencia, España).';

  @override
  String mapSearchGenericError(String error) {
    return 'Error de búsqueda: $error';
  }

  @override
  String get mapAddCourtBtn => 'Añadir una pista';

  @override
  String get mapFindCourtTitle => 'Encontrar una pista';

  @override
  String mapCourtsCount(int count) {
    return '$count Pistas';
  }

  @override
  String mapSearchCityPrompt(String query) {
    return 'Buscar \"$query\"';
  }

  @override
  String get mapSearchCitySub => 'Mover mapa a esta ciudad';

  @override
  String get mapCourtFree => 'Acceso libre y gratuito';

  @override
  String get mapCourtPaid => 'Pista de pago / Club';

  @override
  String mapWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Viento: $wind km/h ($dir)';
  }

  @override
  String get mapLostFoundBtn => 'Objetos Perdidos / Encontrados';

  @override
  String mapLostFoundCount(int count) {
    return '$count objeto(s) reportado(s) aquí';
  }

  @override
  String get mapSubscribeBtn => 'Suscribirse a partidos';

  @override
  String get mapSubscribedBtn => 'Suscrito a alertas';

  @override
  String get mapSubscribeSub =>
      'Recibe notificaciones cuando se cree un partido aquí.';

  @override
  String get mapAdminDeleteCourtBtn => 'Eliminar esta pista (Admin)';

  @override
  String get mapAdminDeleteTitle => 'Confirmar eliminación';

  @override
  String mapAdminDeleteContent(String name) {
    return '¿Estás seguro de que quieres eliminar la pista \'$name\'?';
  }

  @override
  String get mapBtnCancel => 'Cancelar';

  @override
  String get mapBtnDelete => 'Eliminar';

  @override
  String get mapBtnClose => 'Cerrar';

  @override
  String get mapLostFoundTitle => 'Objetos Perdidos / Encontrados';

  @override
  String get mapLostFoundEmpty => 'No hay objetos reportados en esta pista.';

  @override
  String get mapLostBadge => 'PERDIDO';

  @override
  String get mapFoundBadge => 'ENCONTRADO';

  @override
  String get mapLostDeclareBtn => 'He perdido un objeto';

  @override
  String get mapFoundDeclareBtn => 'Objeto encontrado';

  @override
  String get mapDeclareLostTitle => 'Reportar objeto perdido';

  @override
  String get mapDeclareFoundTitle => 'Reportar objeto encontrado';

  @override
  String mapDeclareOnCourt(String name) {
    return 'En la pista: $name';
  }

  @override
  String get mapDeclareSuccess => '¡Anuncio publicado!';

  @override
  String get mapDeclarePublishBtn => 'Publicar anuncio';

  @override
  String get mapProposeCourtTitle => 'Proponer una Pista';

  @override
  String get mapProposeCourtSuccess => '¡Gracias! La pista ha sido añadida.';

  @override
  String get mapProposeCourtBtn => 'Añadir pista';

  @override
  String get tournamentListTitle => 'Calendario Oficial';

  @override
  String tournamentListCount(int count) {
    return '$count Torneos';
  }

  @override
  String get tournamentListEmpty =>
      'No se encontraron torneos para este filtro.';

  @override
  String get tournamentFilterAll => 'Todos';

  @override
  String get tournamentDetailEventDetails => 'Detalles del Evento';

  @override
  String get tournamentDetailDates => 'Fechas';

  @override
  String get tournamentDetailAddress => 'Dirección';

  @override
  String get tournamentDetailCity => 'Ciudad';

  @override
  String get tournamentDetailEvents => 'Eventos';

  @override
  String get tournamentDetailBalls => 'Bolas';

  @override
  String get tournamentDetailPrice => 'Precio';

  @override
  String get tournamentDetailCategory => 'Categoría';

  @override
  String get tournamentDetailRegistration => 'Inscripción y Contacto';

  @override
  String get tournamentDetailRegistrationType => 'Tipo de inscripción:';

  @override
  String get tournamentDetailReferee => 'Árbitro';

  @override
  String get profileTitle => 'Mi Perfil';

  @override
  String get profileCityUnknown => 'Ciudad no definida';

  @override
  String profileLevel(int level) {
    return '🏅 NIVEL $level · COMPETIDOR';
  }

  @override
  String profileRanking(String ranking) {
    return '🎾 Ranking Beach Tennis: $ranking';
  }

  @override
  String get profileMatchesPlayed => 'Partidos Jugados';

  @override
  String get profileFftRanking => 'RANKING FFT';

  @override
  String get profileAdminPanelTitle => 'Panel de Administración';

  @override
  String get profileAdminPanelSub =>
      'Gestiona vídeos de YouTube y noticias en directo.';

  @override
  String get profileAdminPanelBtn => 'Abrir Panel 👑';

  @override
  String get profileRadarTitle => 'Radar de Torneos (Sniper)';

  @override
  String profileRadarActivated(String region) {
    return 'Radar activado para la región: $region';
  }

  @override
  String get profileRadarError => 'Error al activar el radar';

  @override
  String get profileRadarSub =>
      'Recibe una notificación push instantánea cuando se anuncie un torneo en tu región para ser el primero en inscribirte.';

  @override
  String get profileRadarRegion => 'Región monitoreada: ';

  @override
  String get profileRadarEditRegion => 'Editar región';

  @override
  String get profileRadarRegionHint => 'Ingresa una ciudad o región...';

  @override
  String get profileBtnCancel => 'Cancelar';

  @override
  String get profileBtnValidate => 'Validar';

  @override
  String get profilePreferencesTitle => 'Preferencias de Juego';

  @override
  String get profilePrefPosition => 'Posición preferida';

  @override
  String get profilePrefNotSet => 'No especificado';

  @override
  String get profilePrefAvailability => 'Disponibilidad';

  @override
  String get profileLegalTitle => 'Legal';

  @override
  String get profilePrivacy => 'Política de Privacidad';

  @override
  String get profileTerms => 'Términos de Servicio';

  @override
  String get profileAccountManagement => 'Gestión de Cuenta';

  @override
  String get profileLogout => 'Cerrar sesión';

  @override
  String get profileDeleteAccount => 'Eliminar mi cuenta';

  @override
  String get profileDeleteAccountConfirmTitle => 'Eliminar cuenta';

  @override
  String get profileDeleteAccountConfirmSub =>
      'Esta acción es irreversible. Tu perfil, partidos y mensajes serán eliminados permanentemente.';

  @override
  String get profileBtnDelete => 'Eliminar';

  @override
  String get rankingFirst => '1º';

  @override
  String rankingNth(int num) {
    return '$numº';
  }

  @override
  String profileEditPhotoError(String error) {
    return 'Error de selección: $error';
  }

  @override
  String get profileEditPhotoDeleted =>
      'Foto de perfil eliminada (haz clic en Guardar para confirmar).';

  @override
  String get profileEditPhotoTitle => 'Foto de perfil';

  @override
  String get profileEditPhotoGallery => 'Elegir de la galería';

  @override
  String get profileEditPhotoCamera => 'Tomar una foto';

  @override
  String get profileEditPhotoRemove => 'Eliminar foto actual';

  @override
  String get profileEditLicenceSuccess =>
      '¡Licencia FFT validada! Ranking actualizado.';

  @override
  String get profileEditLicenceNotFound =>
      'Licencia no encontrada en el ranking oficial.';

  @override
  String profileEditLicenceError(String error) {
    return 'Error de conexión: $error';
  }

  @override
  String profileEditSaveError(String error) {
    return 'Error: $error';
  }

  @override
  String get profileEditTitle => 'Editar Perfil';

  @override
  String get profileEditName => 'Nombre y Apellido';

  @override
  String get profileEditLicence => 'Número de licencia (Opcional)';

  @override
  String get profileEditVerifyBtn => 'Verificar';

  @override
  String get profileEditCity => 'Ciudad o Región';

  @override
  String get profileEditFft => 'Ranking FFT (ej. 3/6, Sin clasificar...)';

  @override
  String get profileEditLevel => 'Nivel';

  @override
  String profileEditLevelBtn(int level) {
    return 'Niv. $level';
  }

  @override
  String get profileEditPosition => 'Posición preferida';

  @override
  String get profileEditPosLeft => 'Izquierda';

  @override
  String get profileEditPosRight => 'Derecha';

  @override
  String get profileEditPosAny => 'Cualquiera';

  @override
  String get profileEditSelect => 'Seleccionar';

  @override
  String get profileEditAvailability => 'Disponibilidad';

  @override
  String get profileEditAvailEvening => 'Tardes y fines de semana';

  @override
  String get profileEditAvailWeek => 'Entre semana';

  @override
  String get profileEditAvailAll => 'Siempre';

  @override
  String get profileEditAvailVar => 'Variable';

  @override
  String get profileEditLookingForPartner => 'Buscando pareja';

  @override
  String get profileEditLookingForPartnerSub =>
      'Aparece en Beach Tinder para encontrar una pareja de tu nivel.';

  @override
  String get profileEditSaveBtn => 'Guardar';

  @override
  String get mapDeclareLostHint =>
      'Ej: Olvidé mis gafas Oakley rosas en el banco...';

  @override
  String get mapDeclareFoundHint =>
      'Ej: Encontré una funda MBB cerca de la red 3...';
}
