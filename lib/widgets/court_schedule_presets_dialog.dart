import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/court_schedule_preset.dart';
import '../models/tournament.dart';
import '../models/tournament_bracket_model.dart';
import '../screens/tournaments/court_schedule_screen.dart';
import '../theme/colors.dart';

class CourtSchedulePresetsDialog extends StatefulWidget {
  final TournamentModel tournament;
  final bool isAuthorized;
  final TournamentBracket? initialBracket;

  const CourtSchedulePresetsDialog({
    super.key,
    required this.tournament,
    required this.isAuthorized,
    this.initialBracket,
  });

  @override
  State<CourtSchedulePresetsDialog> createState() => _CourtSchedulePresetsDialogState();
}

class _CourtSchedulePresetsDialogState extends State<CourtSchedulePresetsDialog> {
  bool _showCreateForm = false;
  late Set<String> _selectedCats;
  late int _courtsCount;
  final TextEditingController _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    final tFormats = widget.tournament.formats;
    final Set<String> defaultCats = {};
    if (tFormats.any((f) => f.toUpperCase().contains('DH') || f.toLowerCase().contains('homme') || f.toLowerCase().contains('messieurs'))) {
      defaultCats.add('DH');
    }
    if (tFormats.any((f) => f.toUpperCase().contains('DD') || f.toLowerCase().contains('dame') || f.toLowerCase().contains('femme'))) {
      defaultCats.add('DD');
    }
    if (tFormats.any((f) => f.toUpperCase().contains('DX') || f.toLowerCase().contains('mixte'))) {
      defaultCats.add('DX');
    }
    if (defaultCats.isEmpty) {
      defaultCats.addAll({'DH', 'DD'});
    }
    _selectedCats = defaultCats;
    _courtsCount = widget.initialBracket?.numCourts ?? 4;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _presetsRef => FirebaseFirestore.instance
      .collection('tournaments')
      .doc(widget.tournament.id)
      .collection('court_schedules');

