import 'dart:ui';
import 'package:flutter/material.dart';
import '../data/tournament_cities.dart';
import '../theme/colors.dart';

/// Champ de saisie intelligent de ville avec suggestions instantanées et filtres par pays
class SmartCityAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onCitySelected;

  const SmartCityAutocompleteField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.validator,
    this.onCitySelected,
  });

  @override
  State<SmartCityAutocompleteField> createState() => _SmartCityAutocompleteFieldState();
}

class _SmartCityAutocompleteFieldState extends State<SmartCityAutocompleteField> {
  void _openCityPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CityPickerModal(
        currentCity: widget.controller.text,
        onSelected: (selectedCity) {
          final regionPart = selectedCity.region != null ? ' (${selectedCity.region})' : '';
          final formatted = '${selectedCity.name}$regionPart';
          widget.controller.text = formatted;
          if (widget.onCitySelected != null) {
            widget.onCitySelected!(formatted);
          }
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      readOnly: true,
      onTap: _openCityPickerSheet,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.15),
        hintText: widget.hint ?? "Choisir ma ville ou région...",
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.coral),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: const Text(
                "Choisir",
                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      validator: widget.validator,
    );
  }
}

class _CityPickerModal extends StatefulWidget {
  final String currentCity;
  final ValueChanged<TournamentCity> onSelected;

  const _CityPickerModal({
    required this.currentCity,
    required this.onSelected,
  });

  @override
  State<_CityPickerModal> createState() => _CityPickerModalState();
}

class _CityPickerModalState extends State<_CityPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCountryFilter = 'ALL';
  String _searchQuery = '';

  final List<Map<String, String>> _countryPills = [
    {'code': 'ALL', 'label': 'Toutes 🌍'},
    {'code': 'France', 'label': 'France 🇫🇷'},
    {'code': 'La Réunion', 'label': 'Réunion 🇷🇪'},
    {'code': 'Italie', 'label': 'Italie 🇮🇹'},
    {'code': 'Espagne', 'label': 'Espagne 🇪🇸'},
    {'code': 'Brésil', 'label': 'Brésil 🇧🇷'},
    {'code': 'Aruba', 'label': 'Aruba 🇦🇼'},
    {'code': 'Venezuela', 'label': 'Venezuela 🇻🇪'},
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TournamentCity> get _filteredCities {
    return kTournamentCities.where((c) {
      if (_selectedCountryFilter != 'ALL' && c.country != _selectedCountryFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final full = '${c.name} ${c.country} ${c.region ?? ''}'.toLowerCase();
        return full.contains(_searchQuery);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.location_city_rounded, color: AppColors.gold, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Villes & Destinations Beach Tennis",
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "Sélectionnez votre ville parmi les lieux de compétitions officielles pour calibrer vos alertes et votre radar.",
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 14),

              // Barre de recherche
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Rechercher une ville (ex: Marseille, Cervia...)",
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              // Filtres pays
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _countryPills.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final p = _countryPills[i];
                    final isSel = _selectedCountryFilter == p['code'];
                    return InkWell(
                      onTap: () => setState(() => _selectedCountryFilter = p['code']!),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.gold : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel ? AppColors.gold : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          p['label']!,
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Liste des villes filtrées
              Expanded(
                child: _filteredCities.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_off, color: Colors.white38, size: 36),
                            const SizedBox(height: 8),
                            const Text(
                              "Aucune ville de tournoi trouvée",
                              style: TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            if (_searchCtrl.text.trim().isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  final customCity = TournamentCity(
                                    name: _searchCtrl.text.trim(),
                                    country: 'France',
                                    flag: '📍',
                                  );
                                  widget.onSelected(customCity);
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.add_location_alt, color: AppColors.gold, size: 16),
                                label: Text(
                                  "Utiliser '${_searchCtrl.text.trim()}' quand même",
                                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredCities.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                        itemBuilder: (ctx, i) {
                          final city = _filteredCities[i];
                          final isCurrent = widget.currentCity.toLowerCase().contains(city.name.toLowerCase());
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(city.flag, style: const TextStyle(fontSize: 18)),
                            ),
                            title: Text(
                              city.name,
                              style: TextStyle(
                                color: isCurrent ? AppColors.gold : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${city.country}${city.region != null ? ' • ${city.region}' : ''}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                            ),
                            trailing: isCurrent
                                ? const Icon(Icons.check_circle, color: AppColors.gold, size: 20)
                                : const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
                            onTap: () {
                              widget.onSelected(city);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
