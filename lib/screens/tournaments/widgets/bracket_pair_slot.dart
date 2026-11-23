import '../../../models/tournament_bracket_model.dart';

/// Représente un slot de paire (slot 1 ou 2) dans un match pour la permutation JAT
class BracketPairSlot {
  final BracketMatch match;
  final int slot; // 1 ou 2
  final TournamentPair? pair;
  final String? poolId;

  const BracketPairSlot({
    required this.match,
    required this.slot,
    this.pair,
    this.poolId,
  });
}
