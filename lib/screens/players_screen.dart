import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import 'chat_detail_screen.dart';
import 'public_profile_screen.dart';
import 'create_match_screen.dart';
import 'fft_rankings_screen.dart';
import 'package:share_plus/share_plus.dart';

class PlayersScreen extends StatefulWidget {
  final bool isEmbedded;

  const PlayersScreen({super.key, this.isEmbedded = false});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  int _selectedTabIndex = 0;
  String _selectedLevelFilter = "Tous";

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
        if (_selectedLevelFilter == "Mes amis") {
          return currentUser != null && currentUser.friendsIds.contains(p.id);
        } else if (_selectedLevelFilter == "Niveau 1-3") {
          if (p.level < 1 || p.level > 3) return false;
        } else if (_selectedLevelFilter == "Niveau 4-6") {
          if (p.level < 4 || p.level > 6) return false;
        } else if (_selectedLevelFilter == "Niveau 7+") {
          if (p.level < 7) return false;
        }
        if (currentUser != null && currentUser.friendsIds.contains(p.id)) {
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
                    const Text("Trouver un partenaire", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                    Text(
                      query.isEmpty 
                          ? "${allPlayers.length} membres inscrits" 
                          : "${filteredLocalPlayers.length} membres · ${fftResults.length} résultats FFT", 
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

                // Search Bar Glass (Only show in first tab)
                if (_selectedTabIndex == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: TextField(
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) {
                              FocusScope.of(context).unfocus();
                            },
                            onChanged: (val) => context.read<AppState>().updatePlayerSearch(val),
                            decoration: InputDecoration(
                              hintText: "Nom, prénom ou n° licence (ex: 4008757)...",
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

                // Custom Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTabIndex = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 0 ? AppColors.gold : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text("Tous les joueurs", style: TextStyle(color: _selectedTabIndex == 0 ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTabIndex = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 1 ? AppColors.coral : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.handshake, size: 16, color: _selectedTabIndex == 1 ? Colors.white : Colors.white70),
                                  const SizedBox(width: 6),
                                  Text("Recherche Partenaire", style: TextStyle(color: _selectedTabIndex == 1 ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Level Filter Chips (Only show in first tab when not searching)
                if (_selectedTabIndex == 0 && query.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ["Tous", "Niveau 1-3", "Niveau 4-6", "Niveau 7+", "Mes amis"].map((filter) {
                          final isSelected = _selectedLevelFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedLevelFilter = filter);
                                }
                              },
                              selectedColor: AppColors.gold,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                Expanded(
                  child: _selectedTabIndex == 1 
                      ? _buildPartnerFinder(context, allPlayers, currentUser)
                      : (query.isNotEmpty && filteredLocalPlayers.isEmpty && fftResults.isEmpty && !isSearching)
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 60, color: Colors.white60),
                              SizedBox(height: 16),
                              Text("Aucun joueur trouvé", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text("Essayez un autre nom", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.coral,
                          backgroundColor: const Color(0xFF1E2638),
                          onRefresh: () async {
                            await context.read<AppState>().loadData();
                          },
                          child: Scrollbar(
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              children: [
                                // FFT Rankings Banner (Opens FftRankingsScreen)
                                if (query.isEmpty) ...[
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FftRankingsScreen()));
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 24),
                                          ),
                                          const SizedBox(width: 14),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Classement Officiel FFT",
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  "Consulter le Top 200 Hommes & Dames",
                                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                // Friends Section (Only when no search query and when filter allows)
                                if (query.isEmpty && (_selectedLevelFilter == "Tous" || _selectedLevelFilter == "Mes amis") && myFriends.isNotEmpty) ...[
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
                                    child: Text("MES AMIS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.coral, letterSpacing: 1.1)),
                                  ),
                                  ...myFriends.map((p) => _buildLocalPlayerCard(context, p, isFriend: true)),
                                  const SizedBox(height: 16),
                                ],

                                // Local Registered Players Section
                                if (filteredLocalPlayers.isNotEmpty && _selectedLevelFilter != "Mes amis") ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                                    child: Text(query.isEmpty ? "AUTRES JOUEURS" : "MEMBRES DE L'APPLICATION", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: 1.1)),
                                  ),
                                  ...filteredLocalPlayers.map((p) => _buildLocalPlayerCard(context, p, isFriend: currentUser?.friendsIds.contains(p.id) ?? false)),
                                  const SizedBox(height: 16),
                                ],

                            // Official FFT Ranking Database Results Section
                            if (fftResults.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Text("CLASSEMENT OFFICIEL FFT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 1.1)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                                    child: Text("${fftResults.length}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...fftResults.map((p) => _buildFFTPlayerCard(context, p)),
                            ],
                          ],
                        ),
                      ),
                    ),
                ),
                const SizedBox(height: 80), // Navigation spacing
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
                    Text(player.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text("Niv. ${player.level} · ${player.location}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                                ? "🏅 Clt Ten'Up : N° ${player.ranking}"
                                : "🏅 Clt : Non classé (NC)",
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
              Column(
                children: [
                  Text("${player.eloScore}", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 18)),
                  const Text("POINTS", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatDetailScreen(otherUser: player)),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                tooltip: "Envoyer un message",
              ),
              // Add/Remove Friend Button
              IconButton(
                onPressed: () {
                  if (isFriend) {
                    context.read<AppState>().removeFriend(player.id);
                  } else {
                    context.read<AppState>().addFriend(player.id);
                  }
                },
                icon: Icon(isFriend ? Icons.person_remove : Icons.person_add, color: isFriend ? Colors.redAccent : AppColors.gold),
                tooltip: isFriend ? "Retirer de mes amis" : "Ajouter aux amis",
              ),
              // Invite to Play Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateMatchScreen(invitedPlayer: player)),
                  );
                },
                icon: const Icon(Icons.sports_tennis, size: 16),
                label: const Text("Inviter", style: TextStyle(fontWeight: FontWeight.bold)),
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
    final String elo = player['elo']?.toString() ?? '-';
    final String club = player['club'] ?? '';
    
    // We add the action row below the row
    return _buildGlassCard(
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
              Column(
                children: [
                  Text(elo, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 18)),
                  const Text("Pts", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Actions
          Builder(
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

              if (registeredMember != null) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(player: registeredMember!)));
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
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      SharePlus.instance.share(ShareParams(
                        text: "Salut $fullName ! Viens me rejoindre sur l'application BeachMatch pour trouver des partenaires de Beach Tennis et participer aux tournois : https://beachmatch.app/download",
                      ));
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerFinder(BuildContext context, List<UserModel> allPlayers, UserModel? currentUser) {
    if (currentUser == null) {
      return const Center(
        child: Text("Connectez-vous pour utiliser la Recherche de Partenaire", style: TextStyle(color: Colors.white)),
      );
    }

    final lookingForPartnerPlayers = allPlayers.where((p) => p.isLookingForPartner && p.id != currentUser.id).toList();

    return RefreshIndicator(
      color: AppColors.coral,
      backgroundColor: const Color(0xFF1E2638),
      onRefresh: () async {
        await context.read<AppState>().loadData();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          _buildMyPartnerStatusCard(context, currentUser),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                const Text(
                  "JOUEURS QUI RECHERCHENT UN PARTENAIRE",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.coral, letterSpacing: 1.1),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text("${lookingForPartnerPlayers.length}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.coral)),
                ),
              ],
            ),
          ),
          if (lookingForPartnerPlayers.isEmpty)
            _buildGlassCard(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: const Column(
                children: [
                  Icon(Icons.people_outline_rounded, size: 48, color: Colors.white54),
                  SizedBox(height: 12),
                  Text(
                    "Aucun autre joueur disponible actuellement",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Votre profil est visible par la communauté si votre statut est activé. Revenez régulièrement !",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                  ),
                ],
              ),
            )
          else
            ...lookingForPartnerPlayers.map((player) => _buildPartnerPlayerCard(context, player, currentUser)),
        ],
      ),
    );
  }

  Widget _buildMyPartnerStatusCard(BuildContext context, UserModel currentUser) {
    final bool isLooking = currentUser.isLookingForPartner;

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
                        const Text(
                          "Mon statut de recherche",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
                          ? "Actif · Votre profil apparaît dans cette liste"
                          : "En pause · Activez pour recevoir des invitations",
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

  Widget _buildPartnerPlayerCard(BuildContext context, UserModel player, UserModel currentUser) {
    bool isFriend = currentUser.friendsIds.contains(player.id);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(player: player)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.coral,
              backgroundImage: (player.photoUrl != null && player.photoUrl!.isNotEmpty) ? NetworkImage(player.photoUrl!) : null,
              child: (player.photoUrl == null || player.photoUrl!.isEmpty)
                  ? Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text("Niveau ${player.level} • ${player.location.isNotEmpty ? player.location : 'France'}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  if (player.eloScore > 0)
                    Text("${player.eloScore} pts FFT", style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isFriend)
              ElevatedButton(
                onPressed: () {
                  context.read<AppState>().addFriend(player.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                ),
                child: const Text("Inviter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(otherUser: player),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 14),
                label: const Text("Message", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
