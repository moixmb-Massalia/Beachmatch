import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/tournament_bracket_model.dart';
import '../../../theme/colors.dart';
import 'bracket_pair_slot.dart';

/// Ligne d'affichage d'une paire dans une carte de match ou de poule,
/// avec gestion visuelle du vainqueur (trophée doré), des têtes de série (TS),
/// et du glisser-déposer / permuter (Swap JAT) en un toucher ou appui long.
class BracketPairRow extends StatelessWidget {
  final TournamentPair? pair;
  final bool isWinner;
  final bool isCompleted;
  final String? fallbackLabel;
  final BracketMatch? match;
  final int? slot;
  final TournamentBracket? bracket;
  final String? poolId;
  final bool isJat;
  final BracketPairSlot? selectedSwapSlot;
  final void Function(BracketPairSlot slot)? onSwapSlotSelected;
  final VoidCallback? onSwapSlotCleared;
  final void Function({
    required BracketPairSlot source,
    required BracketPairSlot target,
    required TournamentBracket bracket,
  })? onExecuteSwap;

  const BracketPairRow({
    super.key,
    required this.pair,
    required this.isWinner,
    required this.isCompleted,
    this.fallbackLabel,
    this.match,
    this.slot,
    this.bracket,
    this.poolId,
    this.isJat = false,
    this.selectedSwapSlot,
    this.onSwapSlotSelected,
    this.onSwapSlotCleared,
    this.onExecuteSwap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    final currentPair = pair;

    if (currentPair == null) {
      content = Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fallbackLabel ?? "En attente du tour précédent...",
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    } else if (currentPair.isBye) {
      content = const Row(
        children: [
          Icon(Icons.remove_circle_outline, size: 13, color: Colors.white30),
          SizedBox(width: 8),
          Text(
            "EXEMPT (BYE)",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          if (isCompleted && isWinner)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 16),
            )
          else
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isWinner ? AppColors.gold : Colors.white30,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Text(
              currentPair.displayName,
              style: TextStyle(
                color: isCompleted
                    ? (isWinner ? Colors.white : Colors.white54)
                    : Colors.white,
                fontSize: 12.5,
                fontWeight: isWinner ? FontWeight.w900 : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (currentPair.seed != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
              child: Text(
                "TS${currentPair.seed}",
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      );
    }

    if (match == null || slot == null || bracket == null || !isJat) {
      return content;
    }

    final isSelectedSource = selectedSwapSlot != null &&
        selectedSwapSlot!.match.id == match!.id &&
        selectedSwapSlot!.slot == slot;

    final isTargetCandidate = selectedSwapSlot != null && !isSelectedSource;

    final currentSlot = BracketPairSlot(
      match: match!,
      slot: slot!,
      pair: currentPair,
      poolId: poolId,
    );

    Widget rowWrapper = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: isSelectedSource || isTargetCandidate ? 6 : 4,
        vertical: isSelectedSource || isTargetCandidate ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: isSelectedSource
            ? AppColors.gold.withValues(alpha: 0.25)
            : (isTargetCandidate ? AppColors.gold.withValues(alpha: 0.08) : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: isSelectedSource
            ? Border.all(color: AppColors.gold, width: 2.0)
            : (isTargetCandidate
                ? Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.2)
                : null),
        boxShadow: isSelectedSource
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(child: content),
          if (isSelectedSource) ...[
            const SizedBox(width: 6),
            const Icon(Icons.swap_horizontal_circle, color: AppColors.gold, size: 18),
          ] else if (isTargetCandidate) ...[
            const SizedBox(width: 6),
            const Icon(Icons.touch_app_rounded, color: AppColors.gold, size: 16),
          ] else if (selectedSwapSlot == null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: "Appui long pour permuter",
              child: Icon(
                Icons.swap_vert_rounded,
                color: Colors.white.withValues(alpha: 0.25),
                size: 14,
              ),
            ),
          ],
        ],
      ),
    );

    Widget dragTarget = DragTarget<BracketPairSlot>(
      onWillAcceptWithDetails: (details) {
        final src = details.data;
        return src.match.id != match!.id || src.slot != slot;
      },
      onAcceptWithDetails: (details) {
        onExecuteSwap?.call(
          source: details.data,
          target: currentSlot,
          bracket: bracket!,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        if (isHovered) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold, width: 2.2),
            ),
            child: rowWrapper,
          );
        }
        return rowWrapper;
      },
    );

    Widget draggable = LongPressDraggable<BracketPairSlot>(
      data: currentSlot,
      delay: const Duration(milliseconds: 250),
      onDragStarted: () {
        HapticFeedback.heavyImpact();
        onSwapSlotSelected?.call(currentSlot);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Paire en déplacement : ${currentPair?.displayName ?? 'Slot'}. Déposez sur une case ou touchez une paire pour permuter.",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.grey.shade900,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: "Annuler",
              textColor: AppColors.gold,
              onPressed: () => onSwapSlotCleared?.call(),
            ),
          ),
        );
      },
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentPair?.displayName ?? fallbackLabel ?? "Paire",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: dragTarget,
      ),
      child: dragTarget,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (selectedSwapSlot != null) {
          if (isSelectedSource) {
            HapticFeedback.lightImpact();
            onSwapSlotCleared?.call();
          } else {
            onExecuteSwap?.call(
              source: selectedSwapSlot!,
              target: currentSlot,
              bracket: bracket!,
            );
          }
        } else {
          HapticFeedback.lightImpact();
          onSwapSlotSelected?.call(currentSlot);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Paire prête à permuter : ${currentPair?.displayName ?? 'Slot'}. Touchez une autre paire pour échanger leurs places.",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.grey.shade900,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: "Annuler",
                textColor: AppColors.gold,
                onPressed: () => onSwapSlotCleared?.call(),
              ),
            ),
          );
        }
      },
      child: draggable,
    );
  }
}
