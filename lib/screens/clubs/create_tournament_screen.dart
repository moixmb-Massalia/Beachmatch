import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/club.dart';
import '../../models/tournament.dart';
import '../../providers/app_state.dart';
import '../../theme/colors.dart';

class CreateTournamentScreen extends StatefulWidget {
  final ClubModel club;
  final TournamentModel? initialTournament;

  const CreateTournamentScreen({super.key, required this.club, this.initialTournament});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0; // 0: Épreuves, 1: Date & Lieu, 2: JAT & Contact, 3: Récap & Validation

  late final TextEditingController _nameController;
  late final TextEditingController _dateController;
  late final TextEditingController _addressController;
  late final TextEditingController _courtsCountController;
  late final TextEditingController _priceController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _refereeController;
  late String _selectedCategory;
  late List<String> _selectedFormats;
  bool _isLoading = false;

  final List<String> _categories = [
    'BT 2000',
    'BT 1000',
    'BT 500',
    'BT 250',
    'BT 100',
    'BT 25',
  ];

  final List<Map<String, String>> _availableFormats = [
    {'key': 'DH', 'label': 'DH', 'badge': 'DH'},
    {'key': 'DD', 'label': 'DD', 'badge': 'DD'},
    {'key': 'DX', 'label': 'DX', 'badge': 'DX'},
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.initialTournament;
    _nameController = TextEditingController(text: t?.name ?? '');
    _dateController = TextEditingController(text: t?.dateString ?? '');

    String defaultLocation = t?.location ?? '';
    if (defaultLocation.isEmpty && widget.club.location.isNotEmpty && !widget.club.location.toLowerCase().contains('recherche')) {
      defaultLocation = widget.club.location;
    }
    _addressController = TextEditingController(text: defaultLocation);
    _courtsCountController = TextEditingController(text: '4');
    _priceController = TextEditingController(text: t?.price ?? '');
    _phoneController = TextEditingController(text: t?.contactPhone ?? '');
    _emailController = TextEditingController(text: t?.contactEmail ?? '');
    _refereeController = TextEditingController(text: t?.referee ?? '');
    _selectedCategory = t != null && _categories.contains(t.category) ? t.category : 'BT 250';

    if (t != null && t.formats.isNotEmpty) {
      _selectedFormats = List<String>.from(t.formats);
    } else {
      _selectedFormats = ['DH', 'DD'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _addressController.dispose();
    _courtsCountController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _refereeController.dispose();
    super.dispose();
  }

  void _toggleFormat(String formatKey) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedFormats.contains(formatKey)) {
        if (_selectedFormats.length > 1) {
          _selectedFormats.remove(formatKey);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Vous devez sélectionner au moins un format de tableau (DH, DD ou DX)."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _selectedFormats.add(formatKey);
      }
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 1)),
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E293B)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final startStr = "${picked.start.day.toString().padLeft(2, '0')}/${picked.start.month.toString().padLeft(2, '0')}/${picked.start.year}";
      final endStr = "${picked.end.day.toString().padLeft(2, '0')}/${picked.end.month.toString().padLeft(2, '0')}/${picked.end.year}";
      setState(() {
        if (picked.start == picked.end) {
          _dateController.text = startStr;
        } else {
          _dateController.text = "$startStr - $endStr";
        }
      });
    }
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez renseigner le nom du tournoi."), backgroundColor: Colors.redAccent),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_dateController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez renseigner les dates du tournoi."), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }
    setState(() {
      if (_currentStep < 3) _currentStep++;
    });
  }

  void _prevStep() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentStep > 0) _currentStep--;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final isEditing = widget.initialTournament != null;
      final id = isEditing ? widget.initialTournament!.id : const Uuid().v4();

      final tournamentData = {
        'id': id,
        'clubId': widget.club.id,
        'name': _nameController.text.trim(),
        'club': widget.club.name.isNotEmpty ? widget.club.name : (widget.initialTournament?.club ?? 'Club Officiel'),
        'location': _addressController.text.trim(),
        'dateString': _dateController.text.trim(),
        'distance': widget.initialTournament?.distance ?? 0.0,
        'category': _selectedCategory,
        'formats': _selectedFormats,
        'price': _priceController.text.trim(),
        'contactPhone': _phoneController.text.trim(),
        'contactEmail': _emailController.text.trim(),
        'referee': _refereeController.text.trim(),
        'latitude': widget.initialTournament?.latitude,
        'longitude': widget.initialTournament?.longitude,
      };

      if (isEditing) {
        await FirebaseFirestore.instance.collection('tournaments').doc(id).update(tournamentData);
      } else {
        await FirebaseFirestore.instance.collection('tournaments').doc(id).set(tournamentData);
      }

      if (mounted) {
        await context.read<AppState>().loadData();
        if (!mounted) return;

        final createdTournament = TournamentModel.fromMap(tournamentData, id);

        // Modale virale de proposition WhatsApp
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => _buildWhatsAppAnnouncementModal(dialogCtx, createdTournament, isEditing),
        );

        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildWhatsAppAnnouncementModal(BuildContext dialogCtx, TournamentModel tournament, bool isEditing) {
    final formatsStr = _selectedFormats.join(' · ');

    final message = "🏖️ *OUVERTURE DES INSCRIPTIONS BEACH TENNIS* 🏆\n\n"
        "📍 *Tournoi :* ${tournament.name} (${tournament.category})\n"
        "🏟️ *Club :* ${tournament.club}\n"
        "📅 *Dates :* ${tournament.dateString}\n"
        "🎯 *Tableaux proposés :* $formatsStr\n"
        "💰 *Tarif :* ${tournament.price ?? '20€'}\n"
        "👤 *JAT :* ${tournament.referee ?? 'Juge-Arbitre'}\n"
        "${tournament.contactPhone != null && tournament.contactPhone!.isNotEmpty ? '📞 *Contact :* ${tournament.contactPhone}\n' : ''}"
        "\nInscriptions et suivi des scores en direct sur *BeachMatch* ! 🔥";

    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEditing ? "Tournoi mis à jour !" : "Tournoi créé avec succès !",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Voulez-vous annoncer l'ouverture des inscriptions directement auprès des joueurs sur WhatsApp ?",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              message,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, height: 1.3),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: Text("Plus tard", style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final encoded = Uri.encodeComponent(message);
            final url = Uri.parse("https://wa.me/?text=$encoded");
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
          },
          icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
          label: const Text(
            "Partager sur WhatsApp",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialTournament != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_court_aerial_1785052250131.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.78),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isEditing),
                _buildStepProgressBar(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: _buildCurrentStepContent(),
                    ),
                  ),
                ),
                _buildBottomNavigation(isEditing),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports_tennis_rounded, color: AppColors.gold, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "ESPACE ORGANISATEUR JAT",
                      style: TextStyle(color: AppColors.gold.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ],
                ),
                Text(
                  isEditing ? "Modifier le Tournoi" : "Nouveau Tournoi (Pas à Pas)",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgressBar() {
    final steps = [
      {'label': 'Épreuves', 'icon': Icons.sports_tennis_rounded},
      {'label': 'Spot & Dates', 'icon': Icons.calendar_month_rounded},
      {'label': 'JAT & Contact', 'icon': Icons.person_rounded},
      {'label': 'Lancement', 'icon': Icons.rocket_launch_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= _currentStep ? AppColors.gold : Colors.white24,
                ),
              ),
            GestureDetector(
              onTap: () {
                if (i < _currentStep) setState(() => _currentStep = i);
              },
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: i == _currentStep
                          ? AppColors.gold
                          : (i < _currentStep ? AppColors.gold.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i <= _currentStep ? AppColors.gold : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: i < _currentStep
                          ? const Icon(Icons.check, size: 14, color: AppColors.gold)
                          : Text(
                              "${i + 1}",
                              style: TextStyle(
                                color: i == _currentStep ? Colors.black : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i]['label'] as String,
                    style: TextStyle(
                      color: i <= _currentStep ? Colors.white : Colors.white38,
                      fontSize: 10,
                      fontWeight: i == _currentStep ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Epreuves();
      case 1:
        return _buildStep2DatesAndLieu();
      case 2:
        return _buildStep3JatAndContacts();
      case 3:
      default:
        return _buildStep4Summary();
    }
  }

  // Étape 1 : Épreuves & Formats
  Widget _buildStep1Epreuves() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("1. Nom & Formats de l'épreuve", "Choisissez les tableaux ouverts aux joueurs."),
        const SizedBox(height: 16),
        _buildGlassTextField(
          controller: _nameController,
          label: "Nom du tournoi *",
          hint: "Ex: Open d'Été Beach Tennis BT 250",
          icon: Icons.emoji_events_rounded,
          validator: (val) => val == null || val.trim().isEmpty ? "Nom requis" : null,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              dropdownColor: const Color(0xFF1E293B),
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Tableaux proposés (sélectionnez 1, 2 ou 3) :",
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: _availableFormats.map((fmt) {
            final isSelected = _selectedFormats.contains(fmt['key']);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _toggleFormat(fmt['key']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.gold.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.15),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          fmt['badge']!,
                          style: TextStyle(
                            color: isSelected ? AppColors.gold : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmt['label']!,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Étape 2 : Date, Lieu & Terrains
  Widget _buildStep2DatesAndLieu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("2. Calendrier & Spot", "Renseignez les dates, le spot de jeu et les terrains."),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickDateRange,
          child: AbsorbPointer(
            child: _buildGlassTextField(
              controller: _dateController,
              label: "Dates de la compétition *",
              hint: "Ex: 12/07/2026 - 13/07/2026",
              icon: Icons.date_range_rounded,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassTextField(
          controller: _addressController,
          label: "Lieu / Spot de Beach Tennis *",
          hint: "Ex: Plage du Couchant, La Grande-Motte",
          icon: Icons.location_on_rounded,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildGlassTextField(
                controller: _courtsCountController,
                label: "Terrains disponibles",
                hint: "4",
                icon: Icons.grid_view_rounded,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGlassTextField(
                controller: _priceController,
                label: "Frais d'inscription",
                hint: "Ex: 15€ / joueur (selon Ten'Up)",
                icon: Icons.euro_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Étape 3 : JAT & Contacts
  Widget _buildStep3JatAndContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("3. Contact JAT Responsable", "Ces coordonnées permettront aux joueurs de vous contacter."),
        const SizedBox(height: 16),
        _buildGlassTextField(
          controller: _refereeController,
          label: "Nom & Prénom du Juge-Arbitre (JAT)",
          hint: "Ex: Marc Dupont",
          icon: Icons.verified_user_rounded,
        ),
        const SizedBox(height: 16),
        _buildGlassTextField(
          controller: _phoneController,
          label: "Téléphone WhatsApp JAT",
          hint: "Ex: +33 6 12 34 56 78",
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildGlassTextField(
          controller: _emailController,
          label: "Email officiel de contact",
          hint: "Ex: tournoi@beachtennis.fr",
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  // Étape 4 : Récapitulatif
  Widget _buildStep4Summary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: AppColors.gold, size: 22),
              SizedBox(width: 8),
              Text(
                "RÉCAPITULATIF OFFICIEL",
                style: TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          _summaryRow("Tournoi", _nameController.text.trim()),
          _summaryRow("Catégorie", _selectedCategory),
          _summaryRow("Club Hôte", widget.club.name),
          _summaryRow("Tableaux ouverts", _selectedFormats.join(' · ')),
          _summaryRow("Dates", _dateController.text.trim()),
          _summaryRow("Spot / Lieu", _addressController.text.trim()),
          _summaryRow("Frais inscription", _priceController.text.trim()),
          _summaryRow("JAT", _refereeController.text.trim().isNotEmpty ? _refereeController.text.trim() : 'Non renseigné'),
          _summaryRow("WhatsApp JAT", _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : 'Non renseigné'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "—",
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
      ],
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.gold, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isEditing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Précédent", style: TextStyle(color: Colors.white)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_currentStep == 3 ? _submit : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      _currentStep == 3
                          ? (isEditing ? "Enregistrer les modifications" : "Créer le Tournoi & Partager")
                          : "Étape suivante ➔",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
