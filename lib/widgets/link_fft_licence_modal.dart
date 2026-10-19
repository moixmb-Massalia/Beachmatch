import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class LinkFftLicenceModal extends StatefulWidget {
  const LinkFftLicenceModal({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LinkFftLicenceModal(),
    );
  }

  @override
  State<LinkFftLicenceModal> createState() => _LinkFftLicenceModalState();
}

class _LinkFftLicenceModalState extends State<LinkFftLicenceModal> {
  final TextEditingController _licenceCtrl = TextEditingController();
  bool _isVerifying = false;
  bool _isSaving = false;
  Map<String, dynamic>? _detectedData;
  String? _errorMessage;

  @override
  void dispose() {
    _licenceCtrl.dispose();
    super.dispose();
  }

  String _normalizeClub(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _verify() async {
    final rawLic = _licenceCtrl.text.trim().toUpperCase();
    if (rawLic.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _detectedData = null;
    });

    final cleanDigits = rawLic.replaceAll(RegExp(r'\D'), '');

    try {
      // 1. Tenter l'appel Cloud Function
      bool resolved = false;
      try {
        final response = await http.post(
          Uri.parse('https://europe-west1-beach-tennis-216f4.cloudfunctions.net/verifyLicence'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'data': {'licenceNumber': rawLic}
          }),
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final res = json.decode(response.body);
          if (res is Map && res.containsKey('result') && res['result'] != null) {
            final data = res['result'] as Map<String, dynamic>;
            _detectedData = {
              'fullName': "${data['firstName']} ${data['lastName']}".trim(),
              'ranking': data['ranking']?.toString() ?? 'NC',
              'club': data['club']?.toString() ?? '',
              'elo': int.tryParse(data['elo']?.toString() ?? '0') ?? 0,
              'licence': rawLic,
            };
            resolved = true;
          }
        }
      } catch (_) {}

      // 2. Fallback consultation directe Firestore fft_rankings
      if (!resolved && cleanDigits.isNotEmpty) {
        final fftDoc = await FirebaseFirestore.instance.collection('fft_rankings').doc(cleanDigits).get();
        if (fftDoc.exists && fftDoc.data() != null) {
          final fd = fftDoc.data()!;
          final rank = (fd['level'] ?? fd['ranking'] ?? fd['rank'])?.toString() ?? 'NC';
          final name = (fd['fullName'] ?? "${fd['firstName'] ?? ''} ${fd['lastName'] ?? ''}").toString().trim();
          _detectedData = {
            'fullName': name.isNotEmpty ? name : 'Licencié FFT',
            'ranking': rank,
            'club': (fd['club'] ?? '').toString().trim(),
            'elo': int.tryParse((fd['eloScore'] ?? fd['elo'] ?? '0').toString()) ?? 0,
            'licence': rawLic,
          };
          resolved = true;
        }
      }

      if (!resolved) {
        setState(() {
          _errorMessage = "Numéro de licence introuvable. Vérifiez la saisie (ex: 6039759 ou 1234567A).";
        });
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur de vérification : $e";
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _confirmAndSave() async {
    if (_detectedData == null) return;
    setState(() => _isSaving = true);

    try {
      final appState = context.read<AppState>();
      final currentUser = appState.currentUser;
      if (currentUser == null) return;

      final rawClub = (_detectedData!['club'] ?? '').toString().trim();
      String? clubId;
      String? clubName = rawClub.isNotEmpty ? rawClub : null;

      // Résolution du Club dans la collection clubs
      if (rawClub.isNotEmpty) {
        try {
          final direct = await FirebaseFirestore.instance
              .collection('clubs')
              .where('name', isEqualTo: rawClub)
              .limit(1)
              .get();

          if (direct.docs.isNotEmpty) {
            clubId = direct.docs.first.id;
            clubName = direct.docs.first.data()['name'] ?? rawClub;
          } else {
            final allClubs = await FirebaseFirestore.instance.collection('clubs').limit(400).get();
            final normRaw = _normalizeClub(rawClub);
            for (var c in allClubs.docs) {
              final cName = (c.data()['name'] ?? '').toString();
              final normC = _normalizeClub(cName);
              if (normC == normRaw || (normC.length > 4 && normRaw.contains(normC)) || (normRaw.length > 4 && normC.contains(normRaw))) {
                clubId = c.id;
                clubName = cName;
                break;
              }
            }
          }
        } catch (_) {}
      }

      // Mise à jour profil
      final cleanLicence = _detectedData!['licence']?.toString().toUpperCase();
      final ranking = _detectedData!['ranking']?.toString();
      final elo = (_detectedData!['elo'] as num?)?.toInt() ?? int.tryParse('${_detectedData!['elo']}');

      await appState.updateProfile(
        displayName: currentUser.displayName,
        location: currentUser.location,
        level: currentUser.level,
        photoUrl: currentUser.photoUrl,
        licenceNumber: cleanLicence,
        ranking: (ranking != null && ranking.isNotEmpty && ranking != 'NC') ? ranking : currentUser.ranking,
        eloScore: (elo != null && elo > 0) ? elo : currentUser.eloScore,
        clubId: clubId,
        clubName: clubName,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0E7A3E),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Compte certifié FFT ! Bienvenue${clubName != null ? " au club $clubName" : ""} 🏖️",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = "Erreur d'enregistrement : $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF141923),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poignée de glissement
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // En-tête
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: AppColors.gold, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Lier ma Licence FFT 🏅",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Débloquez votre classement officiel et rejoignez votre club",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Champ N° Licence
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _licenceCtrl,
                    textCapitalization: TextCapitalization.characters,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Ex: 6039759 ou 1234567A",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      prefixIcon: const Icon(Icons.card_membership_rounded, color: AppColors.gold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text("Vérifier", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                  ],
                ),
              ),
            ],

            // Résultat de la détection
            if (_detectedData != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Licence FFT reconnue !",
                          style: TextStyle(color: Colors.greenAccent.shade400, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoLine("Titulaire", _detectedData!['fullName']),
                    const SizedBox(height: 6),
                    _buildInfoLine("Classement Officiel", _detectedData!['ranking'] == 'NC' ? 'Non Classé (NC)' : "${_detectedData!['ranking']}e National"),
                    if (_detectedData!['club'] != null && _detectedData!['club'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoLine("Club Rattaché", _detectedData!['club']),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _confirmAndSave,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                label: const Text(
                  "Confirmer & Certifier mon compte",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7A3E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                ),
              ),
            ],

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Row(
      children: [
        Text("$label : ", style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
