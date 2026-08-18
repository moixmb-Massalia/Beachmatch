import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/user.dart';
import 'create_match_screen.dart';
import 'chat_detail_screen.dart';
import 'public_profile_screen.dart';
import '../widgets/beach_weather_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';

class MapScreen extends StatefulWidget {
  final CourtModel? initialCourt;
  const MapScreen({super.key, this.initialCourt});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  MapType _currentMapType = MapType.normal;
  
  // Track center for crosshair functionality
  LatLng? _currentCenter;

  String _removeAccents(String str) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  void _searchLocation(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    final cleanQuery = _removeAccents(query.trim()).toLowerCase();
    final courts = context.read<AppState>().courts;
    
    final matchingCourts = courts.where((court) {
      final nameNorm = _removeAccents(court.name).toLowerCase();
      final cityNorm = _removeAccents(court.city).toLowerCase();
      final descNorm = _removeAccents(court.description ?? '').toLowerCase();
      return nameNorm.contains(cleanQuery) || 
             cityNorm.contains(cleanQuery) ||
             descNorm.contains(cleanQuery);
    }).toList();

    // Tri par pertinence et distance
    final userPos = context.read<AppState>().currentPosition;
    if (userPos != null) {
      matchingCourts.sort((a, b) {
        final distA = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, a.latitude, a.longitude);
        final distB = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
    }

    setState(() {
      _searchResults = [
        // 1. Terrains correspondants (jusqu'à 4)
        ...matchingCourts.take(4),
        // 2. Option de Saisie / Déclaration manuelle immédiate
        {"isManualAdd": true, "query": query.trim()},
        // 3. Option de recherche globale de ville OpenStreetMap
        {"isExternal": true, "query": query.trim()},
      ];
    });
  }

  Future<void> _searchExternalCity(String city) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchResults = [];
      _isSearching = true;
    });
    
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(city)}&format=json&countrycodes=fr,es,it,re,mq,gp,nc&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'BeachMatchApp'}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lon), 13.0));
          if (mounted) setState(() { _isSearching = false; _searchController.clear(); });
          return;
        }
      }
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.mapSearchError)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.mapSearchGenericError(e.toString()))));
      }
    }
  }

  void _goToLocation(double lat, double lon) {
    FocusScope.of(context).unfocus();
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lon), 16.0));
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courts = context.watch<AppState>().filteredCourts;
    
    // Set custom markers
    Set<Marker> markers = courts.map((court) {
      return Marker(
        markerId: MarkerId(court.id),
        position: LatLng(court.latitude, court.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange), // Coral like color
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _buildCourtDetails(context, court),
          );
        },
      );
    }).toSet();

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "map_type_btn",
            backgroundColor: Colors.white,
            child: const Icon(Icons.layers, color: AppColors.coral),
            onPressed: () {
              setState(() {
                _currentMapType = _currentMapType == MapType.normal ? MapType.satellite : MapType.normal;
              });
            },
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "my_location_btn",
            backgroundColor: AppColors.coral,
            child: const Icon(Icons.my_location, color: Colors.white),
            onPressed: () {
              final pos = context.read<AppState>().currentPosition;
              if (pos != null && _mapController != null) {
                _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
                  LatLng(pos.latitude, pos.longitude),
                  15.0,
                ));
              }
            },
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 90.0), // Above the bottom nav bar
            child: FloatingActionButton.extended(
              heroTag: "suggest_court_btn",
              onPressed: () => _showSuggestCourtDialog(context),
              backgroundColor: AppColors.coral,
              elevation: 8,
              icon: const Icon(Icons.add_location_alt, color: Colors.white, size: 28),
              label: Text(AppLocalizations.of(context)!.mapAddCourtBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map Background
          GoogleMap(
            mapType: _currentMapType,
            onMapCreated: (controller) {
              _mapController = controller;
              if (widget.initialCourt != null) {
                final target = LatLng(widget.initialCourt!.latitude, widget.initialCourt!.longitude);
                _currentCenter = target;
                controller.animateCamera(CameraUpdate.newLatLngZoom(target, 15.5));
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => _buildCourtDetails(ctx, widget.initialCourt!),
                    );
                  }
                });
              } else {
                _currentCenter = context.read<AppState>().mapCenter;
              }
            },
            initialCameraPosition: CameraPosition(
              target: widget.initialCourt != null 
                  ? LatLng(widget.initialCourt!.latitude, widget.initialCourt!.longitude)
                  : context.read<AppState>().mapCenter,
              zoom: widget.initialCourt != null ? 15.5 : 13.5,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            onCameraMove: (position) {
              _currentCenter = position.target;
            },
            onTap: (latlng) {
              _showSuggestCourtDialog(context, specificLocation: latlng);
            },
            onLongPress: (latlng) {
              _showSuggestCourtDialog(context, specificLocation: latlng);
            },
          ),
          
          // Center Crosshair
          const Center(
            child: IgnorePointer(
              child: Icon(Icons.add, color: AppColors.coral, size: 30),
            ),
          ),

          // Floating Glass Header & Filter Bar
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.map, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(AppLocalizations.of(context)!.mapFindCourtTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
                                  child: Text(AppLocalizations.of(context)!.mapCourtsCount(courts.length), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Rechercher une ville, un terrain...",
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                              ),
                              onChanged: _searchLocation,
                              onSubmitted: (value) {
                                final query = value.trim();
                                if (query.isEmpty) return;
                                final cleanQuery = _removeAccents(query).toLowerCase();
                                final courts = context.read<AppState>().courts;
                                final matchingCourts = courts.where((court) {
                                  final nameNorm = _removeAccents(court.name).toLowerCase();
                                  final cityNorm = _removeAccents(court.city).toLowerCase();
                                  final descNorm = _removeAccents(court.description ?? '').toLowerCase();
                                  return nameNorm.contains(cleanQuery) || cityNorm.contains(cleanQuery) || descNorm.contains(cleanQuery);
                                }).toList();

                                if (matchingCourts.isNotEmpty) {
                                  final court = matchingCourts.first;
                                  _goToLocation(court.latitude, court.longitude);
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => _buildCourtDetails(context, court),
                                  );
                                } else {
                                  _searchExternalCity(query);
                                }
                              },
                            ),

                            // Filtres rapides d'accès & pays
                            Consumer<AppState>(
                              builder: (context, appState, child) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10.0),
                                  child: SizedBox(
                                    height: 32,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        _buildMapFilterChip(
                                          label: "Tous 🌍",
                                          isSelected: appState.selectedCourtFilter == 'ALL' && appState.selectedCourtCountry == 'ALL',
                                          onTap: () {
                                            appState.setCourtFilter('ALL');
                                            appState.setCourtCountry('ALL');
                                          },
                                        ),
                                        _buildMapFilterChip(
                                          label: "🏖️ Plages libres",
                                          isSelected: appState.selectedCourtFilter == 'BEACH_FREE',
                                          onTap: () {
                                            appState.setCourtFilter(appState.selectedCourtFilter == 'BEACH_FREE' ? 'ALL' : 'BEACH_FREE');
                                          },
                                        ),
                                        _buildMapFilterChip(
                                          label: "🏢 Clubs & Complexes",
                                          isSelected: appState.selectedCourtFilter == 'CLUB_FACILITY',
                                          onTap: () {
                                            appState.setCourtFilter(appState.selectedCourtFilter == 'CLUB_FACILITY' ? 'ALL' : 'CLUB_FACILITY');
                                          },
                                        ),
                                        _buildMapFilterChip(
                                          label: "🇫🇷 France",
                                          isSelected: appState.selectedCourtCountry == 'FR',
                                          onTap: () {
                                            appState.setCourtCountry(appState.selectedCourtCountry == 'FR' ? 'ALL' : 'FR');
                                          },
                                        ),
                                        _buildMapFilterChip(
                                          label: "🇪🇸 Espagne",
                                          isSelected: appState.selectedCourtCountry == 'ES',
                                          onTap: () {
                                            appState.setCourtCountry(appState.selectedCourtCountry == 'ES' ? 'ALL' : 'ES');
                                          },
                                        ),
                                        _buildMapFilterChip(
                                          label: "🇮🇹 Italie",
                                          isSelected: appState.selectedCourtCountry == 'IT',
                                          onTap: () {
                                            appState.setCourtCountry(appState.selectedCourtCountry == 'IT' ? 'ALL' : 'IT');
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            if (_isSearching)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
                              )
                            else if (_searchResults.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                constraints: const BoxConstraints(maxHeight: 290),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1B29).withOpacity(0.96),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.6),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  shrinkWrap: true,
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (ctx, i) => Divider(color: Colors.white.withOpacity(0.08), height: 1),
                                  itemBuilder: (ctx, i) {
                                    final item = _searchResults[i];
                                    
                                    // ➕ Option 1 : Saisie / Déclaration manuelle
                                    if (item is Map && item["isManualAdd"] == true) {
                                      return InkWell(
                                        onTap: () {
                                          FocusScope.of(context).unfocus();
                                          final queryText = item["query"] as String;
                                          setState(() => _searchResults = []);
                                          _showSuggestCourtDialog(context, initialName: queryText);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: AppColors.coral.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFFE8604C), Color(0xFFF4A535)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "➕ Déclarer « ${item["query"]} »",
                                                      style: const TextStyle(
                                                        color: AppColors.gold, 
                                                        fontSize: 13, 
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    const Text(
                                                      "Terrain introuvable ? Ajoutez-le sur la carte !",
                                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 14),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    // 🌍 Option 2 : Recherche de Ville OpenStreetMap
                                    if (item is Map && item["isExternal"] == true) {
                                      return ListTile(
                                        dense: true,
                                        leading: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.travel_explore, color: Colors.lightBlueAccent, size: 18),
                                        ),
                                        title: Text(
                                          "Centrer la carte sur « ${item["query"]} »",
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: const Text("Rechercher cette ville sur la carte", style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                                        onTap: () => _searchExternalCity(item["query"]),
                                      );
                                    }
                                    
                                    // 🎾 Option 3 : Terrain existant suggéré
                                    final CourtModel court = item as CourtModel;
                                    final userPos = context.read<AppState>().currentPosition;
                                    String? distStr;
                                    if (userPos != null) {
                                      final d = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, court.latitude, court.longitude) / 1000.0;
                                      distStr = "${d.toStringAsFixed(1)} km";
                                    }

                                    return ListTile(
                                      dense: true,
                                      leading: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.coral.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.sports_tennis_rounded, color: AppColors.coral, size: 18),
                                      ),
                                      title: Text(
                                        court.name, 
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Row(
                                        children: [
                                          Text(court.city, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                          if (distStr != null) ...[
                                            const SizedBox(width: 6),
                                            Text("• $distStr", style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              court.accessType == 'BEACH_FREE' ? 'Plage libre' : 'Club',
                                              style: const TextStyle(color: Colors.white60, fontSize: 9.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 18),
                                      onTap: () {
                                        _goToLocation(court.latitude, court.longitude);
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => _buildCourtDetails(context, court),
                                        );
                                      },
                                    );
                                  },
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.25)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourtDetails(BuildContext context, CourtModel court) {
    // Flags
    String flag = '🇫🇷';
    if (court.country.toLowerCase().contains('espagne') || court.country.toLowerCase().contains('spain')) {
      flag = '🇪🇸';
    } else if (court.country.toLowerCase().contains('italie') || court.country.toLowerCase().contains('italy')) {
      flag = '🇮🇹';
    }

    // Access Type Pill details
    Color accessColor;
    IconData accessIcon;
    String accessLabel;
    if (court.accessType == 'BEACH_FREE') {
      accessColor = const Color(0xFF00B4D8); // Sky / Beach
      accessIcon = Icons.beach_access_rounded;
      accessLabel = "Plage Libre (Amener son filet)";
    } else if (court.accessType == 'PUBLIC_FREE') {
      accessColor = const Color(0xFF2EC4B6); // Emerald green
      accessIcon = Icons.check_circle_rounded;
      accessLabel = "Terrain Équipé Gratuit";
    } else if (court.accessType == 'RENTAL') {
      accessColor = AppColors.coral;
      accessIcon = Icons.credit_card_rounded;
      accessLabel = court.priceInfo != null && court.priceInfo!.isNotEmpty ? court.priceInfo! : "Location à l'heure";
    } else {
      accessColor = AppColors.gold;
      accessIcon = Icons.lock_rounded;
      accessLabel = "Réservé Adhérents Club";
    }

    return SafeArea(
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.88),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                
                // En-tête : Nom + Drapeau & Ville
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(court.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                          const SizedBox(height: 4),
                          Text(
                            "$flag ${court.city.isNotEmpty ? court.city : court.country} (${court.courtCount} terrain${court.courtCount > 1 ? 's' : ''})",
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gold.withOpacity(0.5))),
                      child: const Text("SABLE FIN", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 10)),
                    )
                  ],
                ),
                const SizedBox(height: 14),

                // 🏷️ Pastille Type d'Accès Principale
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: accessColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accessColor.withOpacity(0.7), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(accessIcon, color: accessColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          accessLabel,
                          style: TextStyle(fontSize: 14, color: accessColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 🥅 Pastille Filet & Lignes
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        court.hasNet ? Icons.sports_tennis_rounded : Icons.backpack_rounded,
                        color: court.hasNet ? Colors.greenAccent : Colors.orangeAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          court.hasNet ? "Filet et lignes permanents en place ✓" : "Amener son filet et ses lignes portables",
                          style: TextStyle(
                            fontSize: 12,
                            color: court.hasNet ? Colors.white : Colors.orangeAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (court.description != null && court.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    court.description!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                  ),
                ],

                const SizedBox(height: 14),

                // 🚿 Commodités (Douches & Éclairage)
                Row(
                  children: [
                    _buildAmenityChip(Icons.shower, "Douches", court.hasShowers),
                    const SizedBox(width: 8),
                    _buildAmenityChip(Icons.lightbulb_outline, "Éclairage", court.hasLights),
                    const SizedBox(width: 8),
                    _buildAmenityChip(Icons.local_bar_outlined, "Buvette / Bar", court.hasBar),
                  ],
                ),

                const SizedBox(height: 16),

                // Weather Badge
                BeachWeatherWidget(
                  latitude: court.latitude,
                  longitude: court.longitude,
                ),
                const SizedBox(height: 14),

                // Objets Perdus / Trouvés (Lost & Found)
                InkWell(
                  onTap: () {
                    Navigator.pop(context); // Fermer les détails du terrain
                    _showLostAndFoundDialog(context, court);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.gold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppLocalizations.of(context)!.mapLostFoundBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('courts').doc(court.id).collection('lost_and_found').snapshots(),
                                builder: (context, snapshot) {
                                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                  return Text(AppLocalizations.of(context)!.mapLostFoundCount(count), style: const TextStyle(color: Colors.white54, fontSize: 11));
                                }
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Boutons d'Action Directe (GPS + Réservation + Créer Match)
                Row(
                  children: [
                    // Itinéraire GPS
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF008069),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: const Text("Itinéraire GPS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () async {
                          final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${court.latitude},${court.longitude}");
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Contact Réservation si présent
                    if (court.bookingContact != null && court.bookingContact!.isNotEmpty) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.coral,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.phone_rounded, size: 18),
                          label: const Text("Réserver", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () async {
                            final phoneMatch = RegExp(r'\+?\d[\d\s]{7,15}').firstMatch(court.bookingContact!);
                            if (phoneMatch != null) {
                              final cleanPhone = phoneMatch.group(0)!.replaceAll(' ', '');
                              final uri = Uri.parse("tel:$cleanPhone");
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Contact : ${court.bookingContact}")),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Boutons Utilitaires : Partage & Suggérer une info
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 16, color: Colors.greenAccent),
                        label: const Text("Partager", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _shareCourt(court),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.gold),
                        label: const Text("Enrichir infos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          Navigator.pop(context);
                          _showSuggestEditCourtDialog(context, court);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Bouton Créer une Partie ici
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.black, size: 20),
                    label: const Text("Organiser un match sur ce terrain", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateMatchScreen(preselectedCourt: court),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // ADMIN CONTROLS
                Consumer<AppState>(
                  builder: (context, appState, child) {
                    if (appState.currentUser?.isAdmin == true) {
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.delete_forever),
                              label: Text(AppLocalizations.of(context)!.mapAdminDeleteCourtBtn, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Colors.grey[900],
                                    title: Text(AppLocalizations.of(context)!.mapAdminDeleteTitle, style: const TextStyle(color: Colors.white)),
                                    content: Text(AppLocalizations.of(context)!.mapAdminDeleteContent(court.name), style: const TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(AppLocalizations.of(context)!.mapBtnCancel, style: const TextStyle(color: Colors.white54)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                        onPressed: () async {
                                          Navigator.pop(ctx); // close dialog
                                          Navigator.pop(context); // close bottom sheet
                                          try {
                                            await FirebaseFirestore.instance.collection('courts').doc(court.id).delete();
                                            await appState.loadData();
                                          } catch (e) {
                                            debugPrint("Erreur suppression: $e");
                                          }
                                        },
                                        child: Text(AppLocalizations.of(context)!.mapBtnDelete, style: const TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildAmenityChip(IconData icon, String label, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAvailable ? Colors.white38 : Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isAvailable ? Colors.greenAccent : Colors.white38),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isAvailable ? Colors.white70 : Colors.white38,
              decoration: isAvailable ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _contactReporter(BuildContext context, String targetUserId, String targetUserName, String? targetUserPhoto) async {
    final appState = context.read<AppState>();
    final currentUser = appState.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connectez-vous pour contacter ce joueur.")));
      return;
    }
    if (targetUserId == currentUser.id) return;

    UserModel? targetUser;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(targetUserId).get();
      if (doc.exists && doc.data() != null) {
        targetUser = UserModel.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {}

    targetUser ??= UserModel(
      id: targetUserId,
      displayName: targetUserName,
      photoUrl: targetUserPhoto,
      level: 3,
      eloScore: 1200,
      location: 'Marseille',
      isPremium: false,
      createdAt: DateTime.now(),
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(otherUser: targetUser!),
        ),
      );
    }
  }

  void _showLostAndFoundDialog(BuildContext context, CourtModel court) {
    bool isCreating = false;
    String createType = 'perdu';
    final TextEditingController textCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentUser = context.read<AppState>().currentUser;

          return ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.80,
                padding: EdgeInsets.only(
                  top: 24, 
                  left: 20, 
                  right: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1B29).withOpacity(0.96),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
                ),
                child: isCreating
                    // ✍️ VUE 1 : Formulaire de Déclaration Immédiat (Fluide & Réactif)
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: () => setModalState(() => isCreating = false),
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 14),
                                  label: const Text("Retour", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white70),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: createType == 'perdu' ? Colors.redAccent.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    createType == 'perdu' ? Icons.search_off_rounded : Icons.check_circle_outline_rounded,
                                    color: createType == 'perdu' ? Colors.redAccent : Colors.greenAccent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  createType == 'perdu' ? "Signaler un objet perdu" : "Signaler un objet trouvé",
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              court.name,
                              style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 18),

                            // Sélecteur Type (Perdu / Trouvé)
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setModalState(() => createType = 'perdu'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: createType == 'perdu' ? Colors.redAccent : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text("🔴 J'ai perdu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setModalState(() => createType = 'trouvé'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: createType == 'trouvé' ? Colors.green : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text("🟢 J'ai trouvé", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: textCtrl,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: createType == 'perdu'
                                    ? "Décrivez l'objet perdu (ex: Raquette Drop Shot verte oubliée sur le banc n°2, casquette noire...)"
                                    : "Décrivez l'objet trouvé (ex: Lunettes de soleil Oakley retrouvées au bord du court...)",
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: createType == 'perdu' ? Colors.redAccent : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: isSaving ? null : () async {
                                  final desc = textCtrl.text.trim();
                                  if (desc.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Veuillez décrire l'objet.")),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSaving = true);
                                  try {
                                    final user = context.read<AppState>().currentUser;
                                    await FirebaseFirestore.instance.collection('courts').doc(court.id).collection('lost_and_found').add({
                                      'type': createType,
                                      'description': desc,
                                      'userId': user?.id ?? 'unknown',
                                      'userName': user?.displayName ?? 'Joueur BeachMatch',
                                      'userPhoto': user?.photoUrl,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    textCtrl.clear();
                                    setModalState(() {
                                      isSaving = false;
                                      isCreating = false;
                                    });

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Votre signalement a été publié avec succès !"),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSaving = false);
                                    debugPrint("Erreur ajout objet: $e");
                                  }
                                },
                                child: isSaving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("Publier le signalement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                            ),
                          ],
                        ),
                      )
                    // 📋 VUE 2 : Liste des Signalements + Profils & Contact Direct
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.search_rounded, color: AppColors.gold, size: 22),
                                  SizedBox(width: 8),
                                  Text("Objets Perdus & Trouvés", style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white70),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          Text(court.name, style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),

                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('courts')
                                  .doc(court.id)
                                  .collection('lost_and_found')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                                }
                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.beach_access_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
                                        const SizedBox(height: 12),
                                        const Text(
                                          "Aucun objet signalé sur ce terrain",
                                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Vous avez perdu ou trouvé quelque chose ? Signalez-le ci-dessous !",
                                          style: TextStyle(color: Colors.white38, fontSize: 11),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final items = snapshot.data!.docs;
                                return ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final doc = items[index];
                                    final data = doc.data() as Map<String, dynamic>;
                                    final isLost = data['type'] == 'perdu';
                                    final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                                    final daysAgo = DateTime.now().difference(date).inDays;
                                    final timeStr = daysAgo == 0 ? "Aujourd'hui" : (daysAgo == 1 ? "Hier" : "Il y a $daysAgo j");
                                    final reporterId = data['userId'] as String? ?? 'unknown';
                                    final reporterName = data['userName'] as String? ?? 'Joueur BeachMatch';
                                    final reporterPhoto = data['userPhoto'] as String?;
                                    final isMine = currentUser != null && currentUser.id == reporterId;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isLost ? Colors.redAccent.withOpacity(0.08) : Colors.green.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isLost ? Colors.redAccent.withOpacity(0.35) : Colors.green.withOpacity(0.35),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isLost ? Colors.redAccent : Colors.green,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  isLost ? "🔴 OBJET PERDU" : "🟢 OBJET TROUVÉ",
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                              Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            data['description'] ?? '',
                                            style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.25),
                                          ),
                                          const SizedBox(height: 12),
                                          Divider(color: Colors.white.withOpacity(0.08), height: 1),
                                          const SizedBox(height: 10),

                                          // 👤 Profil du signaleur + Contact MP / Résolution
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 13,
                                                backgroundColor: AppColors.coral.withOpacity(0.3),
                                                backgroundImage: reporterPhoto != null && reporterPhoto.isNotEmpty
                                                    ? NetworkImage(reporterPhoto)
                                                    : null,
                                                child: reporterPhoto == null || reporterPhoto.isEmpty
                                                    ? Text(
                                                        reporterName.isNotEmpty ? reporterName[0].toUpperCase() : '?',
                                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      reporterName,
                                                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      isMine ? "Votre annonce" : (isLost ? "A perdu cet objet" : "A trouvé cet objet"),
                                                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Bouton Action (Contacter en MP ou Supprimer)
                                              if (isMine)
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.redAccent,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  ),
                                                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                                                  label: const Text("Résolu", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  onPressed: () async {
                                                    await FirebaseFirestore.instance
                                                        .collection('courts')
                                                        .doc(court.id)
                                                        .collection('lost_and_found')
                                                        .doc(doc.id)
                                                        .delete();
                                                  },
                                                )
                                              else if (reporterId != 'unknown')
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.coral,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    elevation: 0,
                                                  ),
                                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13),
                                                  label: const Text("Contacter", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  onPressed: () {
                                                    _contactReporter(context, reporterId, reporterName, reporterPhoto);
                                                  },
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          // 🚀 Boutons d'action du bas pour ouvrir la déclaration
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent.withOpacity(0.85),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    icon: const Icon(Icons.search_off_rounded, size: 17),
                                    label: const Text("J'ai perdu un objet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    onPressed: () {
                                      setModalState(() {
                                        createType = 'perdu';
                                        isCreating = true;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00A86B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                                    label: const Text("J'ai trouvé un objet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    onPressed: () {
                                      setModalState(() {
                                        createType = 'trouvé';
                                        isCreating = true;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSuggestCourtDialog(BuildContext context, {LatLng? specificLocation, String? initialName, String? initialCity}) {
    final TextEditingController nameCtrl = TextEditingController(text: initialName ?? '');
    final TextEditingController cityCtrl = TextEditingController(text: initialCity ?? '');
    bool isSaving = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, top: 28, left: 28, right: 28),
                decoration: BoxDecoration(
                  color: Colors.grey[900]!.withOpacity(0.95), // Lighter than black to stand out
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.mapProposeCourtTitle, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Text(
                  specificLocation == null 
                    ? "Le terrain sera ajouté au centre exact de votre écran (+)."
                    : "Le terrain sera ajouté à l'endroit que vous avez touché.",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Nom du terrain ou de la plage",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.beach_access, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Ville (ex: Marseille)",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.location_city, color: Colors.white54),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isSaving ? null : () async {
                      final name = nameCtrl.text.trim();
                      final city = cityCtrl.text.trim();
                      
                      if (name.isEmpty || city.isEmpty) {
                        setModalState(() => errorMessage = "Veuillez remplir tous les champs.");
                        return;
                      }
                      
                      setModalState(() {
                        errorMessage = null;
                        isSaving = true;
                      });
                      
                      try {
                        final locationToSave = specificLocation ?? _currentCenter ?? context.read<AppState>().mapCenter;
                        
                        await FirebaseFirestore.instance.collection('courts').add({
                          "name": name,
                          "latitude": locationToSave.latitude,
                          "longitude": locationToSave.longitude,
                          "isFree": true,
                          "hasLighting": false,
                          "hasParking": false,
                          "city": city,
                        });
                        
                        await context.read<AppState>().loadData();
                        
                        if (context.mounted) {
                          Navigator.pop(ctx); // Close dialog first
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(AppLocalizations.of(context)!.mapProposeCourtSuccess),
                            backgroundColor: Colors.green,
                          ));
                        }
                      } catch (e) {
                        debugPrint("Erreur lors de l'ajout: $e");
                        if (context.mounted) {
                          setModalState(() => errorMessage = "Erreur de connexion. Veuillez réessayer.");
                        }
                      } finally {
                        if (context.mounted) {
                          setModalState(() => isSaving = false);
                        }
                      }
                    },
                    child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(AppLocalizations.of(context)!.mapProposeCourtBtn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          )));
        }
      ),
    );
  }

  void _shareCourt(CourtModel court) {
    final text = "🏖️ *Spot Beach Tennis : ${court.name}* 🎾\n"
        "📍 Ville : ${court.city.isNotEmpty ? court.city : court.country} (${court.country})\n"
        "🏷️ Accès : ${court.accessType == 'BEACH_FREE' ? 'Plage libre (Amener son kit portable)' : (court.accessType == 'CLUB_ONLY' ? 'Réservé Adhérents Club' : 'Location à l\'heure')}\n"
        "🥅 Filet : ${court.hasNet ? 'Filet permanent en place ✓' : 'Amener son kit portable'}\n"
        "🗺️ Itinéraire GPS : https://www.google.com/maps/search/?api=1&query=${court.latitude},${court.longitude}\n\n"
        "Retrouve ce spot et organise des parties sur BeachMatch ! 🏖️📲";
    Share.share(text);
  }

  Widget _buildChoiceChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.gold : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showSuggestEditCourtDialog(BuildContext context, CourtModel court) {
    final TextEditingController editFeedbackCtrl = TextEditingController();
    String selectedType = 'filet';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, top: 28, left: 24, right: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141923),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_rounded, color: AppColors.gold, size: 24),
                              SizedBox(width: 8),
                              Text("Enrichir les infos", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("Terrain : ${court.name} (${court.city})", style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 16),
                      const Text("Que souhaitez-vous signaler ou mettre à jour ?", style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChoiceChip(
                            label: "🥅 Filet / Poteaux",
                            isSelected: selectedType == 'filet',
                            onTap: () => setModalState(() => selectedType = 'filet'),
                          ),
                          _buildChoiceChip(
                            label: "💶 Tarifs / Contact",
                            isSelected: selectedType == 'horaires_prix',
                            onTap: () => setModalState(() => selectedType = 'horaires_prix'),
                          ),
                          _buildChoiceChip(
                            label: "🚿 Douches / Éclairage",
                            isSelected: selectedType == 'douches_eclairage',
                            onTap: () => setModalState(() => selectedType = 'douches_eclairage'),
                          ),
                          _buildChoiceChip(
                            label: "📝 Autre précision",
                            isSelected: selectedType == 'autre',
                            onTap: () => setModalState(() => selectedType = 'autre'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editFeedbackCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Ex: Filet manquant / nouveau numéro de club / éclairage présent...",
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: isSaving ? null : () async {
                            final text = editFeedbackCtrl.text.trim();
                            if (text.isEmpty) return;
                            setModalState(() => isSaving = true);
                            try {
                              final user = context.read<AppState>().currentUser;
                              await FirebaseFirestore.instance.collection('court_suggestions').add({
                                'courtId': court.id,
                                'courtName': court.name,
                                'city': court.city,
                                'category': selectedType,
                                'details': text,
                                'userId': user?.id ?? 'anonyme',
                                'userName': user?.displayName ?? 'Joueur',
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Merci pour votre contribution ! L'équipe va vérifier et enrichir la fiche du terrain. 🙏"), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              debugPrint("Erreur feedback: $e");
                            } finally {
                              if (context.mounted) setModalState(() => isSaving = false);
                            }
                          },
                          child: isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Text("Envoyer la suggestion", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