  Future<void> _createNewPreset(int existingCount) async {
    setState(() => _isCreating = true);
    try {
      final docRef = _presetsRef.doc();
      final defaultName = "Répartition ${existingCount + 1}";
      final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : defaultName;

      final preset = CourtSchedulePreset(
        id: docRef.id,
        tournamentId: widget.tournament.id,
        name: name,
        numCourts: _courtsCount,
        categories: _selectedCats.toList(),
        isOfficial: existingCount == 0, // première répartition automatiquement officielle par défaut
        createdAt: DateTime.now(),
      );

      await docRef.set(preset.toMap());

      if (mounted) {
        Navigator.pop(context); // fermer dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourtScheduleScreen(
              tournament: widget.tournament,
              isAuthorized: widget.isAuthorized,
              initialCategories: _selectedCats,
              initialNumCourts: _courtsCount,
              bracket: widget.initialBracket,
              initialPresetId: preset.id,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error creating court schedule preset: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de création : $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _setOfficial(CourtSchedulePreset preset) async {
    try {
      final snap = await _presetsRef.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isOfficial': doc.id == preset.id});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🟢 ${preset.name} est maintenant la répartition officielle !"),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error setting official preset: $e");
    }
  }

  Future<void> _deletePreset(CourtSchedulePreset preset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Supprimer cette répartition ?", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text("Voulez-vous vraiment supprimer ${preset.name} ? Cette action est irréversible.", style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _presetsRef.doc(preset.id).delete();
    }
  }

  void _openPreset(CourtSchedulePreset preset) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourtScheduleScreen(
          tournament: widget.tournament,
          isAuthorized: widget.isAuthorized,
          initialCategories: preset.categories.toSet(),
          initialNumCourts: preset.numCourts,
          bracket: widget.initialBracket,
          initialPresetId: preset.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _presetsRef.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final presets = docs.map((d) => CourtSchedulePreset.fromMap(d.data(), d.id)).toList();
        presets.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        final bool hasPresets = presets.isNotEmpty;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poignée
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Titre
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.stadium_rounded, color: AppColors.gold, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Répartition des Terrains & Rotations",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            hasPresets
                                ? "${presets.length} scénario(s) enregistré(s) · Gérez vos plannings"
                                : "Générez un planning sur mesure adapté à vos paires",
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 1. Liste des répartitions existantes
                if (hasPresets && !_showCreateForm) ...[
                  const Text(
                    "Scénarios enregistrés :",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: presets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p = presets[index];
                      return _buildPresetCard(p);
                    },
                  ),
                  const SizedBox(height: 16),

                  if (widget.isAuthorized)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          side: const BorderSide(color: AppColors.gold, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(
                          "Créer une autre répartition (Répartition ${presets.length + 1})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _showCreateForm = true;
                            _nameController.text = "Répartition ${presets.length + 1}";
                          });
                        },
                      ),
                    ),
                ] else ...[
                  // 2. Formulaire de création d'une nouvelle répartition
                  if (hasPresets)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Nouvelle Répartition (${presets.length + 1})",
                          style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _showCreateForm = false),
                          icon: const Icon(Icons.arrow_back_rounded, size: 14, color: Colors.white54),
                          label: const Text("Retour aux scénarios", style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // Nom de la répartition
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: "Nom de la répartition",
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                      hintText: "Ex : Répartition ${presets.length + 1} (4 courts)",
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.bookmark_border_rounded, color: AppColors.gold, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tableaux à intégrer
                  const Text("Tableaux à intégrer :", style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCatChip("Double Messieurs (DH)", "DH"),
                      _buildCatChip("Double Dames (DD)", "DD"),
                      _buildCatChip("Double Mixte (DX)", "DX"),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Nombre de terrains
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Nombre de terrains :", style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                          Text("De 2 à 12 courts en simultané", style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white, size: 18),
                              onPressed: _courtsCount > 2 ? () => setState(() => _courtsCount--) : null,
                            ),
                            Text(
                              "$_courtsCount courts",
                              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white, size: 18),
                              onPressed: _courtsCount < 12 ? () => setState(() => _courtsCount++) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Bouton Générer & Enregistrer
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isCreating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.calendar_month_rounded, size: 20),
                      label: Text(
                        _isCreating ? "Génération en cours..." : "Générer & Enregistrer la Répartition",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _isCreating ? null : () => _createNewPreset(presets.length),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetCard(CourtSchedulePreset p) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: p.isOfficial ? AppColors.gold.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.1),
          width: p.isOfficial ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    p.isOfficial ? Icons.verified_rounded : Icons.folder_outlined,
                    color: p.isOfficial ? AppColors.gold : Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (p.isOfficial)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 12),
                      SizedBox(width: 4),
                      Text("OFFICIELLE", style: TextStyle(color: Colors.greenAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text("Scénario simulation", style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Text("🏟️ ${p.numCourts} courts", style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(width: 12),
              Text("🎾 ${p.categories.join(' + ')}", style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.isAuthorized && !p.isOfficial)
                TextButton(
                  onPressed: () => _setOfficial(p),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.greenAccent,
                  ),
                  child: const Text("Rendre Officielle", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              if (widget.isAuthorized)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: "Supprimer",
                  onPressed: () => _deletePreset(p),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.isOfficial ? AppColors.gold : Colors.white.withValues(alpha: 0.15),
                  foregroundColor: p.isOfficial ? const Color(0xFF0F172A) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 14),
                label: const Text("Consulter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => _openPreset(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCatChip(String label, String code) {
    final isSelected = _selectedCats.contains(code);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedCats.add(code);
          } else if (_selectedCats.length > 1) {
            _selectedCats.remove(code);
          }
        });
      },
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      selectedColor: AppColors.gold.withValues(alpha: 0.25),
      checkmarkColor: AppColors.gold,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.gold : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11.5,
      ),
    );
  }
}
