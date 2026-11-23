import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../models/tournament_bracket_model.dart';
import '../../../services/bracket_generator_service.dart';
import '../../../theme/colors.dart';

/// Feuille modale d'action express JAT :
/// Saisie du score en 1 clic (presets FFT officiels), sélection du vainqueur,
/// attribution immédiate du terrain et diffusion d'appels terrain / convocation WhatsApp/SMS.
class JatQuickActionSheet {
  static void show(
    BuildContext context, {
    required BracketMatch match,
    required TournamentBracket bracket,
    String? poolId,
    required Future<void> Function(TournamentBracket updated) onSaveBracket,
    required void Function({
      required int court,
      required String roundName,
      required String pair1Name,
      required String pair2Name,
    }) onBroadcastCourtCall,
    required void Function({
      required int court,
      required String roundName,
      required String pair1Name,
      required String pair2Name,
    }) onShareCallMessage,
  }) {
    if (match.pair1 == null || match.pair2 == null) return;

    final scoreController = TextEditingController(text: match.score ?? "");
    String? winnerId = match.winnerId ?? match.pair1!.id;
    int? selectedCourt = match.court;

    // Formats officiels Beach Tennis FFT
    final presets = [
      "4/1 4/2",
      "4/2 4/1",
      "4/2 1/4 10/6",
      "6/3 6/4",
      "6/4 7/5",
      "6/4 3/6 10/8",
      "9/4",
      "9/7",
      "9/8 (5)",
      "WO (Forfait)",
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Poignée du BottomSheet
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Titre & Match
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${match.roundName} · Saisie Express JAT",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 1. SELECTEUR DE VAINQUEUR GRAND FORMAT
                      const Text(
                        "1. DÉSIGNER LE VAINQUEUR (1-CLIC)",
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildWinnerSelectorCard(
                              pair: match.pair1!,
                              isSelected: winnerId == match.pair1!.id,
                              onTap: () => setSheetState(() => winnerId = match.pair1!.id),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildWinnerSelectorCard(
                              pair: match.pair2!,
                              isSelected: winnerId == match.pair2!.id,
                              onTap: () => setSheetState(() => winnerId = match.pair2!.id),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. PRESETS DE SCORE OFFICIELS FFT
                      const Text(
                        "2. SCORE DU MATCH (BOUTONS RAPIDES)",
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: presets.map((s) {
                          final isSelected = scoreController.text == s;
                          return InkWell(
                            onTap: () => setSheetState(() => scoreController.text = s),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.gold.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.gold
                                      : Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  color: isSelected ? AppColors.gold : Colors.white,
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Champ Score Libre
                      TextField(
                        controller: scoreController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: "Ou saisie libre (ex: 6/4 7/5 ou 9/8)",
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                          prefixIcon: const Icon(Icons.edit, color: AppColors.gold, size: 18),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.gold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. TERRAIN DE JEU & APPEL TERRAIN
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "3. TERRAIN ATTRIBUÉ",
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (selectedCourt != null)
                            InkWell(
                              onTap: () {
                                onBroadcastCourtCall(
                                  court: selectedCourt!,
                                  roundName: match.roundName,
                                  pair1Name: match.pair1!.displayName,
                                  pair2Name: match.pair2!.displayName,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.campaign_rounded, size: 13, color: AppColors.gold),
                                    SizedBox(width: 4),
                                    Text(
                                      "Diffuser l'appel 📢",
                                      style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCourtChip(null, "Aucun", selectedCourt == null, () {
                              setSheetState(() => selectedCourt = null);
                            }),
                            const SizedBox(width: 6),
                            for (int c = 1; c <= (bracket.numCourts > 0 ? bracket.numCourts : 4); c++) ...[
                              _buildCourtChip(c, "Court $c", selectedCourt == c, () {
                                setSheetState(() => selectedCourt = c);
                              }),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Partage WhatsApp / SMS
                      if (selectedCourt != null)
                        InkWell(
                          onTap: () {
                            onShareCallMessage(
                              court: selectedCourt!,
                              roundName: match.roundName,
                              pair1Name: match.pair1!.displayName,
                              pair2Name: match.pair2!.displayName,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share_rounded, size: 14, color: Colors.greenAccent),
                                SizedBox(width: 6),
                                Text(
                                  "Envoyer la convocation (WhatsApp / SMS)",
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // 4. BOUTON UNIQUE DE VALIDATION
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.gold.withValues(alpha: 0.4),
                        ),
                        onPressed: () async {
                          if (scoreController.text.trim().isEmpty || winnerId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Veuillez sélectionner un vainqueur et un score"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);

                          TournamentBracket updated;
                          if (poolId != null) {
                            updated = BracketGeneratorService.recordPoolMatchScore(
                              bracket: bracket,
                              poolId: poolId,
                              matchId: match.id,
                              score: scoreController.text.trim(),
                              winnerId: winnerId!,
                            );
                          } else {
                            updated = BracketGeneratorService.recordMatchScore(
                              bracket: bracket,
                              matchId: match.id,
                              score: scoreController.text.trim(),
                              winnerId: winnerId!,
                            );
                          }

                          // Mettre à jour le terrain si changé
                          if (poolId != null) {
                            updated = updated.copyWith(
                              pools: updated.pools.map((p) {
                                if (p.id != poolId) return p;
                                return p.copyWith(
                                  matches: p.matches.map((m) {
                                    if (m.id != match.id) return m;
                                    return m.copyWith(
                                      court: selectedCourt,
                                      clearCourt: selectedCourt == null,
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            );
                          } else {
                            updated = updated.copyWith(
                              mainMatches: updated.mainMatches.map((m) {
                                if (m.id != match.id) return m;
                                return m.copyWith(
                                  court: selectedCourt,
                                  clearCourt: selectedCourt == null,
                                );
                              }).toList(),
                              consolationMatches: updated.consolationMatches.map((m) {
                                if (m.id != match.id) return m;
                                return m.copyWith(
                                  court: selectedCourt,
                                  clearCourt: selectedCourt == null,
                                );
                              }).toList(),
                            );
                          }

                          await onSaveBracket(updated);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("⚡ Score enregistré ! L'arbre avance immédiatement."),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              match.isCompleted
                                  ? "METTRE À JOUR LE RÉSULTAT ⚡"
                                  : "VALIDER & FAIRE AVANCER L'ARBRE ⚡",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 5. BOUTON SÉCURISÉ D'EFFACEMENT / REMISE À ZÉRO DU MATCH
                      if (match.isCompleted || match.score != null || match.winnerId != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.7),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final sheetNav = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(context);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: const Color(0xFF0F172A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Réinitialiser le match ?",
                                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  "Voulez-vous effacer le score de ce match (${match.roundName}) ?\n\nLe match sera remis en statut 'À venir' et les qualifications ou progressions associées seront annulées.",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text(
                                      "Effacer le score",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              sheetNav.pop();
                              final updated = BracketGeneratorService.resetMatchScore(
                                bracket: bracket,
                                matchId: match.id,
                                poolId: poolId,
                              );
                              await onSaveBracket(updated);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text("↩️ Match réinitialisé avec succès (remis à zéro) !"),
                                  backgroundColor: Color(0xFFEF4444),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restart_alt_rounded, color: Color(0xFFEF4444), size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Effacer / Réinitialiser ce match (Remise à zéro)",
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildWinnerSelectorCard({
    required TournamentPair pair,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.gold : Colors.white38,
                  size: 18,
                ),
                if (pair.seed != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "TS${pair.seed}",
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pair.displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildCourtChip(
    int? court,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blueAccent.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.white12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : Colors.white70,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
