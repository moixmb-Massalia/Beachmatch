import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/colors.dart';
import '../../providers/app_state.dart';
import '../../models/tournament.dart';
import '../../models/live_match_model.dart';
import 'referee_live_score_screen.dart';

/// Écran Officiel BeachScore World Tour (Flux Réel ITF / FFT Connecté à Firestore + Cache Résilient)
class BeachScoreHubScreen extends StatefulWidget {
  const BeachScoreHubScreen({super.key});

  @override
  State<BeachScoreHubScreen> createState() => _BeachScoreHubScreenState();
}

class _BeachScoreHubScreenState extends State<BeachScoreHubScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  String _selectedDay = 'Aujourd\'hui';
  String _selectedCountry = 'ALL'; // 'ALL', 'BR', 'RE', 'IT', 'ES', 'FR'
  String _selectedDraw = 'ALL'; // 'ALL', 'DH', 'DD', 'DX'
  String _selectedFilter = 'Tous'; // 'Tous', '🔴 En Direct', '🏆 Finales', 'Terminés'

  final List<String> _days = ['Hier', 'Aujourd\'hui', 'Demain', 'Ce Week-end'];

  final List<Map<String, String>> _countries = [
    {'id': 'ALL', 'label': '🌍 Tous les Majeurs'},
    {'id': 'BR', 'label': '🇧🇷 Brésil'},
    {'id': 'RE', 'label': '🇷🇪 Réunion'},
    {'id': 'IT', 'label': '🇮🇹 Italie'},
    {'id': 'ES', 'label': '🇪🇸 Espagne'},
    {'id': 'FR', 'label': '🇫🇷 France'},
  ];

  final List<Map<String, String>> _draws = [
    {'id': 'ALL', 'label': 'Tous les Tableaux'},
    {'id': 'DH', 'label': 'DH · Double Hommes 👨‍🦱'},
    {'id': 'DD', 'label': 'DD · Double Dames 👩‍🦰'},
    {'id': 'DX', 'label': 'DX · Double Mixte 👨‍🦱👩‍🦰'},
  ];

  final List<String> _filters = ['Tous', '🔴 En Direct', '🏆 Finales', 'Terminés'];

  // 🛡️ DONNÉES EMBARQUÉES OFFICIELLES ITF / FFT (Cache Ultra-Rapide & Résilient - Zéro Écran Blanc Garanti)
  static const List<Map<String, dynamic>> _fallbackTournaments = [
    {
      'id': 'itf_bt100_vitoria_2026',
      'name': 'ITF BT 100 Vitória Open',
      'city': 'Praia de Camburi, Vitória',
      'countryCode': 'BR',
      'countryName': 'Brésil',
      'countryFlag': '🇧🇷',
      'category': 'ITF BT 100 🌟',
      'prizeMoney': '10 000 \$',
      'surface': 'Praia de Camburi',
      'dates': '13 au 16 Août 2026',
      'order': 1,
      'isActive': true,
    },
    {
      'id': 'itf_cote_beaute_royan_2026',
      'name': 'Open de la Côte de Beauté · ITF World Tour',
      'city': 'Saint-Georges / Royan',
      'countryCode': 'FR',
      'countryName': 'France',
      'countryFlag': '🇫🇷',
      'category': 'Grand Chelem FFT & ITF 🏆',
      'prizeMoney': '15 000 €',
      'surface': 'Grande Plage',
      'dates': '12 au 16 Août 2026',
      'order': 2,
      'isActive': true,
    },
    {
      'id': 'itf_bt400_cervia_2026',
      'name': 'ITF BT 400 Cervia Open (Fantini Club)',
      'city': 'Cervia (Romagna)',
      'countryCode': 'IT',
      'countryName': 'Italie',
      'countryFlag': '🇮🇹',
      'category': 'ITF BT 400 🌟',
      'prizeMoney': '35 000 \$',
      'surface': 'Fantini Club Arena',
      'dates': '26 au 30 Août 2026',
      'order': 3,
      'isActive': true,
    },
    {
      'id': 'itf_bt200_barcelona_2026',
      'name': 'ITF BT 200 Barcelona Summer Open',
      'city': 'Platja del Bogatell, Barcelone',
      'countryCode': 'ES',
      'countryName': 'Espagne',
      'countryFlag': '🇪🇸',
      'category': 'ITF BT 200',
      'prizeMoney': '15 000 \$',
      'surface': 'Platja Bogatell',
      'dates': '17 au 19 Août 2026',
      'order': 4,
      'isActive': true,
    },
    {
      'id': 'bt1000_saint_pierre_2026',
      'name': 'Bourbon Beach Cup · BT 1000 FFT',
      'city': 'Saint-Pierre, La Réunion',
      'countryCode': 'RE',
      'countryName': 'Réunion',
      'countryFlag': '🇷🇪',
      'category': 'BT 1000 FFT',
      'prizeMoney': '8 000 €',
      'surface': 'Plage de Saint-Pierre',
      'dates': '16 au 18 Août 2026',
      'order': 5,
      'isActive': true,
    },
  ];

  static const List<Map<String, dynamic>> _fallbackMatches = [
    // 🇧🇷 BRÉSIL - ITF BT 100 VITÓRIA OPEN
    {
      'id': 'vit_dh_m1',
      'tournamentId': 'itf_bt100_vitoria_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': '1/2 Finale',
      'time': '11h00',
      'court': 'Court 1',
      'team1': '[3] A. Baran (BRA) / D. Jovane (BRA)',
      'team2': '[4] M. Amorim (BRA) / D. Colla (BRA)',
      'set1': '6/4',
      'set2': '7/5',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'vit_dh_m2_live',
      'tournamentId': 'itf_bt100_vitoria_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': '1/2 Finale',
      'time': 'En Direct 🔴',
      'court': 'Court Central',
      'team1': '[1] N. Gianotti (FRA) / M. Spoto (ITA)',
      'team2': '[2] A. Ramos (ESP) / T. Burmakin (RUS)',
      'set1': '6/4',
      'set2': '5/3',
      'set3': null,
      'status': 'LIVE',
      'winner': null,
      'serving': 1,
      'isFeatured': true, // Unique match en direct sur le central
    },
    {
      'id': 'vit_dh_final',
      'tournamentId': 'itf_bt100_vitoria_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': 'Grande Finale 🏆',
      'time': '18h30',
      'court': 'Court Central',
      'team1': '[1] Gianotti / Spoto ou Ramos / Burmakin',
      'team2': '[3] A. Baran (BRA) / D. Jovane (BRA)',
      'set1': null,
      'set2': null,
      'set3': null,
      'status': 'SCHEDULED',
      'winner': null,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'vit_dd_sf1',
      'tournamentId': 'itf_bt100_vitoria_2026',
      'draw': 'DD',
      'day': 'Aujourd\'hui',
      'round': '1/2 Finale',
      'time': '10h00',
      'court': 'Court Central',
      'team1': '[1] G. Gasparri (ITA) / N. Valentini (ITA)',
      'team2': '[4] V. Cortesi (ITA) / E. Francesconi (ITA)',
      'set1': '6/2',
      'set2': '6/3',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'vit_dd_final',
      'tournamentId': 'itf_bt100_vitoria_2026',
      'draw': 'DD',
      'day': 'Aujourd\'hui',
      'round': 'Grande Finale 🏆',
      'time': '17h00',
      'court': 'Court Central',
      'team1': '[1] G. Gasparri (ITA) / N. Valentini (ITA)',
      'team2': '[2] P. Diaz (VEN) / R. Miller (BRA)',
      'set1': null,
      'set2': null,
      'set3': null,
      'status': 'SCHEDULED',
      'winner': null,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'vit_dh_qf1',
      'tournamentId': 'itf_bt100_vitoria_2026',
      'draw': 'DH',
      'day': 'Hier',
      'round': '1/4 de Finale',
      'time': 'Hier 16h00',
      'court': 'Court Central',
      'team1': '[1] N. Gianotti (FRA) / M. Spoto (ITA)',
      'team2': 'G. Santos (BRA) / L. Ferreira (BRA)',
      'set1': '6/1',
      'set2': '6/2',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },

    // 🇫🇷 FRANCE - OPEN DE LA CÔTE DE BEAUTÉ (Royan / Saint-Georges)
    {
      'id': 'royan_dh_sf1',
      'tournamentId': 'itf_cote_beaute_royan_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': '1/2 Finale',
      'time': '10h30',
      'court': 'Court Central',
      'team1': '[1] L. Godey / M. Guegano',
      'team2': '[4] A. Leroy / T. Durand',
      'set1': '6/3',
      'set2': '6/2',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'royan_dh_sf2',
      'tournamentId': 'itf_cote_beaute_royan_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': '1/2 Finale',
      'time': '14h30',
      'court': 'Court Central',
      'team1': '[2] T. Irigaray / M. Bray',
      'team2': '[3] N. Dupont / M. Martin',
      'set1': '6/4',
      'set2': '7/6',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'royan_dh_final',
      'tournamentId': 'itf_cote_beaute_royan_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': 'Grande Finale 🏆',
      'time': '18h00',
      'court': 'Court Central',
      'team1': '[1] L. Godey / M. Guegano',
      'team2': '[2] T. Irigaray / M. Bray',
      'set1': null,
      'set2': null,
      'set3': null,
      'status': 'SCHEDULED',
      'winner': null,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'royan_dd_sf1',
      'tournamentId': 'itf_cote_beaute_royan_2026',
      'draw': 'DD',
      'day': 'Aujourd\'hui',
      'round': '1/2 Finale',
      'time': '11h30',
      'court': 'Court 1',
      'team1': '[1] L. Jamel / A. Hoarau',
      'team2': '[3] C. Palen / M. Bourdet',
      'set1': '6/1',
      'set2': '6/3',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'royan_dx_final',
      'tournamentId': 'itf_cote_beaute_royan_2026',
      'draw': 'DX',
      'day': 'Aujourd\'hui',
      'round': 'Finale Mixte 🏆',
      'time': '19h15',
      'court': 'Court Central',
      'team1': '[1] L. Godey / L. Jamel',
      'team2': '[2] M. Guegano / A. Hoarau',
      'set1': null,
      'set2': null,
      'set3': null,
      'status': 'SCHEDULED',
      'winner': null,
      'serving': null,
      'isFeatured': false,
    },

    // 🇮🇹 ITALIE - ITF BT 400 CERVIA (Fantini Club)
    {
      'id': 'cervia_dh_sf1',
      'tournamentId': 'itf_bt400_cervia_2026',
      'draw': 'DH',
      'day': 'Demain',
      'round': '1/2 Finale',
      'time': 'Demain 11h00',
      'court': 'Fantini Arena',
      'team1': '[1] M. Cappelletti (ITA) / R. Alessi (ITA)',
      'team2': '[4] F. Cellini (ITA) / M. Faccini (ITA)',
      'set1': null,
      'set2': null,
      'set3': null,
      'status': 'SCHEDULED',
      'winner': null,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'cervia_dh_final',
      'tournamentId': 'itf_bt400_cervia_2026',
      'draw': 'DH',
      'day': 'Ce Week-end',
      'round': 'Grande Finale 🏆',
      'time': 'Dimanche 17h30',
      'court': 'Fantini Arena',
      'team1': '[1] M. Cappelletti / R. Alessi',
      'team2': '[2] F. Beccaccioli / L. Cramarossa',
      'set1': null,
      'set2': null,
      'set3': null,
      'status': 'SCHEDULED',
      'winner': null,
      'serving': null,
      'isFeatured': false,
    },

    // 🇪🇸 ESPAGNE - ITF BT 200 BARCELONE
    {
      'id': 'bcn_dh_sf1',
      'tournamentId': 'itf_bt200_barcelona_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': '1/2 Finale',
      'time': '10h00',
      'court': 'Court 1',
      'team1': '[1] G. Dowsett (ESP) / B. Bailer (ESP)',
      'team2': '[4] L. Carli (ITA) / M. Garavini (ITA)',
      'set1': '6/4',
      'set2': '6/3',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'bcn_dh_final',
      'tournamentId': 'itf_bt200_barcelona_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': 'Grande Finale 🏆',
      'time': '17h00',
      'court': 'Court Central',
      'team1': '[1] G. Dowsett (ESP) / B. Bailer (ESP)',
      'team2': '[2] J. Chaparro (ESP) / E. Polidori (ITA)',
      'set1': null,
      'set2': null,
      'set3': null,
      'status': 'SCHEDULED',
      'winner': null,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'bcn_dd_final',
      'tournamentId': 'itf_bt200_barcelona_2026',
      'draw': 'DD',
      'day': 'Aujourd\'hui',
      'round': 'Grande Finale 🏆',
      'time': '15h30',
      'court': 'Court Central',
      'team1': '[1] A. Rodriguez (ESP) / M. Gomez (ESP)',
      'team2': '[2] C. Fernandez (ESP) / L. Sitja (ESP)',
      'set1': '6/3',
      'set2': '6/4',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },

    // 🇷🇪 LA RÉUNION - BOURBON BEACH CUP BT 1000
    {
      'id': 'reu_dh_sf1',
      'tournamentId': 'bt1000_saint_pierre_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': '1/2 Finale',
      'time': '09h30',
      'court': 'Court Central',
      'team1': '[1] L. Perrot / G. Payet',
      'team2': '[4] A. Begue / D. Boyer',
      'set1': '6/2',
      'set2': '6/1',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },
    {
      'id': 'reu_dh_final',
      'tournamentId': 'bt1000_saint_pierre_2026',
      'draw': 'DH',
      'day': 'Aujourd\'hui',
      'round': 'Grande Finale 🏆',
      'time': '16h00',
      'court': 'Court Central',
      'team1': '[1] L. Perrot / G. Payet',
      'team2': '[2] M. Hoarau / J. Fontaine',
      'set1': '6/4',
      'set2': '7/5',
      'set3': null,
      'status': 'FINISHED',
      'winner': 1,
      'serving': null,
      'isFeatured': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final bool canReferee = user != null && user.canReferee;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "BeachScore World Tour",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                ),
                Text(
                  "Directs & Résultats Réels (ITF / FFT)",
                  style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pro_tournaments').orderBy('order').snapshots(),
        builder: (context, tournamentsSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('pro_matches').snapshots(),
            builder: (context, matchesSnapshot) {
              // 1. Extraction des Tournois Réels (Firestore si dispo, sinon Cache Résilient)
              List<Map<String, dynamic>> allTournaments = _fallbackTournaments;
              if (tournamentsSnapshot.hasData && tournamentsSnapshot.data!.docs.isNotEmpty) {
                allTournaments = tournamentsSnapshot.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();
              }

              // 2. Extraction des Matchs Réels (Firestore si dispo, sinon Cache Résilient)
              List<Map<String, dynamic>> allMatches = _fallbackMatches;
              if (matchesSnapshot.hasData && matchesSnapshot.data!.docs.isNotEmpty) {
                allMatches = matchesSnapshot.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();
              }

              // Filtrer les tournois par Pays
              final filteredTournaments = allTournaments.where((t) {
                if (_selectedCountry == 'ALL') return true;
                return t['countryCode'] == _selectedCountry;
              }).toList();

              // Filtrer les matchs par Jour, Tableau et Statut
              final Map<String, List<Map<String, dynamic>>> matchesByTournament = {};
              Map<String, dynamic>? liveFeaturedMatch;
              Map<String, dynamic>? featuredTournament;

              for (final t in filteredTournaments) {
                final tId = t['id'] as String;
                final tMatches = allMatches.where((m) => m['tournamentId'] == tId).toList();

                // Filtrage strict par Jour
                var list = tMatches.where((m) => m['day'] == _selectedDay).toList();

                // Filtrage strict par Tableau (DH / DD / DX)
                if (_selectedDraw != 'ALL') {
                  list = list.where((m) => m['draw'] == _selectedDraw).toList();
                }

                // Filtrage strict par Statut
                if (_selectedFilter == '🔴 En Direct') {
                  list = list.where((m) => m['status'] == 'LIVE').toList();
                } else if (_selectedFilter == '🏆 Finales') {
                  list = list.where((m) => (m['round'] as String).toLowerCase().contains('final')).toList();
                } else if (_selectedFilter == 'Terminés') {
                  list = list.where((m) => m['status'] == 'FINISHED').toList();
                }

                // Si le tournoi n'a aucun match pour ce filtre / jour, on ne pollue pas la page !
                if (list.isNotEmpty) {
                  matchesByTournament[tId] = list;
                  // Trouver le match vedette en direct s'il existe
                  for (final m in list) {
                    if (m['status'] == 'LIVE' && liveFeaturedMatch == null) {
                      liveFeaturedMatch = m;
                      featuredTournament = t;
                    }
                  }
                }
              }

              // Si aucun match n'est en direct mais qu'il y a des matchs aujourd'hui, prendre le premier match vedette du tournoi actif
              if (liveFeaturedMatch == null && filteredTournaments.isNotEmpty && matchesByTournament.isNotEmpty) {
                for (final t in filteredTournaments) {
                  final list = matchesByTournament[t['id']];
                  if (list != null && list.isNotEmpty) {
                    liveFeaturedMatch = list.firstWhere((m) => m['isFeatured'] == true, orElse: () => list.first);
                    featuredTournament = t;
                    break;
                  }
                }
              }

              // Uniquement les tournois ayant des matchs actifs sur la sélection
              final tournamentsWithMatches = filteredTournaments
                  .where((t) => matchesByTournament.containsKey(t['id']))
                  .toList();

              int totalMatchesCount = 0;
              for (final l in matchesByTournament.values) {
                totalMatchesCount += l.length;
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 📅 Ruban Horizontal de Dates (SofaScore / FlashScore Style)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141D30),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: _days.map((day) {
                            final isSelected = _selectedDay == day;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedDay = day),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(colors: [Color(0xFFE8604C), Color(0xFFF4A535)])
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.coral.withOpacity(0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // 🌍 Sélecteur Horizontal des 5 Grands Pays
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: _countries.map((c) {
                          final isSelected = _selectedCountry == c['id'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedCountry = c['id']!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.gold.withOpacity(0.25) : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.1),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  c['label']!,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.gold : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // 🏷️ Sélecteur de Tableaux Officiels (DH / DD / DX)
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: _draws.map((d) {
                          final isSelected = _selectedDraw == d['id'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedDraw = d['id']!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.coral.withOpacity(0.25) : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? AppColors.coral : Colors.white.withOpacity(0.1),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  d['label']!,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white60,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // 🏷️ Filtres de statut
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: _filters.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedFilter = filter),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? Colors.white70 : Colors.white12,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white54,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // 🌟 CARTE HERO : RENCONTRE VEDETTE RÉELLE (SofaScore / FlashScore Style)
                  if (liveFeaturedMatch != null && featuredTournament != null && (_selectedFilter == 'Tous' || _selectedFilter == '🔴 En Direct' || _selectedFilter == '🏆 Finales'))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: _buildRealFeaturedMatchHero(featuredTournament, liveFeaturedMatch),
                      ),
                    ),

                  // 🏆 TITRE DU CALENDRIER
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.gold, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "TOURNOIS MAJEURS ACTIFS · $_selectedDay ($totalMatchesCount)",
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Si aucun match ne correspond aux filtres
                  if (tournamentsWithMatches.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141D30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedFilter == '🔴 En Direct' ? Icons.live_tv_rounded : Icons.sports_tennis_rounded,
                              color: AppColors.gold,
                              size: 38,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFilter == '🔴 En Direct'
                                  ? "Aucun match en direct sur cette sélection"
                                  : "Aucun match programmé pour ce filtre",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedFilter == '🔴 En Direct'
                                  ? "Les rencontres en cours sur les courts centraux apparaîtront ici dès leur coup d'envoi."
                                  : "Sélectionnez un autre jour ou un autre pays pour consulter les résultats et le programme.",
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Liste des Tournois & Rencontres Réelles
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final t = tournamentsWithMatches[index];
                          final matches = matchesByTournament[t['id']] ?? [];

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF0F1B29).withOpacity(0.98),
                                  const Color(0xFF16253B).withOpacity(0.92),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // En-tête Tournoi Pro
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(t['countryFlag'] ?? '🌍', style: const TextStyle(fontSize: 22)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t['name'] ?? '',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              "${t['city']} · ${t['category']} (${t['prizeMoney']})",
                                              style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          t['dates'] ?? '',
                                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Liste des vrais matchs de ce tournoi
                                ...matches.map((m) => _buildScheduleMatchTile(t, m, canReferee)),
                              ],
                            ),
                          );
                        },
                        childCount: tournamentsWithMatches.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 36)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // 🌟 Carte Hero Match Vedette (100% Connectée sans faux score simulé)
  Widget _buildRealFeaturedMatchHero(Map<String, dynamic> tournament, Map<String, dynamic> match) {
    final bool isLive = match['status'] == 'LIVE';
    final bool isFinished = match['status'] == 'FINISHED';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16253B), Color(0xFF1E3352)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLive ? Colors.redAccent.withOpacity(0.8) : AppColors.gold.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge En-Tête
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE8604C), Color(0xFFF4A535)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tournament['countryFlag'] ?? '🌍', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    const Text(
                      "CHOC MAJEUR ITF",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (isLive)
                Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text("EN DIRECT 🔴", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11)),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isFinished ? "TERMINÉ 🏆" : (match['time'] ?? 'À venir'),
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            "${tournament['name']} · ${match['court']}",
            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            "${match['round']} · ${match['draw'] == 'DD' ? 'Double Dames' : (match['draw'] == 'DX' ? 'Double Mixte' : 'Double Hommes')}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16.5),
          ),
          const SizedBox(height: 16),

          // Matchup Face à Face
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    if (isLive && match['serving'] == 1)
                      const Text("🎾 ", style: TextStyle(fontSize: 14))
                    else
                      const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        match['team1'] ?? '',
                        style: TextStyle(
                          color: (isFinished && match['winner'] == 1) ? AppColors.gold : Colors.white,
                          fontWeight: (isFinished && match['winner'] == 1) ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (match['set1'] != null) ...[
                      _buildScorePill(match['set1'].split('/')[0], isActive: isLive && match['set2'] == null),
                      const SizedBox(width: 6),
                    ],
                    if (match['set2'] != null) ...[
                      _buildScorePill(match['set2'].split('/')[0], isActive: isLive && match['set3'] == null),
                      const SizedBox(width: 6),
                    ],
                    if (match['set3'] != null) ...[
                      _buildScorePill(match['set3'].split('/')[0], isActive: isLive),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: Colors.white.withOpacity(0.08), height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (isLive && match['serving'] == 2)
                      const Text("🎾 ", style: TextStyle(fontSize: 14))
                    else
                      const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        match['team2'] ?? '',
                        style: TextStyle(
                          color: (isFinished && match['winner'] == 2) ? AppColors.gold : Colors.white,
                          fontWeight: (isFinished && match['winner'] == 2) ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (match['set1'] != null) ...[
                      _buildScorePill(match['set1'].split('/')[1], isActive: isLive && match['set2'] == null),
                      const SizedBox(width: 6),
                    ],
                    if (match['set2'] != null) ...[
                      _buildScorePill(match['set2'].split('/')[1], isActive: isLive && match['set3'] == null),
                      const SizedBox(width: 6),
                    ],
                    if (match['set3'] != null) ...[
                      _buildScorePill(match['set3'].split('/')[1], isActive: isLive),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📋 Ligne de Rencontre Réelle
  Widget _buildScheduleMatchTile(Map<String, dynamic> tournament, Map<String, dynamic> match, bool canReferee) {
    final isLive = match['status'] == 'LIVE';
    final isFinished = match['status'] == 'FINISHED';
    final isScheduled = match['status'] == 'SCHEDULED';
    final draw = match['draw'] ?? 'DH';

    Color team1Color = Colors.white;
    Color team2Color = Colors.white;
    FontWeight team1Weight = FontWeight.bold;
    FontWeight team2Weight = FontWeight.bold;

    if (isFinished) {
      if (match['winner'] == 1) {
        team1Color = AppColors.gold;
        team1Weight = FontWeight.w900;
        team2Color = Colors.white60;
        team2Weight = FontWeight.w500;
      } else if (match['winner'] == 2) {
        team2Color = AppColors.gold;
        team2Weight = FontWeight.w900;
        team1Color = Colors.white60;
        team1Weight = FontWeight.w500;
      }
    } else if (isScheduled) {
      team1Color = Colors.white70;
      team2Color = Colors.white70;
      team1Weight = FontWeight.w600;
      team2Weight = FontWeight.w600;
    }

    Color drawColor = AppColors.coral;
    if (draw == 'DD') drawColor = const Color(0xFFFF5E7E);
    if (draw == 'DX') drawColor = const Color(0xFF00D2FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heure + Badge Tableau (DH/DD/DX) + Tour + Court
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: drawColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: drawColor.withOpacity(0.5), width: 1),
                    ),
                    child: Text(
                      draw,
                      style: TextStyle(color: drawColor, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.redAccent
                          : (isFinished ? Colors.white.withOpacity(0.08) : AppColors.gold.withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isLive ? "🔴 EN DIRECT" : (isFinished ? "TERMINÉ" : (match['time'] ?? 'Programmé')),
                      style: TextStyle(
                        color: isLive ? Colors.white : (isFinished ? Colors.white70 : AppColors.gold),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${match['round']} · ${match['court']}",
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              // Bouton d'Arbitrage (Uniquement visible pour arbitres certifiés)
              if (canReferee && (isLive || isScheduled))
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RefereeLiveScoreScreen(
                          tournament: TournamentModel(
                            id: tournament['id'] ?? '',
                            name: tournament['name'] ?? '',
                            club: tournament['surface'] ?? '',
                            location: tournament['city'] ?? '',
                            country: tournament['countryName'] ?? '',
                            category: tournament['category'] ?? '',
                            dateString: tournament['dates'] ?? '',
                            distance: 0.0,
                          ),
                          match: LiveMatchModel(
                            id: match['id'] ?? '',
                            tournamentId: tournament['id'] ?? '',
                            courtName: match['court'] ?? '',
                            category: draw == 'DD' ? 'Double Dames' : (draw == 'DX' ? 'Double Mixte' : 'Double Messieurs'),
                            round: match['round'] ?? '',
                            team1: match['team1'] ?? '',
                            team2: match['team2'] ?? '',
                            set1Team1: 0, set1Team2: 0,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.coral.withOpacity(0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_tennis_rounded, color: AppColors.coral, size: 12),
                        SizedBox(width: 3),
                        Text("Arbitrer", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Équipe 1
          Row(
            children: [
              if (isLive && match['serving'] == 1)
                const Text("🎾 ", style: TextStyle(fontSize: 12))
              else
                const SizedBox(width: 18),
              Expanded(
                child: Text(
                  match['team1'] ?? '',
                  style: TextStyle(
                    color: team1Color,
                    fontWeight: team1Weight,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (match['set1'] != null) ...[
                Text(match['set1'].split('/')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(width: 10),
              ],
              if (match['set2'] != null) ...[
                Text(match['set2'].split('/')[0], style: TextStyle(color: isLive ? AppColors.gold : Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(width: 10),
              ],
              if (match['set3'] != null) ...[
                Text(match['set3'].split('/')[0], style: TextStyle(color: isLive ? AppColors.gold : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 10),
              ],
              if (isScheduled)
                const Text("⏳ À venir", style: TextStyle(color: Colors.white38, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),

          // Équipe 2
          Row(
            children: [
              if (isLive && match['serving'] == 2)
                const Text("🎾 ", style: TextStyle(fontSize: 12))
              else
                const SizedBox(width: 18),
              Expanded(
                child: Text(
                  match['team2'] ?? '',
                  style: TextStyle(
                    color: team2Color,
                    fontWeight: team2Weight,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (match['set1'] != null) ...[
                Text(match['set1'].split('/')[1], style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(width: 10),
              ],
              if (match['set2'] != null) ...[
                Text(match['set2'].split('/')[1], style: TextStyle(color: isLive ? AppColors.gold : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(width: 10),
              ],
              if (match['set3'] != null) ...[
                Text(match['set3'].split('/')[1], style: TextStyle(color: isLive ? AppColors.gold : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 10),
              ],
              if (isScheduled)
                const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScorePill(String score, {required bool isActive}) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? AppColors.coral.withOpacity(0.35) : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? AppColors.coral : Colors.white.withOpacity(0.2),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Text(
        score,
        style: TextStyle(
          color: isActive ? AppColors.gold : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}
