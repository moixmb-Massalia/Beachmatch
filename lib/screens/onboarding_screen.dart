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
  final TextEditingController _arenaController = TextEditingController();
  int _selectedLevel = 1;
  String _selectedCbtCategory = 'Iniciante';
  bool _isVerifying = false;
  bool _isLicenceVerified = false;
  int? _verifiedElo;
  String? _verifiedRanking;

  static const List<String> _cbtCategories = [
    'Iniciante',
    'Categoria D',
    'Categoria C',
    'Categoria B',
    'Categoria A',
    'PRO',
  ];

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AppState>().currentUser;
    _pseudoController = TextEditingController(text: currentUser?.displayName ?? "");
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    _licenceController.dispose();
    _arenaController.dispose();
    super.dispose();
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

  String _detectLang(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    if (user != null && (user.isBrazilian || user.country.toUpperCase() == 'BR')) {
      return 'pt';
    }
    if (appState.currentLocale != null) {
      final code = appState.currentLocale!.languageCode.toLowerCase();
      if (['pt', 'it', 'es', 'fr', 'en'].contains(code)) return code;
    }
    final devLocale = Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    final devLang = devLocale.languageCode.toLowerCase();
    if (['pt', 'it', 'es', 'fr', 'en'].contains(devLang)) return devLang;
    return 'en';
  }

  @override
  Widget build(BuildContext context) {
    final lang = _detectLang(context);

    final title = lang == 'pt'
        ? "Bem-vindo(a) !"
        : (lang == 'es'
            ? "¡Bienvenido/a!"
            : (lang == 'it'
                ? "Benvenuto/a!"
                : (lang == 'en' ? "Welcome!" : "Bienvenue !")));

    final subtitle = lang == 'pt'
        ? "Vamos configurar o seu perfil de atleta."
        : (lang == 'es'
            ? "Configuremos tu perfil de jugador."
            : (lang == 'it'
                ? "Configuriamo il tuo profilo giocatore."
                : (lang == 'en'
                    ? "Let's set up your player profile."
                    : "Configurons votre profil joueur.")));

    final licenceLabel = lang == 'pt'
        ? "Registro CBT / Atleta (Opcional)"
        : (lang == 'es'
            ? "Número de licencia (Opcional)"
            : (lang == 'it'
                ? "Tessera / Licenza (Opzionale)"
                : (lang == 'en' ? "License ID (Optional)" : "Numéro de licence (Optionnel)")));

    final verifyBtnLabel = lang == 'pt'
        ? "Verificar"
        : (lang == 'es' ? "Verificar" : (lang == 'it' ? "Verifica" : (lang == 'en' ? "Verify" : "Vérifier")));

    final nameLabel = lang == 'pt'
        ? "Nome e Sobrenome"
        : (lang == 'es'
            ? "Nombre y Apellidos"
            : (lang == 'it' ? "Nome e Cognome" : (lang == 'en' ? "First and Last Name" : "Prénom et Nom")));

    final levelLabel = lang == 'pt'
        ? "Seu Nível"
        : (lang == 'es' ? "Tu Nivel" : (lang == 'it' ? "Il tuo Livello" : (lang == 'en' ? "Your Level" : "Votre Niveau")));

    final levelDesc = lang == 'pt'
        ? "Nível 1: Iniciante\nNível 3: Jogador regular\nNível 5: Pro / Competidor"
        : (lang == 'es'
            ? "Nivel 1: Principiante\nNivel 3: Jugador regular\nNivel 5: Pro / Competidor"
            : (lang == 'it'
                ? "Livello 1: Principiante\nLivello 3: Giocatore regolare\nLivello 5: Pro / Agonista"
                : (lang == 'en'
                    ? "Level 1: Beginner\nLevel 3: Regular player\nLevel 5: Pro / Competitor"
                    : "Niveau 1: Débutant complet\nNiveau 3: Joueur régulier\nNiveau 5: Pro/Compétiteur")));

    final emptyNameMsg = lang == 'pt'
        ? "Por favor, digite seu nome e sobrenome"
        : (lang == 'es'
            ? "Por favor, introduce tu nombre y apellidos"
            : (lang == 'it'
                ? "Inserisci nome e cognome"
                : (lang == 'en' ? "Please enter your first and last name" : "Veuillez entrer votre Prénom et Nom")));

    final startBtnLabel = lang == 'pt'
        ? "Vamos lá ! 🚀"
        : (lang == 'es'
            ? "¡Vamos! 🚀"
            : (lang == 'it' ? "Cominciamo! 🚀" : (lang == 'en' ? "Let's Go! 🚀" : "C'est parti !")));

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_court_aerial_1785052250131.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
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
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: -5)
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textMain),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Form fields
                          if (lang == 'pt') ...[
                            // Name
                            Text(nameLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _pseudoController,
                              decoration: InputDecoration(
                                hintText: "Ex: André Baran",
                                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Categoria CBT
                            const Row(
                              children: [
                                Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.gold),
                                SizedBox(width: 6),
                                Text("Categoria CBT (Circuito Nacional 🇧🇷)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Selecione sua categoria de jogo para partidas e torneios:",
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: _cbtCategories.map((cat) {
                                final isSelected = _selectedCbtCategory == cat;
                                return ChoiceChip(
                                  label: Text(
                                    cat,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textMain,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: Colors.white,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedCbtCategory = cat;
                                        switch (cat) {
                                          case 'Iniciante':
                                            _selectedLevel = 1;
                                            break;
                                          case 'Categoria D':
                                            _selectedLevel = 2;
                                            break;
                                          case 'Categoria C':
                                            _selectedLevel = 3;
                                            break;
                                          case 'Categoria B':
                                            _selectedLevel = 4;
                                            break;
                                          case 'Categoria A':
                                          case 'PRO':
                                            _selectedLevel = 5;
                                            break;
                                        }
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),

                            // Registro CBT
                            const Text("Registro / ID CBT (Opcional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _licenceController,
                              decoration: InputDecoration(
                                hintText: "Ex: CBT12345",
                                prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textMuted),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Arena / Clube Habitual
                            const Text("Arena ou Clube habitual (Opcional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _arenaController,
                              decoration: InputDecoration(
                                hintText: "Ex: Arena Ipanema, Posto 10...",
                                prefixIcon: const Icon(Icons.beach_access_rounded, color: AppColors.textMuted),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ] else ...[
                            // French / International Flow
                            // Licence
                            Text(licenceLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                      : Text(verifyBtnLabel),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Pseudo -> Real Name
                            Text(nameLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            Text(levelLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: List.generate(5, (index) {
                                final level = index + 1;
                                final isSelected = _selectedLevel == level;
                                final prefix = lang == 'en' ? 'Lvl' : 'Niv.';
                                return ChoiceChip(
                                  label: Text("$prefix $level", style: TextStyle(color: isSelected ? Colors.white : AppColors.textMain)),
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
                            Text(
                              levelDesc,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 32),

                          // Continue Button
                          ElevatedButton(
                            onPressed: () async {
                              if (_pseudoController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(emptyNameMsg)),
                                );
                                return;
                              }
                              
                              final appState = context.read<AppState>();
                              try {
                                if (lang == 'pt') {
                                  await appState.completeOnboarding(
                                    _pseudoController.text.trim(),
                                    _selectedLevel,
                                    cbtId: _licenceController.text.trim().isNotEmpty ? _licenceController.text.trim() : null,
                                    cbtCategory: _selectedCbtCategory,
                                    arena: _arenaController.text.trim().isNotEmpty ? _arenaController.text.trim() : null,
                                  );
                                } else {
                                  await appState.completeOnboarding(
                                    _pseudoController.text.trim(), 
                                    _selectedLevel,
                                    licenceNumber: _isLicenceVerified ? _licenceController.text.trim() : null,
                                    eloScore: _isLicenceVerified ? _verifiedElo : null,
                                    ranking: _isLicenceVerified ? _verifiedRanking : null,
                                  );
                                }
                                
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                                    (route) => false,
                                  );
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
                            child: Text(startBtnLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
