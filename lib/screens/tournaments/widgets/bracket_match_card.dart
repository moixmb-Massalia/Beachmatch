import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../models/tournament_bracket_model.dart';
import '../../../theme/colors.dart';
import 'bracket_pair_row.dart';
import 'bracket_pair_slot.dart';

/// Carte de match officielle dans le tableau du tournoi (Principal ou Consolante)
/// avec Glassmorphism, statut dynamique, attribution de terrain, bouton d'appel,
/// affichage du score et actions JAT ultra-rapides.
class BracketMatchCard extends StatelessWidget {
  final BracketMatch match;
  final TournamentBracket bracket;
  final bool isConsolation;
  final bool isJat;
  final BracketPairSlot? selectedSwapSlot;
  final void Function({
    required int court,
    required String roundName,
    required String pair1Name,
    required String pair2Name,
  })? onBroadcastCourtCall;
  final VoidCallback? onQuickScore;
  final VoidCallback? onManualEdit;
  final void Function(BracketPairSlot slot)? onSwapSlotSelected;
  final VoidCallback? onSwapSlotCleared;
  final void Function({
    required BracketPairSlot source,
    required BracketPairSlot target,
    required TournamentBracket bracket,
  })? onExecuteSwap;

  const BracketMatchCard({
    super.key,
    required this.match,
    required this.bracket,
    this.isConsolation = false,
    this.isJat = false,
    this.selectedSwapSlot,
    this.onBroadcastCourtCall,
    this.onQuickScore,
    this.onManualEdit,
    this.onSwapSlotSelected,
    this.onSwapSlotCleared,
    this.onExecuteSwap,
  });

  Widget _buildRoundTitleBadge() {
    final id = match.id.toLowerCase();
    final rName = match.roundName.toLowerCase();

    String title;
    Color color;
    Color bg;
    Color border;

    if (id.contains('main_2_0') || (rName.contains('finale') && !rName.contains('petite') && !rName.contains('conso') && !isConsolation)) {
      title = "🏆 GRANDE FINALE (Places 1 & 2)";
      color = AppColors.gold;
      bg = AppColors.gold.withValues(alpha: 0.2);
      border = AppColors.gold.withValues(alpha: 0.6);
    } else if (id.contains('place_3_4') || rName.contains('petite') || (rName.contains('3') && rName.contains('4'))) {
      title = "🥉 PETITE FINALE (Places 3 & 4)";
      color = const Color(0xFFF59E0B);
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.2);
      border = const Color(0xFFF59E0B).withValues(alpha: 0.5);
    } else if (id.contains('conso_1_0') || (isConsolation && (rName.contains('finale') || (rName.contains('5') && rName.contains('6'))))) {
      title = "🛡️ FINALE CONSO (Places 5 & 6)";
      color = Colors.cyanAccent;
      bg = Colors.cyanAccent.withValues(alpha: 0.15);
      border = Colors.cyanAccent.withValues(alpha: 0.4);
    } else if (id.contains('conso_place_7_8') || id.contains('place_7_8') || (rName.contains('7') && rName.contains('8'))) {
      title = "🏅 PLACES 7 & 8";
      color = const Color(0xFFC084FC);
      bg = const Color(0xFFC084FC).withValues(alpha: 0.15);
      border = const Color(0xFFC084FC).withValues(alpha: 0.4);
    } else if (id.contains('df_5_8') || rName.contains('places 5-8')) {
      title = "Places 5-8";
      color = Colors.white70;
      bg = Colors.white.withValues(alpha: 0.08);
      border = Colors.white.withValues(alpha: 0.15);
    } else if (match.roundName.isNotEmpty) {
      title = match.roundName;
      color = Colors.white70;
      bg = Colors.white.withValues(alpha: 0.08);
      border = Colors.white.withValues(alpha: 0.15);
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = match.isCompleted
        ? Colors.greenAccent.withValues(alpha: 0.45)
        : (match.isInProgress
            ? AppColors.gold.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.16));

    final isByeMatch = match.isBye;

    if (isByeMatch) {
      final realPair = match.pair1?.isBye == false
          ? match.pair1
          : (match.pair2?.isBye == false ? match.pair2 : null);
      final seedText = realPair?.seed != null ? " [TS${realPair!.seed}]" : "";
      final name = realPair?.displayName ?? "EXEMPT";
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                match.roundName,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "$name$seedText qualifié d'office",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 0.8),
              ),
              child: const Text(
                "EXEMPT",
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: match.isInProgress
                  ? AppColors.gold.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bandeau Statut & Court & Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildRoundTitleBadge(),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: match.isCompleted
                              ? Colors.greenAccent.withValues(alpha: 0.2)
                              : (match.isInProgress
                                  ? AppColors.gold.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          match.isCompleted
                              ? "TERMINÉ"
                              : (match.isInProgress ? "EN COURS" : "À VENIR"),
                          style: TextStyle(
                            color: match.isCompleted
                                ? Colors.greenAccent
                                : (match.isInProgress ? AppColors.gold : Colors.white60),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (match.court != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.blueAccent.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Text(
                            "TERRAIN ${match.court}",
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Appel Terrain (si 2 paires assignées et match non terminé)
                      if (isJat && !isByeMatch && !match.isCompleted && match.pair1 != null && match.pair2 != null) ...[
                        InkWell(
                          onTap: () => onBroadcastCourtCall?.call(
                            court: match.court ?? 1,
                            roundName: match.roundName,
                            pair1Name: match.pair1!.displayName,
                            pair2Name: match.pair2!.displayName,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.campaign_rounded, size: 12, color: AppColors.gold),
                                SizedBox(width: 3),
                                Text(
                                  "Appeler",
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      // Score (si match terminé) - Cliquable par le JAT pour modification rapide
                      if (match.score != null)
                        InkWell(
                          onTap: isJat && !isByeMatch ? onQuickScore : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: Text(
                              match.score!,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      // Bouton Action JAT Express (Saisir Score ou Modifier)
                      if (isJat && !isByeMatch) ...[
                        const SizedBox(width: 5),
                        InkWell(
                          onTap: onQuickScore,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gold.withValues(alpha: 0.95),
                                  AppColors.gold,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 11, color: Colors.black),
                                const SizedBox(width: 2),
                                Text(
                                  match.isCompleted ? "Modifier" : "Saisir",
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.white70, size: 17),
                          tooltip: "Saisie libre JAT",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onManualEdit,
                        ),
                      ],
                    ],
                  ),
                ),

                // Paires 1 et 2
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    children: [
                      BracketPairRow(
                        pair: match.pair1,
                        isWinner: match.winnerId == match.pair1?.id,
                        isCompleted: match.isCompleted,
                        fallbackLabel: "Paire 1",
                        match: match,
                        slot: 1,
                        bracket: bracket,
                        isJat: isJat,
                        selectedSwapSlot: selectedSwapSlot,
                        onSwapSlotSelected: onSwapSlotSelected,
                        onSwapSlotCleared: onSwapSlotCleared,
                        onExecuteSwap: onExecuteSwap,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      BracketPairRow(
                        pair: match.pair2,
                        isWinner: match.winnerId == match.pair2?.id,
                        isCompleted: match.isCompleted,
                        fallbackLabel: isByeMatch ? "EXEMPT (BYE)" : "Paire 2",
                        match: match,
                        slot: 2,
                        bracket: bracket,
                        isJat: isJat,
                        selectedSwapSlot: selectedSwapSlot,
                        onSwapSlotSelected: onSwapSlotSelected,
                        onSwapSlotCleared: onSwapSlotCleared,
                        onExecuteSwap: onExecuteSwap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
