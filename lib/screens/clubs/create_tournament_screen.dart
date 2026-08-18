import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
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
  late final TextEditingController _nameController;
  late final TextEditingController _dateController;
  late final TextEditingController _addressController;
  late final TextEditingController _priceController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _refereeController;
  late String _selectedCategory;
  bool _isLoading = false;

  final List<String> _categories = [
    'BT 2000',
    'BT 1000',
    'BT 500',
    'BT 250',
    'BT 100',
    'BT 25'
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.initialTournament;
    _nameController = TextEditingController(text: t?.name ?? '');
    _dateController = TextEditingController(text: t?.dateString ?? '');
    _addressController = TextEditingController(text: t?.location ?? '');
    _priceController = TextEditingController(text: t?.price ?? '');
    _phoneController = TextEditingController(text: t?.contactPhone ?? '');
    _emailController = TextEditingController(text: t?.contactEmail ?? '');
    _refereeController = TextEditingController(text: t?.referee ?? '');
    _selectedCategory = t != null && _categories.contains(t.category) ? t.category : 'BT 250';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _refereeController.dispose();
    super.dispose();
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
        'name': _nameController.text.trim(),
        'club': widget.club.name.isNotEmpty ? widget.club.name : (widget.initialTournament?.club ?? 'Club Officiel'),
        'location': _addressController.text.trim(),
        'dateString': _dateController.text.trim(),
        'distance': widget.initialTournament?.distance ?? 0.0,
        'category': _selectedCategory,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? "Tournoi modifié avec succès ! ✓" : "Tournoi créé avec succès ! 🏆"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialTournament != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? "Modifier le Tournoi" : "Nouveau Tournoi", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              isEditing ? "Modifiez les informations officielles de cet événement." : "Créez un événement officiel pour votre club.",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Nom du tournoi",
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: "Ex: Open d'été BT 250",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              validator: (val) => val == null || val.isEmpty ? "Requis" : null,
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: const Color(0xFF141923),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Catégorie FFT",
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _dateController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Dates du tournoi",
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: "Ex: 24 - 25 Août 2026",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              validator: (val) => val == null || val.isEmpty ? "Requis" : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Lieu / Ville",
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: "Ex: Marseille, Barcelone, Plage du Prado...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              validator: (val) => val == null || val.isEmpty ? "Requis" : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _priceController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Tarif d'inscription",
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: "Ex: 25 € / joueur",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Téléphone d'inscription",
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: "Numéro de contact",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Email d'inscription",
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: "Adresse email du club",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _refereeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Juge-Arbitre (JAT)",
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: "Nom du juge-arbitre officiel",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            
            const SizedBox(height: 36),
            
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text(
                        isEditing ? "Enregistrer les modifications" : "Créer le tournoi",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
