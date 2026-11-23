import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/app_state.dart';
import '../services/beach_racket_service.dart';

class SmartRacketPickerDialog extends StatefulWidget {
  final UserModel? currentUser;

  const SmartRacketPickerDialog({
    super.key,
    this.currentUser,
  });

  static Future<void> show(BuildContext context, {UserModel? currentUser}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartRacketPickerDialog(currentUser: currentUser),
    );
  }

  @override
  State<SmartRacketPickerDialog> createState() => _SmartRacketPickerDialogState();
}

class _SmartRacketPickerDialogState extends State<SmartRacketPickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _selectedBrand = 'Toutes';
  BeachRacketPreset? _selectedPreset;

  // Custom spec state
  late String _customBrand;
  late String _customModel;
  late String _customMaterial;
  late String _customBalance;
  late String _customSurface;
  late int _customWeight;
  late double _customPower;
  late double _customControl;
  late double _customSpin;
  late String _customPlayStyle;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final u = widget.currentUser;
    _customBrand = (u?.racketBrand?.isNotEmpty ?? false)
        ? u!.racketBrand!
        : (u?.racket?.isNotEmpty ?? false ? u!.racket!.split(' ').first : 'Drop Shot');
    _customModel = u?.racketModel ?? (u?.racket ?? 'Conqueror BT');
    _customMaterial = u?.racketMaterial ?? 'Carbone 3K';
    _customBalance = u?.racketBalance ?? 'Équilibré (Neutre)';
    _customSurface = u?.racketSurface ?? 'Sablée (Rough)';
    _customWeight = u?.racketWeight ?? 330;
    _customPower = u?.racketPower != null ? (u!.racketPower! / 10.0) : 8.5;
    _customControl = u?.racketControl != null ? (u!.racketControl! / 10.0) : 8.0;
    _customSpin = u?.racketSpin != null ? (u!.racketSpin! / 10.0) : 8.5;
    _customPlayStyle = u?.racketPlayStyle ?? 'Polyvalent Attaquant';

    // Try matching an existing preset
    if (u?.racket != null && u!.racket!.isNotEmpty) {
      final matches = BeachRacketService.search(u.racket!);
      if (matches.isNotEmpty) {
        _selectedPreset = matches.first;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSelectPreset(BeachRacketPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _customBrand = preset.brand;
      _customModel = preset.model;
      _customMaterial = preset.material;
      _customBalance = preset.balance;
      _customSurface = preset.surface;
      _customWeight = preset.weightGrams;
      _customPower = preset.power;
      _customControl = preset.control;
      _customSpin = preset.spin;
      _customPlayStyle = preset.playStyle;
    });
  }

  void _recalcCustomSpecs() {
    final specs = BeachRacketService.calculateSpecs(
      material: _customMaterial,
      balance: _customBalance,
      surface: _customSurface,
      weightGrams: _customWeight,
    );
    setState(() {
      _customPower = specs['power']!;
      _customControl = specs['control']!;
      _customSpin = specs['spin']!;
      _customPlayStyle = BeachRacketService.deducePlayStyle(
        power: _customPower,
        control: _customControl,
        balance: _customBalance,
      );
    });
  }

  Future<void> _saveRacket() async {
    setState(() => _isSaving = true);
    try {
      final appState = context.read<AppState>();
      final fullName = '$_customBrand $_customModel'.trim();

      await appState.updateGamePreferences(
        racket: fullName,
        racketBrand: _customBrand,
        racketModel: _customModel,
        racketMaterial: _customMaterial,
        racketBalance: _customBalance,
        racketSurface: _customSurface,
        racketWeight: _customWeight,
        racketPower: (_customPower * 10).round(),
        racketControl: (_customControl * 10).round(),
        racketSpin: (_customSpin * 10).round(),
        racketPlayStyle: _customPlayStyle,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sports_tennis, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Configuration $fullName synchronisée avec succès !',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F9D58),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de sauvegarde: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0B141E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0077B6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sports_tennis, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONFIGURATEUR INTELLIGENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ma Raquette Beach Tennis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF0077B6)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.verified, size: 18),
                  text: 'Catalogue Officiel',
                ),
                Tab(
                  icon: Icon(Icons.tune, size: 18),
                  text: 'Personnaliser / ADN',
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCatalogTab(),
                _buildCustomizerTab(),
              ],
            ),
          ),

          // Bottom Action bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 1: CATALOGUE OFFICIEL BEACH TENNIS
  // ----------------------------------------------------
  Widget _buildCatalogTab() {
    final brands = ['Toutes', ...BeachRacketService.brands];
    final query = _searchController.text.trim();
    final presets = BeachRacketService.search(query, brand: _selectedBrand);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rechercher un modèle (ex: Conqueror, Predator, Carbon 12K)...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF), size: 20),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white60, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF00E5FF)),
              ),
            ),
          ),
        ),

        // Brand chip bar
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: brands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final b = brands[idx];
              final isSel = _selectedBrand == b;
              return ChoiceChip(
                label: Text(
                  b,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.normal,
                    color: isSel ? Colors.black : Colors.white70,
                  ),
                ),
                selected: isSel,
                selectedColor: const Color(0xFF00E5FF),
                backgroundColor: Colors.white.withOpacity(0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSel ? const Color(0xFF00E5FF) : Colors.white12,
                  ),
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedBrand = b);
                },
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Presets list
        Expanded(
          child: presets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun modèle trouvé pour "$query"',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        icon: const Icon(Icons.tune, color: Color(0xFF00E5FF), size: 16),
                        label: const Text(
                          'Créer ma configuration personnalisée',
                          style: TextStyle(color: Color(0xFF00E5FF)),
                        ),
                        onPressed: () => _tabController.animateTo(1),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: presets.length,
                  itemBuilder: (context, idx) {
                    final p = presets[idx];
                    final isSel = _selectedPreset?.id == p.id ||
                        (_customBrand == p.brand && _customModel == p.model);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSel
                              ? [
                                  const Color(0xFF00E5FF).withOpacity(0.18),
                                  const Color(0xFF0077B6).withOpacity(0.12),
                                ]
                              : [
                                  Colors.white.withOpacity(0.05),
                                  Colors.white.withOpacity(0.02),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSel ? const Color(0xFF00E5FF) : Colors.white10,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _onSelectPreset(p),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      p.brand.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.model,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSel)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF00E5FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, size: 14, color: Colors.black),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (p.description != null && p.description!.isNotEmpty) ...[
                                Text(
                                  p.description!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _miniBadge(Icons.layers, p.material),
                                  _miniBadge(Icons.balance, p.balance),
                                  _miniBadge(Icons.grain, p.surface),
                                  _miniBadge(Icons.scale, '${p.weightGrams}g'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Live gauges row
                              Row(
                                children: [
                                  Expanded(child: _miniGauge('Puissance', p.power, const Color(0xFFFF5252))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _miniGauge('Contrôle', p.control, const Color(0xFF00E5FF))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _miniGauge('Effet', p.spin, const Color(0xFFFFD600))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // TAB 2: PERSONNALISATEUR & CALCULATEUR D'ADN
  // ----------------------------------------------------
  Widget _buildCustomizerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tactical DNA Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00E5FF).withOpacity(0.15),
                  const Color(0xFFFF007F).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'ADN TACTIQUE DÉDUIT',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00E5FF)),
                      ),
                      child: Text(
                        _customPlayStyle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _specBar('PUISSANCE', _customPower, const Color(0xFFFF5252)),
                const SizedBox(height: 8),
                _specBar('CONTRÔLE & TOUCHER', _customControl, const Color(0xFF00E5FF)),
                const SizedBox(height: 8),
                _specBar('PRISE D\'EFFET (SPIN)', _customSpin, const Color(0xFFFFD600)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Brand selection
          const Text(
            'Marque',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: BeachRacketService.brands.contains(_customBrand) ? _customBrand : BeachRacketService.brands.first,
            dropdownColor: const Color(0xFF142433),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: BeachRacketService.brands
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _customBrand = val);
            },
          ),

          const SizedBox(height: 16),

          // Model name input
          const Text(
            'Nom du Modèle',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _customModel,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ex: Predator, Conqueror 10, Nexo...',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => _customModel = val,
          ),

          const SizedBox(height: 16),

          // Material selection
          const Text(
            'Matériau du Cadre & Faces',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BeachRacketService.materials.map((mat) {
              final isSel = _customMaterial == mat;
              return ChoiceChip(
                label: Text(
                  mat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? Colors.black : Colors.white70,
                  ),
                ),
                selected: isSel,
                selectedColor: const Color(0xFF00E5FF),
                backgroundColor: Colors.white.withOpacity(0.06),
                onSelected: (val) {
                  if (val) {
                    _customMaterial = mat;
                    _recalcCustomSpecs();
                  }
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Balance selection
          const Text(
            'Équilibre de la Raquette',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BeachRacketService.balances.map((bal) {
              final isSel = _customBalance == bal;
              return ChoiceChip(
                label: Text(
                  bal,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? Colors.black : Colors.white70,
                  ),
                ),
                selected: isSel,
                selectedColor: const Color(0xFF00E5FF),
                backgroundColor: Colors.white.withOpacity(0.06),
                onSelected: (val) {
                  if (val) {
                    _customBalance = bal;
                    _recalcCustomSpecs();
                  }
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Surface texture
          const Text(
            'Texture des Faces',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BeachRacketService.surfaces.map((surf) {
              final isSel = _customSurface == surf;
              return ChoiceChip(
                label: Text(
                  surf,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? Colors.black : Colors.white70,
                  ),
                ),
                selected: isSel,
                selectedColor: const Color(0xFF00E5FF),
                backgroundColor: Colors.white.withOpacity(0.06),
                onSelected: (val) {
                  if (val) {
                    _customSurface = surf;
                    _recalcCustomSpecs();
                  }
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Weight slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Poids',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_customWeight}g',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
            ),
            child: Slider(
              value: _customWeight.toDouble(),
              min: 310,
              max: 350,
              divisions: 40,
              onChanged: (val) {
                setState(() {
                  _customWeight = val.toInt();
                  _recalcCustomSpecs();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SUB-WIDGETS & GAUGES
  // ----------------------------------------------------
  Widget _miniBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _miniGauge(String label, double val, Color color) {
    final pct = (val / 10.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(
              val.toStringAsFixed(1),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3,
          ),
        ),
      ],
    );
  }

  Widget _specBar(String label, double val, Color color) {
    final pct = (val / 10.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$val / 10',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A26),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SÉLECTION ACTUELLE',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_customBrand $_customModel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveRacket,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Valider mon Matériel',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
