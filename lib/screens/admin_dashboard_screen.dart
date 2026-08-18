import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../models/news_item.dart';
import '../models/club.dart';
import '../models/court.dart';
import '../models/tournament.dart';
import '../providers/app_state.dart';

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
                      activeColor: AppColors.coral,
                      onChanged: (val) => setStateDialog(() => isLive = val),
                    ),
                    SwitchListTile(
                      title: const Text("Format Short Vertical 📱", style: TextStyle(color: Colors.white)),
                      value: isShort,
                      activeColor: AppColors.gold,
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

                    if (existingNews == null) {
                      await _firestore.collection('news').add(data);
                    } else {
                      await _firestore.collection('news').doc(existingNews.id).update(data);
                    }
                    Navigator.pop(context);
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
    try {
      await _firestore.collection('users').doc(userId).update({'isBanned': true});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur banni avec succès !')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F121A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Panel Administrateur", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.gold, size: 28),
              onPressed: () => _showAddNewsDialog(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: "Actualités"),
              Tab(text: "Signalements"),
              Tab(icon: Icon(Icons.shield_rounded, size: 16), text: "Modération"),
              Tab(icon: Icon(Icons.star, size: 16), text: "Présidents"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Actualités
            _buildNewsTab(),
            // Tab 2: Signalements
            _buildReportsTab(),
            // Tab 3: Modération Terrains & Tournois
            _buildModerationTab(),
            // Tab 4: Présidents des clubs
            _buildPresidentsTab(),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("Aucune vidéo dans la base de données.", style: TextStyle(color: Colors.white70)));
        }

        final news = docs.map((doc) => NewsItemModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: news.length,
          itemBuilder: (context, index) {
            final item = news[index];
            return Card(
              color: Colors.white.withOpacity(0.1),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(item.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
                ),
                title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(item.category, style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _showAddNewsDialog(existingNews: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.coral),
                      onPressed: () => _deleteNews(item.id),
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
              color: Colors.white.withOpacity(0.1),
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
                    Text("ID Joueur ciblé : $reportedUserId", style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                      color: _moderationSection == 'courts' ? AppColors.coral : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _moderationSection == 'courts' ? AppColors.coral : Colors.white.withOpacity(0.15)),
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
                      color: _moderationSection == 'tournaments' ? AppColors.gold : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _moderationSection == 'tournaments' ? AppColors.gold : Colors.white.withOpacity(0.15)),
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
                      color: _moderationSection == 'suggestions' ? Colors.cyan : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _moderationSection == 'suggestions' ? Colors.cyan : Colors.white.withOpacity(0.15)),
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
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
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

        final filtered = _moderationSearchQuery.isEmpty
            ? courts
            : courts.where((c) {
                final name = c.name.toLowerCase();
                final city = c.city.toLowerCase();
                final country = c.country.toLowerCase();
                return name.contains(_moderationSearchQuery) || city.contains(_moderationSearchQuery) || country.contains(_moderationSearchQuery);
              }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text("Aucun terrain trouvé.", style: TextStyle(color: Colors.white70)));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final court = filtered[index];
            return Card(
              color: Colors.white.withOpacity(0.08),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.coral.withOpacity(0.2),
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
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            const Expanded(child: Text("Supprimer le terrain ?", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
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
              try {
                await _firestore.collection('courts').doc(court.id).delete();
                if (mounted) {
                  await context.read<AppState>().loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Terrain '${court.name}' supprimé avec succès !"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.redAccent),
                  );
                }
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

        final filtered = _moderationSearchQuery.isEmpty
            ? tourns
            : tourns.where((t) {
                final name = t.name.toLowerCase();
                final club = t.club.toLowerCase();
                final loc = t.location.toLowerCase();
                return name.contains(_moderationSearchQuery) || club.contains(_moderationSearchQuery) || loc.contains(_moderationSearchQuery);
              }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text("Aucun tournoi trouvé.", style: TextStyle(color: Colors.white70)));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final tourn = filtered[index];
            return Card(
              color: Colors.white.withOpacity(0.08),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.gold.withOpacity(0.2),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141923),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            const Expanded(child: Text("Supprimer le tournoi ?", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
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
              try {
                await _firestore.collection('tournaments').doc(tournament.id).delete();
                if (mounted) {
                  await context.read<AppState>().loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Tournoi '${tournament.name}' supprimé avec succès !"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.redAccent),
                  );
                }
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
                Icon(Icons.mark_email_read_rounded, size: 54, color: Colors.white.withOpacity(0.2)),
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
              color: Colors.white.withOpacity(0.08),
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
                            await doc.reference.delete();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Suggestion traitée et archivée ! ✓")),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.15),
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
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
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

              final clubs = _presidentSearchQuery.isEmpty
                  ? allClubs
                  : allClubs.where((club) {
                      final name = club.name.toLowerCase();
                      final loc = club.location.toLowerCase();
                      return name.contains(_presidentSearchQuery) || loc.contains(_presidentSearchQuery);
                    }).toList();

              if (clubs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, color: Colors.white.withOpacity(0.3), size: 48),
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
                  return Card(
                    color: Colors.white.withOpacity(0.1),
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.gold.withOpacity(0.2),
                        child: Text(
                          club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(club.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(club.location, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                  Text("Gérer les accès Président", style: TextStyle(color: AppColors.gold.withOpacity(0.9), fontSize: 13)),
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
                                color: Colors.white.withOpacity(0.06),
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
                    await _firestore.collection('clubs').doc(club.id).update({
                      'presidentEmails': emails,
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Présidents mis à jour !")),
                      );
                    }
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
}
