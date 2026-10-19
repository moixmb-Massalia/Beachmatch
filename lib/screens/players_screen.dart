import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import 'chat_detail_screen.dart';
import 'public_profile_screen.dart';
import 'create_match_screen.dart';
import 'package:flutter/services.dart';
import '../services/whatsapp_share_service.dart';

class PlayersScreen extends StatefulWidget {
  final bool isEmbedded;

  const PlayersScreen({super.key, this.isEmbedded = false});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  String _selectedLevelFilter = "ALL";

  @override
  Widget build(BuildContext context) {
    final query = context.watch<AppState>().playerSearchQuery;
    final allPlayers = context.watch<AppState>().players;
    final currentUser = context.watch<AppState>().currentUser;
    final fftResults = context.watch<AppState>().fftSearchResults;
    final isSearching = context.watch<AppState>().isSearchingFFT;

    final myFriends = currentUser != null 
        ? allPlayers.where((p) => currentUser.friendsIds.contains(p.id)).toList()
        : [];

    String norm(String s) {
      return s.toLowerCase()
          .replaceAll(RegExp(r'[éèêë]'), 'e')
          .replaceAll(RegExp(r'[àâä]'), 'a')
          .replaceAll(RegExp(r'[îï]'), 'i')
          .replaceAll(RegExp(r'[ôö]'), 'o')
          .replaceAll(RegExp(r'[ùûü]'), 'u')
          .replaceAll(RegExp(r'[ç]'), 'c')
          .trim();
    }

    final filteredLocalPlayers = allPlayers.where((p) {
      if (currentUser != null && currentUser.id == p.id) {
        return false;
      }
      final q = query.trim();
      if (q.isEmpty) {
        if (_selectedLevelFilter == "LOOKING" || _selectedLevelFilter == "⚡ Cherchent binôme") {
          if (!p.isLookingForPartner) return false;
        } else if (_selectedLevelFilter == "FRIENDS" || _selectedLevelFilter == "Mes amis") {
          return currentUser != null && currentUser.friendsIds.contains(p.id);
        } else if (_selectedLevelFilter == "LVL_1_3" || _selectedLevelFilter == "Niveau 1-3") {
          if (p.level < 1 || p.level > 3) return false;
        } else if (_selectedLevelFilter == "LVL_4_6" || _selectedLevelFilter == "Niveau 4-6") {
          if (p.level < 4 || p.level > 6) return false;
        } else if (_selectedLevelFilter == "LVL_7_PLUS" || _selectedLevelFilter == "Niveau 7+") {
          if (p.level < 7) return false;
        }
        if (currentUser != null && currentUser.friendsIds.contains(p.id) && (_selectedLevelFilter == "ALL" || _selectedLevelFilter == "Tous")) {
          return false;
        }
        return true;
      }
      final nq = norm(q);
      final tokens = nq.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (tokens.isEmpty) return true;

      final pName = norm(p.displayName);
      final pLic = p.licenceNumber != null ? norm(p.licenceNumber!) : '';
      final pLoc = norm(p.location);

      return tokens.every((tok) =>
          pName.contains(tok) ||
          pLic.contains(tok) ||
          pLoc.contains(tok));
    }).toList();

    final isBr = currentUser?.isBrazilian == true;
    final levelFilters = isBr
        ? [
            {'id': 'ALL', 'label': 'Todos'},
            {'id': 'LOOKING', 'label': '⚡ Procurando dupla'},
            {'id': 'LVL_1_3', 'label': 'Nível 1-3'},
            {'id': 'LVL_4_6', 'label': 'Nível 4-6'},
            {'id': 'LVL_7_PLUS', 'label': 'Nível 7+'},
            {'id': 'FRIENDS', 'label': 'Meus amigos'},
          ]
        : [
            {'id': 'ALL', 'label': 'Tous'},
            {'id': 'LOOKING', 'label': '⚡ Cherchent binôme'},
            {'id': 'LVL_1_3', 'label': 'Niveau 1-3'},
            {'id': 'LVL_4_6', 'label': 'Niveau 4-6'},
            {'id': 'LVL_7_PLUS', 'label': 'Niveau 7+'},
            {'id': 'FRIENDS', 'label': 'Mes amis'},
          ];

    final lookingForPartnerPlayers = allPlayers
        .where((p) => p.isLookingForPartner && (currentUser == null || p.id != currentUser.id))
        .toList();

    final mainContent = Column(
      children: [
        if (!widget.isEmbedded)
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.sports_tennis, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isBr ? "Encontrar parceiro(a)" : "Trouver un partenaire", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                    Text(
                      query.isEmpty 
                          ? (isBr ? "${allPlayers.length} atletas cadastrados" : "${allPlayers.length} membres inscrits")
                          : (isBr ? "${filteredLocalPlayers.length} atletas encontrados" : "${filteredLocalPlayers.length} membres · ${fftResults.length} résultats FFT"), 
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Search Bar Glass
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    FocusScope.of(context).unfocus();
                  },
                  onChanged: (val) => context.read<AppState>().updatePlayerSearch(val),
                  decoration: InputDecoration(
                    hintText: isBr ? "Nome, sobrenome ou cidade..." : "Nom, prénom ou n° licence (ex: 4008757)...",
                    hintStyle: const TextStyle(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.normal),
                    prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                    suffixIcon: isSearching 
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
                          )
                        : (query.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white70),
                                onPressed: () => context.read<AppState>().updatePlayerSearch(""),
                              )
                            : null),
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Level Filter Chips with Haptics
        if (query.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: levelFilters.map((filterItem) {
                  final filterId = filterItem['id']!;
                  final filterLabel = filterItem['label']!;
                  final isSelected = _selectedLevelFilter == filterId || _selectedLevelFilter == filterLabel;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        filterLabel,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedLevelFilter = filterId);
                        }
                      },
                      backgroundColor: Colors.black.withValues(alpha: 0.60),
                      selectedColor: filterId == 'LOOKING' ? AppColors.coral : AppColors.gold,
                      side: BorderSide(
                        color: isSelected 
                            ? (filterId == 'LOOKING' ? AppColors.coral : AppColors.gold)
                            : Colors.white.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        // Main Dynamic Scrollable List with Pull-to-refresh
        Expanded(
          child: RefreshIndicator(
            color: AppColors.coral,
            backgroundColor: const Color(0xFF1E2638),
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await context.read<AppState>().loadData();
            },
            child: (query.isNotEmpty && filteredLocalPlayers.isEmpty && fftResults.isEmpty && !isSearching)
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 60, color: Colors.white60),
                            const SizedBox(height: 16),
                            Text(
                              isBr ? "Nenhum atleta encontrado" : "Aucun joueur trouvé",
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isBr ? "Tente outro nome ou cidade" : "Essayez un autre nom ou n° licence",
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      // Mon statut de recherche personnel
                      if (query.isEmpty && currentUser != null) ...[
                        _buildMyPartnerStatusCard(context, currentUser),
                        const SizedBox(height: 12),
                      ],

                      // Carrousel des Joueurs en recherche active
                      if (query.isEmpty && (_selectedLevelFilter == "ALL" || _selectedLevelFilter == "Tous")) ...[
                        _buildLookingForPartnerCarousel(context, lookingForPartnerPlayers),
                      ],

                      // Friends Section
                      if (query.isEmpty && (_selectedLevelFilter == "ALL" || _selectedLevelFilter == "Tous" || _selectedLevelFilter == "FRIENDS" || _selectedLevelFilter == "Mes amis") && myFriends.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Text(
                            isBr ? "MEUS AMIGOS (${myFriends.length})" : "MES AMIS (${myFriends.length})",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.coral, letterSpacing: 1.1),
                          ),
                        ),
                        ...myFriends.map((p) => _buildLocalPlayerCard(context, p, isFriend: true)),
                        const SizedBox(height: 16),
                      ],

                      // Local Registered Players Section
                      if (filteredLocalPlayers.isNotEmpty && _selectedLevelFilter != "FRIENDS" && _selectedLevelFilter != "Mes amis") ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Text(
                            query.isEmpty 
                                ? (isBr ? "COMUNIDADE BEACHMATCH (${filteredLocalPlayers.length})" : "COMMUNAUTÉ BEACHMATCH (${filteredLocalPlayers.length})") 
                                : (isBr ? "ATLETAS DO APP" : "MEMBRES DE L'APPLICATION"),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: 1.1),
                          ),
                        ),
                        ...filteredLocalPlayers.map((p) => _buildLocalPlayerCard(context, p, isFriend: currentUser?.friendsIds.contains(p.id) ?? false)),
                        const SizedBox(height: 16),
                      ],

                      // Official FFT Ranking Database Results Section (France Only)
                      if (fftResults.isNotEmpty && !isBr) ...[
                        Row(
                          children: [
                            const Text("CLASSEMENT OFFICIEL FFT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 1.1)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: Text("${fftResults.length}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...fftResults.map((p) => _buildFFTPlayerCard(context, p)),
                      ],

                      const SizedBox(height: 100), // Bottom space
                    ],
                  ),
                ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return mainContent;
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          SafeArea(
            child: mainContent,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLocalPlayerCard(BuildContext context, UserModel player, {bool isFriend = false}) {
    final String initial = player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : "?";
    final isBr = player.isBrazilian || (context.read<AppState>().currentUser?.isBrazilian ?? false);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PublicProfileScreen(player: player)),
        );
      },
      child: _buildGlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.displayName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (player.isLookingForPartner) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.greenAccent, width: 1),
                            ),
                            child: Text(isBr ? "🟢 Disponível" : "🟢 Dispo", style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(isBr ? "Nível ${player.level} · ${player.location}" : "Niv. ${player.level} · ${player.location}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: (player.ranking != null && player.ranking!.isNotEmpty && player.ranking != 'NC')
                                ? AppColors.gold.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (player.ranking != null && player.ranking!.isNotEmpty && player.ranking != 'NC')
                                  ? AppColors.gold
                                  : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            (player.ranking != null && player.ranking!.isNotEmpty && player.ranking != 'NC')
                                ? (isBr ? "🏅 Ranking : Nº ${player.ranking}" : "🏅 Clt Ten'Up : N° ${player.ranking}")
                                : (isBr ? "🏅 Sem ranking (NC)" : "🏅 Clt : Non classé (NC)"),
                            style: TextStyle(
                              color: (player.ranking != null && player.ranking!.isNotEmpty && player.ranking != 'NC')
                                  ? AppColors.gold
                                  : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Message Button
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatDetailScreen(otherUser: player)),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                tooltip: isBr ? "Enviar mensagem" : "Envoyer un message",
              ),
              // Add/Remove Friend Button
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (isFriend) {
                    context.read<AppState>().removeFriend(player.id);
                  } else {
                    context.read<AppState>().addFriend(player.id);
                  }
                },
                icon: Icon(isFriend ? Icons.person_remove : Icons.person_add, color: isFriend ? Colors.redAccent : AppColors.gold),
                tooltip: isFriend ? (isBr ? "Remover dos amigos" : "Retirer de mes amis") : (isBr ? "Adicionar aos amigos" : "Ajouter aux amis"),
              ),
              // Invite to Play Button
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateMatchScreen(invitedPlayer: player)),
                  );
                },
                icon: const Icon(Icons.sports_tennis, size: 16),
                label: Text(isBr ? "Convidar" : "Inviter", style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildFFTPlayerCard(BuildContext context, Map<String, dynamic> player) {
    final String firstName = player['firstName'] ?? '';
    final String lastName = player['lastName'] ?? '';
    final String fullName = "$firstName $lastName".trim();
    final String initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : "F";
    final String licence = player['licenceNumber'] ?? '';
    final String level = player['level']?.toString() ?? '-';
    final String club = player['club'] ?? '';
    
    // We add the action row below the row
    return Builder(
      builder: (context) {
        final allAppPlayers = context.watch<AppState>().players;
        UserModel? registeredMember;
        for (final p in allAppPlayers) {
          if ((p.licenceNumber != null && p.licenceNumber!.isNotEmpty && licence.isNotEmpty && p.licenceNumber!.contains(licence)) ||
              p.displayName.trim().toLowerCase() == fullName.toLowerCase()) {
            registeredMember = p;
            break;
          }
        }

        return GestureDetector(
          onTap: () {
            PublicProfileScreen.open(
              context,
              player: registeredMember,
              userId: licence.isNotEmpty ? licence : fullName,
              displayName: fullName,
              ranking: level,
              location: club,
            );
          },
          child: _buildGlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.greenAccent, width: 1.5),
                      ),
                      child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fullName, 
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                                child: const Text("FFT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("Licence: $licence · Clt: $level", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          if (club.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(club, style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Actions
                if (registeredMember != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          PublicProfileScreen.open(context, player: registeredMember);
                        },
                        icon: const Icon(Icons.person, size: 14),
                        label: const Text("Membre actif · Voir profil", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          PublicProfileScreen.open(
                            context,
                            userId: licence.isNotEmpty ? licence : fullName,
                            displayName: fullName,
                            ranking: level,
                            location: club,
                          );
                        },
                        icon: const Icon(Icons.badge_rounded, size: 14, color: AppColors.gold),
                        label: const Text("Fiche profil", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.gold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          WhatsAppShareService.shareToWhatsAppOrNative(
                            text: "Salut $fullName ! Viens me rejoindre sur l'application BeachMatch pour trouver des partenaires de Beach Tennis et participer aux tournois : https://beachmatch.app/download",
                          );
                        },
                        icon: const Icon(Icons.share, size: 14),
                        label: const Text("Inviter sur BeachMatch", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLookingForPartnerCarousel(BuildContext context, List<UserModel> lookingPlayers) {
    if (lookingPlayers.isEmpty) return const SizedBox.shrink();
    final isBr = context.read<AppState>().currentUser?.isBrazilian ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent,
                  boxShadow: [
                    BoxShadow(color: Colors.greenAccent, blurRadius: 6, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isBr ? "DISPONÍVEIS PARA JOGAR" : "DISPONIBLES POUR JOUER",
                style: const TextStyle(
                  color: AppColors.coral,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${lookingPlayers.length}",
                  style: const TextStyle(color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: lookingPlayers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final player = lookingPlayers[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  PublicProfileScreen.open(context, player: player);
                },
                child: Container(
                  width: 118,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.coral.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.coral,
                            backgroundImage: (player.photoUrl != null && player.photoUrl!.isNotEmpty)
                                ? NetworkImage(player.photoUrl!)
                                : null,
                            child: (player.photoUrl == null || player.photoUrl!.isEmpty)
                                ? Text(
                                    player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : "?",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.greenAccent,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        player.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isBr ? "Nível ${player.level}" : "Niv. ${player.level}",
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMyPartnerStatusCard(BuildContext context, UserModel currentUser) {
    final bool isLooking = currentUser.isLookingForPartner;
    final bool isBr = currentUser.isBrazilian;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLooking
                  ? [AppColors.coral.withValues(alpha: 0.35), AppColors.gold.withValues(alpha: 0.25)]
                  : [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLooking ? AppColors.coral : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLooking ? AppColors.coral : Colors.white12,
                ),
                child: Icon(
                  isLooking ? Icons.handshake_rounded : Icons.pause_circle_outline_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isBr ? "Meu status de busca" : "Mon statut de recherche",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLooking ? Colors.greenAccent : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLooking
                          ? (isBr ? "Ativo · Seu perfil aparece nesta lista" : "Actif · Votre profil apparaît dans cette liste")
                          : (isBr ? "Pausado · Ative para receber convites" : "En pause · Activez pour recevoir des invitations"),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: isLooking,
                activeTrackColor: AppColors.coral,
                onChanged: (val) {
                  context.read<AppState>().toggleLookingForPartner();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
