import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/whatsapp_share_service.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../widgets/feature_discovery_bubble.dart';
import 'public_profile_screen.dart';

class FftRankingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const FftRankingsScreen({super.key, this.isEmbedded = false});

  @override
  State<FftRankingsScreen> createState() => _FftRankingsScreenState();
}

class _FftRankingsScreenState extends State<FftRankingsScreen> with AutomaticKeepAliveClientMixin {
  int _selectedCircuit = 0; // 0: FFT (France), 1: ITF (Mondial)
  int _selectedTabIndex = 0; // 0: Hommes ('M'), 1: Dames ('F')
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AppState>().currentUser;
      if (user != null && user.isBrazilian) {
        setState(() {
          _selectedCircuit = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  int _parseRank(dynamic value, {int defaultRank = 0}) {
    if (value == null) return defaultRank;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned) ?? defaultRank;
    }
    return defaultRank;
  }

  int _parseEvolution(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      final isNegative = trimmed.contains('-') || trimmed.contains('▼');
      final cleaned = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(cleaned) ?? 0;
      return isNegative ? -parsed : parsed;
    }
    return 0;
  }

  String _normalize(String s) {
    return s.toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .trim();
  }

  Future<List<Map<String, dynamic>>> _searchRankings(String query, String gender) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];

    final normQ = _normalize(cleanQ);
    final tokens = normQ.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    final digits = cleanQ.replaceAll(RegExp(r'\D'), '');

    final Map<String, Map<String, dynamic>> resultMap = {};
    void addCandidate(Map<String, dynamic> data, String docId) {
      if (data['gender'] != null && data['gender'] != gender) return;

      final fName = (data['firstName'] ?? '').toString().trim();
      final lName = (data['lastName'] ?? '').toString().trim();
      final rawName = (data['name'] ?? '$fName $lName').toString().trim();
      final nameKey = _normalize(rawName);
      final lic = (data['licenceNumber'] ?? '').toString().trim();

      if (nameKey.isNotEmpty && resultMap.containsKey(nameKey)) {
        final existing = resultMap[nameKey]!;
        final existingLic = (existing['licenceNumber'] ?? '').toString().trim();
        if (existingLic.isEmpty && lic.isNotEmpty) {
          resultMap[nameKey] = data;
        }
        return;
      }

      final key = nameKey.isNotEmpty ? nameKey : (lic.isNotEmpty ? lic : docId);
      resultMap[key] = data;
    }

    final colName = _selectedCircuit == 1 ? 'itf_rankings' : 'fft_rankings';

    // 1. Recherche directe par numéro de licence / rang
    if (digits.isNotEmpty) {
      if (_selectedCircuit == 0 && digits.length >= 3) {
        final doc = await FirebaseFirestore.instance.collection(colName).doc(digits).get();
        if (doc.exists && doc.data() != null) {
          addCandidate(Map<String, dynamic>.from(doc.data()!), digits);
        }
      }

      final licSnap = await FirebaseFirestore.instance
          .collection(colName)
          .where('searchTokens', arrayContains: digits)
          .where('gender', isEqualTo: gender)
          .limit(40)
          .get();
      for (var d in licSnap.docs) {
        addCandidate(Map<String, dynamic>.from(d.data()), d.id);
      }
    }

    // 2. Recherche rapide par searchTokens (insensible aux accents et à la casse)
    for (var tok in tokens) {
      final snap = await FirebaseFirestore.instance
          .collection(colName)
          .where('searchTokens', arrayContains: tok)
          .where('gender', isEqualTo: gender)
          .limit(80)
          .get();
      for (var d in snap.docs) {
        addCandidate(Map<String, dynamic>.from(d.data()), d.id);
      }
    }

    // 3. Fallback range queries si peu de résultats
    if (resultMap.length < 10) {
      final upperQ = cleanQ.toUpperCase();
      final titleQ = cleanQ[0].toUpperCase() + cleanQ.substring(1).toLowerCase();

      final snaps = await Future.wait([
        FirebaseFirestore.instance
            .collection(colName)
            .where('lastName', isGreaterThanOrEqualTo: upperQ)
            .where('lastName', isLessThanOrEqualTo: '$upperQ\uf8ff')
            .where('gender', isEqualTo: gender)
            .limit(30)
            .get(),
        FirebaseFirestore.instance
            .collection(colName)
            .where('firstName', isGreaterThanOrEqualTo: upperQ)
            .where('firstName', isLessThanOrEqualTo: '$upperQ\uf8ff')
            .where('gender', isEqualTo: gender)
            .limit(30)
            .get(),
        FirebaseFirestore.instance
            .collection(colName)
            .where('firstName', isGreaterThanOrEqualTo: titleQ)
            .where('firstName', isLessThanOrEqualTo: '$titleQ\uf8ff')
            .where('gender', isEqualTo: gender)
            .limit(30)
            .get(),
      ]);

      for (var s in snaps) {
        for (var d in s.docs) {
          addCandidate(Map<String, dynamic>.from(d.data()), d.id);
        }
      }
    }

    // Filtrage multi-tokens en mémoire
    final filtered = resultMap.values.where((data) {
      if (tokens.isEmpty) return true;
      final f = _normalize((data['firstName'] ?? '').toString());
      final l = _normalize((data['lastName'] ?? '').toString());
      final n = _normalize((data['name'] ?? '$f $l').toString());
      final c = _normalize((data['club'] ?? '').toString());
      final lic = (data['licenceNumber'] ?? '').toString();

      return tokens.every((tok) =>
          n.contains(tok) ||
          f.contains(tok) ||
          l.contains(tok) ||
          c.contains(tok) ||
          lic.contains(tok));
    }).toList();

    filtered.sort((a, b) {
      final aLic = (a['licenceNumber'] ?? '').toString();
      final bLic = (b['licenceNumber'] ?? '').toString();
      if (aLic == cleanQ && bLic != cleanQ) return -1;
      if (aLic != cleanQ && bLic == cleanQ) return 1;

      final rankA = _parseRank(a['rank'] ?? a['level']);
      final rankB = _parseRank(b['rank'] ?? b['level']);
      return rankA.compareTo(rankB);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final String currentGender = _selectedTabIndex == 0 ? 'M' : 'F';
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          // Black Overlay 55%
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                if (!widget.isEmbedded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (_selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _selectedCircuit == 1 ? Icons.public : Icons.emoji_events,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCircuit == 1 
                                    ? (isBr ? "Ranking Mundial ITF" : "Classement Mondial ITF")
                                    : (isBr ? "Ranking FFT Beach Tennis" : "Classement FFT Beach Tennis"),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedCircuit == 1
                                    ? (isBr ? "Circuito Mundial de Beach Tennis · Temporada 2026" : "Source : ITF World Tour · Tournée Mondiale 2026")
                                    : (isBr ? "Fonte : FFT Ten'Up · Ranking oficial" : "Source : FFT Ten'Up · Classement officiel"),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 12),

                // Circuit Selector [ 🇫🇷 FFT (France) ]  [ 🌍 ITF (Mondial) ]
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedCircuit = 0;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedCircuit == 0 ? AppColors.gold : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedCircuit == 0
                                    ? [
                                        BoxShadow(
                                          color: AppColors.gold.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isBr ? "🇫🇷 FFT (França)" : "🇫🇷 FFT (France)",
                                style: TextStyle(
                                  color: _selectedCircuit == 0 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedCircuit = 1;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedCircuit == 1 ? const Color(0xFF00B4D8) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedCircuit == 1
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF00B4D8).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isBr ? "🌍 ITF (Mundial)" : "🌍 ITF (Mondial)",
                                style: TextStyle(
                                  color: _selectedCircuit == 1 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Bar Glass
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.2),
                        ),
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          onChanged: (val) {
                            _debounceTimer?.cancel();
                            _debounceTimer = Timer(const Duration(milliseconds: 250), () {
                              if (mounted) {
                                setState(() => _searchQuery = val.trim().toLowerCase());
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: _selectedCircuit == 1
                                ? (isBr ? "Buscar atleta mundial, país..." : "Rechercher joueur mondial, nationalité...")
                                : (isBr ? "Buscar por nome ou clube..." : "Rechercher par nom, prénom ou club..."),
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.white60),
                            prefixIcon: Icon(
                              Icons.search,
                              color: _selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                                    onPressed: () => setState(() => _searchQuery = ""),
                                  )
                                : null,
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                FeatureDiscoveryBubble(
                  featureKey: _selectedCircuit == 1 ? 'itf_rankings_tip' : 'fft_rankings_tip',
                  title: _selectedCircuit == 1
                      ? (isBr ? "Ranking Mundial ITF Beach Tennis" : "Classement Mondial ITF Beach Tennis")
                      : (isBr ? "Ranking Nacional Oficial Ten'Up" : "Classement National Officiel Ten'Up"),
                  message: _selectedCircuit == 1
                      ? (isBr
                          ? "Confira os melhores atletas do mundo : Nicolas Gianotti, André Baran, Sophia Chow, Vitória Marchezini, Mattia Spoto..."
                          : "Retrouvez les meilleurs joueurs et joueuses mondiaux : Nicolas Gianotti, André Baran, Sophia Chow, Vitoria Marchezini, Mattia Spoto...")
                      : (isBr
                          ? "Veja os 3.300+ atletas ranqueados na França. Use a busca por nome ou número de licença !"
                          : "Retrouvez les 3 300+ joueurs et joueuses classés en France. Utilisez la recherche pour trouver un joueur par nom ou numéro de licence !"),
                  icon: _selectedCircuit == 1 ? Icons.public_rounded : Icons.search_rounded,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                ),

                // Glass Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedTabIndex = 0;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 0 ? AppColors.gold : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isBr ? "🏆 Masculino" : "🏆 Hommes",
                                style: TextStyle(
                                  color: _selectedTabIndex == 0 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedTabIndex = 1;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 1 ? AppColors.coral : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isBr ? "🎽 Feminino" : "🎽 Dames",
                                style: TextStyle(
                                  color: _selectedTabIndex == 1 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Ranking List
                Expanded(
                  child: _searchQuery.isNotEmpty
                      ? FutureBuilder<List<Map<String, dynamic>>>(
                          future: _searchRankings(_searchQuery, currentGender),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: _selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold,
                                ),
                              );
                            }
                            final items = snapshot.data ?? [];
                            return _buildListFromMaps(items);
                          },
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: _selectedCircuit == 1
                              ? FirebaseFirestore.instance
                                  .collection('itf_rankings')
                                  .where('gender', isEqualTo: currentGender)
                                  .orderBy('rank', descending: false)
                                  .limit(200)
                                  .snapshots()
                              : FirebaseFirestore.instance
                                  .collection('fft_rankings')
                                  .where('gender', isEqualTo: currentGender)
                                  .orderBy('rank', descending: false)
                                  .limit(200)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              // Fallback query by gender sorted in memory
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection(_selectedCircuit == 1 ? 'itf_rankings' : 'fft_rankings')
                                    .where('gender', isEqualTo: currentGender)
                                    .limit(200)
                                    .snapshots(),
                                builder: (context, fallbackSnap) {
                                  if (fallbackSnap.connectionState == ConnectionState.waiting && !fallbackSnap.hasData) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: _selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold,
                                      ),
                                    );
                                  }
                                  if (fallbackSnap.hasError) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white54),
                                          const SizedBox(height: 12),
                                          Text(
                                            isBr ? "Erro ao carregar o ranking" : "Erreur de chargement du classement",
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton(
                                            onPressed: () => setState(() {}),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                                            child: Text(isBr ? "Tentar novamente" : "Réessayer"),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  if (!fallbackSnap.hasData || fallbackSnap.data!.docs.isEmpty) {
                                    return _buildEmptyState();
                                  }
                                  return _buildListFromDocs(fallbackSnap.data!.docs);
                                },
                              );
                            }

                            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: _selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold,
                                ),
                              );
                            }

                            final rawDocs = snapshot.data?.docs ?? [];
                            final docs = rawDocs.where((d) {
                              final data = d.data() as Map<String, dynamic>;
                              return (data['gender'] ?? '').toString().toUpperCase() == currentGender;
                            }).toList();

                            if (docs.isEmpty) {
                              return _buildEmptyState();
                            }

                            return _buildListFromDocs(docs);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListFromDocs(List<QueryDocumentSnapshot> docs) {
    final seen = <String>{};
    final uniqueItems = <Map<String, dynamic>>[];
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final rank = _parseRank(data['rank'] ?? data['level']);
      final name = (data['name'] ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toString().trim().toUpperCase();
      final key = '$rank-$name';
      if (seen.add(key)) {
        uniqueItems.add(data);
      }
    }
    uniqueItems.sort((a, b) => _parseRank(a['rank'] ?? a['level']).compareTo(_parseRank(b['rank'] ?? b['level'])));
    return _buildListFromMaps(uniqueItems);
  }

  Widget _buildListFromMaps(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    final uniqueItems = <Map<String, dynamic>>[];
    for (final data in items) {
      final rank = _parseRank(data['rank'] ?? data['level']);
      final name = (data['name'] ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toString().trim().toUpperCase();
      final key = '$rank-$name';
      if (seen.add(key)) {
        uniqueItems.add(data);
      }
    }

    if (uniqueItems.isEmpty) {
      final isBr = Provider.of<AppState>(context, listen: false).currentUser?.isBrazilian ?? false;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: Colors.white60),
            const SizedBox(height: 12),
            Text(
              isBr ? "Nenhum atleta encontrado" : "Aucun joueur trouvé",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              isBr ? "Tente outro termo ou verifique a ortografia" : "Essayez un autre mot-clé ou vérifiez l'orthographe",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 90),
        itemCount: uniqueItems.length,
        itemBuilder: (context, index) {
          return _buildRankingCard(uniqueItems[index], index);
        },
      ),
    );
  }

  Widget _buildRankingCard(Map<String, dynamic> data, int index) {
    final dynamic rawRank = data['rank'] ?? data['level'];
    final int rank = _parseRank(rawRank, defaultRank: index + 1);

    final dynamic rawEvolution = data['evolution'] ?? data['rankChange'] ?? data['progression'] ?? data['movement'];
    final int evolution = _parseEvolution(rawEvolution);

    String name = (data['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['lastName'] ?? '').toString().trim();
      name = "$first $last".trim();
    }
    final isBr = Provider.of<AppState>(context, listen: false).currentUser?.isBrazilian ?? false;
    if (name.isEmpty) {
      name = isBr ? "Atleta Desconhecido" : "Joueur Inconnu";
    }

    final dynamic rawPoints = data['points'] ?? data['elo'] ?? 0;
    final String points = rawPoints.toString();

    final dynamic rawTournaments = data['tournaments'] ?? data['tournamentsCount'] ?? data['nbTournois'] ?? 0;
    final String tournaments = rawTournaments.toString();

    final String league = (data['league'] ?? data['ligue'] ?? data['club'] ?? '').toString().trim();
    final String flag = (data['flag'] ?? '').toString().trim();
    final String nationality = (data['nationality'] ?? data['nat'] ?? '').toString().trim();

    final String displaySubtitle = _selectedCircuit == 1
        ? (nationality.isNotEmpty ? "$nationality · ITF World Tour" : "ITF World Tour")
        : league;
    final String pointsSuffix = _selectedCircuit == 1 ? "pts ITF" : "pts";

    return GestureDetector(
      onTap: () => _showPlayerRankingModal(context, data, rank, evolution, points, tournaments, displaySubtitle, name, flag, nationality),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
              children: [
                // Rank & Evolution column
                SizedBox(
                  width: 44,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRankBadge(rank),
                      const SizedBox(height: 3),
                      _buildEvolution(evolution),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Player Name + League / Flag
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (_selectedCircuit == 1 && flag.isNotEmpty) ...[
                            Text(flag, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (displaySubtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          displaySubtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Points & Tournaments
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$points $pointsSuffix",
                      style: TextStyle(
                        color: _selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBr ? "$tournaments torneios" : "$tournaments tournois",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }

  void _showPlayerRankingModal(
    BuildContext context,
    Map<String, dynamic> data,
    int rank,
    int evolution,
    String points,
    String tournaments,
    String displaySubtitle,
    String name,
    String flag,
    String nationality,
  ) {
    final isBr = Provider.of<AppState>(context, listen: false).currentUser?.isBrazilian ?? false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1B29).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: (_selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: (_selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          rank <= 3 ? (rank == 1 ? "🥇" : (rank == 2 ? "🥈" : "🥉")) : "#$rank",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (flag.isNotEmpty) ...[
                                Text(flag, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displaySubtitle.isNotEmpty
                                ? displaySubtitle
                                : (_selectedCircuit == 1
                                    ? "ITF Beach Tennis World Tour"
                                    : (isBr ? "Federação Francesa de Tênis" : "Fédération Française de Tennis")),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildModalStat(
                        _selectedCircuit == 1
                            ? (isBr ? "Posição Mundial" : "Rang Mondial")
                            : (isBr ? "Ranking FFT" : "Classement FFT"),
                        "#$rank",
                        _selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold,
                      ),
                      _buildModalStat(
                        _selectedCircuit == 1 ? "Points ITF" : (isBr ? "Pontos Ten'Up" : "Points Ten'Up"),
                        points,
                        Colors.white,
                      ),
                      _buildModalStat(isBr ? "Torneios" : "Tournois", tournaments, Colors.white70),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedCircuit == 1 ? const Color(0xFF00B4D8) : AppColors.gold,
                      foregroundColor: _selectedCircuit == 1 ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.person_search_rounded, size: 20),
                    label: Text(isBr ? "Ver perfil do atleta" : "Consulter la fiche profil", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      PublicProfileScreen.open(
                        context,
                        userId: (data['licenceNumber'] ?? data['userId'] ?? data['name'])?.toString(),
                        displayName: name,
                        ranking: _selectedCircuit == 1 ? "#$rank ITF" : rank.toString(),
                        location: _selectedCircuit == 1 ? nationality : displaySubtitle,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(isBr ? "Compartilhar atleta" : "Partager cette fiche joueur", style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      final circuitText = _selectedCircuit == 1
                          ? (isBr ? "mundial ITF" : "mondial ITF")
                          : (isBr ? "no Beach Tennis francês" : "au Beach Tennis français");
                      final shareMsg = isBr
                          ? "🎾 $name é #$rank $circuitText com $points pts no BeachMatch !"
                          : "🎾 $name est classé(e) #$rank $circuitText avec $points pts sur BeachMatch !";
                      WhatsAppShareService.shareToWhatsAppOrNative(
                        text: shareMsg,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return const Text("🥇", style: TextStyle(fontSize: 22));
    } else if (rank == 2) {
      return const Text("🥈", style: TextStyle(fontSize: 22));
    } else if (rank == 3) {
      return const Text("🥉", style: TextStyle(fontSize: 22));
    } else {
      return Text(
        "$rank",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      );
    }
  }

  Widget _buildEvolution(int evo) {
    if (evo > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "▲",
            style: TextStyle(
              color: Color(0xFF4ADE80),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 1),
          Text(
            "$evo",
            style: const TextStyle(
              color: Color(0xFF4ADE80),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (evo < 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "▼",
            style: TextStyle(
              color: Color(0xFFF87171),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 1),
          Text(
            "${evo.abs()}",
            style: const TextStyle(
              color: Color(0xFFF87171),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      return const Text(
        "—",
        style: TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    final isBr = Provider.of<AppState>(context, listen: false).currentUser?.isBrazilian ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedCircuit == 1 ? Icons.public : Icons.emoji_events_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              isBr ? "Nenhum ranking disponível" : "Aucun classement disponible",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedCircuit == 1
                  ? (isBr
                      ? "Os dados oficiais do ITF Beach Tennis World Tour aparecerão aqui após sincronização."
                      : "Les données officielles ITF Beach Tennis World Tour apparaîtront ici dès synchronisation.")
                  : (isBr
                      ? "Os dados FFT Ten'Up aparecerão aqui após sincronização."
                      : "Les données FFT Ten'Up apparaîtront ici dès synchronisation."),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
