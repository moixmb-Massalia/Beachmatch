import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';
import '../models/user.dart';
import '../providers/app_state.dart';
import 'chat_detail_screen.dart';
import 'create_match_screen.dart';
import 'clubs/club_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final UserModel? player;
  final String? userId;
  final String? fallbackDisplayName;
  final String? fallbackPhotoUrl;
  final String? fallbackRanking;
  final String? fallbackLocation;

  const PublicProfileScreen({
    super.key,
    this.player,
    this.userId,
    this.fallbackDisplayName,
    this.fallbackPhotoUrl,
    this.fallbackRanking,
    this.fallbackLocation,
  });

  static void open(
    BuildContext context, {
    UserModel? player,
    String? userId,
    String? displayName,
    String? photoUrl,
    String? ranking,
    String? location,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          player: player,
          userId: userId ?? player?.id,
          fallbackDisplayName: displayName ?? player?.displayName,
          fallbackPhotoUrl: photoUrl ?? player?.photoUrl,
          fallbackRanking: ranking ?? player?.ranking,
          fallbackLocation: location ?? player?.location,
        ),
      ),
    );
  }

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  UserModel? _resolvedPlayer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.player != null) {
      _resolvedPlayer = widget.player;
    } else {
      _loadPlayer();
    }
  }

  Future<void> _loadPlayer() async {
    final targetId = widget.userId;
    // 1. Check in-memory AppState first
    if (targetId != null && targetId.isNotEmpty) {
      final appState = context.read<AppState>();
      final local = appState.players.where((p) => p.id == targetId).firstOrNull;
      if (local != null) {
        if (mounted) setState(() => _resolvedPlayer = local);
        return;
      }
    }

    // 2. Fetch from Firestore if targetId is set
    if (targetId != null && targetId.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(targetId).get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _resolvedPlayer = UserModel.fromMap(doc.data()!, doc.id);
              _isLoading = false;
            });
            return;
          }
        }
      } catch (_) {
        // Fallback below
      }
    }

    // 3. Fallback synthetic UserModel if not registered or offline
    if (mounted) {
      setState(() {
        _resolvedPlayer = UserModel(
          id: targetId ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
          displayName: (widget.fallbackDisplayName != null && widget.fallbackDisplayName!.trim().isNotEmpty)
              ? widget.fallbackDisplayName!.trim()
              : 'Joueur Beach Tennis',
          level: 3,
          eloScore: 1000,
          location: widget.fallbackLocation ?? 'France',
          isPremium: false,
          createdAt: DateTime.now(),
          photoUrl: widget.fallbackPhotoUrl,
          ranking: widget.fallbackRanking ?? 'NC',
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _resolvedPlayer == null) {
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
              child: Container(color: Colors.black.withValues(alpha: 0.65)),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.fallbackDisplayName ?? "Profil du Joueur",
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final player = _resolvedPlayer!;
    final currentUser = context.watch<AppState>().currentUser;
    final bool isMe = currentUser != null && currentUser.id == player.id;
    final bool isFriend = currentUser != null && currentUser.friendsIds.contains(player.id);

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text("Profil du Joueur", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (currentUser?.isAdmin == true && !isMe)
                        InkWell(
                          onTap: () => _showAdminSheet(context, player),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold, size: 16),
                                SizedBox(width: 5),
                                Text(
                                  "Admin",
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Avatar Header
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.gold, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gold.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                              CircleAvatar(
                                radius: 55,
                                backgroundColor: AppColors.coral,
                                backgroundImage: player.photoUrl != null ? NetworkImage(player.photoUrl!) : null,
                                child: player.photoUrl == null
                                    ? Text(
                                        player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : "?",
                                        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          player.displayName,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on, color: AppColors.gold, size: 16),
                            const SizedBox(width: 4),
                            Text(player.location.isNotEmpty ? player.location : "France", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                        if (player.isBanned) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red, width: 1.2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.block_rounded, color: Colors.red, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "COMPTE BANNI PAR L'ADMINISTRATION",
                                  style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (player.isReferee) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.gavel_rounded, color: AppColors.gold, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  player.isBrazilian ? "Árbitro Oficial CBT ⚖️" : "Arbitre Officiel JAT FFT ⚖️",
                                  style: const TextStyle(color: AppColors.gold, fontSize: 11.5, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (player.isAmbassador) ...[
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
                                  player.ambassadorTitle ?? "Embaixador Oficial · BeachMatch 🇧🇷",
                                  style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (player.isBrazilian) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF009B3A).withValues(alpha: 0.25),
                                  const Color(0xFFFEDF00).withValues(alpha: 0.25),
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
                                  player.cbtCategory != null && player.cbtCategory!.isNotEmpty
                                      ? "${player.cbtCategory}${player.cbtId != null && player.cbtId!.isNotEmpty ? ' · ID CBT ${player.cbtId}' : ''} · Atleta Oficial"
                                      : "Atleta CBT Brasil 🇧🇷",
                                  style: const TextStyle(color: Color(0xFFFEDF00), fontSize: 11.5, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (player.clubName != null && player.clubName!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: player.clubId != null
                                ? () => ClubDetailScreen.open(context, player.clubId!)
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
                                      (player.isBrazilian ? "Arena : " : "Club : ") + player.clubName!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (player.clubId != null) ...[
                                    const SizedBox(width: 5),
                                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 11),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (player.isLookingForPartner) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.coral, width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.handshake_rounded, color: AppColors.coral, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  player.isBrazilian ? "Procurando parceiro(a)" : "Recherche activement un partenaire",
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Stats Grid (Niveau · Classement FFT / CBT)
                        Row(
                          children: [
                            Expanded(child: _buildStatCard(player.isBrazilian ? "Nível" : "Niveau", "Niv. ${player.level}", Icons.star, AppColors.gold)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard(
                              player.isBrazilian ? "Cat. CBT 🇧🇷" : "Rang FFT",
                              player.isBrazilian
                                  ? ((player.cbtCategory != null && player.cbtCategory!.isNotEmpty)
                                      ? player.cbtCategory!
                                      : ((player.ranking != null && player.ranking!.isNotEmpty && player.ranking != 'NC')
                                          ? player.ranking!
                                          : "Amador"))
                                  : _formatRanking(player.ranking),
                              Icons.workspace_premium,
                              AppColors.coral,
                              progression: player.rankingProgression,
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Préférences de jeu (si renseignées)
                        if ((player.preferredPosition != null && player.preferredPosition!.isNotEmpty) ||
                            (player.availability != null && player.availability!.isNotEmpty)) ...[
                          _buildGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("PRÉFÉRENCES DE JEU", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: 1.1)),
                                const SizedBox(height: 14),
                                if (player.preferredPosition != null && player.preferredPosition!.isNotEmpty)
                                  _buildInfoRow(Icons.sports_tennis, "Côté préféré", player.preferredPosition!),
                                if (player.preferredPosition != null && player.preferredPosition!.isNotEmpty &&
                                    player.availability != null && player.availability!.isNotEmpty)
                                  const Divider(color: Colors.white24, height: 20),
                                if (player.availability != null && player.availability!.isNotEmpty)
                                  _buildInfoRow(Icons.access_time_rounded, "Disponibilités", player.availability!),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Detailed Card
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.isBrazilian ? "INFORMAÇÕES DO ATLETA 🇧🇷" : "INFORMATIONS JOUEUR",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: 1.1),
                              ),
                              if (player.isBrazilian) ...[
                                _buildInfoRow(
                                  Icons.badge_rounded,
                                  "ID / Filiação CBT",
                                  (player.cbtId != null && player.cbtId!.trim().isNotEmpty)
                                      ? "ID CBT: ${player.cbtId} · Cadastrado ✓"
                                      : "Atleta Amador (Não filiado)",
                                ),
                                const Divider(color: Colors.white24, height: 24),
                                _buildInfoRow(
                                  Icons.military_tech,
                                  "Categoria CBT",
                                  (player.cbtCategory != null && player.cbtCategory!.trim().isNotEmpty)
                                      ? player.cbtCategory!
                                      : ((player.ranking != null && player.ranking!.trim().isNotEmpty && player.ranking != 'NC')
                                          ? player.ranking!
                                          : "Iniciante / Amador"),
                                ),
                                if (player.clubName != null && player.clubName!.isNotEmpty) ...[
                                  const Divider(color: Colors.white24, height: 24),
                                  _buildInfoRow(Icons.sports_tennis, "Arena / Clube", player.clubName!),
                                ],
                                const Divider(color: Colors.white24, height: 24),
                                _buildInfoRow(
                                  Icons.calendar_today,
                                  "Membro desde",
                                  "${player.createdAt.day.toString().padLeft(2, '0')}/${player.createdAt.month.toString().padLeft(2, '0')}/${player.createdAt.year}",
                                ),
                              ] else ...[
                                _buildInfoRow(
                                  Icons.card_membership,
                                  "Numéro de Licence FFT",
                                  (player.licenceNumber != null && player.licenceNumber!.trim().isNotEmpty)
                                      ? "n°${player.licenceNumber} · Certifié ✓"
                                      : "Non renseignée (Non certifié)",
                                ),
                                if (player.clubName != null && player.clubName!.isNotEmpty) ...[
                                  const Divider(color: Colors.white24, height: 24),
                                  _buildInfoRow(Icons.shield_rounded, "Club Officiel FFT", player.clubName!),
                                ],
                                const Divider(color: Colors.white24, height: 24),
                                _buildInfoRow(Icons.military_tech, "Classement Officiel FFT", _formatRanking(player.ranking)),
                                const Divider(color: Colors.white24, height: 24),
                                _buildInfoRow(Icons.calendar_today, "Membre depuis", "${player.createdAt.day}/${player.createdAt.month}/${player.createdAt.year}"),
                              ],
                              if (currentUser?.isAdmin == true && player.email != null && player.email!.isNotEmpty) ...[
                                const Divider(color: Colors.white24, height: 24),
                                _buildInfoRow(Icons.alternate_email_rounded, "Email (Visible Admin)", player.email!),
                              ],
                            ],
                          ),
                        ),

                        // Action Buttons Bar (When viewing another player)
                        if (!isMe) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ChatDetailScreen(otherUser: player)),
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                                  label: const Text("Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (isFriend) {
                                      context.read<AppState>().removeFriend(player.id);
                                    } else {
                                      context.read<AppState>().addFriend(player.id);
                                    }
                                  },
                                  icon: Icon(isFriend ? Icons.check_circle_rounded : Icons.person_add_rounded, size: 18),
                                  label: Text(isFriend ? "Ami ✓" : "Ajouter", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFriend ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.12),
                                    foregroundColor: isFriend ? Colors.greenAccent : Colors.white,
                                    side: BorderSide(color: isFriend ? Colors.greenAccent : Colors.white30),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => CreateMatchScreen(invitedPlayer: player)),
                                    );
                                  },
                                  icon: const Icon(Icons.sports_tennis_rounded, size: 18),
                                  label: const Text("Inviter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.coral,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
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

  String _formatRanking(String? ranking) {
    if (ranking == null || ranking.isEmpty || ranking == "NC") return "NC";
    final num = int.tryParse(ranking);
    if (num != null) {
      if (num == 1) return "1er";
      return "$num" "ème";
    }
    return ranking;
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {int? progression}) {
    return _buildGlassCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              if (progression != null && progression != 0) ...[
                const SizedBox(width: 4),
                Icon(progression > 0 ? Icons.arrow_upward : Icons.arrow_downward, color: progression > 0 ? Colors.greenAccent : Colors.redAccent, size: 14),
                Text(
                  progression > 0 ? "+$progression" : "$progression",
                  style: TextStyle(color: progression > 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  void _showAdminSheet(BuildContext context, UserModel player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isRef = player.isReferee;
        bool isAmb = player.isAmbassador;
        bool isBanned = player.isBanned;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF131824),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Modération & Administration",
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                player.displayName,
                                style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),

                    // Email avec bouton copier
                    if (player.email != null && player.email!.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined, color: AppColors.gold),
                        title: const Text("Email du compte", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        subtitle: Text(player.email!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppColors.gold, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: player.email!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Email copié dans le presse-papiers !")),
                            );
                          },
                        ),
                      ),

                    // ID Utilisateur avec bouton copier
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fingerprint_rounded, color: Colors.white54),
                      title: const Text("ID Document Firestore", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      subtitle: Text(player.id, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: player.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("ID copié dans le presse-papiers !")),
                          );
                        },
                      ),
                    ),

                    const Divider(color: Colors.white10, height: 20),

                    // Switch Arbitre JAT FFT
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(player.isBrazilian ? "Árbitro Oficial CBT ⚖️" : "Arbitre Officiel JAT FFT ⚖️", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Donne accès à l'arbitrage officiel des tournois", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      value: isRef,
                      activeThumbColor: AppColors.gold,
                      onChanged: (val) async {
                        setModalState(() => isRef = val);
                        setState(() {
                          _resolvedPlayer = _resolvedPlayer?.copyWith(isReferee: val);
                        });
                        await FirebaseFirestore.instance.collection('users').doc(player.id).update({'isReferee': val});
                      },
                    ),

                    // Switch Ambassadeur
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Ambassadeur BeachMatch 👑", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Affiche le badge d'ambassadeur officiel sur le profil", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      value: isAmb,
                      activeThumbColor: AppColors.gold,
                      onChanged: (val) async {
                        setModalState(() => isAmb = val);
                        setState(() {
                          _resolvedPlayer = _resolvedPlayer?.copyWith(isAmbassador: val);
                        });
                        await FirebaseFirestore.instance.collection('users').doc(player.id).update({'isAmbassador': val});
                      },
                    ),

                    const SizedBox(height: 14),

                    // Bouton Bannir / Débannir
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBanned ? Colors.green.shade700 : Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(isBanned ? Icons.check_circle_rounded : Icons.block_rounded),
                        label: Text(
                          isBanned ? "Débannir cet utilisateur" : "Bannir cet utilisateur",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              backgroundColor: const Color(0xFF141923),
                              title: Text(
                                isBanned ? "Débannir le compte ?" : "Bannir le compte ?",
                                style: const TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                isBanned
                                    ? "L'utilisateur pourra à nouveau se connecter et jouer."
                                    : "L'utilisateur sera immédiatement déconnecté et bloqué. Continuer ?",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isBanned ? Colors.green : Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(dialogCtx);
                                    final newVal = !isBanned;
                                    setModalState(() => isBanned = newVal);
                                    setState(() {
                                      _resolvedPlayer = _resolvedPlayer?.copyWith(isBanned: newVal);
                                    });
                                    await FirebaseFirestore.instance.collection('users').doc(player.id).update({'isBanned': newVal});
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(newVal ? "Utilisateur banni !" : "Utilisateur débanni !")),
                                      );
                                    }
                                  },
                                  child: Text(isBanned ? "Débannir" : "Bannir définitivement"),
                                ),
                              ],
                            ),
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
      },
    );
  }
}
