// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'BeachMatch';

  @override
  String get navHome => 'Início';

  @override
  String get navCourts => 'Campos';

  @override
  String get navPlayers => 'Jogadores';

  @override
  String get navTournaments => 'Torneios';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Perfil';

  @override
  String homeHeaderLevel(int level) {
    return 'Nív. $level';
  }

  @override
  String get homeHeaderSeason => 'TEMPORADA 2026';

  @override
  String get homeHeaderTitle => 'Beach Tennis Club';

  @override
  String get homeHeaderSubtitle => 'Encontre um campo e parceiros em 1 clique';

  @override
  String homeWeatherSunny(int temp) {
    return '$temp°C · Ensolarado';
  }

  @override
  String homeWeatherWindSand(int wind) {
    return 'Vento ${wind}km/h · Areia quente 🏖️';
  }

  @override
  String get homeWeatherPerfect => 'Perfeito';

  @override
  String get homeDirectNews => 'DIRETO E NOTÍCIAS';

  @override
  String get homeMatchOnSand => 'PARTIDA NA AREIA';

  @override
  String homeMatchPlayersInfo(int current, int max) {
    return '$current/$max Jogadores';
  }

  @override
  String homeMatchRequiredLevel(int level) {
    return 'Nív. $level';
  }

  @override
  String get homeMatchTapDetails => 'Toque para ver os detalhes';

  @override
  String get homeMatchCancel => 'Cancelar';

  @override
  String get homeMatchQuit => 'Sair';

  @override
  String get homeMatchFull => 'Completo';

  @override
  String get homeMatchJoin => 'Entrar';

  @override
  String get homeDialogCancelTitle => 'Cancelar a partida';

  @override
  String get homeDialogCancelContent =>
      'Tem certeza que deseja cancelar esta partida?';

  @override
  String get homeDialogNoKeep => 'Não, manter';

  @override
  String get homeDialogYesCancel => 'Sim, cancelar';

  @override
  String get homeManagePlayersTitle => 'Gerir Jogadores';

  @override
  String get homeManagePlayersEmpty =>
      'Nenhum outro jogador entrou nesta partida ainda.';

  @override
  String homeManagePlayersRemoved(String name) {
    return '$name foi removido da partida.';
  }

  @override
  String homeMatchDetailsRequiredLevel(int level) {
    return 'Nível exigido: $level';
  }

  @override
  String homeMatchDetailsWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Vento: $wind km/h ($dir)';
  }

  @override
  String homeMatchDetailsPlayersRegistered(int current, int max) {
    return '$current / $max Jogadores Inscritos';
  }

  @override
  String get homeMatchDetailsHost => 'ANFITRIÃO';

  @override
  String homeMatchDetailsPlayerStats(int level, int score) {
    return 'Nível $level · $score pts';
  }

  @override
  String get homeMatchDetailsCancelGame => 'Cancelar minha partida';

  @override
  String get homeMatchDetailsQuitGame => 'Sair da partida';

  @override
  String get homeMatchDetailsJoinGame => 'Entrar na partida';

  @override
  String get homeMatchDetailsFull => 'Completo';

  @override
  String get homeMatchesTitle => 'Próximas partidas';

  @override
  String get homeMatchesLive => 'Ao vivo';

  @override
  String get homeEmptyStateTitle => 'A areia te espera!';

  @override
  String get homeEmptyStateSubtitle =>
      'Seja o primeiro a organizar uma partida de Beach Tennis na sua área.';

  @override
  String get homeCreateMatchButton => 'Criar uma partida';

  @override
  String get homeFabCreate => 'Criar um jogo';

  @override
  String get homeHeaderGreeting => 'Olá';

  @override
  String get homeNewsTitle => 'MUNDO BEACH TENNIS';

  @override
  String get homeNewsBadgeDefault => 'NOTÍCIA';

  @override
  String get homeNewsBadgeLive => 'AO VIVO 🔴';

  @override
  String get homeNewsBadgeTuto => 'TUTORIAL 🎓';

  @override
  String get homeNewsBtnLive => 'ASSISTIR AO VIVO 🔴';

  @override
  String get homeNewsBtnTuto => 'INICIAR TUTORIAL EM VÍDEO 🎬';

  @override
  String homeMatchShareMessage(String date, int level, String id) {
    return 'Junte-se a mim para jogar Beach Tennis no dia $date! \nNível alvo: $level\nBaixe o BeachMatch para entrar na minha partida: https://beachmatch.app/match/$id';
  }

  @override
  String get homeMatchShareTooltip => 'Compartilhar';

  @override
  String get homeMatchManageTooltip => 'Gerenciar jogadores';

  @override
  String get mapSearchError =>
      'Cidade não encontrada. Tente ser mais específico (ex: Rio de Janeiro, Brasil).';

  @override
  String mapSearchGenericError(String error) {
    return 'Erro de busca: $error';
  }

  @override
  String get mapAddCourtBtn => 'Adicionar uma quadra';

  @override
  String get mapFindCourtTitle => 'Encontrar uma quadra';

  @override
  String mapCourtsCount(int count) {
    return '$count Quadras';
  }

  @override
  String mapSearchCityPrompt(String query) {
    return 'Buscar \"$query\"';
  }

  @override
  String get mapSearchCitySub => 'Mover mapa para esta cidade';

  @override
  String get mapCourtFree => 'Acesso Livre e Gratuito';

  @override
  String get mapCourtPaid => 'Quadra Paga / Clube';

  @override
  String mapWeatherWind(int temp, int wind, String dir) {
    return '$temp°C • Vento: $wind km/h ($dir)';
  }

  @override
  String get mapLostFoundBtn => 'Achados e Perdidos';

  @override
  String mapLostFoundCount(int count) {
    return '$count item(ns) reportado(s) aqui';
  }

  @override
  String get mapSubscribeBtn => 'Inscrever-se nas partidas';

  @override
  String get mapSubscribedBtn => 'Inscrito nos alertas';

  @override
  String get mapSubscribeSub =>
      'Receba notificações quando uma partida for criada aqui.';

  @override
  String get mapAdminDeleteCourtBtn => 'Excluir esta quadra (Admin)';

  @override
  String get mapAdminDeleteTitle => 'Confirmar exclusão';

  @override
  String mapAdminDeleteContent(String name) {
    return 'Tem certeza de que deseja excluir a quadra \'$name\'?';
  }

  @override
  String get mapBtnCancel => 'Cancelar';

  @override
  String get mapBtnDelete => 'Excluir';

  @override
  String get mapBtnClose => 'Fechar';

  @override
  String get mapLostFoundTitle => 'Achados e Perdidos';

  @override
  String get mapLostFoundEmpty => 'Nenhum item reportado nesta quadra.';

  @override
  String get mapLostBadge => 'PERDIDO';

  @override
  String get mapFoundBadge => 'ACHADO';

  @override
  String get mapLostDeclareBtn => 'Perdi um item';

  @override
  String get mapFoundDeclareBtn => 'Item achado';

  @override
  String get mapDeclareLostTitle => 'Reportar item perdido';

  @override
  String get mapDeclareFoundTitle => 'Reportar item achado';

  @override
  String mapDeclareOnCourt(String name) {
    return 'Na quadra: $name';
  }

  @override
  String get mapDeclareSuccess => 'Anúncio publicado!';

  @override
  String get mapDeclarePublishBtn => 'Publicar anúncio';

  @override
  String get mapProposeCourtTitle => 'Propor uma Quadra';

  @override
  String get mapProposeCourtSuccess => 'Obrigado! A quadra foi adicionada.';

  @override
  String get mapProposeCourtBtn => 'Adicionar quadra';

  @override
  String get tournamentListTitle => 'Calendário Oficial';

  @override
  String tournamentListCount(int count) {
    return '$count Torneios';
  }

  @override
  String get tournamentListEmpty =>
      'Nenhum torneio encontrado para este filtro.';

  @override
  String get tournamentFilterAll => 'Todos';

  @override
  String get tournamentDetailEventDetails => 'Detalhes do Evento';

  @override
  String get tournamentDetailDates => 'Datas';

  @override
  String get tournamentDetailAddress => 'Endereço';

  @override
  String get tournamentDetailCity => 'Cidade';

  @override
  String get tournamentDetailEvents => 'Eventos';

  @override
  String get tournamentDetailBalls => 'Bolas';

  @override
  String get tournamentDetailPrice => 'Preço';

  @override
  String get tournamentDetailCategory => 'Categoria';

  @override
  String get tournamentDetailRegistration => 'Inscrição e Contato';

  @override
  String get tournamentDetailRegistrationType => 'Tipo de inscrição:';

  @override
  String get tournamentDetailReferee => 'Árbitro';

  @override
  String get profileTitle => 'Meu Perfil';

  @override
  String get profileCityUnknown => 'Cidade não definida';

  @override
  String profileLevel(int level) {
    return '🏅 NÍVEL $level · COMPETIDOR';
  }

  @override
  String profileRanking(String ranking) {
    return '🎾 Ranking Beach Tennis: $ranking';
  }

  @override
  String get profileMatchesPlayed => 'Partidas Jogadas';

  @override
  String get profileFftRanking => 'RANKING FFT';

  @override
  String get profileAdminPanelTitle => 'Painel de Administração';

  @override
  String get profileAdminPanelSub =>
      'Gerencie vídeos do YouTube e notícias ao vivo.';

  @override
  String get profileAdminPanelBtn => 'Abrir Painel 👑';

  @override
  String get profileRadarTitle => 'Radar de Torneios (Sniper)';

  @override
  String profileRadarActivated(String region) {
    return 'Radar ativado para a região: $region';
  }

  @override
  String get profileRadarError => 'Erro ao ativar o radar';

  @override
  String get profileRadarSub =>
      'Receba uma notificação push instantânea quando um torneio for anunciado em sua região para ser o primeiro a se inscrever.';

  @override
  String get profileRadarRegion => 'Região monitorada: ';

  @override
  String get profileRadarEditRegion => 'Editar região';

  @override
  String get profileRadarRegionHint => 'Digite uma cidade ou região...';

  @override
  String get profileBtnCancel => 'Cancelar';

  @override
  String get profileBtnValidate => 'Validar';

  @override
  String get profilePreferencesTitle => 'Preferências de Jogo';

  @override
  String get profilePrefPosition => 'Posição preferida';

  @override
  String get profilePrefNotSet => 'Não especificado';

  @override
  String get profilePrefAvailability => 'Disponibilidade';

  @override
  String get profileLegalTitle => 'Legal';

  @override
  String get profilePrivacy => 'Política de Privacidade';

  @override
  String get profileTerms => 'Termos de Serviço';

  @override
  String get profileAccountManagement => 'Gestão de Conta';

  @override
  String get profileLogout => 'Sair';

  @override
  String get profileDeleteAccount => 'Excluir minha conta';

  @override
  String get profileDeleteAccountConfirmTitle => 'Excluir conta';

  @override
  String get profileDeleteAccountConfirmSub =>
      'Esta ação é irreversível. Seu perfil, partidas e mensagens serão excluídos permanentemente.';

  @override
  String get profileBtnDelete => 'Excluir';

  @override
  String get rankingFirst => '1º';

  @override
  String rankingNth(int num) {
    return '$numº';
  }

  @override
  String profileEditPhotoError(String error) {
    return 'Erro de seleção: $error';
  }

  @override
  String get profileEditPhotoDeleted =>
      'Foto de perfil removida (clique em Salvar para confirmar).';

  @override
  String get profileEditPhotoTitle => 'Foto de perfil';

  @override
  String get profileEditPhotoGallery => 'Escolher da galeria';

  @override
  String get profileEditPhotoCamera => 'Tirar uma foto';

  @override
  String get profileEditPhotoRemove => 'Remover foto atual';

  @override
  String get profileEditLicenceSuccess =>
      'Licença FFT validada! Ranking atualizado.';

  @override
  String get profileEditLicenceNotFound =>
      'Licença não encontrada no ranking oficial.';

  @override
  String profileEditLicenceError(String error) {
    return 'Erro de conexão: $error';
  }

  @override
  String profileEditSaveError(String error) {
    return 'Erro: $error';
  }

  @override
  String get profileEditTitle => 'Editar Perfil';

  @override
  String get profileEditName => 'Nome e Sobrenome';

  @override
  String get profileEditLicence => 'Número da licença (Opcional)';

  @override
  String get profileEditVerifyBtn => 'Verificar';

  @override
  String get profileEditCity => 'Cidade ou Região';

  @override
  String get profileEditFft => 'Ranking FFT (ex. 3/6, Não classificado...)';

  @override
  String get profileEditLevel => 'Nível';

  @override
  String profileEditLevelBtn(int level) {
    return 'Nív. $level';
  }

  @override
  String get profileEditPosition => 'Posição preferida';

  @override
  String get profileEditPosLeft => 'Esquerda';

  @override
  String get profileEditPosRight => 'Direita';

  @override
  String get profileEditPosAny => 'Qualquer';

  @override
  String get profileEditSelect => 'Selecionar';

  @override
  String get profileEditAvailability => 'Disponibilidade';

  @override
  String get profileEditAvailEvening => 'Noites e finais de semana';

  @override
  String get profileEditAvailWeek => 'Dias de semana';

  @override
  String get profileEditAvailAll => 'Sempre';

  @override
  String get profileEditAvailVar => 'Variável';

  @override
  String get profileEditLookingForPartner => 'Procurando parceiro';

  @override
  String get profileEditLookingForPartnerSub =>
      'Apareça no Beach Tinder para encontrar um parceiro do seu nível.';

  @override
  String get profileEditSaveBtn => 'Salvar';

  @override
  String get mapDeclareLostHint =>
      'Ex: Esqueci meus óculos Oakley rosas no banco...';

  @override
  String get mapDeclareFoundHint =>
      'Ex: Encontrei uma capa MBB perto da rede 3...';
}
