import 'package:flutter/material.dart';
import '../theme/colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Politique de Confidentialité", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Politique de Confidentialité et CGU",
              style: TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSection("1. Collecte des données", 
              "Nous collectons les données suivantes : nom, prénom, adresse e-mail (via Google Sign-In), numéro de licence FFT (optionnel), et position géographique (si autorisée) pour vous proposer des terrains à proximité."
            ),
            _buildSection("2. Utilisation des données", 
              "Vos données sont utilisées exclusivement pour le bon fonctionnement de l'application BeachMatch (création de matchs, classement, chat entre joueurs). Aucune donnée n'est revendue à des tiers."
            ),
            _buildSection("3. Géolocalisation", 
              "La position GPS n'est utilisée qu'à votre demande pour centrer la carte et calculer la distance des terrains. Elle n'est pas stockée de manière continue sur nos serveurs."
            ),
            _buildSection("4. Suppression des données", 
              "Vous pouvez à tout moment supprimer l'intégralité de votre compte et de vos données en utilisant le bouton 'Supprimer mon compte' dans la section 'Profil'. Cette action effacera toutes vos informations de nos bases de données Firebase."
            ),
            _buildSection("5. Règles de la communauté", 
              "En utilisant BeachMatch, vous vous engagez à respecter les autres joueurs, à honorer votre présence lors des matchs confirmés et à reporter fidèlement les scores pour le maintien d'un classement juste."
            ),
            const SizedBox(height: 40),
            const Text("Dernière mise à jour : 27 Juillet 2026", style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
