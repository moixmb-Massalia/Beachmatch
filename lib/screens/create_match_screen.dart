import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/user.dart';
import '../models/court.dart';

class CreateMatchScreen extends StatefulWidget {
  final UserModel? invitedPlayer;
  final CourtModel? preselectedCourt;

  const CreateMatchScreen({super.key, this.invitedPlayer, this.preselectedCourt});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  String? _selectedCourtId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _targetLevel = 3;
  int _maxPlayers = 4;
  bool _isPrivate = false;
  final TextEditingController _descController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedCourt != null) {
      _selectedCourtId = widget.preselectedCourt!.id;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveMatch() async {
    if (_selectedCourtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner un terrain de Beach Tennis.")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final scheduledTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final matchId = await context.read<AppState>().createMatch(
        courtId: _selectedCourtId!,
        scheduledTime: scheduledTime,
        targetLevel: _targetLevel,
        maxPlayers: _maxPlayers,
        isPrivate: _isPrivate,
        description: _descController.text.trim(),
        invitedPlayerIds: widget.invitedPlayer != null ? [widget.invitedPlayer!.id] : null,
      );

      if (mounted) {
        final courts = context.read<AppState>().courts;
        final selectedCourt = courts.firstWhere(
          (c) => c.id == _selectedCourtId,
          orElse: () => CourtModel(id: '', name: 'Terrain de Beach', latitude: 0, longitude: 0, isFree: true, hasLights: false, hasShowers: false),
        );
        _showSuccessDialog(matchId ?? '', selectedCourt.name, scheduledTime);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur lors de la création : $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(String matchId, String courtName, DateTime matchDate) {
    final formattedDate = DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(matchDate);
    final shareText = "🎾 Partie de Beach Tennis !\n\n"
        "📅 $formattedDate\n"
        "📍 $courtName\n"
        "🎯 Niveau $_targetLevel • $_maxPlayers joueurs max\n\n"
        "Rejoins la partie sur BeachMatch pour compléter le terrain : https://beachmatch.app/match?id=$matchId";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Text("🎉", style: TextStyle(fontSize: 40)),
            SizedBox(height: 8),
            Text(
              "Partie créée avec succès !",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isPrivate
                  ? "Votre partie privée est prête. Partagez-la avec vos amis pour qu'ils puissent vous rejoindre !"
                  : "Votre partie est désormais visible par tous les joueurs de la région.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008069), // WhatsApp Green
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text(
                "Partager sur WhatsApp",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () {
                Share.share(shareText);
              },
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("Voir mes matchs", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courts = context.read<AppState>().courts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Créer une partie",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background plage
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_court_aerial_1785052250131.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.78),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Invitation spéciale
                  if (widget.invitedPlayer != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gold, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_add_alt_1_rounded, color: AppColors.gold, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Invitation directe pour", style: TextStyle(fontSize: 12, color: Colors.white70)),
                                Text(
                                  widget.invitedPlayer!.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 1. Choix de la Visibilité (Formule Gagnante : Publique VS Privée)
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.visibility_rounded, color: AppColors.gold, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Visibilité de la partie",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildVisibilityOption(
                                title: "Publique 🌐",
                                subtitle: "Ouverte à tous les beacheurs",
                                isSelected: !_isPrivate,
                                onTap: () => setState(() => _isPrivate = false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildVisibilityOption(
                                title: "Privée 🔒",
                                subtitle: "Amis / Sur invitation",
                                isSelected: _isPrivate,
                                onTap: () => setState(() => _isPrivate = true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Sélection du Terrain
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: AppColors.coral, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Terrain de Beach Tennis",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Autocomplete<CourtModel>(
                          displayStringForOption: (CourtModel court) =>
                              court.id == "NEW_COURT" ? "+ Saisir un terrain manuellement" : "${court.name} (${court.city})",
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<CourtModel>.empty();
                            }
                            final query = textEditingValue.text.toLowerCase();
                            final matches = courts.where((CourtModel court) {
                              return court.name.toLowerCase().contains(query) || court.city.toLowerCase().contains(query);
                            }).toList();

                            matches.add(CourtModel(id: "NEW_COURT", name: textEditingValue.text, latitude: 0, longitude: 0, isFree: true, hasLights: false, hasShowers: false));
                            return matches;
                          },
                          onSelected: (CourtModel selection) async {
                            FocusScope.of(context).unfocus();
                            if (selection.id == "NEW_COURT") {
                              final newCourtName = await showDialog<String>(
                                context: context,
                                builder: (ctx) {
                                  String name = selection.name;
                                  return AlertDialog(
                                    backgroundColor: const Color(0xFF1E293B),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text("Ajouter un terrain", style: TextStyle(color: Colors.white)),
                                    content: TextFormField(
                                      initialValue: name,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        hintText: "Nom ou adresse du terrain",
                                        hintStyle: TextStyle(color: Colors.white38),
                                      ),
                                      onChanged: (v) => name = v,
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
                                        onPressed: () => Navigator.pop(ctx, name),
                                        child: const Text("Ajouter", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (newCourtName != null && newCourtName.isNotEmpty) {
                                final docRef = await FirebaseFirestore.instance.collection('courts').add({
                                  "name": newCourtName,
                                  "city": "Inconnue",
                                  "latitude": context.read<AppState>().currentPosition?.latitude ?? 43.6961,
                                  "longitude": context.read<AppState>().currentPosition?.longitude ?? 7.2717,
                                  "isFree": true,
                                  "hasLighting": false,
                                  "hasParking": false,
                                });
                                await context.read<AppState>().loadData();
                                setState(() => _selectedCourtId = docRef.id);
                              }
                            } else {
                              setState(() => _selectedCourtId = selection.id);
                            }
                          },
                          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Rechercher un terrain de plage...",
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.08),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Date et Heure
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: AppColors.gold, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Date & Heure du match",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (date != null) setState(() => _selectedDate = date);
                                },
                                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                                label: Text(
                                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.12),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime,
                                  );
                                  if (time != null) setState(() => _selectedTime = time);
                                },
                                icon: const Icon(Icons.access_time_rounded, size: 18),
                                label: Text(
                                  _selectedTime.format(context),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.12),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Niveau Cible & Format de jeu
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sports_tennis_rounded, color: AppColors.coral, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Niveau cible & Format",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text("Niveau des participants", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(5, (index) => _buildLevelChip(index + 1)),
                        ),
                        const SizedBox(height: 16),
                        const Text("Nombre de joueurs", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPlayerCountChip(label: "Double (4 joueurs)", count: 4),
                            _buildPlayerCountChip(label: "8 joueurs", count: 8),
                            _buildPlayerCountChip(label: "Simple (2)", count: 2),
                            _buildPlayerCountChip(label: "Personnaliser", count: _maxPlayers, isCustom: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Message / Consignes optionnelles
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes_rounded, color: AppColors.gold, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Message / Consignes (Optionnel)",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Ex : Balles fournies, match amical détendu...",
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bouton Créer
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveMatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_task_rounded, size: 20),
                              SizedBox(width: 8),
                              Text("Publier la partie", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral.withOpacity(0.3) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.coral : Colors.white.withOpacity(0.15),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelChip(int level) {
    final isSelected = _targetLevel == level;
    return GestureDetector(
      onTap: () => setState(() => _targetLevel = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.coral
              : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.coral
                : Colors.white.withOpacity(0.25),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.coral.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          "Niveau $level",
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCountChip({required String label, required int count, bool isCustom = false}) {
    final isSelected = isCustom ? (_maxPlayers != 2 && _maxPlayers != 4 && _maxPlayers != 8) : (_maxPlayers == count);
    final displayLabel = isCustom && isSelected ? "Perso: $_maxPlayers" : label;

    return GestureDetector(
      onTap: () {
        if (isCustom) {
          _showCustomPlayerCountDialog();
        } else {
          setState(() => _maxPlayers = count);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.coral
              : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.coral
                : Colors.white.withOpacity(0.25),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.coral.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom) ...[
              Icon(Icons.tune_rounded, size: 14, color: isSelected ? Colors.white : Colors.white70),
              const SizedBox(width: 4),
            ],
            Text(
              displayLabel,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomPlayerCountDialog() {
    int tempCount = (_maxPlayers == 2 || _maxPlayers == 4 || _maxPlayers == 8) ? 6 : _maxPlayers;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.coral),
                SizedBox(width: 8),
                Text("Nombre de joueurs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$tempCount joueurs",
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 26),
                ),
                const SizedBox(height: 12),
                Slider(
                  value: tempCount.toDouble(),
                  min: 2,
                  max: 16,
                  divisions: 14,
                  activeColor: AppColors.coral,
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    setDialogState(() => tempCount = val.round());
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
                onPressed: () {
                  setState(() => _maxPlayers = tempCount);
                  Navigator.pop(ctx);
                },
                child: const Text("Valider", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
