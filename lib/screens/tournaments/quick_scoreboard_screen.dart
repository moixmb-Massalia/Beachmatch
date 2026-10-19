import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/colors.dart';
import '../../services/sound_service.dart';

/// 🎾 Marqueur de Score Officiel Beach Tennis (No-Ad, Super Tie-Break, Changement de Côté)
class QuickScoreboardScreen extends StatefulWidget {
  const QuickScoreboardScreen({super.key});

  @override
  State<QuickScoreboardScreen> createState() => _QuickScoreboardScreenState();
}

class _QuickScoreboardScreenState extends State<QuickScoreboardScreen> {
  final TextEditingController _team1Ctrl = TextEditingController(text: "Paire 1");
  final TextEditingController _team2Ctrl = TextEditingController(text: "Paire 2");

  int _points1 = 0; // 0, 15, 30, 40 (No-Ad)
  int _points2 = 0;

  int _set1Games1 = 0;
  int _set1Games2 = 0;

  int _set2Games1 = 0;
  int _set2Games2 = 0;

  int _stbPoints1 = 0;
  int _stbPoints2 = 0;

  int _currentSet = 1;
  int _servingTeam = 1;
  int? _winner;
  bool _isSuperTieBreak = false;

  final List<Map<String, dynamic>> _history = [];

  static const List<String> _pointLabels = ["0", "15", "30", "40"];

  @override
  void dispose() {
    _team1Ctrl.dispose();
    _team2Ctrl.dispose();
    super.dispose();
  }

  void _saveState() {
    _history.add({
      'p1': _points1,
      'p2': _points2,
      's1g1': _set1Games1,
      's1g2': _set1Games2,
      's2g1': _set2Games1,
      's2g2': _set2Games2,
      'stb1': _stbPoints1,
      'stb2': _stbPoints2,
      'set': _currentSet,
      'serving': _servingTeam,
      'winner': _winner,
      'isStb': _isSuperTieBreak,
    });
    if (_history.length > 30) _history.removeAt(0);
  }

  void _undo() {
    if (_history.isEmpty) return;
    HapticFeedback.mediumImpact();
    final last = _history.removeLast();
    setState(() {
      _points1 = last['p1'];
      _points2 = last['p2'];
      _set1Games1 = last['s1g1'];
      _set1Games2 = last['s1g2'];
      _set2Games1 = last['s2g1'];
      _set2Games2 = last['s2g2'];
      _stbPoints1 = last['stb1'];
      _stbPoints2 = last['stb2'];
      _currentSet = last['set'];
      _servingTeam = last['serving'];
      _winner = last['winner'];
      _isSuperTieBreak = last['isStb'];
    });
  }

  void _addPoint(int team) {
    if (_winner != null) return;
    HapticFeedback.heavyImpact();
    SoundService.playScore();
    _saveState();

    setState(() {
      if (_isSuperTieBreak) {
        if (team == 1) {
          _stbPoints1++;
        } else {
          _stbPoints2++;
        }

        final totalStb = _stbPoints1 + _stbPoints2;
        if (totalStb % 2 == 1) {
          _servingTeam = _servingTeam == 1 ? 2 : 1;
        }

        if (_stbPoints1 >= 10 && _stbPoints1 - _stbPoints2 >= 2) {
          _winner = 1;
          _showVictoryDialog(1);
        } else if (_stbPoints2 >= 10 && _stbPoints2 - _stbPoints1 >= 2) {
          _winner = 2;
          _showVictoryDialog(2);
        }
        return;
      }

      if (team == 1) {
        if (_points1 == 3) {
          _winGame(1);
        } else {
          _points1++;
        }
      } else {
        if (_points2 == 3) {
          _winGame(2);
        } else {
          _points2++;
        }
      }
    });
  }

  void _winGame(int team) {
    _points1 = 0;
    _points2 = 0;
    _servingTeam = _servingTeam == 1 ? 2 : 1;

    if (_currentSet == 1) {
      if (team == 1) {
        _set1Games1++;
      } else {
        _set1Games2++;
      }

      if ((_set1Games1 >= 6 && _set1Games1 - _set1Games2 >= 2) || _set1Games1 == 7) {
        _currentSet = 2;
        _showSetDialog(1, _team1Ctrl.text);
      } else if ((_set1Games2 >= 6 && _set1Games2 - _set1Games1 >= 2) || _set1Games2 == 7) {
        _currentSet = 2;
        _showSetDialog(1, _team2Ctrl.text);
      }
    } else if (_currentSet == 2) {
      if (team == 1) {
        _set2Games1++;
      } else {
        _set2Games2++;
      }

      final set1WonBy1 = _set1Games1 > _set1Games2;
      final set2WonBy1 = (_set2Games1 >= 6 && _set2Games1 - _set2Games2 >= 2) || _set2Games1 == 7;
      final set2WonBy2 = (_set2Games2 >= 6 && _set2Games2 - _set2Games1 >= 2) || _set2Games2 == 7;

      if (set2WonBy1) {
        if (set1WonBy1) {
          _winner = 1;
          _showVictoryDialog(1);
        } else {
          _currentSet = 3;
          _isSuperTieBreak = true;
          _showStbDialog();
        }
      } else if (set2WonBy2) {
        if (!set1WonBy1) {
          _winner = 2;
          _showVictoryDialog(2);
        } else {
          _currentSet = 3;
          _isSuperTieBreak = true;
          _showStbDialog();
        }
      }
    }
  }

