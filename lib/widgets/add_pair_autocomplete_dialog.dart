import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';
import '../models/tournament_bracket_model.dart';

class AddPairAutocompleteDialog extends StatefulWidget {
  final String category;
  final TournamentPair? existingPair;

  const AddPairAutocompleteDialog({
    super.key,
    required this.category,
    this.existingPair,
  });

  static Future<TournamentPair?> show(
    BuildContext context, {
    required String category,
    TournamentPair? existingPair,
  }) {
    return showDialog<TournamentPair>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AddPairAutocompleteDialog(
        category: category,
        existingPair: existingPair,
      ),
    );
  }

  @override
  State<AddPairAutocompleteDialog> createState() => _AddPairAutocompleteDialogState();
}

class _AddPairAutocompleteDialogState extends State<AddPairAutocompleteDialog> {
  late TextEditingController _p1NameController;
  late TextEditingController _p2NameController;
  late TextEditingController _p1RankController;
  late TextEditingController _p2RankController;

  String? _p1Club;
  String? _p2Club;
  bool _p1IsVerified = false;
  bool _p2IsVerified = false;

  String? _p1GenderFilter;
  String? _p2GenderFilter;

  List<Map<String, dynamic>> _p1Suggestions = [];
  List<Map<String, dynamic>> _p2Suggestions = [];
  bool _p1Loading = false;
  bool _p2Loading = false;

  Timer? _p1Debounce;
  Timer? _p2Debounce;

  @override
  void initState() {
    super.initState();
    final pair = widget.existingPair;

    _p1NameController = TextEditingController(text: pair?.player1Name ?? '');
    _p2NameController = TextEditingController(text: pair?.player2Name ?? '');
    _p1RankController = TextEditingController(
      text: pair != null && pair.player1Rank < 9999 ? '${pair.player1Rank}' : '500',
    );
    _p2RankController = TextEditingController(
      text: pair != null && pair.player2Rank < 9999 ? '${pair.player2Rank}' : '500',
    );

    // Initialisation des filtres de genre selon l'épreuve
    final cat = widget.category.toLowerCase();
    if (cat.contains('dame') || cat.contains('femme') || cat == 'dd') {
      _p1GenderFilter = 'F';
      _p2GenderFilter = 'F';
    } else if (cat.contains('mixte') || cat == 'dx') {
      _p1GenderFilter = 'M';
      _p2GenderFilter = 'F';
    } else {
      // Hommes / DH par défaut
      _p1GenderFilter = 'M';
      _p2GenderFilter = 'M';
    }

    _p1NameController.addListener(() => setState(() {}));
    _p2NameController.addListener(() => setState(() {}));
    _p1RankController.addListener(() => setState(() {}));
    _p2RankController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _p1Debounce?.cancel();
    _p2Debounce?.cancel();
    _p1NameController.dispose();
    _p2NameController.dispose();
    _p1RankController.dispose();
    _p2RankController.dispose();
    super.dispose();
  }

