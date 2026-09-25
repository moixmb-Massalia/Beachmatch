import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/tournament.dart';
import '../../models/tournament_bracket_model.dart';
import '../../models/court_call_model.dart';
import '../../services/bracket_generator_service.dart';
import '../../services/tournament_pdf_service.dart';
import '../../theme/colors.dart';

class TournamentBracketScreen extends StatefulWidget {
  final TournamentModel tournament;
  final bool isAuthorized;

  const TournamentBracketScreen({
    super.key,
    required this.tournament,
    required this.isAuthorized,
  });

  @override
  State<TournamentBracketScreen> createState() => _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Contrôleurs de défilement manuel direct (sans zoom)
  final ScrollController _mainVerticalController = ScrollController();
  final ScrollController _mainHorizontalController = ScrollController();
  final ScrollController _consoVerticalController = ScrollController();
  final ScrollController _consoHorizontalController = ScrollController();

  bool _isSaving = false;
  String _selectedCategory = 'double_messieurs';
  bool _forceJatMode = true; // JAT activé par défaut pour gain de temps
  bool _isTreeMode = true; // Toggle Vue Arbre Graphique vs Vue Liste Express

  bool get _isJat =>
      widget.isAuthorized ||
      _forceJatMode ||
      (FirebaseAuth.instance.currentUser != null);

