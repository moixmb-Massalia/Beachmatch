import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../models/news_item.dart';
import '../models/club.dart';
import '../models/court.dart';
import '../models/tournament.dart';
import '../models/user.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/app_state.dart';
import 'public_profile_screen.dart';
import '../widgets/admin_health_checker_sheet.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _moderationSection = 'courts'; // 'courts' or 'tournaments'
  final TextEditingController _moderationSearchCtrl = TextEditingController();
  String _moderationSearchQuery = '';

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .trim();
  }

  bool _matchesTokens(String text, List<String> tokens) {
    if (tokens.isEmpty) return true;
    final norm = _normalize(text);
    return tokens.every((token) => norm.contains(token));
  }

  void _showAddNewsDialog({NewsItemModel? existingNews}) {
    final titleCtrl = TextEditingController(text: existingNews?.title);
    final descCtrl = TextEditingController(text: existingNews?.description);
    final catCtrl = TextEditingController(text: existingNews?.category ?? 'TUTORIEL HEBDO 🎓');
    final videoIdCtrl = TextEditingController(
        text: existingNews?.videoUrl?.split('v=').last ?? '');
    
    bool isLive = existingNews?.isLive ?? false;
    bool isShort = existingNews?.videoUrl?.contains('/shorts/') ?? false;
    NewsType type = existingNews?.type ?? NewsType.tutorial;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141923),
              title: Text(existingNews == null ? "Ajouter une Vidéo" : "Modifier la Vidéo", style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Titre", labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    TextField(
                      controller: catCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Catégorie (ex: DIRECT WORLD TOUR 🔴)", labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    TextField(
                      controller: videoIdCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "ID Vidéo YouTube (ex: 8m10M7aKxBs)", labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    SwitchListTile(
                      title: const Text("C'est un LIVE 🔴", style: TextStyle(color: Colors.white)),
                      value: isLive,
                      activeThumbColor: AppColors.coral,
                      onChanged: (val) => setStateDialog(() => isLive = val),
                    ),
                    SwitchListTile(
                      title: const Text("Format Short Vertical 📱", style: TextStyle(color: Colors.white)),
                      value: isShort,
                      activeThumbColor: AppColors.gold,
                      onChanged: (val) => setStateDialog(() => isShort = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || videoIdCtrl.text.isEmpty) return;
                    
                    final data = {
                      'title': titleCtrl.text,
                      'description': descCtrl.text,
                      'category': catCtrl.text,
                      'type': type.toString().split('.').last,
                      'imageUrl': 'assets/images/beach_sunset_players_1785052273648.jpg',
                      'videoUrl': isShort ? 'https://www.youtube.com/shorts/${videoIdCtrl.text}' : 'https://www.youtube.com/watch?v=${videoIdCtrl.text}',
                      'publishedAt': Timestamp.now(),
                      'isLive': isLive,
                    };

                    final nav = Navigator.of(context);
                    if (existingNews == null) {
                      await _firestore.collection('news').add(data);
                    } else {
                      await _firestore.collection('news').doc(existingNews.id).update(data);
                    }
                    nav.pop();
                  },
                  child: const Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteNews(String id) {
    _firestore.collection('news').doc(id).delete();
  }

  void _banUser(String userId, String reportId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firestore.collection('users').doc(userId).update({'isBanned': true});
      messenger.showSnackBar(const SnackBar(content: Text('Utilisateur banni avec succès !')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim();
    final isSuperAdmin = currentEmail == 'moixmb@gmail.com';

    if (!isSuperAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F121A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Accès Administrateur", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_person_rounded, color: AppColors.coral, size: 54),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Accès Restreint",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Ce panel d'administration et les statistiques des inscrits sont strictement réservés au compte moixmb@gmail.com.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text("Retour", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F121A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Panel Administrateur", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF10B981), size: 24),
              tooltip: "Diagnostic Santé & Pannes",
              onPressed: () => AdminHealthCheckerSheet.show(context),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.gold, size: 28),
              onPressed: () => _showAddNewsDialog(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.symmetric(horizontal: 8),
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.newspaper_rounded, size: 18), text: "Actualités"),
              Tab(icon: Icon(Icons.flag_rounded, size: 18), text: "Signalements"),
              Tab(icon: Icon(Icons.shield_rounded, size: 18), text: "Modération"),
              Tab(icon: Icon(Icons.star_rounded, size: 18), text: "Présidents"),
              Tab(icon: Icon(Icons.sports_tennis_rounded, size: 18), text: "BeachScore"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Actualités & Statistiques Inscrits
            _buildNewsTab(),
            // Tab 2: Signalements
            _buildReportsTab(),
            // Tab 3: Modération Terrains & Tournois
            _buildModerationTab(),
            // Tab 4: Présidents des clubs
            _buildPresidentsTab(),
            // Tab 5: BeachScore World Tour
            _buildBeachScoreTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('news').orderBy('publishedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }

        final newsDocs = snapshot.data?.docs ?? [];
        final news = newsDocs.map((doc) => NewsItemModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // 1. Dashboard des Inscrits & Pays en Direct (Temps Réel Firestore)
            _buildUserStatsHeader(),
            const SizedBox(height: 20),

            // 2. En-tête de la section Vidéos & Actualités
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.ondemand_video_rounded, color: AppColors.coral, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Vidéos & Tutos du Hub",
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${news.length} vidéo${news.length > 1 ? 's' : ''} publiée${news.length > 1 ? 's' : ''}",
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddNewsDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Ajouter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Liste des vidéos / actualités
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28.0),
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (news.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(
                  child: Text(
                    "Aucune vidéo dans la base de données.",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              ...news.map((item) {
                return Card(
                  color: Colors.white.withValues(alpha: 0.08),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(item.imageUrl, width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 150),
                    ),
                    title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(item.category, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                          onPressed: () => _showAddNewsDialog(existingNews: item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coral, size: 20),
                          onPressed: () => _deleteNews(item.id),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('reports').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("Aucun signalement pour le moment.", style: TextStyle(color: Colors.white70)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final reportedUserId = data['reportedUserId'] ?? '';
            final reason = data['reason'] ?? 'Aucune raison fournie';
            final details = data['details'] ?? '';
            final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            return Card(
              color: Colors.white.withValues(alpha: 0.1),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Motif : $reason", style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text("Détails : $details", style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: reportedUserId.isNotEmpty
                          ? () => PublicProfileScreen.open(context, userId: reportedUserId)
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "ID Joueur ciblé : $reportedUserId",
                            style: const TextStyle(color: AppColors.gold, fontSize: 12, decoration: TextDecoration.underline),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.open_in_new_rounded, color: AppColors.gold, size: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("Date : ${date.toString().substring(0, 16)}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.block),
                        label: const Text("Bannir l'utilisateur"),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Bannir l'utilisateur ?"),
                              content: const Text("Cette action déconnectera immédiatement l'utilisateur et l'empêchera de se reconnecter. Continuer ?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _banUser(reportedUserId, doc.id);
                                  },
                                  child: const Text("Bannir définitivement", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- MODERATION TAB (COURTS & TOURNAMENTS) ---
  Widget _buildModerationTab() {
    return Column(
      children: [
        // Sub-navigation pills (Terrains vs Tournois vs Suggestions)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _moderationSection = 'courts'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _moderationSection == 'courts' ? AppColors.coral : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _moderationSection == 'courts' ? AppColors.coral : Colors.white.withValues(alpha: 0.15)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "🏖️ Terrains",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _moderationSection = 'tournaments'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _moderationSection == 'tournaments' ? AppColors.gold : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _moderationSection == 'tournaments' ? AppColors.gold : Colors.white.withValues(alpha: 0.15)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "⭐ Tournois",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _moderationSection = 'suggestions'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _moderationSection == 'suggestions' ? Colors.cyan : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _moderationSection == 'suggestions' ? Colors.cyan : Colors.white.withValues(alpha: 0.15)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "💡 Suggestions Joueurs",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search Bar for Moderation (if not suggestions)
        if (_moderationSection != 'suggestions')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: TextField(
                controller: _moderationSearchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (val) => setState(() => _moderationSearchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: _moderationSection == 'courts'
                      ? "Rechercher un terrain ou une ville..."
                      : "Rechercher un tournoi ou un club...",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                  suffixIcon: _moderationSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () {
                            _moderationSearchCtrl.clear();
                            setState(() => _moderationSearchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),

        // Content List
        Expanded(
          child: _moderationSection == 'courts'
              ? _buildCourtsModerationList()
              : _moderationSection == 'tournaments'
                  ? _buildTournamentsModerationList()
                  : _buildSuggestionsModerationList(),
        ),
      ],
    );
  }

  Widget _buildCourtsModerationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('courts').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.coral));

        final allDocs = snapshot.data!.docs;
        final courts = allDocs.map((doc) => CourtModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        final tokens = _normalize(_moderationSearchQuery).split(' ').where((t) => t.isNotEmpty).toList();
        final filtered = tokens.isEmpty
            ? courts
            : courts.where((c) => _matchesTokens("${c.name} ${c.city} ${c.country} ${c.description ?? ''}", tokens)).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text("Aucun terrain trouvé.", style: TextStyle(color: Colors.white70)));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final court = filtered[index];
            return Card(
              color: Colors.white.withValues(alpha: 0.08),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.coral.withValues(alpha: 0.2),
                  child: const Icon(Icons.beach_access_rounded, color: AppColors.coral, size: 20),
                ),
                title: Text(court.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text("📍 ${court.city.isNotEmpty ? court.city : court.country} • ${court.country}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      court.accessType == 'BEACH_FREE'
                          ? "🏖️ Plage libre (Kit portable)"
                          : court.accessType == 'CLUB_ONLY'
                              ? "🏢 Réservé Club"
                              : "💳 Location à l'heure",
                      style: TextStyle(
                        color: court.accessType == 'BEACH_FREE' ? Colors.cyanAccent : AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  tooltip: "Supprimer ce terrain",
                  onPressed: () => _confirmDeleteCourt(court),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCourt(CourtModel court) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141923),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text("Supprimer le terrain ?", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          "Êtes-vous sûr de vouloir supprimer définitivement le terrain '${court.name}' (${court.city}) de la carte BeachMatch ?",
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final appState = context.read<AppState>();
              try {
                await _firestore.collection('courts').doc(court.id).delete();
                await appState.loadData();
                messenger.showSnackBar(
                  SnackBar(content: Text("Terrain '${court.name}' supprimé avec succès !"), backgroundColor: Colors.green),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentsModerationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tournaments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.gold));

        final allDocs = snapshot.data!.docs;
        final tourns = allDocs.map((doc) => TournamentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        final tokens = _normalize(_moderationSearchQuery).split(' ').where((t) => t.isNotEmpty).toList();
        final filtered = tokens.isEmpty
            ? tourns
            : tourns.where((t) => _matchesTokens("${t.name} ${t.club} ${t.location} ${t.category}", tokens)).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text("Aucun tournoi trouvé.", style: TextStyle(color: Colors.white70)));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final tourn = filtered[index];
            return Card(
              color: Colors.white.withValues(alpha: 0.08),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                  child: Text(
                    tourn.category.isNotEmpty ? tourn.category : 'BT',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
                title: Text(tourn.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text("📍 ${tourn.location} • 📅 ${tourn.dateString}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text("🏢 ${tourn.club}", style: const TextStyle(color: AppColors.gold, fontSize: 11)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  tooltip: "Supprimer ce tournoi",
                  onPressed: () => _confirmDeleteTournament(tourn),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTournament(TournamentModel tournament) {
    final currentEmail = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim();
    if (currentEmail != 'moixmb@gmail.com') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Action réservée à l'administrateur principal (moixmb@gmail.com)."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141923),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text("Supprimer le tournoi ?", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          "Êtes-vous sûr de vouloir supprimer définitivement le tournoi '${tournament.name}' (${tournament.club}) ?",
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final appState = context.read<AppState>();
              try {
                await _firestore.collection('tournaments').doc(tournament.id).delete();
                await appState.loadData();
                messenger.showSnackBar(
                  SnackBar(content: Text("Tournoi '${tournament.name}' supprimé avec succès !"), backgroundColor: Colors.green),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsModerationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('court_suggestions').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyan));

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read_rounded, size: 54, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                const Text("Aucune suggestion en attente", style: TextStyle(color: Colors.white54, fontSize: 15)),
                const SizedBox(height: 4),
                const Text("Les signalements et enrichissements des joueurs apparaîtront ici.", style: TextStyle(color: Colors.white30, fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final courtName = data['courtName'] ?? 'Terrain';
            final city = data['city'] ?? '';
            final category = data['category'] ?? 'autre';
            final details = data['details'] ?? '';
            final userName = data['userName'] ?? 'Joueur';

            return Card(
              color: Colors.white.withValues(alpha: 0.08),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded, color: Colors.cyan, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$courtName ($city)",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 22),
                          tooltip: "Marquer comme traité (Supprimer)",
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await doc.reference.delete();
                            messenger.showSnackBar(
                              const SnackBar(content: Text("Suggestion traitée et archivée ! ✓")),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Catégorie : $category",
                        style: const TextStyle(color: Colors.cyan, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      details,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Proposé par : $userName",
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- PRESIDENTS TAB ---
  final TextEditingController _presidentSearchCtrl = TextEditingController();
  String _presidentSearchQuery = '';

  Widget _buildPresidentsTab() {
    return Column(
      children: [
        // Barre de recherche de club en temps réel
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: TextField(
              controller: _presidentSearchCtrl,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                setState(() {
                  _presidentSearchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Rechercher un club ou une ville (ex: Marseille, Prado)...",
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold),
                suffixIcon: _presidentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 18),
                        onPressed: () {
                          _presidentSearchCtrl.clear();
                          setState(() {
                            _presidentSearchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('clubs').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.gold));

              final allClubs = snapshot.data!.docs.map((doc) {
                return ClubModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              }).toList();

              final tokens = _normalize(_presidentSearchQuery).split(' ').where((t) => t.isNotEmpty).toList();
              final clubs = tokens.isEmpty
                  ? allClubs
                  : allClubs.where((club) => _matchesTokens("${club.name} ${club.location}", tokens)).toList();

              if (clubs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, color: Colors.white.withValues(alpha: 0.3), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _presidentSearchQuery.isNotEmpty
                              ? "Aucun club trouvé pour '$_presidentSearchQuery'."
                              : "Aucun club.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: clubs.length,
                itemBuilder: (context, index) {
                  final club = clubs[index];
                  final displayLoc = (club.location.isEmpty || club.location.toLowerCase().contains('recherche'))
                      ? 'France'
                      : club.location;

                  return Card(
                    color: Colors.white.withValues(alpha: 0.1),
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                        child: Text(
                          club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(club.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayLoc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            club.presidentEmails.isEmpty
                                ? "⚠️ Aucun président défini"
                                : "✅ ${club.presidentEmails.length} président(s)",
                            style: TextStyle(
                              color: club.presidentEmails.isEmpty ? Colors.orange : Colors.greenAccent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.manage_accounts, color: AppColors.gold),
                        tooltip: "Gérer les présidents",
                        onPressed: () => _showManagePresidentsDialog(club),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showManagePresidentsDialog(ClubModel club) {
    final emailCtrl = TextEditingController();
    List<String> emails = List<String>.from(club.presidentEmails);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141923),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(club.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text("Gérer les accès Président", style: TextStyle(color: AppColors.gold.withValues(alpha: 0.9), fontSize: 13)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (emails.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text("Aucun président actuellement.", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: emails.length,
                          itemBuilder: (context, index) {
                            final email = emails[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.person, color: AppColors.gold, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(email, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      setStateDialog(() {
                                        emails.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const Divider(color: Colors.white24, height: 20),
                    const SizedBox(height: 4),
                    const Text("Ajouter un président :", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emailCtrl,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: "email@exemple.com",
                              hintStyle: TextStyle(color: Colors.white38),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.gold, size: 28),
                          onPressed: () {
                            final email = emailCtrl.text.trim().toLowerCase();
                            if (email.isNotEmpty && !emails.contains(email)) {
                              setStateDialog(() {
                                emails.add(email);
                                emailCtrl.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save, size: 18),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    await _firestore.collection('clubs').doc(club.id).update({
                      'presidentEmails': emails,
                    });
                    nav.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Présidents mis à jour !")),
                    );
                  },
                  label: const Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── BEACHSCORE ADMIN TAB ────────────────────────────────────────────────
  Widget _buildBeachScoreTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('pro_matches').orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final docId = docs[i].id;
            final status = d['status'] as String? ?? 'SCHEDULED';
            final team1  = d['team1']  as String? ?? '—';
            final team2  = d['team2']  as String? ?? '—';
            final date   = d['date']   as String? ?? '—';

            Color statusColor = Colors.white38;
            if (status == 'LIVE')     statusColor = Colors.red;
            if (status == 'FINISHED') statusColor = AppColors.gold;

            return Card(
              color: Colors.white.withValues(alpha: 0.08),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date + statut
                    Row(
                      children: [
                        Text(date, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Équipes
                    Text(team1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Text('vs', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text(team2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    // Boutons actions
                    Wrap(
                      spacing: 8,
                      children: [
                        if (status == 'LIVE')
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.emoji_events, color: AppColors.gold, size: 14),
                            label: const Text('Terminer', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                            onPressed: () => _showFinishMatchDialog(docId, d),
                          ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit, color: Colors.white70, size: 14),
                          label: const Text('Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          onPressed: () => _showFinishMatchDialog(docId, d),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFinishMatchDialog(String docId, Map<String, dynamic> d) {
    final s1Ctrl = TextEditingController(text: d['set1']?.toString() ?? '');
    final s2Ctrl = TextEditingController(text: d['set2']?.toString() ?? '');
    final s3Ctrl = TextEditingController(text: d['set3']?.toString() ?? '');
    int winner = (d['winner'] as num?)?.toInt() ?? int.tryParse('${d['winner']}') ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF141923),
          title: const Text('Entrer les scores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Format : score1/score2  (ex: 6/4)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 12),
                _scoreField('Set 1 *', s1Ctrl),
                const SizedBox(height: 8),
                _scoreField('Set 2', s2Ctrl),
                const SizedBox(height: 8),
                _scoreField('Super TB', s3Ctrl),
                const SizedBox(height: 16),
                const Text('Vainqueur :', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _winnerBtn(1, winner, (v) => setStateDialog(() => winner = v)),
                    const SizedBox(width: 10),
                    _winnerBtn(2, winner, (v) => setStateDialog(() => winner = v)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () {
                final update = <String, dynamic>{
                  'status': 'FINISHED',
                  'winner': winner,
                  if (s1Ctrl.text.trim().isNotEmpty) 'set1': s1Ctrl.text.trim(),
                  if (s2Ctrl.text.trim().isNotEmpty) 'set2': s2Ctrl.text.trim(),
                  if (s3Ctrl.text.trim().isNotEmpty) 'set3': s3Ctrl.text.trim(),
                };
                 _firestore.collection('pro_matches').doc(docId).update(update);
                final nav = Navigator.of(context);
                final msg = ScaffoldMessenger.of(context);
                nav.pop();
                msg.showSnackBar(
                  const SnackBar(content: Text('✅ Match mis à jour !')),
                );
              },
              child: const Text('Valider', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        hintText: 'ex: 6/4',
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
      ),
    );
  }

  Widget _winnerBtn(int value, int current, void Function(int) onTap) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.gold : Colors.white24),
        ),
        child: Text(
          'Équipe $value',
          style: TextStyle(
            color: selected ? AppColors.gold : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // STATISTIQUES DES INSCRITS & PAYS EN DIRECT (FIRESTORE)
  // ============================================================================

  Map<String, dynamic> _getUserCountryInfo(Map<String, dynamic> data) {
    final location = (data['location'] ?? '').toString().toLowerCase();
    final club = (data['club'] ?? '').toString().toLowerCase();
    final email = (data['email'] ?? '').toString().toLowerCase();
    final name = (data['displayName'] ?? '').toString().toLowerCase();
    final fullText = '$location $club $email $name';

    // 1. Brésil
    final brazilKeywords = [
      'bitencourt', 'meira', 'gortchola', 'gabriel', 'taysa', 'santos', 'pivoto', 'pires',
      'danyel', 'nilton', 'weverton', 'rubia', 'paula', 'karine', 'davi', 'melo', 'bisolo',
      'rossini', 'soares', 'heridelson', 'brasil', 'brazil', 'rio', 'sao paulo'
    ];
    if (brazilKeywords.any((k) => fullText.contains(k))) {
      return {'name': 'Brésil', 'flag': '🇧🇷', 'code': 'BR', 'color': const Color(0xFF009C3B)};
    }

    // 2. DOM-TOM Français
    if (fullText.contains('suzini') || fullText.contains('guyane') || fullText.contains('973')) {
      return {'name': 'Guyane', 'flag': '🇬🇫', 'code': 'GF', 'color': const Color(0xFF002395)};
    }
    if (fullText.contains('reunion') || fullText.contains('réunion') || fullText.contains('974')) {
      return {'name': 'La Réunion', 'flag': '🇷🇪', 'code': 'RE', 'color': const Color(0xFF002395)};
    }
    if (fullText.contains('guadeloupe') || fullText.contains('971')) {
      return {'name': 'Guadeloupe', 'flag': '🇬🇵', 'code': 'GP', 'color': const Color(0xFF002395)};
    }
    if (fullText.contains('martinique') || fullText.contains('972')) {
      return {'name': 'Martinique', 'flag': '🇲🇶', 'code': 'MQ', 'color': const Color(0xFF002395)};
    }
    if (fullText.contains('saint-barth') || fullText.contains('st barth') || fullText.contains('977')) {
      return {'name': 'Saint-Barth', 'flag': '🇧🇱', 'code': 'BL', 'color': const Color(0xFF002395)};
    }

    // 3. Italie
    final italyKeywords = ['maurizio', 'villa', 'depiero', 'de piero', 'peretti', 'italia', 'italy', 'ravenna', 'roma', 'cagliari', 'bologna'];
    if (italyKeywords.any((k) => fullText.contains(k))) {
      return {'name': 'Italie', 'flag': '🇮🇹', 'code': 'IT', 'color': const Color(0xFF009246)};
    }

    // 4. Algérie / Maghreb
    final dzKeywords = [
      'bellahsene', 'houria', 'tekd', 'hammadache', 'ham', 'moumohbell', 'pouilie',
      'biba', 'benouza', 'nazbel', 'rabea', 'kimhassiba', 'lagache', 'ali gg'
    ];
    if (dzKeywords.any((k) => fullText.contains(k))) {
      return {'name': 'Algérie', 'flag': '🇩🇿', 'code': 'DZ', 'color': const Color(0xFF006233)};
    }

    // 5. Pologne
    if (fullText.contains('dzierzgwa') || fullText.contains('polska') || fullText.contains('poland')) {
      return {'name': 'Pologne', 'flag': '🇵🇱', 'code': 'PL', 'color': const Color(0xFFDC143C)};
    }

    // 6. France (Métropole)
    final frKeywords = [
      'huteau', 'barrionuevo', 'duglos', 'ourliac', 'rouyer', 'mateos', 'argaud',
      'blevenec', 'lane', 'claude', 'marseille', 'toulon', 'chapellois', 'montmeyran',
      'queirel', 'dijon', 'paris', 'bordeaux', 'lyon', 'france'
    ];
    final lic = (data['licenceNumber'] ?? '').toString().trim();
    if (lic.isNotEmpty || frKeywords.any((k) => fullText.contains(k))) {
      return {'name': 'France', 'flag': '🇫🇷', 'code': 'FR', 'color': const Color(0xFF002395)};
    }

    return {'name': 'Autre', 'flag': '🌐', 'code': 'AUT', 'color': Colors.blueGrey};
  }

  Widget _buildUserStatsHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141923),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
          );
        }

        final docs = snapshot.data!.docs;
        final totalCount = docs.length;

        final now = DateTime.now();
        final last24h = now.subtract(const Duration(hours: 24));
        final last7d = now.subtract(const Duration(days: 7));

        int new24hCount = 0;
        int new7dCount = 0;
        int jatCount = 0;
        int realCount = 0;

        final Map<String, int> countryCounts = {};
        final Map<String, String> countryFlags = {};
        final List<Map<String, dynamic>> allUsersList = [];

        final roboRegex = RegExp(r'^[a-z]+\.[0-9]{5}@gmail\.com$');

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['displayName'] ?? '').toString().trim();
          final email = (data['email'] ?? '').toString().trim().toLowerCase();
          final isReferee = data['isReferee'] == true;
          final lic = (data['licenceNumber'] ?? '').toString().trim();

          final isBot = email.contains('cloudtestlabaccounts') || roboRegex.hasMatch(email);
          final isReal = !isBot && (name.isNotEmpty || lic.isNotEmpty || email.isNotEmpty);
          if (isReal) realCount++;
          if (isReferee) jatCount++;

          DateTime? createdAt;
          final rawCreated = data['createdAt'];
          if (rawCreated is Timestamp) {
            createdAt = rawCreated.toDate();
          } else if (rawCreated is String) {
            createdAt = DateTime.tryParse(rawCreated);
          }

          if (createdAt != null) {
            if (createdAt.isAfter(last24h)) new24hCount++;
            if (createdAt.isAfter(last7d)) new7dCount++;
          }

          final countryInfo = _getUserCountryInfo(data);
          final countryName = countryInfo['name'] as String;
          final countryFlag = countryInfo['flag'] as String;

          countryCounts[countryName] = (countryCounts[countryName] ?? 0) + 1;
          countryFlags[countryName] = countryFlag;

          allUsersList.add({
            'id': doc.id,
            'name': name.isEmpty ? 'Utilisateur sans pseudo' : name,
            'email': email,
            'location': data['location'] ?? '',
            'club': data['club'] ?? data['clubName'] ?? '',
            'licence': lic,
            'isReferee': isReferee,
            'createdAt': createdAt,
            'country': countryName,
            'flag': countryFlag,
            'isReal': isReal,
            'photoUrl': data['photoUrl'],
            'ranking': data['ranking'],
            'level': data['level'],
            'eloScore': data['eloScore'],
            'isBanned': data['isBanned'] == true,
            'isAmbassador': data['isAmbassador'] == true,
            'ambassadorTitle': data['ambassadorTitle'],
            'cbtCategory': data['cbtCategory'],
            'cbtId': data['cbtId'],
            'rawData': data,
          });
        }

        // Trier les pays par nombre d'inscrits décroissant
        final sortedCountries = countryCounts.keys.toList()
          ..sort((a, b) => countryCounts[b]!.compareTo(countryCounts[a]!));

        // Trier les utilisateurs par date de création décroissante
        final sortedUsers = List<Map<String, dynamic>>.from(allUsersList)
          ..sort((a, b) {
            final da = a['createdAt'] as DateTime? ?? DateTime(2020);
            final db = b['createdAt'] as DateTime? ?? DateTime(2020);
            return db.compareTo(da);
          });

        final recentUsers = sortedUsers.take(8).toList();

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B2333),
                Color(0xFF131824),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header du dashboard
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00E676), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
                          SizedBox(width: 5),
                          Text(
                            "LIVE STATS",
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Inscriptions & Communauté",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => _showUsersDetailSheet(context, allUsersList),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.list_alt_rounded, color: AppColors.gold, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "Voir tout",
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              // Compteurs statistiques clés
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    _buildStatCounterCard(
                      label: "Total Inscrits",
                      value: "$totalCount",
                      subtext: "$realCount réels",
                      icon: Icons.people_alt_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCounterCard(
                      label: "Nouveaux 24h",
                      value: new24hCount > 0 ? "+$new24hCount" : "0",
                      subtext: "Dernière journée",
                      icon: Icons.bolt_rounded,
                      color: new24hCount > 0 ? AppColors.coral : Colors.white60,
                      isHighlight: new24hCount > 0,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCounterCard(
                      label: "7 Derniers Jours",
                      value: new7dCount > 0 ? "+$new7dCount" : "0",
                      subtext: "Cette semaine",
                      icon: Icons.trending_up_rounded,
                      color: new7dCount > 0 ? AppColors.gold : Colors.white60,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCounterCard(
                      label: "JAT / Arbitres",
                      value: "$jatCount",
                      subtext: "Officiels",
                      icon: Icons.gavel_rounded,
                      color: const Color(0xFF64B5F6),
                    ),
                  ],
                ),
              ),

              // Section Répartition par Pays
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(
                  children: [
                    const Icon(Icons.public_rounded, color: AppColors.gold, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      "Répartition par Pays",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${sortedCountries.length} territoires",
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Chips horizontaux défilables par pays
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: sortedCountries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final country = sortedCountries[index];
                    final count = countryCounts[country] ?? 0;
                    final flag = countryFlags[country] ?? '🌐';
                    final pct = totalCount > 0 ? ((count / totalCount) * 100).toStringAsFixed(0) : '0';

                    return InkWell(
                      onTap: () => _showUsersDetailSheet(context, allUsersList, initialCountry: country),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: count >= 10
                                ? AppColors.gold.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(flag, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  country,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "$count inscrit${count > 1 ? 's' : ''} ($pct%)",
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 14),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Aperçu des derniers inscrits (cliquables vers profil complet)
              if (recentUsers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_new_rounded, color: AppColors.coral, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        "Derniers arrivés :",
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: recentUsers.map((u) {
                              final name = u['name'] as String;
                              final flag = u['flag'] as String;
                              final shortName = name.length > 14 ? '${name.substring(0, 12)}…' : name;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _openUserProfile(context, u),
                                    borderRadius: BorderRadius.circular(8),
                                    splashColor: AppColors.gold.withValues(alpha: 0.25),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(flag, style: const TextStyle(fontSize: 13)),
                                          const SizedBox(width: 4),
                                          Text(
                                            shortName,
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 3),
                                          const Icon(Icons.chevron_right_rounded, color: AppColors.gold, size: 13),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCounterCard({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    bool isHighlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isHighlight ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlight ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtext,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showUsersDetailSheet(
    BuildContext context,
    List<Map<String, dynamic>> allUsers, {
    String? initialCountry,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String selectedCountry = initialCountry ?? 'Tous';
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Liste des pays uniques
            final countriesSet = <String>{'Tous'};
            for (final u in allUsers) {
              final c = u['country'] as String? ?? 'Autre';
              countriesSet.add(c);
            }
            final countriesList = countriesSet.toList();

            // Filtrage des utilisateurs
            final filteredUsers = allUsers.where((u) {
              if (selectedCountry != 'Tous' && u['country'] != selectedCountry) {
                return false;
              }
              if (searchQuery.isNotEmpty) {
                final q = searchQuery.toLowerCase();
                final name = (u['name'] as String? ?? '').toLowerCase();
                final email = (u['email'] as String? ?? '').toLowerCase();
                final club = (u['club'] as String? ?? '').toLowerCase();
                final lic = (u['licence'] as String? ?? '').toLowerCase();
                if (!name.contains(q) && !email.contains(q) && !club.contains(q) && !lic.contains(q)) {
                  return false;
                }
              }
              return true;
            }).toList();

            final DateFormat dateFormat = DateFormat('dd/MM/yyyy HH:mm');

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Color(0xFF131824),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Poignée de glissement
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Titre et bouton fermer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.people_alt_rounded, color: AppColors.gold, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Membres & Inscrits BeachMatch",
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "${filteredUsers.length} affiché${filteredUsers.length > 1 ? 's' : ''} sur ${allUsers.length} au total",
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Barre de recherche
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Rechercher par nom, email, club, licence...",
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 20),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val.trim();
                        });
                      },
                    ),
                  ),

                  // Chips de filtrage par pays
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: countriesList.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, idx) {
                        final c = countriesList[idx];
                        final isSelected = c == selectedCountry;
                        final count = c == 'Tous'
                            ? allUsers.length
                            : allUsers.where((u) => u['country'] == c).length;

                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (sel) {
                            setModalState(() {
                              selectedCountry = c;
                            });
                          },
                          label: Text(
                            "$c ($count)",
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          selectedColor: AppColors.gold,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Divider(color: Colors.white10, height: 1),

                  // Liste des utilisateurs
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? const Center(
                            child: Text(
                              "Aucun inscrit ne correspond à ces critères.",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final u = filteredUsers[index];
                              final name = u['name'] as String;
                              final email = u['email'] as String;
                              final flag = u['flag'] as String;
                              final country = u['country'] as String;
                              final club = u['club'] as String;
                              final loc = u['location'] as String;
                              final lic = u['licence'] as String;
                              final isRef = u['isReferee'] == true;
                              final isBanned = u['isBanned'] == true;
                              final dt = u['createdAt'] as DateTime?;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _openUserProfile(context, u),
                                  onLongPress: () => _showUserQuickOptions(context, u),
                                  borderRadius: BorderRadius.circular(14),
                                  splashColor: AppColors.gold.withValues(alpha: 0.15),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isBanned
                                          ? Colors.red.withValues(alpha: 0.08)
                                          : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isBanned
                                            ? Colors.red.withValues(alpha: 0.5)
                                            : isRef
                                                ? AppColors.gold.withValues(alpha: 0.4)
                                                : Colors.white.withValues(alpha: 0.08),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Avatar avec badge drapeau
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                                              backgroundImage: u['photoUrl'] != null && (u['photoUrl'] as String).isNotEmpty
                                                  ? NetworkImage(u['photoUrl'] as String)
                                                  : null,
                                              child: (u['photoUrl'] == null || (u['photoUrl'] as String).isEmpty)
                                                  ? Text(
                                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                      style: const TextStyle(
                                                        color: AppColors.gold,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Text(flag, style: const TextStyle(fontSize: 14)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),

                                        // Détails de l'utilisateur
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        decoration: isBanned ? TextDecoration.lineThrough : null,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isBanned)
                                                    Container(
                                                      margin: const EdgeInsets.only(left: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.red, width: 0.6),
                                                      ),
                                                      child: const Text(
                                                        "BANNI",
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  if (isRef)
                                                    Container(
                                                      margin: const EdgeInsets.only(left: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.gold.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: AppColors.gold, width: 0.6),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.gavel_rounded, color: AppColors.gold, size: 10),
                                                          SizedBox(width: 3),
                                                          Text(
                                                            "JAT FFT",
                                                            style: TextStyle(
                                                              color: AppColors.gold,
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.w900,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),

                                              if (email.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2.0),
                                                  child: Text(
                                                    email,
                                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                  ),
                                                ),

                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.06),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      "$flag $country",
                                                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                                                    ),
                                                  ),
                                                  if (club.isNotEmpty && club != 'Sans club')
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.06),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        club,
                                                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                                                      ),
                                                    ),
                                                  if (loc.isNotEmpty && loc != 'Ma Position' && loc != 'Non définie')
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.06),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        loc,
                                                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                                                      ),
                                                    ),
                                                  if (lic.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.gold.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        "Licence: $lic",
                                                        style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                ],
                                              ),

                                              if (dt != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 6.0),
                                                  child: Text(
                                                    "Inscrit le ${dateFormat.format(dt)}",
                                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Bouton interactif Voir Profil & Options
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            InkWell(
                                              onTap: () => _openUserProfile(context, u),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.gold.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "Profil",
                                                      style: TextStyle(
                                                        color: AppColors.gold,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    SizedBox(width: 2),
                                                    Icon(Icons.chevron_right_rounded, color: AppColors.gold, size: 14),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () => _showUserQuickOptions(context, u),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Padding(
                                                padding: const EdgeInsets.all(4.0),
                                                child: Icon(Icons.more_horiz_rounded, color: Colors.white.withValues(alpha: 0.4), size: 18),
                                              ),
                                            ),
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
              ),
            );
          },
        );
      },
    );
  }

  void _openUserProfile(BuildContext context, Map<String, dynamic> u) {
    UserModel player;
    final rawData = u['rawData'];
    if (rawData is Map<String, dynamic>) {
      player = UserModel.fromMap(rawData, u['id'] as String);
    } else {
      player = UserModel(
        id: u['id'] as String,
        displayName: u['name'] as String,
        level: (u['level'] as num?)?.toInt() ?? 3,
        eloScore: (u['eloScore'] as num?)?.toInt() ?? 1500,
        location: (u['location'] as String?)?.isNotEmpty == true ? (u['location'] as String) : 'France',
        isPremium: false,
        createdAt: (u['createdAt'] as DateTime?) ?? DateTime.now(),
        photoUrl: u['photoUrl'] as String?,
        licenceNumber: u['licence'] as String?,
        ranking: u['ranking'] as String?,
        isReferee: u['isReferee'] == true,
        isBanned: u['isBanned'] == true,
        isAmbassador: u['isAmbassador'] == true,
        ambassadorTitle: u['ambassadorTitle'] as String?,
        cbtCategory: u['cbtCategory'] as String?,
        cbtId: u['cbtId'] as String?,
        clubName: u['club'] as String?,
        email: u['email'] as String?,
      );
    }

    PublicProfileScreen.open(
      context,
      player: player,
      userId: player.id,
      displayName: player.displayName,
      location: player.location,
      photoUrl: player.photoUrl,
      ranking: player.ranking,
    );
  }

  void _showUserQuickOptions(BuildContext context, Map<String, dynamic> u) {
    final userId = u['id'] as String;
    final email = u['email'] as String? ?? '';
    final name = u['name'] as String;
    bool isReferee = u['isReferee'] == true;
    bool isBanned = u['isBanned'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF131824),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              if (email.isNotEmpty)
                                Text(email, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_rounded, color: AppColors.gold, size: 20),
                      ),
                      title: const Text("Voir le profil joueur complet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openUserProfile(context, u);
                      },
                    ),
                    if (email.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                        ),
                        title: const Text("Copier l'adresse email", style: TextStyle(color: Colors.white)),
                        subtitle: Text(email, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: email));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Email copié dans le presse-papiers !")),
                          );
                        },
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isReferee ? AppColors.gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(isReferee ? Icons.gavel_rounded : Icons.gavel_outlined, color: isReferee ? AppColors.gold : Colors.white70, size: 20),
                      ),
                      title: Text(isReferee ? "Retirer l'accréditation JAT FFT" : "Accréditer Arbitre JAT FFT ⚖️", style: const TextStyle(color: Colors.white)),
                      onTap: () async {
                        final newVal = !isReferee;
                        setModalState(() => isReferee = newVal);
                        u['isReferee'] = newVal;
                        await _firestore.collection('users').doc(userId).update({'isReferee': newVal});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(newVal ? "Joueur accrédité JAT FFT !" : "Accréditation JAT retirée")),
                          );
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isBanned ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(isBanned ? Icons.check_circle_rounded : Icons.block_rounded, color: isBanned ? Colors.green : Colors.red, size: 20),
                      ),
                      title: Text(
                        isBanned ? "Débannir le compte joueur" : "Bannir ce compte 🚫",
                        style: TextStyle(color: isBanned ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            backgroundColor: const Color(0xFF141923),
                            title: Text(isBanned ? "Débannir ?" : "Bannir ?", style: const TextStyle(color: Colors.white)),
                            content: Text(
                              isBanned
                                  ? "L'utilisateur aura à nouveau accès à BeachMatch."
                                  : "L'utilisateur sera immédiatement déconnecté et bloqué. Continuer ?",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isBanned ? Colors.green : Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  Navigator.pop(dialogCtx);
                                  Navigator.pop(ctx);
                                  final newVal = !isBanned;
                                  u['isBanned'] = newVal;
                                  await _firestore.collection('users').doc(userId).update({'isBanned': newVal});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(newVal ? "Joueur banni !" : "Joueur débanni !")),
                                    );
                                  }
                                },
                                child: Text(isBanned ? "Débannir" : "Bannir"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
