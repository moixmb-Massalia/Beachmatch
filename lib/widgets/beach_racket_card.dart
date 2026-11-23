import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/beach_racket_service.dart';
import '../theme/colors.dart';
import 'smart_racket_picker_dialog.dart';

class BeachRacketCard extends StatelessWidget {
  final UserModel user;
  final bool isEditable;
  final VoidCallback? onEdit;

  const BeachRacketCard({
    super.key,
    required this.user,
    this.isEditable = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasRacket = user.racket != null && user.racket!.trim().isNotEmpty;

    if (!hasRacket) {
      if (!isEditable) return const SizedBox.shrink();
      return _buildEmptyInvitationCard(context);
    }

    // Récupérer ou déduire les specs intelligentes
    final brand = user.racketBrand ?? _extractBrand(user.racket!);
    final model = user.racketModel ?? _extractModel(user.racket!, brand);
    final racketSpec = BeachRacketService.detectOrBuildCustom(
      brand: brand,
      model: model,
      material: user.racketMaterial,
      balance: user.racketBalance,
      surface: user.racketSurface,
      thicknessMm: 20,
      weightGrams: user.racketWeight ?? 330,
    );

    final power = user.racketPower ?? racketSpec.powerScore;
    final control = user.racketControl ?? racketSpec.controlScore;
    final spin = user.racketSpin ?? racketSpec.spinScore;
    final playStyle = user.racketPlayStyle ?? racketSpec.playStyle;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Effet reflet glassmorphism
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.08),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête : Badge Équipement Officiel & Bouton Modifier
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.sports_tennis, color: AppColors.gold, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brand.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                model,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (isEditable)
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 24),
                          tooltip: "Modifier ma raquette",
                          onPressed: onEdit ?? () => _openPicker(context),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Style de jeu déduit
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flash_on_rounded, color: AppColors.gold, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Profil : $playStyle",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Capsules caractéristiques techniques
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSpecPill(Icons.layers_rounded, racketSpec.material),
                      _buildSpecPill(Icons.balance_rounded, "Équilibre ${racketSpec.balance}"),
                      _buildSpecPill(Icons.grain_rounded, racketSpec.surface),
                      _buildSpecPill(Icons.straighten_rounded, "${racketSpec.thicknessMm} mm"),
                      _buildSpecPill(Icons.scale_rounded, "${racketSpec.weightGrams}g"),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 14),

                  // Jauges visuelles Puissance / Contrôle / Effets
                  _buildGaugeRow("Puissance", power, const Color(0xFFEF4444)),
                  const SizedBox(height: 8),
                  _buildGaugeRow("Contrôle", control, const Color(0xFF10B981)),
                  const SizedBox(height: 8),
                  _buildGaugeRow("Effets (Spin)", spin, const Color(0xFF38BDF8)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInvitationCard(BuildContext context) {
    return InkWell(
      onTap: onEdit ?? () => _openPicker(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E293B).withValues(alpha: 0.9),
              const Color(0xFF0F172A).withValues(alpha: 0.9),
            ],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.sports_tennis, color: AppColors.gold, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Votre Raquette de Beach Tennis 🎾",
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Choisissez votre modèle (Drop Shot, Heroe's, Nox...) pour révéler votre ADN de jeu !",
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeRow(String label, int value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (value / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            "$value%",
            textAlign: TextAlign.right,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  String _extractBrand(String full) {
    for (final b in BeachRacketService.famousBrands) {
      if (full.toLowerCase().contains(b.toLowerCase())) return b;
    }
    return full.split(' ').first;
  }

  String _extractModel(String full, String brand) {
    final clean = full.replaceAll(brand, '').trim();
    return clean.isNotEmpty ? clean : full;
  }

  void _openPicker(BuildContext context) {
    SmartRacketPickerDialog.show(context, currentUser: user);
  }
}
