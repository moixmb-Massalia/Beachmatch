import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import 'chat_detail_screen.dart';
import 'public_profile_screen.dart';
import 'create_match_screen.dart';
import 'package:share_plus/share_plus.dart';
class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  int _selectedTabIndex = 0;

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
      final q = query.trim();
      if (q.isEmpty) {
        if (currentUser != null && currentUser.friendsIds.contains(p.id)) {
          return false;
        }
        return true;
      }
      final nq = norm(q);
      final nameMatches = norm(p.displayName).contains(nq);
      final licMatches = p.licenceNumber != null && norm(p.licenceNumber!).contains(nq);
      final locMatches = norm(p.location).contains(nq);
      return nameMatches || licMatches || locMatches;
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
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
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
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
                      color: Colors.white.withOpacity(0.1),
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
                      : Scrollbar(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            children: [
                              // Friends Section (Only when no search query)
                              if (query.isEmpty && myFriends.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
                                  child: Text("MES AMIS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.coral, letterSpacing: 1.1)),
                                ),
                                ...myFriends.map((p) => _buildLocalPlayerCard(context, p, isFriend: true)),
                                const SizedBox(height: 16),
                              ],

                              // Local Registered Players Section
                              if (filteredLocalPlayers.isNotEmpty) ...[
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
                                    decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
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
                const SizedBox(height: 80), // Navigation spacing
              ],
            ),
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
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
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
                                ? AppColors.gold.withOpacity(0.2)
                                : Colors.white.withOpacity(0.08),
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
                  color: Colors.greenAccent.withOpacity(0.2),
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
                      Share.share(
                        "Salut $fullName ! Viens me rejoindre sur l'application BeachMatch pour trouver des partenaires de Beach Tennis et participer aux tournois : https://beachmatch.app/download",
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

    if (lookingForPartnerPlayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_off, size: 60, color: Colors.white60),
            const SizedBox(height: 16),
            const Text("Aucun joueur disponible", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Revenez plus tard !", style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: lookingForPartnerPlayers.length,
      itemBuilder: (context, index) {
        final player = lookingForPartnerPlayers[index];
        bool isFriend = currentUser.friendsIds.contains(player.id);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.coral.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.coral,
                backgroundImage: player.photoUrl != null ? NetworkImage(player.photoUrl!) : null,
                child: player.photoUrl == null ? Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text("Niveau ${player.level} • ${player.location}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    if (player.eloScore > 0)
                      Text("${player.eloScore} pts FFT", style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (!isFriend)
                ElevatedButton(
                  onPressed: () {
                    context.read<AppState>().addFriend(player.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text("Inviter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  ),
                  icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 16),
                  label: const Text("Message", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );
      },
    );
  }
}
