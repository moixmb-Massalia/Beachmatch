import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../providers/app_state.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late TextEditingController _pseudoController;
  final TextEditingController _licenceController = TextEditingController();
  int _selectedLevel = 1;
  bool _isVerifying = false;
  bool _isLicenceVerified = false;
  int? _verifiedElo;
  String? _verifiedRanking;

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AppState>().currentUser;
    _pseudoController = TextEditingController(text: currentUser?.displayName ?? "");
  }

  Future<void> _verifyLicence() async {
    final licence = _licenceController.text.trim();
    if (licence.isEmpty) return;

    setState(() => _isVerifying = true);
    try {
      final response = await http.post(
        Uri.parse('https://europe-west1-beach-tennis-216f4.cloudfunctions.net/verifyLicence'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'data': {'licenceNumber': licence}
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        if (responseBody.containsKey('result')) {
          final data = responseBody['result'] as Map<String, dynamic>;
        setState(() {
          _pseudoController.text = "${data['firstName']} ${data['lastName']}";
          _selectedLevel = int.parse(data['level'].toString());
          _verifiedElo = data['elo'] != null ? int.tryParse(data['elo'].toString()) : null;
          _verifiedRanking = data['ranking']?.toString();
          _isLicenceVerified = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Licence vérifiée avec succès !"), backgroundColor: Colors.green),
          );
        }
        }
      } else {
        throw Exception("Erreur Serveur: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_court_aerial_1785052250131.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, spreadRadius: -5)
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Bienvenue !",
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textMain),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Configurons votre profil joueur.",
                            style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Licence
                          const Text("Numéro de licence (Optionnel)", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _licenceController,
                                  decoration: InputDecoration(
                                    hintText: "Ex: 1234567A",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isVerifying ? null : _verifyLicence,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isVerifying 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("Vérifier"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Pseudo -> Real Name
                          const Text("Prénom et Nom", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _pseudoController,
                            readOnly: _isLicenceVerified,
                            decoration: InputDecoration(
                              hintText: "Ex: Rafa Nadal",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: _isLicenceVerified ? Colors.grey[200] : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Level
                          const Text("Votre Niveau", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: List.generate(5, (index) {
                              final level = index + 1;
                              final isSelected = _selectedLevel == level;
                              return ChoiceChip(
                                label: Text("Niv. $level", style: TextStyle(color: isSelected ? Colors.white : AppColors.textMain)),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white,
                                onSelected: (selected) {
                                  if (selected) setState(() => _selectedLevel = level);
                                },
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Niveau 1: Débutant complet\nNiveau 3: Joueur régulier\nNiveau 5: Pro/Compétiteur",
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Continue Button
                          ElevatedButton(
                            onPressed: () async {
                              if (_pseudoController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Veuillez entrer votre Prénom et Nom")),
                                );
                                return;
                              }
                              
                              final appState = context.read<AppState>();
                              try {
                                await appState.completeOnboarding(
                                  _pseudoController.text.trim(), 
                                  _selectedLevel,
                                  licenceNumber: _isLicenceVerified ? _licenceController.text.trim() : null,
                                  eloScore: _isLicenceVerified ? _verifiedElo : null,
                                  ranking: _isLicenceVerified ? _verifiedRanking : null,
                                );
                                
                                if (context.mounted) {
                                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Erreur: ${e.toString()}")),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("C'est parti !", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
