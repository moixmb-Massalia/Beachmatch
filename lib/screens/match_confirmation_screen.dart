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
      final doc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();
      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      _match = MatchModel.fromMap(doc.data()!, doc.id);
      
      // Fetch all participants
      List<UserModel> users = [];
      for (String userId in _match!.participantsIds) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          users.add(UserModel.fromMap(userDoc.data()!, userDoc.id));
          _presentUserIds.add(userId); // Default to all present
        }
      }

      setState(() {
        _participants = users;
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur chargement partie: $e");
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
    if (_isLoading) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Validation de la Partie", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("La partie est-elle bien terminée ?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text("Veuillez décocher les joueurs qui étaient absents pour ne pas leur attribuer de points.", style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 24),
            
            Expanded(
              child: ListView.builder(
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  final user = _participants[index];
                  final isPresent = _presentUserIds.contains(user.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isPresent ? AppColors.gold : Colors.white24, width: 2),
                    ),
                    child: CheckboxListTile(
                      activeColor: AppColors.gold,
                      checkColor: Colors.black,
                      title: Text(user.displayName, style: TextStyle(color: isPresent ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                      subtitle: Text(isPresent ? "+40 POINTS" : "Absent", style: TextStyle(color: isPresent ? AppColors.coral : Colors.redAccent, fontSize: 12)),
                      secondary: CircleAvatar(
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        backgroundColor: AppColors.coral,
                        child: user.photoUrl == null ? Text(user.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
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
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _presentUserIds.isEmpty ? null : _confirmMatch,
                child: const Text("Valider les présences", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
