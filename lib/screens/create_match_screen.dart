import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/whatsapp_share_service.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import '../models/court.dart';
import '../widgets/feature_discovery_bubble.dart';
import 'public_profile_screen.dart';

class CreateMatchScreen extends StatefulWidget {
  final UserModel? invitedPlayer;
  final CourtModel? preselectedCourt;

  const CreateMatchScreen({super.key, this.invitedPlayer, this.preselectedCourt});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  String? _selectedCourtId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _targetLevel = 3;
  int _maxPlayers = 4;
  bool _isPrivate = false;
  bool _isReiDaPraia = false;
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _pixKeyController = TextEditingController();
  final TextEditingController _courtCostController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedCourt != null) {
      _selectedCourtId = widget.preselectedCourt!.id;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _pixKeyController.dispose();
    _courtCostController.dispose();
    super.dispose();
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .trim();
  }

  bool _matchesTokens(String text, List<String> tokens) {
    if (tokens.isEmpty) return true;
    final norm = _normalize(text);
    return tokens.every((token) => norm.contains(token));
  }

  Future<void> _saveMatch() async {
    final isBrazilian = context.read<AppState>().currentUser?.isBrazilian == true;
    if (_selectedCourtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isBrazilian ? "Por favor, selecione uma quadra de Beach Tennis." : "Veuillez sélectionner un terrain de Beach Tennis.")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final scheduledTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final userEnteredDesc = _descController.text.trim();
      final finalDescription = _isReiDaPraia
          ? (userEnteredDesc.isNotEmpty ? "👑 Rei da Praia • $userEnteredDesc" : "👑 Formato Rei da Praia (4 jogadores em rodízio)")
          : userEnteredDesc;

      final matchId = await context.read<AppState>().createMatch(
        courtId: _selectedCourtId!,
        scheduledTime: scheduledTime,
        targetLevel: _targetLevel,
        maxPlayers: _maxPlayers,
        isPrivate: _isPrivate,
        description: finalDescription,
        invitedPlayerIds: widget.invitedPlayer != null ? [widget.invitedPlayer!.id] : null,
        pixKey: _pixKeyController.text.trim().isNotEmpty ? _pixKeyController.text.trim() : null,
        courtCost: double.tryParse(_courtCostController.text.trim().replaceAll(',', '.')),
      );

      if (mounted) {
        final courts = context.read<AppState>().courts;
        final selectedCourt = courts.firstWhere(
          (c) => c.id == _selectedCourtId,
          orElse: () => CourtModel(id: '', name: isBrazilian ? 'Quadra de Beach' : 'Terrain de Beach', latitude: 0, longitude: 0, isFree: true, hasLights: false, hasShowers: false),
        );
        _showSuccessDialog(matchId ?? '', selectedCourt.name, scheduledTime);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isBrazilian ? "Erro ao criar partida : $e" : "Erreur lors de la création : $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(String matchId, String courtName, DateTime matchDate) {
    final isBrazilian = context.read<AppState>().currentUser?.isBrazilian == true;
    final formattedDate = isBrazilian
        ? DateFormat("EEEE, d 'de' MMMM 'às' HH:mm", 'pt_BR').format(matchDate)
        : DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(matchDate);

    final shareText = isBrazilian
        ? "🎾 Partida de Beach Tennis !\n\n"
          "📅 $formattedDate\n"
          "📍 $courtName\n"
          "🎯 ${_isReiDaPraia ? '👑 Formato Rei da Praia (4 jogadores)' : 'Nível $_targetLevel • $_maxPlayers jogadores'}\n\n"
          "Partiu praia ? Entra pelo BeachMatch pra fechar a quadra: https://beachmatch.app/match?id=$matchId\n\n"
          "#BeachTennisBrasil #BeachMatch #PartiuPraia"
        : "🎾 Partie de Beach Tennis !\n\n"
          "📅 $formattedDate\n"
          "📍 $courtName\n"
          "🎯 ${_isReiDaPraia ? '👑 Roi de la plage (4 joueurs)' : 'Niveau $_targetLevel • $_maxPlayers joueurs max'}\n\n"
          "Rejoins la partie sur BeachMatch pour compléter le terrain : https://beachmatch.app/match?id=$matchId";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Text("🎉", style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              isBrazilian ? "Partida criada com sucesso !" : "Partie créée avec succès !",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isPrivate
                  ? (isBrazilian
                      ? "Sua partida privada está pronta. Compartilhe no WhatsApp com seus amigos para eles entrarem na quadra !"
                      : "Votre partie privée est prête. Partagez-la avec vos amis pour qu'ils puissent vous rejoindre !")
                  : (isBrazilian
                      ? "Sua partida está visível para todos os atletas da região na comunidade BeachMatch."
                      : "Votre partie est désormais visible par tous les joueurs de la région."),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008069), // WhatsApp Green
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: Text(
                isBrazilian ? "Convidar no WhatsApp" : "Partager sur WhatsApp",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () {
                WhatsAppShareService.shareToWhatsAppOrNative(text: shareText);
              },
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text(
                isBrazilian ? "Ver minhas partidas" : "Voir mes matchs",
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final courts = appState.courts;
    final isBrazilian = appState.currentUser?.isBrazilian == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isBrazilian ? "Criar uma Partida" : "Créer une partie",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background plage
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_court_aerial_1785052250131.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.78),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FeatureDiscoveryBubble(
                    featureKey: 'create_match_tip',
                    title: isBrazilian ? "Organização rápida de partidas" : "Organisation de partie simplifiée",
                    message: isBrazilian
                        ? "Digite uma cidade ou arena para encontrar a quadra. Escolha o horário, formato (Dupla ou Rei da Praia) e convide seus parceiros no WhatsApp !"
                        : "Tapez une ville ou un club pour auto-compléter le terrain. Choisissez l'heure, le format (2v2 ou 1v1) et partagez l'invitation avec vos amis !",
                    icon: Icons.sports_tennis_rounded,
                    margin: const EdgeInsets.only(bottom: 16),
                  ),

                  // Invitation spéciale
                  if (widget.invitedPlayer != null)
                    GestureDetector(
                      onTap: () => PublicProfileScreen.open(context, player: widget.invitedPlayer!),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gold, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.gold,
                              backgroundImage: (widget.invitedPlayer!.photoUrl != null && widget.invitedPlayer!.photoUrl!.isNotEmpty)
                                  ? NetworkImage(widget.invitedPlayer!.photoUrl!)
                                  : null,
                              child: (widget.invitedPlayer!.photoUrl == null || widget.invitedPlayer!.photoUrl!.isEmpty)
                                  ? Text(
                                      widget.invitedPlayer!.displayName.isNotEmpty ? widget.invitedPlayer!.displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Invitation directe pour (appuyer pour voir profil)", style: TextStyle(fontSize: 11, color: Colors.white70)),
                                  Text(
                                    widget.invitedPlayer!.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 14),
                          ],
                        ),
                      ),
                    ),

                  // 1. Choix de la Visibilité (Formule Gagnante : Publique VS Privée)
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.visibility_rounded, color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isBrazilian ? "Visibilidade da partida" : "Visibilité de la partie",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildVisibilityOption(
                                title: isBrazilian ? "Pública 🌐" : "Publique 🌐",
                                subtitle: isBrazilian ? "Aberta a todos os atletas" : "Ouverte à tous les beacheurs",
                                isSelected: !_isPrivate,
                                onTap: () => setState(() => _isPrivate = false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildVisibilityOption(
                                title: isBrazilian ? "Privada 🔒" : "Privée 🔒",
                                subtitle: isBrazilian ? "Amigos / Apenas convidados" : "Amis / Sur invitation",
                                isSelected: _isPrivate,
                                onTap: () => setState(() => _isPrivate = true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Sélection du Terrain
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppColors.coral, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isBrazilian ? "Quadra de Beach Tennis" : "Terrain de Beach Tennis",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Autocomplete<CourtModel>(
                          initialValue: widget.preselectedCourt != null
                              ? TextEditingValue(text: "${widget.preselectedCourt!.name} (${widget.preselectedCourt!.city})")
                              : null,
                          displayStringForOption: (CourtModel court) =>
                              court.id == "NEW_COURT" ? (isBrazilian ? "+ Inserir quadra manualmente" : "+ Saisir un terrain manuellement") : "${court.name} (${court.city})",
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              if (isBrazilian) {
                                final brCourts = courts.where((c) {
                                  final ctry = c.country.toLowerCase();
                                  return ctry == 'br' || ctry.contains('br') || ctry.contains('brasil') || ctry.contains('bresil');
                                }).toList();
                                if (brCourts.isNotEmpty) return brCourts.take(8);
                              }
                              return courts.take(8);
                            }
                            final tokens = _normalize(textEditingValue.text).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
                            final matches = courts.where((CourtModel court) {
                              return _matchesTokens("${court.name} ${court.city} ${court.country} ${court.description ?? ''}", tokens);
                            }).toList();

                            matches.add(CourtModel(
                              id: "NEW_COURT",
                              name: textEditingValue.text,
                              latitude: 0,
                              longitude: 0,
                              isFree: true,
                              hasLights: false,
                              hasShowers: false,
                            ));
                            return matches;
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: Colors.transparent,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width - 72,
                                      constraints: const BoxConstraints(maxHeight: 260),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16253B).withValues(alpha: 0.96),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ListView.separated(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                                        itemBuilder: (context, index) {
                                          final court = options.elementAt(index);
                                          final isNew = court.id == "NEW_COURT";
                                          return ListTile(
                                            dense: true,
                                            leading: Icon(
                                              isNew ? Icons.add_location_alt_rounded : Icons.sports_tennis_rounded,
                                              color: isNew ? AppColors.gold : AppColors.coral,
                                              size: 20,
                                            ),
                                            title: Text(
                                              isNew ? (isBrazilian ? "+ Inserir quadra manualmente" : "+ Saisir un terrain manuellement") : court.name,
                                              style: TextStyle(
                                                color: isNew ? AppColors.gold : Colors.white,
                                                fontWeight: isNew ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            subtitle: !isNew && court.city.isNotEmpty
                                                ? Text(court.city, style: const TextStyle(color: Colors.white60, fontSize: 11))
                                                : null,
                                            onTap: () => onSelected(court),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          onSelected: (CourtModel selection) async {
                            FocusScope.of(context).unfocus();
                            if (selection.id == "NEW_COURT") {
                              final appState = context.read<AppState>();
                              final currentPos = appState.currentPosition;
                              final newCourtName = await showDialog<String>(
                                context: context,
                                builder: (ctx) {
                                  String name = selection.name;
                                  return AlertDialog(
                                    backgroundColor: const Color(0xFF1E293B),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: Text(isBrazilian ? "Adicionar uma quadra" : "Ajouter un terrain", style: const TextStyle(color: Colors.white)),
                                    content: TextFormField(
                                      initialValue: name,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: isBrazilian ? "Nome ou endereço da quadra" : "Nom ou adresse du terrain",
                                        hintStyle: const TextStyle(color: Colors.white38),
                                      ),
                                      onChanged: (v) => name = v,
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isBrazilian ? "Cancelar" : "Annuler")),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
                                        onPressed: () => Navigator.pop(ctx, name),
                                        child: Text(isBrazilian ? "Adicionar" : "Ajouter", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (newCourtName != null && newCourtName.isNotEmpty) {
                                final fallbackLat = isBrazilian ? -15.7801 : 43.6961;
                                final fallbackLng = isBrazilian ? -47.9292 : 7.2717;
                                final docRef = await FirebaseFirestore.instance.collection('courts').add({
                                  "name": newCourtName,
                                  "city": isBrazilian ? "Brasil" : "Inconnue",
                                  "country": isBrazilian ? "BR" : "FR",
                                  "latitude": currentPos?.latitude ?? fallbackLat,
                                  "longitude": currentPos?.longitude ?? fallbackLng,
                                  "isFree": true,
                                  "hasLighting": false,
                                  "hasParking": false,
                                });
                                await appState.loadData();
                                if (mounted) {
                                  setState(() => _selectedCourtId = docRef.id);
                                }
                              }
                            } else {
                              setState(() => _selectedCourtId = selection.id);
                            }
                          },
                          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: isBrazilian ? "Buscar uma quadra ou arena..." : "Rechercher un terrain de plage...",
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.08),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                              ),
                            );
                          },
                        ),
                        if (_selectedCourtId != null) ...[
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final selectedCourt = courts.firstWhere(
                                (c) => c.id == _selectedCourtId,
                                orElse: () => CourtModel(id: '', name: isBrazilian ? 'Quadra selecionada' : 'Terrain sélectionné', latitude: 0, longitude: 0, isFree: true, hasLights: false, hasShowers: false),
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "${isBrazilian ? 'Quadra selecionada' : 'Terrain sélectionné'} : ${selectedCourt.name}",
                                        style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Date et Heure
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isBrazilian ? "Data & Horário da partida" : "Date & Heure du match",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (date != null) setState(() => _selectedDate = date);
                                },
                                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                                label: Text(
                                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime,
                                  );
                                  if (time != null) setState(() => _selectedTime = time);
                                },
                                icon: const Icon(Icons.access_time_rounded, size: 18),
                                label: Text(
                                  _selectedTime.format(context),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Niveau Cible & Format de jeu
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sports_tennis_rounded, color: AppColors.coral, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isBrazilian ? "Nível & Formato" : "Niveau cible & Format",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isBrazilian ? "Nível dos atletas" : "Niveau des participants",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(5, (index) => _buildLevelChip(index + 1)),
                        ),
                        Text(
                          isBrazilian ? "Número de jogadores & Formato" : "Nombre de joueurs",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPlayerCountChip(label: isBrazilian ? "Dupla (4)" : "Double (4)", count: 4),
                            _buildPlayerCountChip(
                              label: "👑 Rei da Praia (4)",
                              count: 4,
                              isReiDaPraia: true,
                            ),
                            _buildPlayerCountChip(label: isBrazilian ? "Simples (2)" : "Simple (2)", count: 2),
                            _buildPlayerCountChip(label: isBrazilian ? "8 jogadores" : "8 joueurs", count: 8),
                            _buildPlayerCountChip(label: isBrazilian ? "Personalizar" : "Personnaliser", count: _maxPlayers, isCustom: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Message / Consignes optionnelles
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notes_rounded, color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isBrazilian ? "Mensagem / Observações (Opcional)" : "Message / Consignes (Optionnel)",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: isBrazilian ? "Ex: Bolinhas inclusas, jogo descontraído..." : "Ex : Balles fournies, match amical détendu...",
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 6. Chave Pix (Réservé exclusivement au Brésil 🇧🇷)
                  if (context.watch<AppState>().currentUser?.isBrazilian == true) ...[
                    const SizedBox(height: 16),
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF32BCAD).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF32BCAD), size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Chave Pix para rateio da quadra (Opcional)",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pixKeyController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Ex: Celular, CPF ou e-mail do organizador",
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _courtCostController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Valor total da quadra em R\$ (ex: 120)",
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixText: "R\$ ",
                              prefixStyle: const TextStyle(color: Color(0xFF32BCAD), fontWeight: FontWeight.bold),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Bouton Créer
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveMatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_task_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isBrazilian ? "Criar e publicar partida" : "Publier la partie",
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.coral : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelChip(int level) {
    final isSelected = _targetLevel == level;
    final isBr = context.read<AppState>().currentUser?.isBrazilian == true;
    return GestureDetector(
      onTap: () => setState(() => _targetLevel = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.coral
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.coral
                : Colors.white.withValues(alpha: 0.25),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.coral.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          isBr ? "Nível $level" : "Niveau $level",
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCountChip({
    required String label,
    required int count,
    bool isCustom = false,
    bool isReiDaPraia = false,
  }) {
    final isSelected = isReiDaPraia
        ? _isReiDaPraia
        : (isCustom
            ? (_maxPlayers != 2 && _maxPlayers != 4 && _maxPlayers != 8 && !_isReiDaPraia)
            : (_maxPlayers == count && !_isReiDaPraia));
    final displayLabel = isCustom && isSelected ? "Perso: $_maxPlayers" : label;

    return GestureDetector(
      onTap: () {
        if (isCustom) {
          setState(() => _isReiDaPraia = false);
          _showCustomPlayerCountDialog();
        } else if (isReiDaPraia) {
          setState(() {
            _isReiDaPraia = true;
            _maxPlayers = 4;
          });
        } else {
          setState(() {
            _isReiDaPraia = false;
            _maxPlayers = count;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isReiDaPraia ? const Color(0xFFFFD700) : AppColors.coral)
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isReiDaPraia ? const Color(0xFFFFD700) : AppColors.coral)
                : Colors.white.withValues(alpha: 0.25),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isReiDaPraia ? const Color(0xFFFFD700) : AppColors.coral).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom) ...[
              Icon(Icons.tune_rounded, size: 14, color: isSelected ? Colors.white : Colors.white70),
              const SizedBox(width: 4),
            ],
            Text(
              displayLabel,
              style: TextStyle(
                color: isSelected
                    ? (isReiDaPraia ? Colors.black : Colors.white)
                    : Colors.white70,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomPlayerCountDialog() {
    int tempCount = (_maxPlayers == 2 || _maxPlayers == 4 || _maxPlayers == 8) ? 6 : _maxPlayers;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.coral),
                SizedBox(width: 8),
                Text("Nombre de joueurs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$tempCount joueurs",
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 26),
                ),
                const SizedBox(height: 12),
                Slider(
                  value: tempCount.toDouble(),
                  min: 2,
                  max: 16,
                  divisions: 14,
                  activeColor: AppColors.coral,
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    setDialogState(() => tempCount = val.round());
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
                onPressed: () {
                  setState(() => _maxPlayers = tempCount);
                  Navigator.pop(ctx);
                },
                child: const Text("Valider", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
