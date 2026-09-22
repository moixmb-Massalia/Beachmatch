import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';
import '../models/user.dart';
import '../providers/app_state.dart';
import 'chat_detail_screen.dart';
import 'create_match_screen.dart';

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
                        if (player.isLookingForPartner) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.coral, width: 1.2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.handshake_rounded, color: AppColors.coral, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Recherche activement un partenaire",
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Stats Grid (Niveau · Points ELO · Classement FFT)
                        Row(
                          children: [
                            Expanded(child: _buildStatCard("Niveau", "Niv. ${player.level}", Icons.star, AppColors.gold)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatCard("Points ELO", "${player.eloScore}", Icons.bolt, Colors.amberAccent)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatCard("Rang FFT", _formatRanking(player.ranking), Icons.workspace_premium, AppColors.coral, progression: player.rankingProgression)),
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
                              const Text("INFORMATIONS JOUEUR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: 1.1)),
                              const SizedBox(height: 16),
                              _buildInfoRow(Icons.card_membership, "Numéro de Licence FFT", player.licenceNumber ?? "Non renseignée"),
                              const Divider(color: Colors.white24, height: 24),
                              _buildInfoRow(Icons.military_tech, "Classement Officiel FFT", _formatRanking(player.ranking)),
                              const Divider(color: Colors.white24, height: 24),
                              _buildInfoRow(Icons.calendar_today, "Membre depuis", "${player.createdAt.day}/${player.createdAt.month}/${player.createdAt.year}"),
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
}
