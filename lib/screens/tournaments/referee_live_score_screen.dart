import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/colors.dart';
import '../../models/live_match_model.dart';
import '../../models/tournament.dart';

class RefereeLiveScoreScreen extends StatefulWidget {
  final TournamentModel tournament;
  final LiveMatchModel? match; // If null, creates a new live match

  const RefereeLiveScoreScreen({
    super.key,
    required this.tournament,
    this.match,
  });

  @override
  State<RefereeLiveScoreScreen> createState() => _RefereeLiveScoreScreenState();
}

class _RefereeLiveScoreScreenState extends State<RefereeLiveScoreScreen> {
  late TextEditingController _team1Ctrl;
  late TextEditingController _team2Ctrl;
  late TextEditingController _courtCtrl;
  late String _selectedRound;

  final List<String> _rounds = [
    'Finale 🏆',
    '1/2 Finale',
    '1/4 Finale',
    '1/8 de Finale',
    '1/16 de Finale',
    '1/32 de Finale',
    'Petite Finale (3e place)',
    'Phase de Poules',
  ];

  late int _set1Team1;
  late int _set1Team2;
  late int _set2Team1;
  late int _set2Team2;
  int? _set3Team1;
  int? _set3Team2;
  late int _currentSet; // 1, 2, 3
  late int _servingTeam; // 1 or 2
  late String _status; // 'LIVE', 'FINISHED', 'PAUSED'
  int? _winner; // 1 or 2
  String? _matchId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    final m = widget.match;
    _matchId = m?.id;
    _team1Ctrl = TextEditingController(text: m?.team1 ?? 'Paire A');
    _team2Ctrl = TextEditingController(text: m?.team2 ?? 'Paire B');
    _courtCtrl = TextEditingController(text: m?.courtName ?? 'Court Central');

    final r = m?.round ?? 'Finale 🏆';
    _selectedRound = _rounds.contains(r) ? r : _rounds.first;

    _set1Team1 = m?.set1Team1 ?? 0;
    _set1Team2 = m?.set1Team2 ?? 0;
    _set2Team1 = m?.set2Team1 ?? 0;
    _set2Team2 = m?.set2Team2 ?? 0;
    _set3Team1 = m?.set3Team1;
    _set3Team2 = m?.set3Team2;
    _currentSet = m?.currentSet ?? 1;
    _servingTeam = m?.servingTeam ?? 1;
    _status = m?.status ?? 'LIVE';
    _winner = m?.winner;

