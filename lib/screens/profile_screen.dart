import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import 'profile_edit_screen.dart';
import 'privacy_screen.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';
import 'clubs/club_detail_screen.dart';
import 'clubs/president_dashboard_screen.dart';
import 'tournaments/tournament_radar_screen.dart';
import 'public_profile_screen.dart';
import 'chat_detail_screen.dart';
import '../widgets/link_fft_licence_modal.dart';
import '../l10n/app_localizations.dart';
import 'fft_rankings_screen.dart';
import 'tutorial_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F141E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: "Retour",
                )
              : null,
          title: const Text("Profil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.coral),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_tennis_ball_1785052281869.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (Navigator.canPop(context)) ...[
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                              tooltip: "Retour",
                            ),
                            const SizedBox(width: 2),
                          ],
                          Text(
                            AppLocalizations.of(context).profileTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileEditScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.gold, width: 1.3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_rounded, color: AppColors.gold, size: 16),
                              const SizedBox(width: 5),
                              Text(
                                user.isBrazilian ? "Editar" : "Modifier",
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.coral,
                    backgroundColor: const Color(0xFF1E2638),
                    onRefresh: () async {
                      await context.read<AppState>().loadData();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildProfileHeader(context, user),
                        const SizedBox(height: 24),
                        _buildStatsGrid(context, user),
                        const SizedBox(height: 24),
                        _buildFriendsSection(context, user),
                        const SizedBox(height: 24),
                        _buildAdminSection(context, user),
                        _buildPresidentClubSection(context, user),
                        _buildRadarSection(context, user),
                        const SizedBox(height: 24),
                        _buildPreferences(context),
                        const SizedBox(height: 24),
                        _buildLanguageSelector(context),
                        const SizedBox(height: 24),
                        _buildLegalSection(context, user),
                        const SizedBox(height: 24),
                        _buildDangerousZone(context, user),
                        const SizedBox(height: 90), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, user) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileEditScreen()));
            },
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                    border: Border.all(color: AppColors.gold, width: 3),
                    boxShadow: [
                      BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2)
                    ],
                    image: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                      ? DecorationImage(image: NetworkImage(user.photoUrl!), fit: BoxFit.cover) 
                      : null,
                  ),
                  child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                    ? Center(child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)))
                    : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E2638), width: 2.5),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: Colors.black, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(user.displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.gold),
              const SizedBox(width: 4),
              Text(user.location.isNotEmpty ? user.location : AppLocalizations.of(context).profileCityUnknown, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(AppLocalizations.of(context).profileLevel(user.level), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
          ),
          if (user.ranking != null && user.ranking!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(AppLocalizations.of(context).profileRanking(_formatRanking(context, user.ranking)), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
          if (user.isAmbassador) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD700), // Gold
                    Color(0xFFFF8C00), // Dark Orange
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.black, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    user.ambassadorTitle ?? "Embaixador Oficial · BeachMatch 🇧🇷",
                    style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
          if (user.isBrazilian) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF009B3A).withValues(alpha: 0.25), // Verde Brasil
                      const Color(0xFFFEDF00).withValues(alpha: 0.25), // Amarelo Brasil
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFEDF00).withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("🇧🇷", style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Text(
                      user.cbtCategory != null && user.cbtCategory!.isNotEmpty
                          ? "${user.cbtCategory}${user.cbtId != null && user.cbtId!.isNotEmpty ? ' · ID CBT ${user.cbtId}' : ''} · Atleta Oficial"
                          : "Atleta CBT Brasil 🇧🇷 · Toque para definir categoria",
                      style: const TextStyle(color: Color(0xFFFEDF00), fontSize: 11.5, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFEDF00), size: 11),
                  ],
                ),
              ),
            ),
          ] else ...[
            if (user.licenceNumber != null && user.licenceNumber!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "Licence FFT n°${user.licenceNumber} · Certifié ✓",
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => LinkFftLicenceModal.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Profil non certifié · Débloquer mon badge FFT",
                        style: TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.amberAccent, size: 10),
                    ],
                  ),
                ),
              ),
            ],
          ],
          if (user.clubName != null && user.clubName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: user.clubId != null
                  ? () => ClubDetailScreen.open(context, user.clubId!)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.22),
                      AppColors.coral.withValues(alpha: 0.22),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_rounded, color: AppColors.gold, size: 16),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        user.isBrazilian ? "Arena : ${user.clubName}" : "Club : ${user.clubName}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.clubId != null) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 11),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Bouton évident et impossible à rater pour modifier son profil
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileEditScreen()));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.coral, Color(0xFFF97316)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.coral.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    user.isBrazilian ? "Editar meu perfil & informações" : "Modifier mon profil & mes infos",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRanking(BuildContext context, String? ranking) {
    if (ranking == null || ranking.trim().isEmpty || ranking.trim() == "NC") return "NC";
    final num = int.tryParse(ranking.trim());
    if (num != null) {
      try {
        if (num == 1) return AppLocalizations.of(context).rankingFirst;
        return AppLocalizations.of(context).rankingNth(num);
      } catch (_) {
        return "${num}e";
      }
    }
    return ranking.trim();
  }

  Widget _buildStatsGrid(BuildContext context, UserModel user) {
    final matches = context.watch<AppState>().matches;
    final userMatchesCount = matches.where((m) => m.participantsIds.contains(user.id) || m.hostId == user.id).length;
    final totalMatches = user.totalMatches > userMatchesCount ? user.totalMatches : userMatchesCount;

    final rankingLabel = user.isBrazilian
        ? "Cat. CBT 🇧🇷"
        : AppLocalizations.of(context).profileFftRanking;
    final rankingVal = user.isBrazilian && user.cbtCategory != null && user.cbtCategory!.isNotEmpty
        ? user.cbtCategory!
        : _formatRanking(context, user.ranking);

    return Row(
      children: [
        Expanded(child: _buildStatCard(user.isBrazilian ? "Partidas 🎾" : "Matchs joués 🎾", totalMatches.toString())), 
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (user.isBrazilian) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileEditScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FftRankingsScreen()),
                );
              }
            },
            child: _buildStatCard(
              rankingLabel, 
              rankingVal, 
              isHighlight: true, 
              progression: user.rankingProgression,
              isClickable: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, {bool isHighlight = false, int? progression, bool isClickable = false}) {
    return _buildGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isClickable)
                const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 11),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isHighlight ? AppColors.gold : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (progression != null && progression != 0) ...[
                const SizedBox(width: 4),
                Icon(
                  progression > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: progression > 0 ? Colors.greenAccent : Colors.redAccent,
                  size: 15,
                ),
                Text(
                  progression > 0 ? "+$progression" : "$progression",
                  style: TextStyle(
                    color: progression > 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          if (isClickable) ...[
            const SizedBox(height: 4),
            const Text(
              "Voir le classement ›",
              style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendsSection(BuildContext context, UserModel user) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: AppColors.gold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    user.isBrazilian ? "Meus Amigos" : "Mes Amis",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${user.friendsIds.length}",
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (user.friendsIds.isNotEmpty)
                GestureDetector(
                  onTap: () => _showFriendsBottomSheet(context, user),
                  child: Text(
                    user.isBrazilian ? "Ver todos →" : "Voir tout →",
                    style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (user.friendsIds.isEmpty)
            Text(
              user.isBrazilian
                  ? "Você ainda não adicionou amigos. Encontre atletas na aba Comunidade !"
                  : "Vous n'avez pas encore ajouté d'amis. Retrouvez des joueurs dans l'onglet Communauté !",
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            )
          else
            _buildFriendsPreviewRow(context, user),
        ],
      ),
    );
  }

  Widget _buildFriendsPreviewRow(BuildContext context, UserModel user) {
    final allPlayers = context.watch<AppState>().players;
    final friends = allPlayers.where((p) => user.friendsIds.contains(p.id)).take(6).toList();

    return Row(
      children: [
        ...friends.map((friend) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(player: friend)));
              },
              child: Tooltip(
                message: friend.displayName,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.coral.withValues(alpha: 0.3),
                  backgroundImage: (friend.photoUrl != null && friend.photoUrl!.isNotEmpty)
                      ? NetworkImage(friend.photoUrl!)
                      : null,
                  child: (friend.photoUrl == null || friend.photoUrl!.isEmpty)
                      ? Text(
                          friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        )
                      : null,
                ),
              ),
            ),
          );
        }),
        if (user.friendsIds.length > 6)
          GestureDetector(
            onTap: () => _showFriendsBottomSheet(context, user),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              child: Text(
                "+${user.friendsIds.length - 6}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  void _showFriendsBottomSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (sheetContext, scrollController) {
            final allPlayers = Provider.of<AppState>(context, listen: false).players;
            final friends = allPlayers.where((p) => user.friendsIds.contains(p.id)).toList();

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF161F30),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, color: AppColors.gold, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          "${user.isBrazilian ? 'Meus Amigos' : 'Mes Amis'} (${user.friendsIds.length})",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: friends.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                user.isBrazilian ? "Nenhum amigo encontrado na lista." : "Aucun ami trouvé dans la liste.",
                                style: const TextStyle(color: Colors.white60),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: friends.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final friend = friends[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.coral.withValues(alpha: 0.3),
                                    backgroundImage: (friend.photoUrl != null && friend.photoUrl!.isNotEmpty)
                                        ? NetworkImage(friend.photoUrl!)
                                        : null,
                                    child: (friend.photoUrl == null || friend.photoUrl!.isEmpty)
                                        ? Text(friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                  title: Text(friend.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text("${user.isBrazilian ? 'Nível' : 'Niveau'} ${friend.level} · ${friend.location}", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.gold, size: 20),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(otherUser: friend)));
                                        },
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(player: friend)));
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminSection(BuildContext context, user) {
    final authEmail = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim();
    final isSuperAdmin = authEmail == 'moixmb@gmail.com';
    if (!isSuperAdmin) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: AppColors.gold, size: 24),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).profileAdminPanelTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).profileAdminPanelSub, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
                },
                child: Text(AppLocalizations.of(context).profileAdminPanelBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresidentClubSection(BuildContext context, UserModel user) {
    final firebaseEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final presidentClubs = snapshot.data!.docs
            .map((doc) => ClubModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((club) {
              final hasAdminId = club.adminId.isNotEmpty && club.adminId == user.id;
              final hasEmail = firebaseEmail.isNotEmpty &&
                  club.presidentEmails.map((e) => e.toLowerCase().trim()).contains(firebaseEmail);
              return hasAdminId || hasEmail;
            })
            .toList();

        if (presidentClubs.isEmpty) return const SizedBox.shrink();

        final myClub = presidentClubs.first;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.coral.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppColors.coral, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.isBrazilian ? "Espaço Presidente de Arena" : "Espace Président de Club",
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.isBrazilian ? "Gerencie sua arena e seus torneios" : "Gérez votre club et vos tournois",
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.domain, color: AppColors.gold, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          myClub.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.dashboard_customize, size: 18),
                    label: Text(
                      user.isBrazilian ? "Abrir Painel da Arena" : "Ouvrir le Tableau de Bord Club",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PresidentDashboardScreen(club: myClub)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadarSection(BuildContext context, UserModel user) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: AppColors.coral, size: 24),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).profileRadarTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              const Spacer(),
              Switch(
                value: user.tournamentAlertsEnabled,
                activeThumbColor: AppColors.coral,
                onChanged: (bool value) async {
                  try {
                    await context.read<AppState>().updateUserPreferences(
                      tournamentAlertsEnabled: value,
                      alertRegion: user.alertRegion ?? user.location,
                    );
                    if (context.mounted && value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context).profileRadarActivated(user.alertRegion ?? user.location)),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).profileRadarError), backgroundColor: Colors.redAccent));
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).profileRadarSub,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          if (user.tournamentAlertsEnabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_city, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).profileRadarRegion, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Expanded(
                  child: Text(
                    user.alertRegion ?? user.location,
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                  onPressed: () {
                    _showEditRegionDialog(context, user);
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: AppColors.coral.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.radar_rounded, size: 18, color: AppColors.coral),
              label: Text(
                user.isBrazilian ? "Abrir o Radar 360°" : "Ouvrir le Radar 360°",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TournamentRadarScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditRegionDialog(BuildContext context, UserModel user) {
    final TextEditingController ctrl = TextEditingController(text: user.alertRegion ?? user.location);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(AppLocalizations.of(context).profileRadarEditRegion, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).profileRadarRegionHint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).profileBtnCancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () async {
              Navigator.pop(ctx);
              if (ctrl.text.trim().isNotEmpty) {
                await context.read<AppState>().updateUserPreferences(
                  tournamentAlertsEnabled: user.tournamentAlertsEnabled,
                  alertRegion: ctrl.text.trim(),
                );
              }
            },
            child: Text(AppLocalizations.of(context).profileBtnValidate, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferences(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).profilePreferencesTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              GestureDetector(
                onTap: () => _showEditGamePreferencesModal(context, user),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        user.isBrazilian ? "Editar" : "Modifier",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildListTile(
            Icons.sports_tennis,
            AppLocalizations.of(context).profilePrefPosition,
            user.preferredPosition ?? AppLocalizations.of(context).profilePrefNotSet,
          ),
          Divider(color: Colors.white.withValues(alpha: 0.2)),
          _buildListTile(
            Icons.access_time_filled,
            AppLocalizations.of(context).profilePrefAvailability,
            user.availability ?? AppLocalizations.of(context).profilePrefNotSet,
          ),
          Divider(color: Colors.white.withValues(alpha: 0.2)),
          _buildListTile(
            Icons.handshake_rounded,
            user.isBrazilian ? "Procurando parceiro(a)" : "Recherche partenaire",
            user.isLookingForPartner
                ? (user.isBrazilian ? "Ativo 🤝" : "Actif 🤝")
                : (user.isBrazilian ? "Não" : "Non"),
          ),
        ],
      ),
    );
  }

  void _showEditGamePreferencesModal(BuildContext context, UserModel user) {
    String? selectedPos = user.preferredPosition;
    String? selectedAvail = user.availability;
    int selectedLevel = user.level;
    bool isLooking = user.isLookingForPartner;
    final isBr = user.isBrazilian;

    final positions = isBr
        ? ["Esquerda", "Direita", "Polivalente"]
        : ["Gauche", "Droite", "Polyvalent"];
    final availabilities = isBr
        ? [
            "Noites & Fins de semana",
            "Dias de semana",
            "Sempre disponível",
            "Horários flexíveis",
          ]
        : [
            "Soirs & Week-ends",
            "En semaine",
            "Tout le temps",
            "Variable",
          ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF141923),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppColors.gold, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        isBr ? "Preferências de Jogo" : "Préférences de Jeu",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isBr
                        ? "Personalize seu estilo e horários para encontrar os melhores parceiros."
                        : "Personnalisez votre style et vos disponibilités pour trouver les meilleurs partenaires.",
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Côté de jeu
                  Text(
                    isBr ? "Posição preferida em quadra" : "Côté de jeu préféré",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: positions.map((pos) {
                      final isSelected = selectedPos == pos;
                      return ChoiceChip(
                        label: Text(pos, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: AppColors.coral,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        onSelected: (selected) {
                          setModalState(() {
                            selectedPos = selected ? pos : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Disponibilités
                  Text(
                    isBr ? "Disponibilidade" : "Disponibilités",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availabilities.map((avail) {
                      final isSelected = selectedAvail == avail;
                      return ChoiceChip(
                        label: Text(avail, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        onSelected: (selected) {
                          setModalState(() {
                            selectedAvail = selected ? avail : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Niveau de jeu auto-évalué
                  Text(
                    isBr ? "Nível autoavaliado" : "Niveau auto-évalué",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(5, (index) {
                      final lvl = index + 1;
                      final isSelected = selectedLevel == lvl;
                      final labels = isBr
                          ? ["1 (Iniciante)", "2 (Intermediário)", "3 (Avançado)", "4 (Competidor)", "5 (Profissional)"]
                          : ["1 (Débutant)", "2 (Intermédiaire)", "3 (Confirmé)", "4 (Compétiteur)", "5 (Expert)"];
                      return ChoiceChip(
                        label: Text(labels[index], style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.gold,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedLevel = lvl;
                            });
                          }
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Recherche de partenaire switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.handshake_rounded, color: AppColors.coral, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isBr ? "Procurando parceiro(a)" : "Recherche de partenaire",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                isBr ? "Ficar visível para atletas da região" : "Être visible par les joueurs de la région",
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isLooking,
                          activeThumbColor: AppColors.coral,
                          onChanged: (val) {
                            setModalState(() {
                              isLooking = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bouton Enregistrer
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await context.read<AppState>().updateGamePreferences(
                            preferredPosition: selectedPos,
                            availability: selectedAvail,
                            level: selectedLevel,
                            isLookingForPartner: isLooking,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isBr ? "Preferências de jogo atualizadas ! 🎾" : "Préférences de jeu mises à jour ! 🎾",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Erreur: $e"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        isBr ? "Salvar preferências" : "Enregistrer mes préférences",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeLocale = appState.currentLocale ?? Localizations.localeOf(context);

    final languages = [
      {'code': 'fr', 'country': '', 'flag': '🇫🇷', 'label': 'Français'},
      {'code': 'pt', 'country': 'BR', 'flag': '🇧🇷', 'label': 'Português (Brasil)'},
      {'code': 'en', 'country': '', 'flag': '🇬🇧', 'label': 'English'},
      {'code': 'es', 'country': '', 'flag': '🇪🇸', 'label': 'Español'},
      {'code': 'it', 'country': '', 'flag': '🇮🇹', 'label': 'Italiano'},
    ];

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.language_rounded, color: AppColors.gold, size: 22),
              SizedBox(width: 8),
              Text(
                "Langue / Idioma",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Sélectionnez votre langue d'affichage / Escolha seu idioma.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: languages.map((lang) {
              final isSelected = activeLocale.languageCode == lang['code'] &&
                  (lang['country']!.isEmpty || activeLocale.countryCode == lang['country']);

              return GestureDetector(
                onTap: () {
                  final newLocale = lang['country']!.isNotEmpty
                      ? Locale(lang['code']!, lang['country']!)
                      : Locale(lang['code']!);
                  context.read<AppState>().setLocale(newLocale);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.2),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lang['flag']!, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        lang['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 16),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context, UserModel user) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).profileLegalTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.explore_rounded, color: AppColors.gold),
            title: Text(
              user.isBrazilian ? "Guia do App · Tour das Funcionalidades 🇧🇷" : "Guide de l'App · Tour complet",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              user.isBrazilian 
                  ? "Conheça todos os menus e recursos do app em uma só passada" 
                  : "Découvrez toutes les fonctionnalités et onglets de l'application",
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TutorialScreen(isReplay: true)),
              );
            },
          ),
          const Divider(color: Colors.white12, height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.policy_rounded, color: AppColors.gold),
            title: Text(
              user.isBrazilian ? "Termos Gerais & Privacidade" : "Conditions Générales & Confidentialité",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              user.isBrazilian ? "Regras de uso e proteção dos seus dados" : "Règles d'utilisation et protection de vos données",
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyScreen()));
            },
          ),
          const Divider(color: Colors.white12, height: 24),
          const Center(
            child: Text(
              "BeachMatch v1.0.0 · Build 2026.09",
              style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerousZone(BuildContext context, UserModel user) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).profileAccountManagement, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.redAccent)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.white70),
              label: Text(AppLocalizations.of(context).profileLogout, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text(
                      user.isBrazilian ? "Sair da conta ?" : "Se déconnecter ?",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      user.isBrazilian
                          ? "Deseja realmente sair da sua conta BeachMatch ?"
                          : "Voulez-vous vraiment vous déconnecter de votre compte BeachMatch ?",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          user.isBrazilian ? "Cancelar" : "Annuler",
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          user.isBrazilian ? "Sair" : "Déconnexion",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await context.read<AppState>().logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              label: Text(AppLocalizations.of(context).profileDeleteAccount, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                _showDeleteAccountDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141923), // Deep solid dark background
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 10),
                  Text(AppLocalizations.of(context).profileDeleteAccountConfirmTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).profileDeleteAccountConfirmSub,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppLocalizations.of(context).profileBtnCancel, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: Text(AppLocalizations.of(context).profileBtnDelete, style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await context.read<AppState>().deleteAccount();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 15, color: Colors.white70)),
          const Spacer(),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
