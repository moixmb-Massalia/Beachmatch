import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_item.dart';

class NewsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of news items for automatic live updating
  Stream<List<NewsItemModel>> getNewsStream() {
    return _firestore
        .collection('news')
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return getCuratedNews();
          }
          final items = snapshot.docs.map((doc) => NewsItemModel.fromMap(doc.data(), doc.id)).toList();
          items.sort((a, b) {
            if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
            if (a.type != b.type) {
              if (a.type == NewsType.live) return -1;
              if (b.type == NewsType.live) return 1;
              if (a.type == NewsType.tutorial) return -1;
              if (b.type == NewsType.tutorial) return 1;
            }
            return b.publishedAt.compareTo(a.publishedAt);
          });
          return items;
        }).handleError((_) {
          return getCuratedNews();
        });
  }

  // High-quality curated feed with 10+ professional Beach Tennis tutorials and live streams
  static List<NewsItemModel> getCuratedNews() {
    final now = DateTime.now();
    return [
      // 🔴 1. LIVE MONDIAL (Détection de direct ou Replay Officiel ITF)
      NewsItemModel(
        id: 'live_1',
        title: '🔴 DIRECT : Programa PLAY BT',
        description: 'La référence mondiale ! Suivez les directs, tournois et émissions du plus grand hub de Beach Tennis au monde (Programa PLAY BT).',
        category: 'DIRECT WORLD TOUR 🔴',
        type: NewsType.live,
        imageUrl: 'assets/images/beach_sunset_players_1785052273648.jpg',
        videoUrl: 'https://www.youtube.com/@ProgramaPLAYBT/live', // Auto redirects to live stream
        publishedAt: now,
        isLive: true,
      ),

      // 🎓 2. CATALOGUE DE TUTORIELS PROS
      NewsItemModel(
        id: 'tuto_9',
        title: '🎓 TUTO : Ton premier cours de Beach Tennis',
        description: 'Les bases indispensables pour commencer le beach tennis sur de bonnes bases.',
        category: 'TUTORIEL 🎓',
        type: NewsType.tutorial,
        imageUrl: 'assets/images/beach_court_aerial_1785052250131.jpg',
        videoUrl: 'https://youtu.be/8mHz-H_u2-8?si=oexI8SGp2QXRCGAU', 
        publishedAt: now.subtract(const Duration(days: 1)),
        isLive: false,
      ),
      NewsItemModel(
        id: 'tuto_8',
        title: '🎓 TUTO : Maîtrise ton service en 15 minutes',
        description: 'Des exercices rapides et ciblés pour améliorer la puissance et la régularité de ton service.',
        category: 'TUTORIEL 🎓',
        type: NewsType.tutorial,
        imageUrl: 'assets/images/hero_beach_tennis_1785051787379.jpg',
        videoUrl: 'https://youtu.be/YLm9rStbZ6U?si=nJMn6MBQv11T1Ua-', 
        publishedAt: now.subtract(const Duration(days: 2)),
        isLive: false,
      ),
      NewsItemModel(
        id: 'tuto_1',
        title: '🎓 TUTO : Le Smash',
        description: 'Apprenez la technique parfaite pour maîtriser le smash au Beach Tennis.',
        category: 'TUTORIEL 🎓',
        type: NewsType.tutorial,
        imageUrl: 'assets/images/beach_tennis_racket_1785052259397.jpg',
        videoUrl: 'https://youtu.be/wIUW1pit-D8?si=Tvu2LMmG90lPaN_c', 
        publishedAt: now.subtract(const Duration(days: 3)),
        isLive: false,
      ),
      NewsItemModel(
        id: 'tuto_2',
        title: '🎓 TUTO : Le Service',
        description: 'Découvrez les bases pour réaliser un service efficace et puissant sur le sable.',
        category: 'TUTORIEL 🎓',
        type: NewsType.tutorial,
        imageUrl: 'assets/images/beach_tennis_ball_1785052281869.jpg',
        videoUrl: 'https://youtu.be/WCjv1GD1cEU?si=hvA2Mgdqv7V8xiRd', 
        publishedAt: now.subtract(const Duration(days: 4)),
        isLive: false,
      ),
      NewsItemModel(
        id: 'tuto_3',
        title: '🎓 TUTO : Coup droit et Revers',
        description: 'Les fondamentaux du coup droit et du revers pour un maximum de contrôle.',
        category: 'TUTORIEL 🎓',
        type: NewsType.tutorial,
        imageUrl: 'assets/images/beach_court_aerial_1785052250131.jpg',
        videoUrl: 'https://youtu.be/Bpb0aGv1FPU?si=dqmfeMPvuEeBWos3', 
        publishedAt: now.subtract(const Duration(days: 5)),
        isLive: false,
      ),
      NewsItemModel(
        id: 'tuto_4',
        title: '🎓 TUTO : Le Rush',
        description: 'Montez au filet avec agressivité en maîtrisant la technique du rush.',
        category: 'TUTORIEL 🎓',
        type: NewsType.tutorial,
        imageUrl: 'assets/images/beach_tennis_ball_1785052281869.jpg',
        videoUrl: 'https://youtu.be/VmQfJvSvBmc?si=fTcBNht9scFEGAYF', 
        publishedAt: now.subtract(const Duration(days: 6)),
        isLive: false,
      ),
      NewsItemModel(
        id: 'tuto_5',
        title: '🎓 TUTO : Le Rainbow',
        description: 'Découvrez le coup signature du beach tennis : le rainbow !',
        category: 'TUTORIEL 🎓',
        type: NewsType.tutorial,
        imageUrl: 'assets/images/beach_court_aerial_1785052250131.jpg',
        videoUrl: 'https://youtu.be/Kl0zmFv4h8Q?si=YU93g9_iaFDFV-ov', 
        publishedAt: now.subtract(const Duration(days: 7)),
        isLive: false,
      ),
      NewsItemModel(
        id: 'tuto_6',
        title: '🎓 TUTO : Le Bras Roulé',
        description: 'La technique ultime pour lober vos adversaires avec précision.',
        category: 'TUTORIEL 🎓',
        type: NewsType.tutorial,
        imageUrl: 'assets/images/hero_beach_tennis_1785051787379.jpg',
        videoUrl: 'https://youtu.be/l81OvziQQF4?si=Rti4p6saBUSJrjow', 
        publishedAt: now.subtract(const Duration(days: 8)),
        isLive: false,
      ),
      NewsItemModel(
        id: 'tuto_7',
        title: '🎓 TUTO : Tactique pour repousser les joueurs',
        description: 'Stratégie et astuces pour gagner du terrain et repousser vos adversaires au fond du court.',
        category: 'TUTORIEL 🎓',
        type: NewsType.tutorial,
        imageUrl: 'assets/images/beach_tennis_ball_1785052281869.jpg',
        videoUrl: 'https://youtu.be/DwHIndg9Jmo?si=Ws4bEdElV9cti6uH', 
        publishedAt: now.subtract(const Duration(days: 9)),
        isLive: false,
      ),

      // 🏆 3. ACTUS MONDIALES
      NewsItemModel(
        id: 'news_1',
        title: '🏆 ITF Aruba Open 2026 : Le programme officiel dévoilé',
        description: 'Plus de 500 joueurs venus de 30 pays s\'affronteront sur le sable d\'Aruba le mois prochain.',
        category: 'ACTU MONDIALE 🌐',
        type: NewsType.news,
        imageUrl: 'assets/images/beach_sunset_players_1785052273648.jpg',
        videoUrl: null,
        publishedAt: now.subtract(const Duration(days: 20)),
        isLive: false,
      ),
    ];
  }
}
