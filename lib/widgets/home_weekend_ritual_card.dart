import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
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

    final user = context.watch<AppState>().currentUser;
    final lang = (user?.isBrazilian == true || user?.country.toUpperCase() == 'BR' || Localizations.localeOf(context).languageCode == 'pt')
        ? 'pt'
        : Localizations.localeOf(context).languageCode.toLowerCase();

    final title = lang == 'pt'
        ? "🔥 Partiu Beach Tennis no fim de semana !"
        : (lang == 'es'
            ? "🔥 ¡Prepara tu fin de semana!"
            : (lang == 'it'
                ? "🔥 Preparati per il weekend!"
                : (lang == 'en' ? "🔥 Get ready for the weekend!" : "🔥 Préparez votre week-end !")));

    final desc = now.weekday == DateTime.sunday
        ? (lang == 'pt'
            ? "Últimos horários livres para jogar hoje !"
            : (lang == 'es'
                ? "¡Últimos horarios disponibles para jugar hoy!"
                : (lang == 'it'
                    ? "Ultimi slot liberi per giocare oggi!"
                    : (lang == 'en'
                        ? "Last available court slots to play today!"
                        : "Derniers créneaux libres pour taper la balle aujourd'hui !"))))
        : (lang == 'pt'
            ? "As quadras do fim de semana estão lotando rápido. Crie ou entre em uma partida."
            : (lang == 'es'
                ? "Las pistas del fin de semana se llenan rápido. Crea o únete a un partido."
                : (lang == 'it'
                    ? "I campi del weekend si riempiono in fretta. Crea o unisciti a una partita."
                    : (lang == 'en'
                        ? "Weekend court slots fill up fast. Create or join a match."
                        : "Les créneaux de samedi & dimanche se remplissent vite. Créez ou rejoignez une partie."))));

    final actionBtn = lang == 'pt'
        ? "Jogar"
        : (lang == 'es'
            ? "Jugar"
            : (lang == 'it' ? "Gioca" : (lang == 'en' ? "Play" : "Créer")));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8604C).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, height: 1.25),
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
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMatchScreen()));
            },
            child: Text(
              actionBtn,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
