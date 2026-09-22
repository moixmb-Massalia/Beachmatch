import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';
import '../services/whatsapp_share_service.dart';
import '../providers/app_state.dart';
import '../models/match.dart';
import '../models/user.dart';
import '../models/court.dart';
import '../screens/public_profile_screen.dart';
import 'beach_weather_widget.dart';
import '../l10n/app_localizations.dart';

/// Carte de match affichée sur l'écran d'accueil avec détails, inscription et partage SOS
class HomeMatchCard extends StatelessWidget {
  final UserModel? user;
  final MatchModel match;
  final List<CourtModel> courts;

  const HomeMatchCard({
    super.key,
    required this.user,
    required this.match,
    required this.courts,
  });

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 24}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int courtIdx = courts.indexWhere((c) => c.id == match.courtId);
    final court = courtIdx != -1 ? courts[courtIdx] : null;
    final courtName = court?.name ?? "Terrain Beach Tennis";
    final timeFormatted = DateFormat('dd MMM à HH:mm').format(match.scheduledTime);
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showMatchDetailsBottomSheet(context, user, match, court),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sports_tennis, color: Colors.white, size: 10),
                        const SizedBox(width: 4),
                        Text(AppLocalizations.of(context).homeMatchOnSand, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(AppLocalizations.of(context).homeMatchPlayersInfo(match.participantsIds.length, match.maxPlayers), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(courtName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.access_time_filled, color: Colors.white70, size: 12),
                  const SizedBox(width: 6),
                  Text(timeFormatted, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context).homeMatchRequiredLevel(match.targetLevel), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  _buildMatchButton(context, user, match),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppLocalizations.of(context).homeMatchTapDetails, style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.touch_app, color: AppColors.gold, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchButton(BuildContext context, UserModel? user, MatchModel match) {
    if (user == null) return const SizedBox();
    
    final bool isParticipating = match.participantsIds.contains(user.id);
    final bool isHost = match.hostId == user.id;
    final bool isFull = match.participantsIds.length >= match.maxPlayers;
    
    if (isParticipating) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHost && match.participantsIds.length > 1)
            IconButton(
              icon: const Icon(Icons.manage_accounts, color: Colors.white),
              onPressed: () => _showManagePlayersDialog(context, match),
              tooltip: AppLocalizations.of(context).homeMatchManageTooltip,
            ),
          if (!isFull)
            IconButton(
              onPressed: () {
                final dateStr = DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(match.scheduledTime);
                final courtIdx = courts.indexWhere((c) => c.id == match.courtId);
                final courtName = courtIdx != -1 ? courts[courtIdx].name : "Terrain Beach Tennis";
                WhatsAppShareService.shareMatchSOS(
                  matchDate: dateStr,
                  courtName: courtName,
                  targetLevel: match.targetLevel,
                  currentPlayers: match.participantsIds.length,
                  maxPlayers: match.maxPlayers,
                  matchId: match.id,
                );
              },
              icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 22),
              tooltip: "Partager sur WhatsApp (SOS Joueur)",
            ),
          if (!isFull) const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (isHost) {
                _showCancelMatchDialog(context, match.id);
              } else {
                context.read<AppState>().leaveMatch(match.id);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isHost ? Colors.redAccent.withValues(alpha: 0.8) : Colors.white24,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(isHost ? AppLocalizations.of(context).homeMatchCancel : AppLocalizations.of(context).homeMatchQuit, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }
    
    if (isFull) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.withValues(alpha: 0.5),
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(AppLocalizations.of(context).homeMatchFull, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      );
    }
    
    final bool isJoining = context.select<AppState, bool>((s) => s.isJoiningMatch);
    
    return ElevatedButton(
      onPressed: isJoining ? null : () {
        context.read<AppState>().joinMatch(match.id);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      child: isJoining 
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(AppLocalizations.of(context).homeMatchJoin, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  void _showCancelMatchDialog(BuildContext context, String matchId) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context).homeDialogCancelTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).homeDialogCancelContent,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(AppLocalizations.of(context).homeDialogNoKeep, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await context.read<AppState>().cancelMatch(matchId);
                          },
                          child: Text(AppLocalizations.of(context).homeDialogYesCancel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showManagePlayersDialog(BuildContext context, MatchModel match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final players = context.watch<AppState>().players;
        final participantIds = match.participantsIds.where((id) => id != match.hostId).toList();

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).homeManagePlayersTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 16),
              if (participantIds.isEmpty)
                Text(AppLocalizations.of(context).homeManagePlayersEmpty, style: const TextStyle(color: Colors.white70)),
              ...participantIds.map((id) {
                final pIdx = players.indexWhere((p) => p.id == id);
                if (pIdx != -1) {
                  return _buildManagePlayerTile(ctx, context, match, players[pIdx]);
                }
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(id).get(),
                  builder: (context, snapshot) {
                    UserModel p;
                    if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
                      p = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>, id);
                    } else {
                      p = UserModel(
                        id: id,
                        displayName: "Joueur",
                        level: match.targetLevel,
                        eloScore: 0,
                        location: "",
                        isPremium: false,
                        createdAt: DateTime.now(),
                      );
                    }
                    return _buildManagePlayerTile(ctx, context, match, p);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildManagePlayerTile(BuildContext modalCtx, BuildContext parentContext, MatchModel match, UserModel p) {
    return ListTile(
      onTap: () {
        Navigator.pop(modalCtx);
        PublicProfileScreen.open(parentContext, player: p);
      },
      leading: CircleAvatar(
        backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty) ? NetworkImage(p.photoUrl!) : null,
        backgroundColor: AppColors.coral,
        child: (p.photoUrl == null || p.photoUrl!.isEmpty) ? Text(p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white)) : null,
      ),
      title: Text(p.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(AppLocalizations.of(parentContext).homeHeaderLevel(p.level), style: const TextStyle(color: AppColors.gold)),
      trailing: IconButton(
        icon: const Icon(Icons.person_remove, color: Colors.redAccent),
        onPressed: () {
          parentContext.read<AppState>().kickPlayer(match.id, p.id);
          Navigator.pop(modalCtx);
          ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text(AppLocalizations.of(parentContext).homeManagePlayersRemoved(p.displayName))));
        },
      ),
    );
  }

  static Widget _buildDetailBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showMatchDetailsBottomSheet(BuildContext context, UserModel? user, MatchModel match, CourtModel? court) {
    final timeFormatted = DateFormat('EEEE dd MMM à HH:mm', 'fr_FR').format(match.scheduledTime);
    final courtName = court?.name ?? "Terrain Beach Tennis";
    final isParticipating = match.participantsIds.contains(user?.id);
    final isHost = match.hostId == user?.id;
    final isFull = match.participantsIds.length >= match.maxPlayers;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            image: DecorationImage(
              image: ResizeImage(AssetImage('assets/images/beach_sunset_players_1785052273648.jpg'), width: 1080),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(20)),
                        child: Text(AppLocalizations.of(context).homeMatchOnSand, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(height: 16),
                      Text(courtName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: AppColors.gold, size: 20),
                          const SizedBox(width: 8),
                          Text(timeFormatted, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.gold, size: 20),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context).homeMatchDetailsRequiredLevel(match.targetLevel), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (court != null)
                        BeachWeatherWidget(
                          latitude: court.latitude,
                          longitude: court.longitude,
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _buildDetailBadge(Icons.pool, "Sable chaud"),
                          const SizedBox(width: 8),
                          _buildDetailBadge(Icons.sports_baseball, "Balles fournies"),
                          const SizedBox(width: 8),
                          _buildDetailBadge(Icons.verified, "Terrain officiel"),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(AppLocalizations.of(context).homeMatchDetailsPlayersRegistered(match.participantsIds.length, match.maxPlayers), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final allPlayers = context.watch<AppState>().players;
                          final currentUser = context.watch<AppState>().currentUser;

                          return Column(
                            children: match.participantsIds.map<Widget>((id) {
                              final isHost = id == match.hostId;
                              UserModel? known;
                              if (currentUser != null && currentUser.id == id) {
                                known = currentUser;
                              } else {
                                final idx = allPlayers.indexWhere((p) => p.id == id);
                                if (idx != -1) known = allPlayers[idx];
                              }

                              return _buildParticipantTile(context, id, isHost, match.targetLevel, known);
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isParticipating)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                if (isHost) {
                                  _showCancelMatchDialog(context, match.id);
                                } else {
                                  context.read<AppState>().leaveMatch(match.id);
                                }
                              },
                              child: Text(isHost ? AppLocalizations.of(context).homeMatchDetailsCancelGame : AppLocalizations.of(context).homeMatchDetailsQuitGame, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                        else if (!isFull)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.read<AppState>().joinMatch(match.id);
                              },
                              child: Text(AppLocalizations.of(context).homeMatchDetailsJoinGame, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                        else
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Text(AppLocalizations.of(context).homeMatchDetailsFull, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildParticipantTile(BuildContext context, String playerId, bool isHost, int matchLevel, UserModel? knownUser) {
    if (knownUser != null) {
      return _buildParticipantRow(context, knownUser, isHost);
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(playerId).get(),
      builder: (context, snapshot) {
        UserModel user;
        if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
          user = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>, playerId);
        } else {
          user = UserModel(
            id: playerId,
            displayName: "Joueur",
            level: matchLevel,
            eloScore: 0,
            location: "",
            isPremium: false,
            createdAt: DateTime.now(),
          );
        }
        return _buildParticipantRow(context, user, isHost);
      },
    );
  }

  static Widget _buildParticipantRow(BuildContext context, UserModel p, bool isHost) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PublicProfileScreen(player: p)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isHost ? AppColors.gold : Colors.white24, width: 1.2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.coral,
              backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty) ? NetworkImage(p.photoUrl!) : null,
              child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                  ? Text(
                      p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : "?",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.displayName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHost) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            AppLocalizations.of(context).homeMatchDetailsHost,
                            style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).homeMatchDetailsPlayerStats(p.level, p.eloScore),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 12),
          ],
        ),
      ),
    );
  }
}
