import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../models/match.dart';
import '../models/user.dart';

class MatchConfirmationScreen extends StatefulWidget {
  final String matchId;

  const MatchConfirmationScreen({super.key, required this.matchId});

  @override
  State<MatchConfirmationScreen> createState() => _MatchConfirmationScreenState();
}

class _MatchConfirmationScreenState extends State<MatchConfirmationScreen> {
  bool _isLoading = true;
  MatchModel? _match;
  List<UserModel> _participants = [];
  final Set<String> _presentUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchMatchData();
  }

  Future<void> _fetchMatchData() async {
    try {
      final cachedPlayers = context.read<AppState>().players;
      final doc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();
      if (!mounted) return;
      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      _match = MatchModel.fromMap(doc.data()!, doc.id);
      
      // Fast in-memory resolution with AppState.players cache + parallel Future.wait
      List<UserModel> users = [];
      final cachedMap = {for (var p in cachedPlayers) p.id: p};

      final missingIds = <String>[];
      for (String userId in _match!.participantsIds) {
        if (cachedMap.containsKey(userId)) {
          users.add(cachedMap[userId]!);
          _presentUserIds.add(userId); // Default to all present
        } else {
          missingIds.add(userId);
        }
      }

      if (missingIds.isNotEmpty) {
        final fetchedDocs = await Future.wait(
          missingIds.map((id) => FirebaseFirestore.instance.collection('users').doc(id).get()),
        );
        for (var userDoc in fetchedDocs) {
          if (userDoc.exists && userDoc.data() != null) {
            final u = UserModel.fromMap(userDoc.data()!, userDoc.id);
            users.add(u);
            _presentUserIds.add(u.id);
          }
        }
      }

      setState(() {
        _participants = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur chargement partie: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmMatch() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AppState>().confirmMatch(widget.matchId, _presentUserIds.toList());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Partie validée ! Les points ont été distribués.", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _match == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (_match == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text("Partie introuvable.", style: TextStyle(color: Colors.white))),
      );
    }

    final court = context.watch<AppState>().courts.where((c) => c.id == _match!.courtId).firstOrNull;
    final courtName = court?.name ?? "Terrain";

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Validation de la Partie", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
              color: Colors.black.withValues(alpha: 0.82),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte récapitulative du match
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sports_tennis_rounded, color: AppColors.gold, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    courtName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${_match!.scheduledTime.day.toString().padLeft(2, '0')}/${_match!.scheduledTime.month.toString().padLeft(2, '0')} à ${_match!.scheduledTime.hour.toString().padLeft(2, '0')}h${_match!.scheduledTime.minute.toString().padLeft(2, '0')}",
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                "${_presentUserIds.length}/${_participants.length} présents",
                                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "La partie est-elle bien terminée ?",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Décochez les joueurs qui étaient absents pour ne pas leur attribuer de points.",
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: _participants.isEmpty
                        ? const Center(
                            child: Text(
                              "Aucun participant inscrit.",
                              style: TextStyle(color: Colors.white60),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _participants.length,
                            itemBuilder: (context, index) {
                              final user = _participants[index];
                              final isPresent = _presentUserIds.contains(user.id);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isPresent
                                      ? AppColors.gold.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isPresent ? AppColors.gold : Colors.white24,
                                    width: isPresent ? 2 : 1,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  activeColor: AppColors.gold,
                                  checkColor: Colors.black,
                                  title: Text(
                                    user.displayName.isEmpty ? "Joueur" : user.displayName,
                                    style: TextStyle(
                                      color: isPresent ? Colors.white : Colors.white54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isPresent ? "+40 POINTS" : "Absent (0 pt)",
                                    style: TextStyle(
                                      color: isPresent ? AppColors.coral : Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  secondary: CircleAvatar(
                                    backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                                        ? NetworkImage(user.photoUrl!)
                                        : null,
                                    backgroundColor: AppColors.coral,
                                    child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                                        ? Text(
                                            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : "?",
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          )
                                        : null,
                                  ),
                                  value: isPresent,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        _presentUserIds.add(user.id);
                                      } else {
                                        _presentUserIds.remove(user.id);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        disabledBackgroundColor: Colors.white12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 4,
                      ),
                      onPressed: (_presentUserIds.isEmpty || _isLoading) ? null : _confirmMatch,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                            )
                          : const Text(
                              "Valider les présences",
                              style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