  void _showSetDialog(int setNum, String winnerName) {
    final isBr = context.read<AppState>().currentUser?.isBrazilian == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isBr
            ? "🎾 $winnerName venceu o Set $setNum ! Iniciando Set ${setNum + 1}."
            : "🎾 $winnerName a remporté le Set $setNum ! Début du Set ${setNum + 1}."),
        backgroundColor: AppColors.gold,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showStbDialog() {
    final isBr = context.read<AppState>().currentUser?.isBrazilian == true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162032),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.gold, width: 2)),
        title: Row(
          children: [
            const Icon(Icons.flash_on_rounded, color: AppColors.gold, size: 28),
            const SizedBox(width: 10),
            Text(
              isBr ? "Super Tie-Break !" : "Super Tie-Break !",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(
          isBr
              ? "1 Set a 1 ! A partida será decidida em um Super Tie-Break emocionante até 10 pontos (com 2 de diferença)."
              : "1 Set partout ! Le match va se décider au Super Tie-Break décisif en 10 points gagnants (avec 2 points d'écart).",
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isBr ? "Iniciar Super TB 🔥" : "Lancer le Super TB 🔥", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showVictoryDialog(int winningTeam) {
    SoundService.playVictory();
    final isBr = context.read<AppState>().currentUser?.isBrazilian == true;
    final winnerName = winningTeam == 1 ? _team1Ctrl.text : _team2Ctrl.text;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162032),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.gold, width: 2)),
        title: Column(
          children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 48),
            const SizedBox(height: 8),
            Text(
              isBr ? "VITÓRIA !" : "VICTOIRE !",
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 22),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              winnerName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              isBr
                  ? "Placar final : $_set1Games1/$_set1Games2 · $_set2Games1/$_set2Games2 ${_isSuperTieBreak ? '· [$_stbPoints1-$_stbPoints2]' : ''}"
                  : "Score final : $_set1Games1/$_set1Games2 · $_set2Games1/$_set2Games2 ${_isSuperTieBreak ? '· [$_stbPoints1-$_stbPoints2]' : ''}",
              style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetMatch();
            },
            child: Text(isBr ? "Nova Partida" : "Nouveau Match", style: const TextStyle(color: AppColors.gold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isBr ? "Concluir" : "Terminer", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _resetMatch() {
    _saveState();
    setState(() {
      _points1 = 0;
      _points2 = 0;
      _set1Games1 = 0;
      _set1Games2 = 0;
      _set2Games1 = 0;
      _set2Games2 = 0;
      _stbPoints1 = 0;
      _stbPoints2 = 0;
      _currentSet = 1;
      _servingTeam = 1;
      _winner = null;
      _isSuperTieBreak = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBr = context.watch<AppState>().currentUser?.isBrazilian == true;
    final totalGames = (_currentSet == 1 ? _set1Games1 + _set1Games2 : _set2Games1 + _set2Games2);
    final shouldChangeEnds = !_isSuperTieBreak && totalGames > 0 && totalGames % 2 == 1 && _points1 == 0 && _points2 == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10192D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.sports_tennis_rounded, color: AppColors.gold, size: 22),
            const SizedBox(width: 8),
            Text(
              isBr ? "Placar de Jogo" : "Marqueur de Score",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded, color: Colors.white70),
            tooltip: isBr ? "Desfazer ponto" : "Annuler point",
            onPressed: _history.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: isBr ? "Zerar partida" : "Réinitialiser",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF162032),
                  title: Text(isBr ? "Zerar partida ?" : "Réinitialiser le match ?", style: const TextStyle(color: Colors.white)),
                  content: Text(
                    isBr ? "Todos os pontos e sets serão zerados." : "Tous les points et sets actuels seront remis à zéro.",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isBr ? "Cancelar" : "Annuler", style: const TextStyle(color: Colors.white60))),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetMatch();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: Text(isBr ? "Zerar" : "Réinitialiser", style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🟡 Bandeau d'état : Set en cours / Changement de côté
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: shouldChangeEnds ? AppColors.gold : const Color(0xFF142036),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    shouldChangeEnds ? Icons.swap_horiz_rounded : Icons.fiber_manual_record_rounded,
                    color: shouldChangeEnds ? Colors.black : AppColors.gold,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    shouldChangeEnds
                        ? (isBr ? "TROCA DE LADO ! (Número ímpar de games)" : "CHANGEMENT DE CÔTÉ ! (Nombre impair de jeux)")
                        : (_isSuperTieBreak
                            ? (isBr ? "SUPER TIE-BREAK (ATÉ 10 PTS)" : "SUPER TIE-BREAK (10 POINTS)")
                            : (isBr ? "SET $_currentSet EM ANDAMENTO (NO-AD)" : "SET $_currentSet EN COURS (POINT DÉCISIF NO-AD)")),
                    style: TextStyle(
                      color: shouldChangeEnds ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // 🏆 RÉCAPITULATIF DES SETS EN DIRECT
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isBr ? "PLACAR OFICIAL" : "SCORE OFFICIEL",
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  _buildSetHeaderCell("S1"),
                  _buildSetHeaderCell("S2"),
                  if (_isSuperTieBreak || _currentSet == 3) _buildSetHeaderCell("STB"),
                  _buildSetHeaderCell("JEU", width: 50, color: AppColors.gold),
                ],
              ),
            ),

            // 👥 LIGNE SCORE ÉQUIPE 1
            _buildTeamScoreRow(
              teamNum: 1,
              controller: _team1Ctrl,
              isServing: _servingTeam == 1,
              s1: _set1Games1,
              s2: _set2Games1,
              stb: _stbPoints1,
              currentPoints: _isSuperTieBreak ? _stbPoints1.toString() : _pointLabels[_points1],
              isWinner: _winner == 1,
            ),

            const Divider(color: Colors.white12, height: 1),

            // 👥 LIGNE SCORE ÉQUIPE 2
            _buildTeamScoreRow(
              teamNum: 2,
              controller: _team2Ctrl,
              isServing: _servingTeam == 2,
              s1: _set1Games2,
              s2: _set2Games2,
              stb: _stbPoints2,
              currentPoints: _isSuperTieBreak ? _stbPoints2.toString() : _pointLabels[_points2],
              isWinner: _winner == 2,
            ),

            const Spacer(),

            // 🎾 GRANDES ZONES TACTILES POUR MARQUER LES POINTS (+1 POINT)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // BOUTON POINT ÉQUIPE 1
                  Expanded(
                    child: _buildBigPointButton(
                      teamNum: 1,
                      teamName: _team1Ctrl.text,
                      pointText: _isSuperTieBreak ? "+1 PT" : (_points1 == 3 ? "Balle de Jeu" : "+ POINT"),
                      color: const Color(0xFF2563EB),
                      onTap: () => _addPoint(1),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // BOUTON POINT ÉQUIPE 2
                  Expanded(
                    child: _buildBigPointButton(
                      teamNum: 2,
                      teamName: _team2Ctrl.text,
                      pointText: _isSuperTieBreak ? "+1 PT" : (_points2 == 3 ? "Balle de Jeu" : "+ POINT"),
                      color: const Color(0xFFE11D48),
                      onTap: () => _addPoint(2),
                    ),
                  ),
                ],
              ),
            ),

            // 🔄 Bouton rapide Changement de Serveur
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _servingTeam = _servingTeam == 1 ? 2 : 1);
                },
                icon: const Icon(Icons.sports_tennis_rounded, color: AppColors.gold, size: 16),
                label: Text(
                  isBr
                      ? "Mudar Sacador (Atual: ${_servingTeam == 1 ? _team1Ctrl.text : _team2Ctrl.text})"
                      : "Changer de Serveur (Actuel: ${_servingTeam == 1 ? _team1Ctrl.text : _team2Ctrl.text})",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetHeaderCell(String label, {double width = 36, Color color = Colors.white60}) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(left: 6),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildTeamScoreRow({
    required int teamNum,
    required TextEditingController controller,
    required bool isServing,
    required int s1,
    required int s2,
    required int stb,
    required String currentPoints,
    required bool isWinner,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: isWinner
          ? AppColors.gold.withValues(alpha: 0.15)
          : (isServing ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.transparent),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            child: isServing
                ? Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCCFF00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFCCFF00), blurRadius: 6, spreadRadius: 1),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: isWinner ? AppColors.gold : Colors.white,
                fontWeight: isWinner ? FontWeight.w900 : FontWeight.bold,
                fontSize: 15,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          _buildScoreCell(s1.toString(), isActive: _currentSet == 1),
          _buildScoreCell(s2.toString(), isActive: _currentSet == 2),
          if (_isSuperTieBreak || _currentSet == 3)
            _buildScoreCell(stb.toString(), isActive: _isSuperTieBreak, isStb: true),

          Container(
            width: 50,
            height: 38,
            margin: const EdgeInsets.only(left: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFF59E0B)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Text(
              currentPoints,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCell(String score, {bool isActive = false, bool isStb = false}) {
    return Container(
      width: 36,
      height: 34,
      margin: const EdgeInsets.only(left: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? (isStb ? AppColors.coral : AppColors.gold) : Colors.white24,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Text(
        score,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white70,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildBigPointButton({
    required int teamNum,
    required String teamName,
    required String pointText,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 130,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                teamName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pointText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