  final List<Map<String, dynamic>> _categories = [
    {
      'key': 'double_messieurs',
      'label': 'Double Hommes',
      'icon': Icons.sports_tennis,
      'badge': 'Poules + Arbre'
    },
    {
      'key': 'double_dames',
      'label': 'Double Dames',
      'icon': Icons.sports_tennis_outlined,
      'badge': 'Poules + Arbre'
    },
    {
      'key': 'double_mixtes',
      'label': 'Double Mixtes',
      'icon': Icons.star_rounded,
      'badge': 'Tableau 16'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mainVerticalController.dispose();
    _mainHorizontalController.dispose();
    _consoVerticalController.dispose();
    _consoHorizontalController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _bracketRef =>
      FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('brackets')
          .doc(_selectedCategory);

  DocumentReference<Map<String, dynamic>> get _legacyRef =>
      FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('bracket')
          .doc('current');

  Future<void> _saveBracket(TournamentBracket bracket) async {
    setState(() => _isSaving = true);
    try {
      await _bracketRef.set(bracket.toMap(), SetOptions(merge: true));
      if (_selectedCategory == 'double_messieurs') {
        await _legacyRef.set(bracket.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de sauvegarde : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _scrollToRound(ScrollController controller, int roundIndex) {
    // Largeur de colonne (310) + marge (24) = 334px par tour
    final targetOffset = roundIndex * 334.0;
    if (controller.hasClients) {
      controller.animateTo(
        targetOffset.clamp(0.0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _broadcastCourtCall({
    required int court,
    required String roundName,
    required String pair1Name,
    required String pair2Name,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('court_calls')
          .add({
        'tournamentId': widget.tournament.id,
        'category': _selectedCategory,
        'court': court,
        'roundName': roundName,
        'pair1Name': pair1Name,
        'pair2Name': pair2Name,
        'calledAt': DateTime.now().toIso8601String(),
        'isActive': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("📢 Appel diffusé : Convoqués sur Court $court !"),
            backgroundColor: AppColors.gold,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: "Partager WhatsApp",
              textColor: const Color(0xFF0F172A),
              onPressed: () => _shareCallMessage(
                court: court,
                roundName: roundName,
                pair1Name: pair1Name,
                pair2Name: pair2Name,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'appel : $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _dismissCourtCall(String callId) async {
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament.id)
        .collection('court_calls')
        .doc(callId)
        .update({'isActive': false});
  }

  void _shareCallMessage({
    required int court,
    required String roundName,
    required String pair1Name,
    required String pair2Name,
  }) {
    final text = "📢 CONVOCATION OFFICIELLE BEACH TENNIS\n"
        "🏆 Tournoi : ${widget.tournament.name}\n"
        "📍 Match : $roundName\n"
        "🎾 Paire 1 : $pair1Name\n"
        "🎾 Paire 2 : $pair2Name\n"
        "⚡ TERRAIN ATTRIBUÉ : COURT $court\n"
        "Merci de vous présenter immédiatement sur le terrain !";

    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: "Convocation Match Court $court",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D14),
      body: Stack(
        children: [
          // 1. Fond Signature Sunset Beach Tennis
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          // 2. Dégradé Glassmorphism Sombre Profond
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xDF090D14),
                    Color(0xF5090D14),
                    Color(0xFF070A0F),
                  ],
                ),
              ),
            ),
          ),
          // 3. Contenu Principal
          SafeArea(
            child: Column(
              children: [
                // Top App Bar personnalisé Glassmorphism avec Export PDF
                _buildCustomAppBar(),

                // Sélecteur de Catégorie (Hommes / Dames / Mixtes)
                _buildCategorySelector(),

                // Bannière d'Appel des Joueurs sur le Terrain en Direct (Live Ticker)
                _buildLiveCourtCallBanner(),

                // Stream Firestore du Tableau
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _bracketRef.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.gold),
                        );
                      }

                      TournamentBracket bracket;
                      if (snapshot.hasData &&
                          snapshot.data?.exists == true &&
                          snapshot.data?.data() != null) {
                        bracket = TournamentBracket.fromMap(
                            snapshot.data!.data()!, widget.tournament.id);
                      } else {
                        bracket = TournamentBracket(
                          tournamentId: widget.tournament.id,
                          category: _selectedCategory,
                          format: _selectedCategory == 'double_mixtes'
                              ? 'elimination'
                              : 'pools_and_bracket',
                          numCourts: 4,
                          status: 'draft',
                          updatedAt: DateTime.now(),
                        );
                      }

                      final isPoolFormat = bracket.format == 'pools_and_bracket';

                      return Column(
                        children: [
                          // Barre de Progression Globale du Tournoi
                          _buildTournamentProgressBar(bracket),

                          // Sous-onglets de navigation adaptatifs
                          _buildSubTabBar(isPoolFormat, bracket),

                          // Vues des Onglets
                          Expanded(
                            child: Stack(
                              children: [
                                TabBarView(
                                  controller: _tabController,
                                  children: isPoolFormat
                                      ? [
                                          _buildPoolsTab(bracket),
                                          _buildFinalPhaseTab(bracket),
                                          _buildPairsManagementTab(bracket),
                                        ]
                                      : [
                                          _buildMainDrawTab(bracket),
                                          _buildConsolationTab(bracket),
                                          _buildPairsManagementTab(bracket),
                                        ],
                                ),
                                if (_isSaving)
                                  Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          color: AppColors.gold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TOP APP BAR CUSTOM GLASSMORPHISM AVEC BOUTON PDF FFT
  // ==========================================
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Bouton Retour
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Titre & Tournoi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "TABLEAUX OFFICIELS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: const Text(
                        "FFT",
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.tournament.name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Bouton Export PDF Officiel FFT
          Tooltip(
            message: "Exporter Feuille Officielle FFT (PDF)",
            child: InkWell(
              onTap: _exportPdf,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.1),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.gold, size: 16),
              ),
            ),
          ),
          // Bouton Copier / Partager Procès-Verbal des Résultats
          Tooltip(
            message: "Procès-Verbal & Récapitulatif JAT (Texte / WhatsApp)",
            child: InkWell(
              onTap: _showSummaryModal,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.1),
                ),
                child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 16),
              ),
            ),
          ),
          // Toggle JAT Express
          InkWell(
            onTap: () {
              setState(() => _forceJatMode = !_forceJatMode);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isJat
                      ? "Mode Arbitre (JAT) Activé : Saisie et modifications directes"
                      : "Mode Spectateur Activé"),
                  duration: const Duration(seconds: 2),
                  backgroundColor: _isJat ? AppColors.gold : const Color(0xFF1E293B),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isJat
                    ? AppColors.gold.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isJat
                      ? AppColors.gold.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.2,
                ),
                boxShadow: _isJat
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    _isJat ? Icons.sports_score_rounded : Icons.visibility_rounded,
                    color: _isJat ? AppColors.gold : Colors.white70,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isJat ? "JAT ACTIF" : "SPECTATEUR",
                    style: TextStyle(
                      color: _isJat ? AppColors.gold : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    try {
      final doc = await _bracketRef.get();
      if (!doc.exists || doc.data() == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucune donnée de tableau à exporter en PDF")),
          );
        }
        return;
      }

      final bracket = TournamentBracket.fromMap(doc.data()!, widget.tournament.id);
      await TournamentPdfService.generateAndExportPdf(
        tournament: widget.tournament,
        bracket: bracket,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'export PDF : $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _showSummaryModal() async {
    try {
      final doc = await _bracketRef.get();
      if (!doc.exists || doc.data() == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucune donnée de tournoi à récapituler")),
          );
        }
        return;
      }

      final bracket = TournamentBracket.fromMap(doc.data()!, widget.tournament.id);
      final summaryText = TournamentPdfService.generateTextSummary(
        tournament: widget.tournament,
        bracket: bracket,
      );

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.82,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.assignment_turned_in_rounded, color: AppColors.gold, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Procès-Verbal des Résultats JAT",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Format officiel FFT prêt pour saisie MOJA, envoi par Email ou WhatsApp :",
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  // Zone de texte scrollable monospace
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          summaryText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Boutons d'action
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white24),
                            ),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text(
                            "Copier le Texte",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: summaryText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("📋 Résultats copiés dans le presse-papier !"),
                                backgroundColor: AppColors.gold,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text(
                            "Partager (WhatsApp)",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          onPressed: () {
                            SharePlus.instance.share(
                              ShareParams(
                                text: summaryText,
                                subject: "Procès-Verbal FFT ${widget.tournament.name}",
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur génération récapitulatif : $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ==========================================
  // BANNIERE D'APPEL DES JOUEURS EN DIRECT (LIVE TICKER)
  // ==========================================
  Widget _buildLiveCourtCallBanner() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('court_calls')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data!.docs.first;
        final call = CourtCallModel.fromMap(doc.data(), doc.id);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.35),
                      const Color(0xFFE11D48).withValues(alpha: 0.25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.campaign_rounded, color: Colors.black, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "APPEL COURT ${call.court}",
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "EN DIRECT",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${call.pair1Name} vs ${call.pair2Name}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_isJat) ...[
                      // Bouton Acquitter Appel
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white70, size: 20),
                        tooltip: "Clôturer l'appel",
                        onPressed: () => _dismissCourtCall(call.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // SELECTEUR DE CATEGORIE AVEC BADGE
  // ==========================================
  Widget _buildCategorySelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat['key'];
            final isMixte = cat['key'] == 'double_mixtes';
            final activeColor = isMixte ? AppColors.gold : AppColors.coral;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  if (_selectedCategory != cat['key']) {
                    setState(() {
                      _selectedCategory = cat['key'];
                      _tabController.index = 0;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? activeColor
                              : Colors.white.withValues(alpha: 0.15),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 15,
                            color: isSelected ? activeColor : Colors.white70,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cat['badge'] as String,
                              style: TextStyle(
                                color: isSelected ? activeColor : Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==========================================
  // BARRE DE PROGRESSION DU TOURNOI
  // ==========================================
  Widget _buildTournamentProgressBar(TournamentBracket bracket) {
    int totalMatches = 0;
    int completedMatches = 0;

    if (bracket.format == 'pools_and_bracket') {
      for (final p in bracket.pools) {
        totalMatches += p.matches.length;
        completedMatches += p.matches.where((m) => m.isCompleted).length;
      }
      totalMatches += bracket.mainMatches.length;
      completedMatches += bracket.mainMatches.where((m) => m.isCompleted).length;
    } else {
      totalMatches = bracket.mainMatches.length + bracket.consolationMatches.length;
      completedMatches = bracket.mainMatches.where((m) => m.isCompleted).length +
          bracket.consolationMatches.where((m) => m.isCompleted).length;
    }

    if (totalMatches == 0) return const SizedBox.shrink();

    final ratio = (completedMatches / totalMatches).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            percent == 100 ? Icons.check_circle_rounded : Icons.timelapse_rounded,
            color: percent == 100 ? Colors.greenAccent : AppColors.gold,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            "$completedMatches / $totalMatches matches terminés ($percent%)",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percent == 100 ? Colors.greenAccent : AppColors.gold,
                ),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUB-TAB BAR DYNAMIQUE (GLASSMORPHISM)
  // ==========================================
  Widget _buildSubTabBar(bool isPoolFormat, TournamentBracket bracket) {
    final pairsCount = bracket.pairs.isNotEmpty
        ? bracket.pairs.length
        : (isPoolFormat
            ? bracket.pools.fold(0, (acc, p) => acc + p.pairs.length)
            : 12);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.gold,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: isPoolFormat
            ? [
                const Tab(
                  iconMargin: EdgeInsets.only(bottom: 2),
                  icon: Icon(Icons.grid_view_rounded, size: 16),
                  text: "Poules A & B",
                ),
                const Tab(
                  iconMargin: EdgeInsets.only(bottom: 2),
                  icon: Icon(Icons.emoji_events_rounded, size: 16),
                  text: "Phase Finale",
                ),
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: const Icon(Icons.people_alt_rounded, size: 16),
                  text: "Paires ($pairsCount)",
                ),
              ]
            : [
                const Tab(
                  iconMargin: EdgeInsets.only(bottom: 2),
                  icon: Icon(Icons.account_tree_rounded, size: 16),
                  text: "Principal",
                ),
                const Tab(
                  iconMargin: EdgeInsets.only(bottom: 2),
                  icon: Icon(Icons.shield_outlined, size: 16),
                  text: "Consolante",
                ),
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: const Icon(Icons.people_alt_rounded, size: 16),
                  text: "Paires ($pairsCount)",
                ),
              ],
      ),
    );
  }

  // ==========================================
  // CARTE GLASSMORPHISM GENERIQUE
  // ==========================================
  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? borderColor,
    Color? backgroundColor,
    double radius = 16,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.18),
              width: 1.1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // ==========================================
  // ONGLET POULES A & B (FORMAT POULES)
  // ==========================================
  Widget _buildPoolsTab(TournamentBracket bracket) {
    if (bracket.pools.isEmpty) {
      return _buildEmptyState(
        title: "Poules non générées",
        subtitle: _isJat
            ? "Vérifiez vos paires dans l'onglet 'Paires' puis cliquez sur 'Générer les Poules'."
            : "Le juge-arbitre n'a pas encore publié les poules de ce tableau.",
        actionText: _isJat ? "Gérer les Paires" : null,
        onAction: _isJat ? () => _tabController.animateTo(2) : null,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
      physics: const BouncingScrollPhysics(),
      children: [
        for (final pool in bracket.pools) ...[
          _buildPoolSection(pool, bracket),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildPoolSection(TournamentPool pool, TournamentBracket bracket) {
    final standings = pool.calculateStandings();
    final isPouleA = pool.id == "poule_a";
    final accentColor = isPouleA ? AppColors.gold : AppColors.coral;

    final completedMatches = pool.matches.where((m) => m.isCompleted).length;
    final isPoolFinished = completedMatches == pool.matches.length && pool.matches.isNotEmpty;

    return _buildGlassCard(
      radius: 18,
      borderColor: accentColor.withValues(alpha: 0.4),
      backgroundColor: Colors.black.withValues(alpha: 0.3),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête Poule avec Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.25),
                  accentColor.withValues(alpha: 0.05),
                ],
              ),
              border: Border(
                bottom: BorderSide(color: accentColor.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.sports_tennis_rounded, color: accentColor, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  pool.name.toUpperCase(),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPoolFinished
                        ? Colors.greenAccent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPoolFinished
                          ? Colors.greenAccent.withValues(alpha: 0.5)
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    isPoolFinished ? "TERMINÉE" : "$completedMatches/${pool.matches.length} JOUÉS",
                    style: TextStyle(
                      color: isPoolFinished ? Colors.greenAccent : Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  "${pool.pairs.length} Équipes",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Tableau de classement
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "CLASSEMENT EN DIRECT",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "Top 2 qualifiés en 1/2 Finales",
                      style: TextStyle(
                        color: accentColor.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(34),
                        1: FlexColumnWidth(4.5),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.5),
                        5: FlexColumnWidth(1.5),
                        6: FlexColumnWidth(1.5),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border(
                              bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                          ),
                          children: [
                            _buildTh("#"),
                            _buildTh("ÉQUIPE"),
                            _buildTh("V"),
                            _buildTh("D"),
                            _buildTh("SETS"),
                            _buildTh("+/-"),
                            _buildTh("PTS"),
                          ],
                        ),
                        for (int i = 0; i < standings.length; i++)
                          _buildStandingRow(i + 1, standings[i], accentColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Matches de poule
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "MATCHES DE LA POULE",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (_isJat)
                      Text(
                        "1-Clic pour arbitrer / convoquer",
                        style: TextStyle(
                          color: AppColors.gold.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ...pool.matches.map((m) => _buildPoolMatchCard(m, pool, bracket)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTh(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  TableRow _buildStandingRow(int rank, PoolStanding standing, Color accent) {
    String medal = "$rank";
    if (rank == 1) medal = "🥇";
    if (rank == 2) medal = "🥈";
    if (rank == 3) medal = "🥉";

    final isQualif = rank <= 2;

    return TableRow(
      decoration: BoxDecoration(
        color: isQualif
            ? (rank == 1 ? AppColors.gold.withValues(alpha: 0.08) : accent.withValues(alpha: 0.05))
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            medal,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      standing.pair.displayName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: isQualif ? FontWeight.w900 : FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (standing.pair.seed != null)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "TS${standing.pair.seed}",
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (isQualif)
                Text(
                  rank == 1 ? "Qualifié 1/2 finale (vs 2e Poule B)" : "Qualifié 1/2 finale (vs 1er Poule A)",
                  style: TextStyle(
                    color: rank == 1 ? AppColors.gold : accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        Text(
          "${standing.won}",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "${standing.lost}",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        Text(
          "${standing.setsWon}-${standing.setsLost}",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        Text(
          standing.diffGames >= 0 ? "+${standing.diffGames}" : "${standing.diffGames}",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: standing.diffGames > 0
                ? Colors.greenAccent
                : (standing.diffGames < 0 ? Colors.redAccent : Colors.white70),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "${standing.points}",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoolMatchCard(
      BracketMatch match, TournamentPool pool, TournamentBracket bracket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: match.isCompleted
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : (match.isInProgress
                  ? AppColors.gold.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.1)),
          width: match.isInProgress ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: match.isCompleted
                      ? Colors.greenAccent.withValues(alpha: 0.2)
                      : (match.isInProgress
                          ? AppColors.gold.withValues(alpha: 0.2)
                          : Colors.white10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  match.isCompleted
                      ? "TERMINÉ"
                      : (match.isInProgress ? "EN COURS" : "À JOUER"),
                  style: TextStyle(
                    color: match.isCompleted
                        ? Colors.greenAccent
                        : (match.isInProgress ? AppColors.gold : Colors.white60),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (match.court != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "TERRAIN ${match.court}",
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (match.score != null)
                Text(
                  match.score!,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              if (_isJat) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.white70, size: 18),
                  tooltip: "Saisie libre JAT",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showManualMatchEditDialog(match, bracket),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _buildPairRow(
            match.pair1,
            match.winnerId == match.pair1?.id,
            match.isCompleted,
            fallbackLabel: "Paire 1",
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: Colors.white10, height: 1),
          ),
          _buildPairRow(
            match.pair2,
            match.winnerId == match.pair2?.id,
            match.isCompleted,
            fallbackLabel: "Paire 2",
          ),
          if (_isJat) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bouton Appel Terrain Rapide
                if (!match.isCompleted && match.pair1 != null && match.pair2 != null) ...[
                  InkWell(
                    onTap: () => _broadcastCourtCall(
                      court: match.court ?? 1,
                      roundName: match.roundName,
                      pair1Name: match.pair1!.displayName,
                      pair2Name: match.pair2!.displayName,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_rounded, size: 14, color: AppColors.gold),
                          SizedBox(width: 4),
                          Text(
                            "Appeler",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                InkWell(
                  onTap: () => _showQuickJatActionSheet(match, bracket, poolId: pool.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.9),
                          AppColors.gold,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.3),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 14, color: Colors.black),
                        const SizedBox(width: 4),
                        Text(
                          match.isCompleted ? "Modifier Score" : "Saisir Score ⚡",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // ONGLET PHASE FINALE CROISÉE (POULES)
  // ==========================================
  Widget _buildFinalPhaseTab(TournamentBracket bracket) {
    if (bracket.mainMatches.isEmpty) {
      return _buildEmptyState(
        title: "Phase Finale non programmée",
        subtitle:
            "Les demi-finales et finales apparaîtront dès que les poules seront configurées.",
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const BouncingScrollPhysics(),
      children: [
        // Bandeau d'information
        _buildGlassCard(
          radius: 14,
          padding: const EdgeInsets.all(12),
          backgroundColor: AppColors.gold.withValues(alpha: 0.08),
          borderColor: AppColors.gold.withValues(alpha: 0.3),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Phase finale croisée automatique : 1er A vs 2ème B, 1er B vs 2ème A. Les 3èmes jouent pour la 5/6ème place.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionHeader("DEMI-FINALES CROISÉES", AppColors.gold, Icons.emoji_events_rounded),
        const SizedBox(height: 8),
        ...bracket.mainMatches
            .where((m) => m.matchCode == 'DF1' || m.matchCode == 'DF2')
            .map((m) => _buildFinalPhaseMatchCard(m, bracket)),

        const SizedBox(height: 16),
        _buildSectionHeader("GRANDE FINALE & PETITE FINALE (3/4)", AppColors.coral, Icons.military_tech_rounded),
        const SizedBox(height: 8),
        ...bracket.mainMatches
            .where((m) => m.matchCode == 'FINALE' || m.matchCode == 'PLACE_3_4')
            .map((m) => _buildFinalPhaseMatchCard(m, bracket)),

        const SizedBox(height: 16),
        _buildSectionHeader("MATCH DE CLASSEMENT (PLACE 5 / 6)", Colors.white70, Icons.low_priority_rounded),
        const SizedBox(height: 8),
        ...bracket.mainMatches
            .where((m) => m.matchCode == 'PLACE_5_6')
            .map((m) => _buildFinalPhaseMatchCard(m, bracket)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildFinalPhaseMatchCard(BracketMatch match, TournamentBracket bracket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildMatchCard(match, bracket, isConsolation: false),
    );
  }

  // ==========================================
  // TABLEAU PRINCIPAL (16-DRAW ELIMINATION)
  // DÉFILEMENT NATUREL MANUEL DE HAUT EN BAS & GAUCHE À DROITE
  // SANS AUCUN ZOOM ACCIDENTEL
  // ==========================================
  Widget _buildMainDrawTab(TournamentBracket bracket) {
    if (bracket.mainMatches.isEmpty) {
      return _buildEmptyState(
        title: "Tableau principal vide",
        subtitle: _isJat
            ? "Inscrivez vos 12 paires dans l'onglet 'Paires' puis générez le tableau FFT."
            : "Le juge-arbitre n'a pas encore publié l'arbre de ce tournoi.",
        actionText: _isJat ? "Gérer les Paires" : null,
        onAction: _isJat ? () => _tabController.animateTo(2) : null,
      );
    }

    final Map<int, List<BracketMatch>> rounds = {};
    for (var m in bracket.mainMatches) {
      rounds.putIfAbsent(m.roundIndex, () => []).add(m);
    }
    final sortedRoundKeys = rounds.keys.toList()..sort();

    return Column(
      children: [
        // Barre d'outils Arbre avec raccourcis rapides des tours
        _buildBracketToolbar(
          horizontalController: _mainHorizontalController,
          rounds: rounds,
          sortedRoundKeys: sortedRoundKeys,
        ),

        // Zone de défilement manuel
        Expanded(
          child: _isTreeMode
              ? _buildManualTreeDraw(
                  rounds: rounds,
                  sortedRoundKeys: sortedRoundKeys,
                  bracket: bracket,
                  verticalController: _mainVerticalController,
                  horizontalController: _mainHorizontalController,
                  isConsolation: false,
                )
              : _buildListDraw(rounds, sortedRoundKeys, bracket, isConsolation: false),
        ),
      ],
    );
  }

  // ==========================================
  // TABLEAU DE CONSOLANTE
  // ==========================================
  Widget _buildConsolationTab(TournamentBracket bracket) {
    if (bracket.consolationMatches.isEmpty) {
      return _buildEmptyState(
        title: "Tableau de consolante vide",
        subtitle:
            "Le tableau de consolante se remplit automatiquement dès que les matches du 1er tour sont joués.",
      );
    }

    final Map<int, List<BracketMatch>> rounds = {};
    for (var m in bracket.consolationMatches) {
      rounds.putIfAbsent(m.roundIndex, () => []).add(m);
    }
    final sortedRoundKeys = rounds.keys.toList()..sort();

    return Column(
      children: [
        _buildBracketToolbar(
          horizontalController: _consoHorizontalController,
          rounds: rounds,
          sortedRoundKeys: sortedRoundKeys,
        ),
        Expanded(
          child: _isTreeMode
              ? _buildManualTreeDraw(
                  rounds: rounds,
                  sortedRoundKeys: sortedRoundKeys,
                  bracket: bracket,
                  verticalController: _consoVerticalController,
                  horizontalController: _consoHorizontalController,
                  isConsolation: true,
                )
              : _buildListDraw(rounds, sortedRoundKeys, bracket, isConsolation: true),
        ),
      ],
    );
  }

  // ==========================================
  // BARRE D'OUTILS TABLEAU (SANS ZOOM - AVEC RACCOURCIS TOURS)
  // ==========================================
  Widget _buildBracketToolbar({
    required ScrollController horizontalController,
    required Map<int, List<BracketMatch>> rounds,
    required List<int> sortedRoundKeys,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Toggle Arbre vs Liste
          InkWell(
            onTap: () => setState(() => _isTreeMode = !_isTreeMode),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Icon(
                    _isTreeMode ? Icons.view_agenda_rounded : Icons.account_tree_rounded,
                    color: AppColors.gold,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isTreeMode ? "Vue Liste" : "Vue Arbre",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Raccourcis de Tours direct (Pills)
          if (_isTreeMode)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: sortedRoundKeys.asMap().entries.map((entry) {
                    final i = entry.key;
                    final roundIdx = entry.value;
                    final roundName = rounds[roundIdx]!.first.roundName;
                    return InkWell(
                      onTap: () => _scrollToRound(horizontalController, i),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          roundName,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
    );
  }

  // ==========================================
  // VUE ARBRE DÉFILEMENT MANUEL LIBRE (SANS ZOOM)
  // ==========================================
  Widget _buildManualTreeDraw({
    required Map<int, List<BracketMatch>> rounds,
    required List<int> sortedRoundKeys,
    required TournamentBracket bracket,
    required ScrollController verticalController,
    required ScrollController horizontalController,
    required bool isConsolation,
  }) {
    return Scrollbar(
      controller: verticalController,
      thumbVisibility: true,
      thickness: 6,
      radius: const Radius.circular(3),
      child: SingleChildScrollView(
        controller: verticalController,
        scrollDirection: Axis.vertical,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Scrollbar(
          controller: horizontalController,
          thumbVisibility: true,
          thickness: 6,
          radius: const Radius.circular(3),
          notificationPredicate: (notif) => notif.depth == 1,
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 16, 40, 120),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedRoundKeys.map((roundIdx) {
                final matches = rounds[roundIdx]!;
                final roundName = matches.first.roundName.toUpperCase();
                final isFinalRound = roundIdx == sortedRoundKeys.last;

                return Container(
                  width: 310,
                  margin: const EdgeInsets.only(right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // En-tête de tour Glassmorphism
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isFinalRound
                                  ? AppColors.gold.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFinalRound
                                    ? AppColors.gold
                                    : Colors.white.withValues(alpha: 0.2),
                                width: isFinalRound ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isFinalRound)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.emoji_events, color: AppColors.gold, size: 16),
                                  ),
                                Text(
                                  roundName,
                                  style: TextStyle(
                                    color: isFinalRound ? AppColors.gold : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Liste de tous les matches du tour qui s'étendent en hauteur
                      ...matches.map((m) => _buildMatchCard(m, bracket, isConsolation: isConsolation)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VUE LISTE EXPRESS (POUR NAVIGATION RAPIDE SUR SMARTPHONE)
  // ==========================================
  Widget _buildListDraw(
    Map<int, List<BracketMatch>> rounds,
    List<int> sortedRoundKeys,
    TournamentBracket bracket, {
    required bool isConsolation,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const BouncingScrollPhysics(),
      children: [
        for (final roundIdx in sortedRoundKeys) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12, top: 4),
            decoration: BoxDecoration(
              color: isConsolation
                  ? AppColors.coral.withValues(alpha: 0.2)
                  : AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isConsolation
                    ? AppColors.coral.withValues(alpha: 0.5)
                    : AppColors.gold.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              rounds[roundIdx]!.first.roundName.toUpperCase(),
              style: TextStyle(
                color: isConsolation ? AppColors.coral : AppColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...rounds[roundIdx]!.map((m) => _buildMatchCard(m, bracket, isConsolation: isConsolation)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ==========================================
  // CARTE DE MATCH OFFICIELLE (GLASSMORPHISM PRO)
  // ==========================================
  Widget _buildMatchCard(
    BracketMatch match,
    TournamentBracket bracket, {
    required bool isConsolation,
  }) {
    final borderColor = match.isCompleted
        ? Colors.greenAccent.withValues(alpha: 0.45)
        : (match.isInProgress
            ? AppColors.gold.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.16));

    final isByeMatch = match.isBye;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        radius: 14,
        padding: EdgeInsets.zero,
        borderColor: borderColor,
        backgroundColor: match.isInProgress
            ? AppColors.gold.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau Statut & Court & Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: match.isCompleted
                          ? Colors.greenAccent.withValues(alpha: 0.2)
                          : (match.isInProgress
                              ? AppColors.gold.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      match.isCompleted
                          ? "TERMINÉ"
                          : (match.isInProgress ? "EN COURS" : "À VENIR"),
                      style: TextStyle(
                        color: match.isCompleted
                            ? Colors.greenAccent
                            : (match.isInProgress ? AppColors.gold : Colors.white60),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (match.court != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Text(
                        "TERRAIN ${match.court}",
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (match.score != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Text(
                        match.score!,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  if (_isJat) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.white70, size: 18),
                      tooltip: "Saisie libre JAT",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showManualMatchEditDialog(match, bracket),
                    ),
                  ],
                ],
              ),
            ),

            // Paires 1 et 2
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildPairRow(
                    match.pair1,
                    match.winnerId == match.pair1?.id,
                    match.isCompleted,
                    fallbackLabel: "Paire 1",
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(color: Colors.white10, height: 1),
                  ),
                  _buildPairRow(
                    match.pair2,
                    match.winnerId == match.pair2?.id,
                    match.isCompleted,
                    fallbackLabel: isByeMatch ? "EXEMPT (BYE)" : "Paire 2",
                  ),
                ],
              ),
            ),

            // Actions JAT Express 1-Clic
            if (_isJat && !isByeMatch)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Bouton Appel Terrain Direct
                    if (!match.isCompleted && match.pair1 != null && match.pair2 != null) ...[
                      InkWell(
                        onTap: () => _broadcastCourtCall(
                          court: match.court ?? 1,
                          roundName: match.roundName,
                          pair1Name: match.pair1!.displayName,
                          pair2Name: match.pair2!.displayName,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.campaign_rounded, size: 14, color: AppColors.gold),
                              SizedBox(width: 4),
                              Text(
                                "Appeler",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    InkWell(
                      onTap: () => _showQuickJatActionSheet(match, bracket),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.gold.withValues(alpha: 0.9),
                              AppColors.gold,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.3),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 14, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(
                              match.isCompleted ? "Modifier Score" : "Saisie Express ⚡",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LIGNE DE PAIRE DANS LA CARTE
  // ==========================================
  Widget _buildPairRow(
    TournamentPair? pair,
    bool isWinner,
    bool isCompleted, {
    String? fallbackLabel,
  }) {
    if (pair == null) {
      return Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fallbackLabel ?? "En attente du tour précédent...",
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    if (pair.isBye) {
      return const Row(
        children: [
          Icon(Icons.remove_circle_outline, size: 13, color: Colors.white30),
          SizedBox(width: 8),
          Text(
            "EXEMPT (BYE)",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (isCompleted && isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 16),
          )
        else
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isWinner ? AppColors.gold : Colors.white30,
              shape: BoxShape.circle,
            ),
          ),
        Expanded(
          child: Text(
            pair.displayName,
            style: TextStyle(
              color: isCompleted
                  ? (isWinner ? Colors.white : Colors.white54)
                  : Colors.white,
              fontSize: 12.5,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (pair.seed != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Text(
              "TS${pair.seed}",
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // JAT ACTION SHEET EXPRESS (GAIN DE TEMPS MAXIMAL !)
  // Saisie du Vainqueur en 1 Clic + Formats Prédéfinis FFT + Terrain Direct + Bouton Appel Terrain
  // ==========================================
  void _showQuickJatActionSheet(
    BracketMatch match,
    TournamentBracket bracket, {
    String? poolId,
  }) {
    if (match.pair1 == null || match.pair2 == null) return;

    final scoreController = TextEditingController(text: match.score ?? "");
    String? winnerId = match.winnerId ?? match.pair1!.id;
    int? selectedCourt = match.court;

    // Formats officiels Beach Tennis FFT
    final presets = [
      "4/1 4/2",
      "4/2 4/1",
      "4/2 1/4 10/6",
      "6/3 6/4",
      "6/4 7/5",
      "6/4 3/6 10/8",
      "9/4",
      "9/7",
      "9/8 (5)",
      "WO (Forfait)",
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Poignée du BottomSheet
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Titre & Match
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${match.roundName} · Saisie Express JAT",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 1. SELECTEUR DE VAINQUEUR GRAND FORMAT
                      const Text(
                        "1. DÉSIGNER LE VAINQUEUR (1-CLIC)",
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildWinnerSelectorCard(
                              pair: match.pair1!,
                              isSelected: winnerId == match.pair1!.id,
                              onTap: () => setSheetState(() => winnerId = match.pair1!.id),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildWinnerSelectorCard(
                              pair: match.pair2!,
                              isSelected: winnerId == match.pair2!.id,
                              onTap: () => setSheetState(() => winnerId = match.pair2!.id),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. PRESETS DE SCORE OFFICIELS FFT
                      const Text(
                        "2. SCORE DU MATCH (BOUTONS RAPIDES)",
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: presets.map((s) {
                          final isSelected = scoreController.text == s;
                          return InkWell(
                            onTap: () => setSheetState(() => scoreController.text = s),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.gold.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.gold
                                      : Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  color: isSelected ? AppColors.gold : Colors.white,
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Champ Score Libre
                      TextField(
                        controller: scoreController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: "Ou saisie libre (ex: 6/4 7/5 ou 9/8)",
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                          prefixIcon: const Icon(Icons.edit, color: AppColors.gold, size: 18),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.gold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. TERRAIN DE JEU & APPEL TERRAIN
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "3. TERRAIN ATTRIBUÉ",
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (selectedCourt != null)
                            InkWell(
                              onTap: () {
                                _broadcastCourtCall(
                                  court: selectedCourt!,
                                  roundName: match.roundName,
                                  pair1Name: match.pair1!.displayName,
                                  pair2Name: match.pair2!.displayName,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.campaign_rounded, size: 13, color: AppColors.gold),
                                    SizedBox(width: 4),
                                    Text(
                                      "Diffuser l'appel 📢",
                                      style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCourtChip(null, "Aucun", selectedCourt == null, () {
                            setSheetState(() => selectedCourt = null);
                          }),
                          const SizedBox(width: 6),
                          for (int c = 1; c <= 4; c++) ...[
                            _buildCourtChip(c, "Court $c", selectedCourt == c, () {
                              setSheetState(() => selectedCourt = c);
                            }),
                            if (c < 4) const SizedBox(width: 6),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Partage WhatsApp / SMS
                      if (selectedCourt != null)
                        InkWell(
                          onTap: () {
                            _shareCallMessage(
                              court: selectedCourt!,
                              roundName: match.roundName,
                              pair1Name: match.pair1!.displayName,
                              pair2Name: match.pair2!.displayName,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share_rounded, size: 14, color: Colors.greenAccent),
                                SizedBox(width: 6),
                                Text(
                                  "Envoyer la convocation (WhatsApp / SMS)",
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // 4. BOUTON UNIQUE DE VALIDATION
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.gold.withValues(alpha: 0.4),
                        ),
                        onPressed: () async {
                          if (scoreController.text.trim().isEmpty || winnerId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Veuillez sélectionner un vainqueur et un score"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);

                          TournamentBracket updated;
                          if (poolId != null) {
                            updated = BracketGeneratorService.recordPoolMatchScore(
                              bracket: bracket,
                              poolId: poolId,
                              matchId: match.id,
                              score: scoreController.text.trim(),
                              winnerId: winnerId!,
                            );
                          } else {
                            updated = BracketGeneratorService.recordMatchScore(
                              bracket: bracket,
                              matchId: match.id,
                              score: scoreController.text.trim(),
                              winnerId: winnerId!,
                            );
                          }

                          // Mettre à jour le terrain si changé
                          if (poolId != null) {
                            updated = updated.copyWith(
                              pools: updated.pools.map((p) {
                                if (p.id != poolId) return p;
                                return p.copyWith(
                                  matches: p.matches.map((m) {
                                    if (m.id != match.id) return m;
                                    return m.copyWith(
                                      court: selectedCourt,
                                      clearCourt: selectedCourt == null,
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            );
                          } else {
                            updated = updated.copyWith(
                              mainMatches: updated.mainMatches.map((m) {
                                if (m.id != match.id) return m;
                                return m.copyWith(
                                  court: selectedCourt,
                                  clearCourt: selectedCourt == null,
                                );
                              }).toList(),
                              consolationMatches: updated.consolationMatches.map((m) {
                                if (m.id != match.id) return m;
                                return m.copyWith(
                                  court: selectedCourt,
                                  clearCourt: selectedCourt == null,
                                );
                              }).toList(),
                            );
                          }

                          await _saveBracket(updated);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("⚡ Score enregistré ! L'arbre avance immédiatement."),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              match.isCompleted
                                  ? "METTRE À JOUR LE RÉSULTAT ⚡"
                                  : "VALIDER & FAIRE AVANCER L'ARBRE ⚡",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 5. BOUTON SÉCURISÉ D'EFFACEMENT / REMISE À ZÉRO DU MATCH
                      if (match.isCompleted || match.score != null || match.winnerId != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.7),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final sheetNav = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(context);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: const Color(0xFF0F172A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Réinitialiser le match ?",
                                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  "Voulez-vous effacer le score de ce match (${match.roundName}) ?\n\nLe match sera remis en statut 'À venir' et les qualifications ou progressions associées seront annulées.",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text(
                                      "Effacer le score",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              sheetNav.pop();
                              final updated = BracketGeneratorService.resetMatchScore(
                                bracket: bracket,
                                matchId: match.id,
                                poolId: poolId,
                              );
                              await _saveBracket(updated);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text("↩️ Match réinitialisé avec succès (remis à zéro) !"),
                                  backgroundColor: Color(0xFFEF4444),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restart_alt_rounded, color: Color(0xFFEF4444), size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Effacer / Réinitialiser ce match (Remise à zéro)",
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildWinnerSelectorCard({
    required TournamentPair pair,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.gold : Colors.white38,
                  size: 18,
                ),
                if (pair.seed != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "TS${pair.seed}",
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pair.displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtChip(
    int? court,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blueAccent.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.white12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : Colors.white70,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // GESTION DES PAIRES & TIRAGE AU SORT
  // ==========================================
  Widget _buildPairsManagementTab(TournamentBracket bracket) {
    final pairsList = bracket.pairs.isNotEmpty
        ? bracket.pairs
        : (bracket.pools.isNotEmpty
            ? bracket.pools.expand((p) => p.pairs).toList()
            : <TournamentPair>[]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_isJat) ...[
          // Actions JAT
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.black),
                  label: const Text(
                    "Ajouter une Paire",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showAddPairDialog(bracket),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.gold),
                  label: const Text(
                    "Générer Tableaux",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.gold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showGenerateBracketDialog(bracket),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        Text(
          "PAIRES INSCRITES (${pairsList.length})",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        if (pairsList.isEmpty)
          _buildEmptyState(
            title: "Aucune paire enregistrée",
            subtitle: "Cliquez sur 'Ajouter une Paire' ou lancez la génération automatique.",
          )
        else
          for (int i = 0; i < pairsList.length; i++)
            _buildRegisteredPairCard(pairsList[i], i + 1, bracket),
      ],
    );
  }

  Widget _buildRegisteredPairCard(TournamentPair pair, int index, TournamentBracket bracket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: _buildGlassCard(
        radius: 12,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: pair.seed != null
                    ? AppColors.gold.withValues(alpha: 0.2)
                    : Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(
                  color: pair.seed != null ? AppColors.gold : Colors.white24,
                ),
              ),
              child: Center(
                child: Text(
                  pair.seed != null ? "TS" : "$index",
                  style: TextStyle(
                    color: pair.seed != null ? AppColors.gold : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    "Poids total : ${pair.weight} (J1: #${pair.player1Rank} · J2: #${pair.player2Rank})",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (pair.seed != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                ),
                child: Text(
                  "TÊTE DE SÉRIE ${pair.seed}",
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOG : SAISIE LIBRE JAT (CRAYON)
  // ==========================================
  void _showManualMatchEditDialog(BracketMatch match, TournamentBracket bracket) {
    final p1P1Controller = TextEditingController(text: match.pair1?.player1Name ?? "");
    final p1P2Controller = TextEditingController(text: match.pair1?.player2Name ?? "");
    final p2P1Controller = TextEditingController(text: match.pair2?.player1Name ?? "");
    final p2P2Controller = TextEditingController(text: match.pair2?.player2Name ?? "");
    final scoreController = TextEditingController(text: match.score ?? "");
    String? winnerId = match.winnerId;
    int? court = match.court;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text(
            "Saisie Libre Arbitre (JAT) · ${match.roundName}",
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Paire 1 (Joueur 1 & Joueur 2) :",
                  style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: p1P1Controller,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(hintText: "Nom Joueur 1", filled: true, fillColor: Colors.white10),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: p1P2Controller,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(hintText: "Nom Joueur 2", filled: true, fillColor: Colors.white10),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Paire 2 (Joueur 1 & Joueur 2) :",
                  style: TextStyle(color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: p2P1Controller,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(hintText: "Nom Joueur 1", filled: true, fillColor: Colors.white10),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: p2P2Controller,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(hintText: "Nom Joueur 2", filled: true, fillColor: Colors.white10),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Score du Match :",
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: scoreController,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(hintText: "ex: 6/4 6/3 ou 9/4", filled: true, fillColor: Colors.white10),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Terrain de jeu (Court) :",
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                DropdownButton<int?>(
                  value: court,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Aucun terrain")),
                    for (int c = 1; c <= 4; c++)
                      DropdownMenuItem(value: c, child: Text("Terrain $c")),
                  ],
                  onChanged: (val) => setDlgState(() => court = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () async {
                Navigator.pop(ctx);
                TournamentBracket updated = bracket;

                TournamentPair? p1 = match.pair1;
                if (p1P1Controller.text.isNotEmpty || p1P2Controller.text.isNotEmpty) {
                  p1 = (p1 ?? TournamentPair(id: "p1_${DateTime.now().millisecondsSinceEpoch}", player1Name: "", player2Name: ""))
                      .copyWith(
                    player1Name: p1P1Controller.text.trim(),
                    player2Name: p1P2Controller.text.trim(),
                  );
                  updated = BracketGeneratorService.manualUpdateMatchPair(
                    bracket: updated,
                    matchId: match.id,
                    slot: 1,
                    pair: p1,
                  );
                }

                TournamentPair? p2 = match.pair2;
                if (p2P1Controller.text.isNotEmpty || p2P2Controller.text.isNotEmpty) {
                  p2 = (p2 ?? TournamentPair(id: "p2_${DateTime.now().millisecondsSinceEpoch}", player1Name: "", player2Name: ""))
                      .copyWith(
                    player1Name: p2P1Controller.text.trim(),
                    player2Name: p2P2Controller.text.trim(),
                  );
                  updated = BracketGeneratorService.manualUpdateMatchPair(
                    bracket: updated,
                    matchId: match.id,
                    slot: 2,
                    pair: p2,
                  );
                }

                // Score et vainqueur
                if (scoreController.text.trim().isNotEmpty && winnerId != null) {
                  if (match.poolId != null) {
                    updated = BracketGeneratorService.recordPoolMatchScore(
                      bracket: updated,
                      poolId: match.poolId!,
                      matchId: match.id,
                      score: scoreController.text.trim(),
                      winnerId: winnerId,
                    );
                  } else {
                    updated = BracketGeneratorService.recordMatchScore(
                      bracket: updated,
                      matchId: match.id,
                      score: scoreController.text.trim(),
                      winnerId: winnerId,
                    );
                  }
                }

                // Terrain
                if (match.poolId != null) {
                  updated = updated.copyWith(
                    pools: updated.pools.map((p) {
                      if (p.id != match.poolId) return p;
                      return p.copyWith(
                        matches: p.matches.map((m) {
                          if (m.id != match.id) return m;
                          return m.copyWith(court: court, clearCourt: court == null);
                        }).toList(),
                      );
                    }).toList(),
                  );
                } else {
                  updated = updated.copyWith(
                    mainMatches: updated.mainMatches.map((m) => m.id == match.id ? m.copyWith(court: court, clearCourt: court == null) : m).toList(),
                    consolationMatches: updated.consolationMatches.map((m) => m.id == match.id ? m.copyWith(court: court, clearCourt: court == null) : m).toList(),
                  );
                }

                await _saveBracket(updated);
              },
              child: const Text("Enregistrer Modifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOG : AJOUT D'UNE PAIRE
  // ==========================================
  void _showAddPairDialog(TournamentBracket bracket) {
    final p1Controller = TextEditingController();
    final p2Controller = TextEditingController();
    final r1Controller = TextEditingController(text: "500");
    final r2Controller = TextEditingController(text: "500");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("Inscrire une nouvelle paire", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: p1Controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Nom & Prénom Joueur 1", labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: r1Controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Classement FFT Joueur 1", labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: p2Controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Nom & Prénom Joueur 2", labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: r2Controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Classement FFT Joueur 2", labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              if (p1Controller.text.trim().isEmpty || p2Controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              final newPair = TournamentPair(
                id: "pair_${DateTime.now().millisecondsSinceEpoch}",
                player1Name: p1Controller.text.trim(),
                player2Name: p2Controller.text.trim(),
                player1Rank: int.tryParse(r1Controller.text.trim()) ?? 500,
                player2Rank: int.tryParse(r2Controller.text.trim()) ?? 500,
              );

              final pairs = List<TournamentPair>.from(bracket.pairs)..add(newPair);
              await _saveBracket(bracket.copyWith(pairs: pairs));
            },
            child: const Text("Inscrire", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOG : GENERER LES TABLEAUX / POULES
  // ==========================================
  void _showGenerateBracketDialog(TournamentBracket bracket) {
    final isPool = _selectedCategory != 'double_mixtes';
    final currentPairsCount = bracket.pairs.isNotEmpty
        ? bracket.pairs.length
        : (isPool ? bracket.pools.fold(0, (acc, p) => acc + p.pairs.length) : 12);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          isPool ? "Générer les Poules & Phase Finale ?" : "Générer le Tableau Officiel FFT ?",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          isPool
              ? "Cela va répartir les $currentPairsCount paires en 2 Poules (A & B) et créer les demi-finales croisées et finales."
              : "Cela va générer le tableau à élimination directe de 16 avec 4 BYE pour les 4 premières têtes de série selon les règles FFT.",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              Navigator.pop(ctx);
              TournamentBracket generated;
              if (isPool) {
                final allPairs = bracket.pairs.isNotEmpty
                    ? bracket.pairs
                    : (bracket.pools.isNotEmpty
                        ? [...bracket.pools[0].pairs, ...bracket.pools[1].pairs]
                        : <TournamentPair>[]);

                final pA = allPairs.take(3).toList();
                final pB = allPairs.skip(3).take(3).toList();

                generated = BracketGeneratorService.generatePoolsAndBracket(
                  tournamentId: widget.tournament.id,
                  category: _selectedCategory,
                  pouleAPairs: pA,
                  pouleBPairs: pB,
                );
              } else {
                generated = BracketGeneratorService.generateBracket(
                  tournamentId: widget.tournament.id,
                  category: _selectedCategory,
                  registeredPairs: bracket.pairs,
                );
              }
              await _saveBracket(generated);
            },
            child: const Text("Générer Maintenant", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAT VIDE
  // ==========================================
  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.account_tree_outlined, color: AppColors.gold, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.black),
                label: Text(actionText, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
