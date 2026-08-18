import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/user.dart';

class PublicProfileScreen extends StatelessWidget {
  final UserModel player;

  const PublicProfileScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
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
              color: Colors.black.withOpacity(0.65),
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
                                      color: AppColors.gold.withOpacity(0.4),
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
                            Text(player.location, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Stats Grid
                        Row(
                          children: [
                            Expanded(child: _buildStatCard("Niveau", "Niv. ${player.level}", Icons.star, AppColors.gold)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard("Classement FFT", _formatRanking(player.ranking), Icons.workspace_premium, AppColors.coral, progression: player.rankingProgression)),
                          ],
                        ),
                        const SizedBox(height: 16),

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
      return "${num}ème";
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
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
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
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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
