import 'package:flutter/material.dart';
import '../screens/create_match_screen.dart';

/// Bannière incitative le week-end (du jeudi au dimanche) pour créer des parties
class HomeWeekendRitualCard extends StatelessWidget {
  const HomeWeekendRitualCard({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Afficher le jeudi (4), vendredi (5), samedi (6), dimanche (7)
    final isWeekendPrep = now.weekday >= DateTime.thursday;
    if (!isWeekendPrep) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8604C).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🔥 Préparez votre week-end !",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  now.weekday == DateTime.sunday
                      ? "Derniers créneaux libres pour taper la balle aujourd'hui !"
                      : "Les créneaux de samedi & dimanche se remplissent vite. Créez ou rejoignez une partie.",
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFE8604C),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMatchScreen()));
            },
            child: const Text(
              "Créer",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