    if (_matchId == null) {
      _createLiveMatchInFirestore();
    } else {
      _isInitialized = true;
    }
  }

  Future<void> _createLiveMatchInFirestore() async {
    final docRef = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament.id)
        .collection('live_matches')
        .doc();

    _matchId = docRef.id;
    await _syncToFirestore();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _syncToFirestore() async {
    if (_matchId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('live_matches')
          .doc(_matchId)
          .set({
        'tournamentId': widget.tournament.id,
        'courtName': _courtCtrl.text.trim(),
        'round': _selectedRound,
        'team1': _team1Ctrl.text.trim(),
        'team2': _team2Ctrl.text.trim(),
        'set1Team1': _set1Team1,
        'set1Team2': _set1Team2,
        'set2Team1': _set2Team1,
        'set2Team2': _set2Team2,
        'set3Team1': _set3Team1,
        'set3Team2': _set3Team2,
        'currentSet': _currentSet,
        'servingTeam': _servingTeam,
        'status': _status,
        'winner': _winner,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Erreur sync live score: $e");
    }
  }

  // 🎾 Vérification des Règles Officielles du Beach Tennis
  // Set normal (premier à 6 jeux avec 2 d'écart, ou 7-5, ou 7-6 Tie-Break)
  int _checkSetWinner(int s1, int s2) {
    if (s1 >= 6 && (s1 - s2) >= 2) return 1;
    if (s2 >= 6 && (s2 - s1) >= 2) return 2;
    if (s1 == 7 && (s2 == 5 || s2 == 6)) return 1;
    if (s2 == 7 && (s1 == 5 || s1 == 6)) return 2;
    return 0; // Set toujours en cours
  }

  // Super Tie-Break au 3e Set (premier à 10 points avec 2 d'écart)
  int _checkSuperTbWinner(int p1, int p2) {
    if (p1 >= 10 && (p1 - p2) >= 2) return 1;
    if (p2 >= 10 && (p2 - p1) >= 2) return 2;
    return 0; // Super TB toujours en cours
  }

  void _addScore(int team) {
    if (_status == 'FINISHED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le match est terminé. Cliquez sur 'Réinitialiser' ou modifiez les scores si besoin.")),
      );
      return;
    }

    HapticFeedback.heavyImpact();

    setState(() {
      // 1. SET 1
      if (_currentSet == 1) {
        if (team == 1) _set1Team1++; else _set1Team2++;
        _servingTeam = _servingTeam == 1 ? 2 : 1;

        final set1Winner = _checkSetWinner(_set1Team1, _set1Team2);
        if (set1Winner != 0) {
          final winnerName = set1Winner == 1 ? _team1Ctrl.text : _team2Ctrl.text;
          _currentSet = 2;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🎾 Set 1 remporté par $winnerName ($_set1Team1/$_set1Team2) ! Passage au Set 2."),
              backgroundColor: const Color(0xFF00A86B),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      // 2. SET 2
      else if (_currentSet == 2) {
        if (team == 1) _set2Team1++; else _set2Team2++;
        _servingTeam = _servingTeam == 1 ? 2 : 1;

        final set2Winner = _checkSetWinner(_set2Team1, _set2Team2);
        if (set2Winner != 0) {
          final set1Winner = _checkSetWinner(_set1Team1, _set1Team2);

          // Si la même équipe gagne Set 1 et Set 2 ➔ Victoire 2-0 !
          if (set2Winner == set1Winner) {
            _status = 'FINISHED';
            _winner = set2Winner;
            _showVictoryModal(set2Winner);
          } else {
            // 1 Set Partout (1-1) ➔ Super Tie-Break en 10 points au 3e Set !
            _currentSet = 3;
            _set3Team1 = 0;
            _set3Team2 = 0;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("⚡ 1 Set Partout ! Début du Super Tie-Break décisif (10 points gagnants)."),
                backgroundColor: AppColors.coral,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
      // 3. SET 3 (SUPER TIE-BREAK À 10 POINTS)
      else if (_currentSet == 3) {
        _set3Team1 ??= 0;
        _set3Team2 ??= 0;
        if (team == 1) _set3Team1 = _set3Team1! + 1; else _set3Team2 = _set3Team2! + 1;

        // Au Super TB, le service change tous les 2 points (après le 1er point)
        final totalPoints = _set3Team1! + _set3Team2!;
        if (totalPoints % 2 == 1) {
          _servingTeam = _servingTeam == 1 ? 2 : 1;
        }

        final superTbWinner = _checkSuperTbWinner(_set3Team1!, _set3Team2!);
        if (superTbWinner != 0) {
          _status = 'FINISHED';
          _winner = superTbWinner;
          _showVictoryModal(superTbWinner);
        }
      }
    });

    _syncToFirestore();
  }

  void _removeScore(int team) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_status == 'FINISHED') {
        _status = 'LIVE';
        _winner = null;
      }

      if (_currentSet == 1) {
        if (team == 1 && _set1Team1 > 0) _set1Team1--;
        if (team == 2 && _set1Team2 > 0) _set1Team2--;
      } else if (_currentSet == 2) {
        if (team == 1 && _set2Team1 > 0) {
          _set2Team1--;
        } else if (team == 2 && _set2Team2 > 0) {
          _set2Team2--;
        } else if (_set2Team1 == 0 && _set2Team2 == 0) {
          // Revenir au Set 1 si on annule à 0-0 au Set 2
          _currentSet = 1;
          if (team == 1 && _set1Team1 > 0) _set1Team1--;
          if (team == 2 && _set1Team2 > 0) _set1Team2--;
        }
      } else if (_currentSet == 3) {
        if (team == 1 && (_set3Team1 ?? 0) > 0) {
          _set3Team1 = _set3Team1! - 1;
        } else if (team == 2 && (_set3Team2 ?? 0) > 0) {
          _set3Team2 = _set3Team2! - 1;
        } else if ((_set3Team1 ?? 0) == 0 && (_set3Team2 ?? 0) == 0) {
          // Revenir au Set 2 si on annule à 0-0 au Super TB
          _currentSet = 2;
          if (team == 1 && _set2Team1 > 0) _set2Team1--;
          if (team == 2 && _set2Team2 > 0) _set2Team2--;
        }
      }
    });
    _syncToFirestore();
  }

  void _switchServer() {
    HapticFeedback.selectionClick();
    setState(() => _servingTeam = _servingTeam == 1 ? 2 : 1);
    _syncToFirestore();
  }

  void _showVictoryModal(int winningTeam) {
    final winnerName = winningTeam == 1 ? _team1Ctrl.text : _team2Ctrl.text;
    String scoreSummary = "$_set1Team1/$_set1Team2, $_set2Team1/$_set2Team2";
    if (_set3Team1 != null && _set3Team2 != null) {
      scoreSummary += ", [$_set3Team1-$_set3Team2]";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.gold, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 28),
            SizedBox(width: 10),
            Text("MATCH TERMINÉ !", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("🏆 Victoire officielle de :", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
            const SizedBox(height: 6),
            Text(winnerName, style: const TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Score final : $scoreSummary",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK, Résultat Publié ✓", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ✏️ Dialogue Rapide pour Modifier le Nom d'une Paire en 1 Clic
  void _quickEditTeamName(int teamNum) {
    final ctrl = TextEditingController(text: teamNum == 1 ? _team1Ctrl.text : _team2Ctrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold.withOpacity(0.5), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_rounded, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text("Renommer Paire $teamNum", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Ex: Dupont / Martin",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  if (teamNum == 1) _team1Ctrl.text = newName; else _team2Ctrl.text = newName;
                });
                _syncToFirestore();
              }
              Navigator.pop(ctx);
            },
            child: const Text("Enregistrer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ✏️ Dialogue Rapide pour Modifier le Nom du Court
  void _quickEditCourtName() {
    final ctrl = TextEditingController(text: _courtCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold.withOpacity(0.5), width: 1.5),
        ),
        title: const Text("Terrain / Court", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Ex: Court Central, Court 1...",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                setState(() => _courtCtrl.text = newName);
                _syncToFirestore();
              }
              Navigator.pop(ctx);
            },
            child: const Text("Enregistrer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t1Name = _team1Ctrl.text.isEmpty ? "Paire A" : _team1Ctrl.text;
    final t2Name = _team2Ctrl.text.isEmpty ? "Paire B" : _team2Ctrl.text;
    final isSuperTb = _currentSet == 3;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: _status == 'LIVE' ? Colors.redAccent : Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: _status == 'LIVE' ? [const BoxShadow(color: Colors.redAccent, blurRadius: 6, spreadRadius: 1)] : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _status == 'LIVE' ? "CONSOLE ARBITRE EN DIRECT" : "MATCH TERMINÉ",
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ],
            ),
            Text(
              widget.tournament.name,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // 📋 BANDEAU SUPÉRIEUR : Menu Déroulant Tour + Court (Modifiables en 1 Clic Direct)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141D30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    // Court cliquable
                    GestureDetector(
                      onTap: _quickEditCourtName,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, color: AppColors.gold, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _courtCtrl.text,
                              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.edit, color: Colors.white38, size: 10),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 🏆 Menu Déroulant Direct du Tour (1/32e à Finale)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.coral.withOpacity(0.5)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRound,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0F1B29),
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.coral),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5),
                            items: _rounds.map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            )).toList(),
                            onChanged: (newRound) {
                              if (newRound != null) {
                                setState(() => _selectedRound = newRound);
                                _syncToFirestore();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 📊 TABLEAU DE MARQUE DIGITAL OFFICIEL (Clic Direct sur les Équipes pour Renommer)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF0F1B29).withOpacity(0.98), const Color(0xFF16253B).withOpacity(0.95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _winner != null ? AppColors.gold : AppColors.coral.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  children: [
                    // Sélecteur d'onglets de Set
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSetIndicator(1, "Set 1", isCurrent: _currentSet == 1),
                        const SizedBox(width: 8),
                        _buildSetIndicator(2, "Set 2", isCurrent: _currentSet == 2),
                        const SizedBox(width: 8),
                        _buildSetIndicator(3, "Set 3 (Super TB)", isCurrent: _currentSet == 3),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    const SizedBox(height: 14),

                    // Ligne ÉQUIPE 1 (Clic direct pour renommer)
                    _buildTeamScoreRow(
                      teamNum: 1,
                      teamName: t1Name,
                      isServing: _servingTeam == 1,
                      set1: _set1Team1,
                      set2: _set2Team1,
                      set3: _set3Team1,
                      isWinner: _winner == 1,
                      onTapName: () => _quickEditTeamName(1),
                    ),
                    const SizedBox(height: 10),

                    // Ligne ÉQUIPE 2 (Clic direct pour renommer)
                    _buildTeamScoreRow(
                      teamNum: 2,
                      teamName: t2Name,
                      isServing: _servingTeam == 2,
                      set1: _set1Team2,
                      set2: _set2Team2,
                      set3: _set3Team2,
                      isWinner: _winner == 2,
                      onTapName: () => _quickEditTeamName(2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 🎾 GROS BOUTONS DE COMMANDE ARBITRE (JEU PAR JEU / POINT PAR POINT SUPER TB)
              Row(
                children: [
                  // Bouton Équipe 1
                  Expanded(
                    child: _buildActionButton(
                      label: isSuperTb ? "+1 POINT" : "+1 JEU",
                      sublabel: t1Name,
                      color: const Color(0xFFE8604C),
                      icon: isSuperTb ? Icons.sports_tennis_rounded : Icons.add_circle_outline_rounded,
                      onTap: () => _addScore(1),
                      onMinus: () => _removeScore(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Bouton Équipe 2
                  Expanded(
                    child: _buildActionButton(
                      label: isSuperTb ? "+1 POINT" : "+1 JEU",
                      sublabel: t2Name,
                      color: const Color(0xFF00A86B),
                      icon: isSuperTb ? Icons.sports_tennis_rounded : Icons.add_circle_outline_rounded,
                      onTap: () => _addScore(2),
                      onMinus: () => _removeScore(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 🎛️ Commandes Auxiliaires : Serveur & Clôture / Réinitialisation
              Row(
                children: [
                  // Serveur
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: AppColors.gold.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.sports_tennis_rounded, color: AppColors.gold, size: 17),
                      label: Text("Serveur : Paire $_servingTeam 🎾", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _switchServer,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Clôturer / Réinitialiser
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _status == 'FINISHED' ? Colors.grey.shade800 : const Color(0xFFF4A535),
                        foregroundColor: _status == 'FINISHED' ? Colors.white70 : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(_status == 'FINISHED' ? Icons.refresh_rounded : Icons.emoji_events_rounded, size: 17),
                      label: Text(
                        _status == 'FINISHED' ? "Réinitialiser" : "Clôturer le Match",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      onPressed: () {
                        if (_status == 'FINISHED') {
                          setState(() {
                            _set1Team1 = 0; _set1Team2 = 0;
                            _set2Team1 = 0; _set2Team2 = 0;
                            _set3Team1 = null; _set3Team2 = null;
                            _currentSet = 1;
                            _status = 'LIVE';
                            _winner = null;
                          });
                          _syncToFirestore();
                        } else {
                          // Modal pour désigner manuellement le vainqueur
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: const Color(0xFF0F1B29),
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                            builder: (ctx) => Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("Valider la Victoire de :", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 14),
                                  ListTile(
                                    leading: const Icon(Icons.military_tech_rounded, color: AppColors.gold),
                                    title: Text(t1Name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      setState(() { _status = 'FINISHED'; _winner = 1; });
                                      _syncToFirestore();
                                      _showVictoryModal(1);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.military_tech_rounded, color: AppColors.gold),
                                    title: Text(t2Name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      setState(() { _status = 'FINISHED'; _winner = 2; });
                                      _syncToFirestore();
                                      _showVictoryModal(2);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetIndicator(int setNum, String label, {required bool isCurrent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.coral : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isCurrent ? AppColors.coral : Colors.white.withOpacity(0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w500,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _buildTeamScoreRow({
    required int teamNum,
    required String teamName,
    required bool isServing,
    required int set1,
    required int set2,
    required int? set3,
    required bool isWinner,
    required VoidCallback onTapName,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isWinner ? AppColors.gold.withOpacity(0.15) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWinner ? AppColors.gold : (isServing ? AppColors.coral.withOpacity(0.6) : Colors.transparent),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Balle de service
          if (isServing)
            const Text("🎾 ", style: TextStyle(fontSize: 14))
          else
            const SizedBox(width: 22),

          // Nom de l'équipe (Cliquable en 1 tap avec icône crayon)
          Expanded(
            child: GestureDetector(
              onTap: onTapName,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      teamName,
                      style: TextStyle(
                        color: isWinner ? AppColors.gold : Colors.white,
                        fontWeight: isWinner ? FontWeight.w900 : FontWeight.bold,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_rounded, color: Colors.white.withOpacity(0.4), size: 13),
                ],
              ),
            ),
          ),

          // Scores par Set
          _buildScoreBox(set1, isActiveSet: _currentSet == 1),
          const SizedBox(width: 6),
          _buildScoreBox(set2, isActiveSet: _currentSet == 2),
          if (set3 != null || _currentSet == 3) ...[
            const SizedBox(width: 6),
            _buildScoreBox(set3 ?? 0, isActiveSet: _currentSet == 3, isSuperTb: true),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreBox(int score, {required bool isActiveSet, bool isSuperTb = false}) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActiveSet ? AppColors.coral.withOpacity(0.3) : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActiveSet ? AppColors.coral : Colors.white.withOpacity(0.2),
          width: isActiveSet ? 1.5 : 1,
        ),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(
          color: isActiveSet ? AppColors.gold : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String sublabel,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onMinus,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                child: Column(
                  children: [
                    Icon(icon, color: color, size: 34),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sublabel,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(color: color.withOpacity(0.3), height: 1),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              onTap: onMinus,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_circle_outline_rounded, color: Colors.white54, size: 15),
                    SizedBox(width: 4),
                    Text("Annuler (-1)", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
