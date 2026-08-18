import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../providers/app_state.dart';
import '../l10n/app_localizations.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _licenceController;
  late TextEditingController _rankingController;
  int _selectedLevel = 1;
  bool _isSaving = false;
  bool _isVerifying = false;
  bool _isLicenceVerified = false;
  int _verifiedEloScore = 0;
  Uint8List? _selectedImageBytes;
  String? _existingPhotoUrl;
  bool _isLookingForPartner = false;
  String? _preferredPosition;
  String? _availability;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? "");
    _locationController = TextEditingController(text: user?.location ?? "");
    _licenceController = TextEditingController(text: user?.licenceNumber ?? '');
    _rankingController = TextEditingController(text: user?.ranking ?? '');
    _selectedLevel = user?.level ?? 1;
    _existingPhotoUrl = user?.photoUrl;
    _isLookingForPartner = user?.isLookingForPartner ?? false;
    _preferredPosition = user?.preferredPosition;
    _availability = user?.availability;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _licenceController.dispose();
    _rankingController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.profileEditPhotoError(e.toString()))),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedImageBytes = null;
      _existingPhotoUrl = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.profileEditPhotoDeleted)),
      );
    }
  }

  void _showPhotoOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141923),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.profileEditPhotoTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.gold),
              title: Text(AppLocalizations.of(context)!.profileEditPhotoGallery, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.gold),
              title: Text(AppLocalizations.of(context)!.profileEditPhotoCamera, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_selectedImageBytes != null || (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty))
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: Text(AppLocalizations.of(context)!.profileEditPhotoRemove, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyLicence() async {
    final licence = _licenceController.text.trim().toUpperCase();
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
        if (responseBody.containsKey('result') && responseBody['result'] != null) {
          final data = responseBody['result'] as Map<String, dynamic>;
          setState(() {
            _nameController.text = "${data['firstName']} ${data['lastName']}";
            _rankingController.text = data['ranking']?.toString() ?? "NC";
            if (data['club'] != null && data['club'].toString().isNotEmpty) {
              _locationController.text = data['club'];
            }
            _isLicenceVerified = true;
          });
          
          _verifiedEloScore = int.tryParse(data['elo'].toString()) ?? 0;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.profileEditLicenceSuccess), backgroundColor: Colors.green),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.profileEditLicenceNotFound), backgroundColor: Colors.orange),
            );
          }
        }
      } else {
        throw Exception("Erreur Serveur: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.profileEditLicenceError(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    
    try {
      final appState = context.read<AppState>();
      String? photoUrl = _existingPhotoUrl;

      // Upload image if selected
      if (_selectedImageBytes != null && appState.currentUser != null) {
        final ref = FirebaseStorage.instance.ref().child('user_avatars/${appState.currentUser!.id}.jpg');
        await ref.putData(_selectedImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        photoUrl = await ref.getDownloadURL();
      }

      await appState.updateProfile(
        displayName: _nameController.text.trim(),
        location: _locationController.text.trim(),
        level: _selectedLevel,
        photoUrl: photoUrl,
        licenceNumber: _isLicenceVerified ? _licenceController.text.trim() : null,
        ranking: _rankingController.text.trim().isNotEmpty ? _rankingController.text.trim() : null,
        eloScore: _isLicenceVerified ? _verifiedEloScore : null,
        preferredPosition: _preferredPosition,
        availability: _availability,
      );

      if (_isLookingForPartner != appState.currentUser?.isLookingForPartner) {
        await appState.toggleLookingForPartner();
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profileEditSaveError(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.profileEditTitle, style: const TextStyle(color: AppColors.textMain)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar
              Center(
                child: GestureDetector(
                  onTap: _showPhotoOptionsBottomSheet,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _selectedImageBytes != null 
                            ? MemoryImage(_selectedImageBytes!) 
                            : (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty ? NetworkImage(_existingPhotoUrl!) : null) as ImageProvider?,
                        child: (_selectedImageBytes == null && (_existingPhotoUrl == null || _existingPhotoUrl!.isEmpty))
                            ? const Icon(Icons.person, size: 50, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Text(AppLocalizations.of(context)!.profileEditName, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                readOnly: _isLicenceVerified,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _isLicenceVerified ? Colors.grey[200] : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.isEmpty ? "Requis" : null,
              ),
              const SizedBox(height: 16),
              
              Text(AppLocalizations.of(context)!.profileEditLicence, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _licenceController,
                      decoration: InputDecoration(
                        hintText: "Ex: 1234567A",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                        : Text(AppLocalizations.of(context)!.profileEditVerifyBtn),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(AppLocalizations.of(context)!.profileEditCity, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.isEmpty ? "Requis" : null,
              ),
              const SizedBox(height: 16),
              
              Text(AppLocalizations.of(context)!.profileEditFft, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rankingController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  hintText: 'Optionnel',
                ),
              ),
              const SizedBox(height: 32),

              Text(AppLocalizations.of(context)!.profileEditLevel, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(5, (index) {
                  final level = index + 1;
                  final isSelected = _selectedLevel == level;
                  return ChoiceChip(
                    label: Text(AppLocalizations.of(context)!.profileEditLevelBtn(level), style: TextStyle(color: isSelected ? Colors.white : AppColors.textMain)),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedLevel = level);
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),
              Text(AppLocalizations.of(context)!.profileEditPosition, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _preferredPosition,
                decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                items: [
                  AppLocalizations.of(context)!.profileEditPosLeft, 
                  AppLocalizations.of(context)!.profileEditPosRight, 
                  AppLocalizations.of(context)!.profileEditPosAny
                ].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                onChanged: (val) => setState(() => _preferredPosition = val),
                hint: Text(AppLocalizations.of(context)!.profileEditSelect),
              ),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.profileEditAvailability, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _availability,
                decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                items: [
                  AppLocalizations.of(context)!.profileEditAvailEvening, 
                  AppLocalizations.of(context)!.profileEditAvailWeek, 
                  AppLocalizations.of(context)!.profileEditAvailAll, 
                  AppLocalizations.of(context)!.profileEditAvailVar
                ].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                onChanged: (val) => setState(() => _availability = val),
                hint: Text(AppLocalizations.of(context)!.profileEditSelect),
              ),
              const SizedBox(height: 24),
              // NEW: Partner Finder Switch
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.handshake, color: AppColors.coral),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.profileEditLookingForPartner, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(AppLocalizations.of(context)!.profileEditLookingForPartnerSub, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isLookingForPartner,
                      onChanged: (val) {
                        setState(() {
                          _isLookingForPartner = val;
                        });
                      },
                      activeColor: AppColors.coral,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(AppLocalizations.of(context)!.profileEditSaveBtn, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