  void _onP1Changed(String val) {
    _p1Debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _p1Suggestions = [];
        _p1Loading = false;
        _p1IsVerified = false;
        _p1Club = null;
      });
      return;
    }

    setState(() => _p1Loading = true);
    _p1Debounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await _searchFftPlayers(val, _p1GenderFilter);
      if (mounted) {
        setState(() {
          _p1Suggestions = results;
          _p1Loading = false;
        });
      }
    });
  }

  void _onP2Changed(String val) {
    _p2Debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _p2Suggestions = [];
        _p2Loading = false;
        _p2IsVerified = false;
        _p2Club = null;
      });
      return;
    }

    setState(() => _p2Loading = true);
    _p2Debounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await _searchFftPlayers(val, _p2GenderFilter);
      if (mounted) {
        setState(() {
          _p2Suggestions = results;
          _p2Loading = false;
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> _searchFftPlayers(String queryText, String? gender) async {
    final cleaned = queryText.trim().toLowerCase();
    if (cleaned.length < 2) return [];

    final terms = cleaned.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (terms.isEmpty) return [];

    // Recherche via le token le plus long pour maximiser la pertinence
    terms.sort((a, b) => b.length.compareTo(a.length));
    final searchToken = terms.first;

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('fft_rankings');
      query = query.where('searchTokens', arrayContains: searchToken);
      if (gender != null && gender.isNotEmpty) {
        query = query.where('gender', isEqualTo: gender);
      }
      query = query.limit(15);

      final snapshot = await query.get();
      final list = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fullName = (data['name'] ?? '').toString().toLowerCase();
        // Vérifier si tous les termes tapés sont présents dans le nom complet
        final matchesAll = terms.every((t) => fullName.contains(t) || (data['licenceNumber']?.toString().contains(t) ?? false));
        if (matchesAll || terms.length == 1) {
          list.add(data);
        }
      }

      // Trier les résultats par classement officiel (les meilleurs en premier)
      list.sort((a, b) {
        final rA = int.tryParse(a['rank']?.toString() ?? '9999') ?? 9999;
        final rB = int.tryParse(b['rank']?.toString() ?? '9999') ?? 9999;
        return rA.compareTo(rB);
      });

      return list;
    } catch (e) {
      debugPrint("Erreur recherche FFT : $e");
      return [];
    }
  }

  void _selectP1Player(Map<String, dynamic> player) {
    HapticFeedback.selectionClick();
    setState(() {
      _p1NameController.text = (player['name'] ?? '').toString();
      _p1RankController.text = (player['rank'] ?? 500).toString();
      _p1Club = player['club']?.toString();
      _p1IsVerified = true;
      _p1Suggestions = [];
    });
  }

  void _selectP2Player(Map<String, dynamic> player) {
    HapticFeedback.selectionClick();
    setState(() {
      _p2NameController.text = (player['name'] ?? '').toString();
      _p2RankController.text = (player['rank'] ?? 500).toString();
      _p2Club = player['club']?.toString();
      _p2IsVerified = true;
      _p2Suggestions = [];
    });
  }

  int get _rank1 => int.tryParse(_p1RankController.text.trim()) ?? 500;
  int get _rank2 => int.tryParse(_p2RankController.text.trim()) ?? 500;
  int get _pairWeight => _rank1 + _rank2;

  String get _weightBadgeLabel {
    if (_pairWeight <= 100) return "🔥 Paire Favorite (Top 100)";
    if (_pairWeight <= 500) return "⭐ Tête de Série Potentielle";
    if (_pairWeight <= 1200) return "🎾 Tableau Principal";
    return "🏖️ Qualification / Poules";
  }

  void _submit() {
    final p1 = _p1NameController.text.trim();
    final p2 = _p2NameController.text.trim();

    if (p1.isEmpty || p2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez renseigner les noms des deux joueurs."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final resultPair = TournamentPair(
      id: widget.existingPair?.id ?? "pair_${DateTime.now().millisecondsSinceEpoch}",
      player1Name: p1,
      player1Rank: _rank1,
      player2Name: p2,
      player2Rank: _rank2,
      seed: widget.existingPair?.seed,
      isBye: false,
    );

    Navigator.of(context).pop(resultPair);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPair != null;
    final isDx = widget.category.toLowerCase().contains('mixte') || widget.category.toLowerCase() == 'dx';

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Titre
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
                      color: AppColors.gold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? "Modifier la Paire" : "Inscrire une Paire",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          "Recherche instantanée dans les 2 000+ classés Ten'Up",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // JOUEUR 1
              _buildPlayerSection(
                title: isDx ? "Joueur 1 (Messieurs)" : "Joueur 1",
                icon: Icons.person,
                nameController: _p1NameController,
                rankController: _p1RankController,
                club: _p1Club,
                isVerified: _p1IsVerified,
                isLoading: _p1Loading,
                suggestions: _p1Suggestions,
                onChanged: _onP1Changed,
                onSelect: _selectP1Player,
                onClearVerification: () => setState(() {
                  _p1IsVerified = false;
                  _p1Club = null;
                }),
              ),

              const SizedBox(height: 14),

              // Séparateur visuel avec icône versus ou duo
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_rounded, size: 14, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        "PARTENAIRE",
                        style: TextStyle(
                          color: AppColors.gold.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // JOUEUR 2
              _buildPlayerSection(
                title: isDx ? "Joueur 2 (Dames)" : "Joueur 2",
                icon: Icons.person_outline,
                nameController: _p2NameController,
                rankController: _p2RankController,
                club: _p2Club,
                isVerified: _p2IsVerified,
                isLoading: _p2Loading,
                suggestions: _p2Suggestions,
                onChanged: _onP2Changed,
                onSelect: _selectP2Player,
                onClearVerification: () => setState(() {
                  _p2IsVerified = false;
                  _p2Club = null;
                }),
              ),

              const SizedBox(height: 18),

              // BANNER POIDS TOTAL & ESTIMATION TÊTE DE SÉRIE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.15),
                      AppColors.coral.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.scale_rounded, color: Colors.black, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Poids de la paire : ",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              Text(
                                "$_pairWeight",
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                " ($_rank1 + $_rank2)",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _weightBadgeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // BOUTONS D'ACTION
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        "Annuler",
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      icon: Icon(isEditing ? Icons.check_circle_rounded : Icons.add_circle_rounded, size: 18),
                      label: Text(
                        isEditing ? "Enregistrer" : "Inscrire la Paire",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerSection({
    required String title,
    required IconData icon,
    required TextEditingController nameController,
    required TextEditingController rankController,
    required String? club,
    required bool isVerified,
    required bool isLoading,
    required List<Map<String, dynamic>> suggestions,
    required ValueChanged<String> onChanged,
    required ValueChanged<Map<String, dynamic>> onSelect,
    required VoidCallback onClearVerification,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVerified
              ? Colors.greenAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.12),
          width: isVerified ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre avec Pastille certifiée si joueur trouvé dans Ten'Up
          Row(
            children: [
              Icon(icon, size: 14, color: isVerified ? Colors.greenAccent : AppColors.gold),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isVerified ? Colors.greenAccent : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 11, color: Colors.greenAccent),
                      SizedBox(width: 3),
                      Text(
                        "Certifié FFT",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Ligne Champs : Nom & Prénom + Classement
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Champ Nom & Prénom (Autocomplété)
              Expanded(
                flex: 7,
                child: TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: "Nom & Prénom (ex: Dupont)",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
                    suffixIcon: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                            ),
                          )
                        : (nameController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 15, color: Colors.white54),
                                onPressed: () {
                                  nameController.clear();
                                  onChanged('');
                                  onClearVerification();
                                },
                              )
                            : null),
                    filled: true,
                    fillColor: Colors.black26,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Champ Classement FFT
              Expanded(
                flex: 3,
                child: TextField(
                  controller: rankController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    labelText: "Rang FFT",
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                    filled: true,
                    fillColor: Colors.black26,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Affichage du Club si certifié
          if (club != null && club.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_city_rounded, size: 12, color: Colors.white.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    club,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // MENU DÉROULANT DES SUGGESTIONS FFT
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (ctx, idx) {
                    final s = suggestions[idx];
                    final name = s['name']?.toString() ?? '';
                    final rank = s['rank']?.toString() ?? '500';
                    final sClub = s['club']?.toString() ?? '';
                    final licence = s['licenceNumber']?.toString() ?? '';

                    return InkWell(
                      onTap: () => onSelect(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            // Rang badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.gold, width: 0.8),
                              ),
                              child: Text(
                                "#$rank",
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Nom & Club
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (sClub.isNotEmpty || licence.isNotEmpty)
                                    Text(
                                      sClub.isNotEmpty ? sClub : "Licence: $licence",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.gold),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
