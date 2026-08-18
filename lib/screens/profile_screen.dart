import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import 'profile_edit_screen.dart';
import 'privacy_screen.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';
import '../l10n/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_tennis_ball_1785052281869.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6),
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
                      Text(AppLocalizations.of(context)!.profileTitle, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_note, color: Colors.white, size: 28),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileEditScreen()));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: AppColors.coral, size: 26),
                            onPressed: () async {
                              await context.read<AppState>().logout();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildProfileHeader(context, user),
                      const SizedBox(height: 24),
                      _buildStatsGrid(context, user),
                      const SizedBox(height: 24),
                      _buildAdminSection(context, user),
                      _buildRadarSection(context, user),
                      const SizedBox(height: 24),
                      _buildPreferences(context),
                      const SizedBox(height: 24),
                      _buildLegalSection(context),
                      const SizedBox(height: 24),
                      _buildDangerousZone(context),
                      const SizedBox(height: 90), // Bottom padding
                    ],
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
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
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
                      BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)
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
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.black, size: 16),
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
              Text(user.location.isNotEmpty ? user.location : AppLocalizations.of(context)!.profileCityUnknown, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(AppLocalizations.of(context)!.profileLevel(user.level), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
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
              child: Text(AppLocalizations.of(context)!.profileRanking(_formatRanking(context, user.ranking)), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRanking(BuildContext context, String? ranking) {
    if (ranking == null || ranking.isEmpty || ranking == "NC") return "NC";
    final num = int.tryParse(ranking);
    if (num != null) {
      if (num == 1) return AppLocalizations.of(context)!.rankingFirst;
      return AppLocalizations.of(context)!.rankingNth(num);
    }
    return ranking;
  }

  Widget _buildStatsGrid(BuildContext context, user) {
    final matches = context.watch<AppState>().matches;
    final userMatchesCount = matches.where((m) => m.participantsIds.contains(user.id) || m.hostId == user.id).length;

    return Row(
      children: [
        Expanded(child: _buildStatCard("Matchs joués 🎾", userMatchesCount.toString())), 
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(
          AppLocalizations.of(context)!.profileFftRanking, 
          _formatRanking(context, user.ranking), 
          isHighlight: true, 
          progression: user.rankingProgression
        )),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, {bool isHighlight = false, int? progression}) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value, style: TextStyle(color: isHighlight ? AppColors.gold : Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              if (progression != null && progression != 0) ...[
                const SizedBox(width: 4),
                Icon(progression > 0 ? Icons.arrow_upward : Icons.arrow_downward, color: progression > 0 ? Colors.greenAccent : Colors.redAccent, size: 16),
                Text(
                  progression > 0 ? "+$progression" : "$progression",
                  style: TextStyle(color: progression > 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context, user) {
    if (!user.isAdmin) return const SizedBox.shrink();
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
                Text(AppLocalizations.of(context)!.profileAdminPanelTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.profileAdminPanelSub, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                child: Text(AppLocalizations.of(context)!.profileAdminPanelBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
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
              Text(AppLocalizations.of(context)!.profileRadarTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              const Spacer(),
              Switch(
                value: user.tournamentAlertsEnabled,
                activeColor: AppColors.coral,
                onChanged: (bool value) async {
                  try {
                    await context.read<AppState>().updateUserPreferences(
                      tournamentAlertsEnabled: value,
                      alertRegion: user.alertRegion ?? user.location,
                    );
                    if (context.mounted && value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.profileRadarActivated(user.alertRegion ?? user.location)),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profileRadarError), backgroundColor: Colors.redAccent));
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.profileRadarSub,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          if (user.tournamentAlertsEnabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_city, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.profileRadarRegion, style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
            )
          ]
        ],
      ),
    );
  }

  void _showEditRegionDialog(BuildContext context, UserModel user) {
    final TextEditingController _ctrl = TextEditingController(text: user.alertRegion ?? user.location);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(AppLocalizations.of(context)!.profileRadarEditRegion, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: _ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.profileRadarRegionHint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.profileBtnCancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_ctrl.text.trim().isNotEmpty) {
                await context.read<AppState>().updateUserPreferences(
                  tournamentAlertsEnabled: user.tournamentAlertsEnabled,
                  alertRegion: _ctrl.text.trim(),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.profileBtnValidate, style: const TextStyle(color: Colors.white)),
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
                AppLocalizations.of(context)!.profilePreferencesTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              GestureDetector(
                onTap: () => _showEditGamePreferencesModal(context, user),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.coral.withOpacity(0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text(
                        "Modifier",
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
            AppLocalizations.of(context)!.profilePrefPosition,
            user.preferredPosition ?? AppLocalizations.of(context)!.profilePrefNotSet,
          ),
          Divider(color: Colors.white.withOpacity(0.2)),
          _buildListTile(
            Icons.access_time_filled,
            AppLocalizations.of(context)!.profilePrefAvailability,
            user.availability ?? AppLocalizations.of(context)!.profilePrefNotSet,
          ),
          Divider(color: Colors.white.withOpacity(0.2)),
          _buildListTile(
            Icons.handshake_rounded,
            "Recherche partenaire",
            user.isLookingForPartner ? "Actif 🤝" : "Non",
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

    final positions = ["Gauche", "Droite", "Polyvalent"];
    final availabilities = [
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
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
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
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppColors.gold, size: 24),
                      SizedBox(width: 10),
                      Text(
                        "Préférences de Jeu",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Personnalisez votre style et vos disponibilités pour trouver les meilleurs partenaires.",
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Côté de jeu
                  const Text("Côté de jeu préféré", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
                        backgroundColor: Colors.white.withOpacity(0.08),
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
                  const Text("Disponibilités", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
                        backgroundColor: Colors.white.withOpacity(0.08),
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
                  const Text("Niveau auto-évalué", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(5, (index) {
                      final lvl = index + 1;
                      final isSelected = selectedLevel == lvl;
                      final labels = ["1 (Débutant)", "2 (Intermédiaire)", "3 (Confirmé)", "4 (Compétiteur)", "5 (Expert)"];
                      return ChoiceChip(
                        label: Text(labels[index], style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.gold,
                        backgroundColor: Colors.white.withOpacity(0.08),
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
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.handshake_rounded, color: AppColors.coral, size: 22),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Recherche de partenaire",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                "Être visible par les joueurs de la région",
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isLooking,
                          activeColor: AppColors.coral,
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
                              const SnackBar(
                                content: Text("Préférences de jeu mises à jour ! 🎾"),
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
                      child: const Text(
                        "Enregistrer mes préférences",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _buildLegalSection(BuildContext context) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.profileLegalTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip, color: AppColors.gold),
            title: Text(AppLocalizations.of(context)!.profilePrivacy, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyScreen()));
            },
          ),
          Divider(color: Colors.white.withOpacity(0.2)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description, color: AppColors.gold),
            title: Text(AppLocalizations.of(context)!.profileTerms, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDangerousZone(BuildContext context) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.profileAccountManagement, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.redAccent)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.white70),
              label: Text(AppLocalizations.of(context)!.profileLogout, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                await context.read<AppState>().logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              label: Text(AppLocalizations.of(context)!.profileDeleteAccount, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
            border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
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
                  Text(AppLocalizations.of(context)!.profileDeleteAccountConfirmTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.profileDeleteAccountConfirmSub,
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppLocalizations.of(context)!.profileBtnCancel, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
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
                    label: Text(AppLocalizations.of(context)!.profileBtnDelete, style: const TextStyle(fontWeight: FontWeight.bold)),
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
