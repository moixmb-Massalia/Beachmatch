import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';
import '../../models/tournament.dart';
import '../../models/tournament_bracket_model.dart';
import '../../models/court_call_model.dart';
import '../../services/bracket_generator_service.dart';
import '../../services/tournament_pdf_service.dart';
import '../../services/whatsapp_share_service.dart';
import '../../services/jat_authorization_service.dart';
import '../../theme/colors.dart';
import '../../widgets/add_pair_autocomplete_dialog.dart';
import '../../widgets/court_schedule_presets_dialog.dart';
import 'jat_draw_ceremony_screen.dart';
import 'court_schedule_screen.dart';

/// Représente un slot de paire (slot 1 ou 2) dans un match pour la permutation JAT
class BracketPairSlot {
  final BracketMatch match;
  final int slot; // 1 or 2
  final TournamentPair? pair;
  final String? poolId;

  const BracketPairSlot({
    required this.match,
    required this.slot,
    this.pair,
    this.poolId,
  });
}

/// État de conformité et d'avancement du workflow officiel JAT (5 étapes)
class JatWorkflowStatus {
  final int currentStep; // 0 to 4
  final bool step1Complete; // Paires inscrites (>= 4 paires)
  final bool step2Complete; // Tirage & Tableau généré
  final bool step3Complete; // Courts & Planning assignés
  final bool step4Complete; // Tous les matches terminés
  final bool step5Complete; // Clôturé
  final int totalMatches;
  final int completedMatches;
  final int inProgressMatches;
  final int pairCount;
  final String nextActionTitle;
  final String nextActionSubtitle;
  final IconData nextActionIcon;
  final VoidCallback onNextAction;

  const JatWorkflowStatus({
    required this.currentStep,
    required this.step1Complete,
    required this.step2Complete,
    required this.step3Complete,
    required this.step4Complete,
    required this.step5Complete,
    required this.totalMatches,
    required this.completedMatches,
    required this.inProgressMatches,
    required this.pairCount,
    required this.nextActionTitle,
    required this.nextActionSubtitle,
    required this.nextActionIcon,
    required this.onNextAction,
  });
}

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
  TournamentBracket? _currentBracket;
  String _selectedCategory = 'double_messieurs';
  bool _isTreeMode = true; // Toggle Vue Arbre Graphique vs Vue Liste Express
  int? _selectedRoundFilter; // null = Tous les tours (filtre interactif 1/8, Quarts, Demis, Finale)

  late bool _isAuthorizedUser;
  final bool _spectatorPreview = false;

  bool get _isJat => _isAuthorizedUser && !_spectatorPreview;

  // Permutation manuelle des paires dans le tableau (JAT)
  BracketPairSlot? _selectedSwapSlot;

  static final List<Map<String, dynamic>> _allCategories = [
    {
      'key': 'double_messieurs',
      'label': 'DH',
      'formatCode': 'DH',
      'icon': Icons.sports_tennis,
      'badge': 'Poules + Arbre'
    },
    {
      'key': 'double_dames',
      'label': 'DD',
      'formatCode': 'DD',
      'icon': Icons.sports_tennis_outlined,
      'badge': 'Poules + Arbre'
    },
    {
      'key': 'double_mixtes',
      'label': 'DX',
      'formatCode': 'DX',
      'icon': Icons.star_rounded,
      'badge': 'Tableau 16'
    },
  ];

  late List<Map<String, dynamic>> _categories;

  @override
  void initState() {
    super.initState();
    _isAuthorizedUser = widget.isAuthorized;

    final tFormats = widget.tournament.formats;
    _categories = _allCategories.where((c) {
      if (tFormats.isEmpty) return true;
      final code = c['formatCode'] as String;
      return tFormats.contains(code) ||
          tFormats.any((f) => f.toUpperCase().contains(code)) ||
          (code == 'DH' && tFormats.any((f) => f.toLowerCase().contains('homme') || f.toLowerCase().contains('messieurs'))) ||
          (code == 'DD' && tFormats.any((f) => f.toLowerCase().contains('dame') || f.toLowerCase().contains('femme'))) ||
          (code == 'DX' && tFormats.any((f) => f.toLowerCase().contains('mixte')));
    }).toList();

    if (_categories.isEmpty) {
      _categories = List.from(_allCategories);
    }

    _selectedCategory = _categories.first['key'] as String;

    _tabController = TabController(length: 3, vsync: this);
    if (!_isAuthorizedUser) {
      _verifyUserPrivileges();
    }
  }

  Future<void> _verifyUserPrivileges() async {
    final appUser = context.read<AppState>().currentUser;
    final isAuth = await JatAuthorizationService.isAuthorizedForTournament(
      user: appUser,
      tournament: widget.tournament,
    );
    if (mounted && isAuth) {
      setState(() => _isAuthorizedUser = true);
    }
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
      await _legacyRef.set(bracket.toMap(), SetOptions(merge: true));
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

  Future<void> _safeShareText({
    required String text,
    String? subject,
  }) async {
    try {
      await WhatsAppShareService.shareToWhatsAppOrNative(
        text: text,
        subject: subject,
      );
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("📋 Message copié dans le presse-papiers !"),
              backgroundColor: AppColors.gold,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (_) {}
    }
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

    _safeShareText(
      text: text,
      subject: "Convocation Match Court $court",
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
                      _currentBracket = bracket;

                      final isPoolFormat = bracket.format == 'pools_and_bracket';

                      return Column(
                        children: [
                          // Barre de Progression Globale du Tournoi OU Stepper JAT
                          if (_isJat)
                            _buildJatWorkflowStepper(bracket)
                          else
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

                          // Sticky Action Bar JAT
                          if (_isJat && _selectedSwapSlot == null)
                            _buildJatStickyActionBar(bracket),
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
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || (widget.tournament.country ?? '').toUpperCase() == 'BR';

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
          const SizedBox(width: 10),
          // Titre & Tournoi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isBr ? "CHAVE DO TORNEIO" : "TABLEAU DE LA COMPÉTITION",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: Text(
                        isBr ? "CBT" : "FFT",
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 8.5,
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
          const SizedBox(width: 8),
          // Badge Statut : Spectateur verrouillé ou Toggle JAT autorisé
          if (!_isAuthorizedUser)
            InkWell(
              onTap: () {
                final ref = widget.tournament.referee;
                final name = ref != null && ref.trim().isNotEmpty ? ref : "JAT Officiel";
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.sports_score_rounded, color: AppColors.gold, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Accès Juge-Arbitre (JAT)",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      "Ce tournoi et son tableau officiel sont sous la responsabilité de $name.\n\n"
                      "Conformément au règlement fédéral, seuls les Juges-Arbitres officiellement répertoriés dans notre base de données ont les droits pour saisir les scores, générer les poules et modifier les matchs.\n\n"
                      "Compte actuel : ${FirebaseAuth.instance.currentUser?.email ?? 'Non connecté'}\n"
                      "Si vous êtes l'arbitre officiel, connectez-vous avec votre adresse email accréditée pour activer vos accès JAT automatiquement.",
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Compris", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBr ? "ESPECTADOR" : "SPECTATEUR",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 6),
          // Bouton Répartition Terrains [ 🏟️ Terrains ] (Prioritaire et toujours visible)
          InkWell(
            onTap: _showCourtScheduleConfigDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stadium_rounded, color: AppColors.gold, size: 16),
                  SizedBox(width: 4),
                  Text(
                    "Terrains",
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Bouton Exporter / Partager [ 📤 Exporter ]
          InkWell(
            onTap: _showExportShareModal,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ios_share_rounded, color: Color(0xFF0F172A), size: 16),
                  SizedBox(width: 5),
                  Text(
                    "Exporter",
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isJat && _currentBracket != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: "Check-list Officielle JAT FFT (7 points)",
              child: InkWell(
                onTap: () => _showJatChecklistModal(context, _currentBracket!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.45), width: 1.1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checklist_rounded, color: Colors.greenAccent, size: 15),
                      SizedBox(width: 4),
                      Text(
                        "Check-list",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          // Bouton Guide JAT [ ℹ️ ]
          Tooltip(
            message: "Guide JAT (Tableaux & Tirage)",
            child: InkWell(
              onTap: () => _showJatGuideModal(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
                ),
                child: const Icon(Icons.help_outline_rounded, color: AppColors.gold, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCourtScheduleConfigDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CourtSchedulePresetsDialog(
        tournament: widget.tournament,
        isAuthorized: _isJat,
        initialBracket: _currentBracket,
      ),
    );
  }

  void _openDrawCeremony(TournamentBracket bracket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JatDrawCeremonyScreen(
          tournament: widget.tournament,
          initialBracket: bracket,
          categoryKey: _selectedCategory,
          categoryLabel: _categories.isNotEmpty
              ? (_categories.firstWhere(
                  (c) => c['key'] == _selectedCategory,
                  orElse: () => _categories.first,
                )['label'] as String? ?? 'DD')
              : 'DD',
          onSaveBracket: (updatedBracket) async {
            await _saveBracket(updatedBracket);
          },
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    try {
      TournamentBracket? bracket = _currentBracket;
      if (bracket == null) {
        final doc = await _bracketRef.get();
        if (doc.exists && doc.data() != null) {
          bracket = TournamentBracket.fromMap(doc.data()!, widget.tournament.id);
        }
      }

      if (bracket == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucune donnée de tableau à exporter en PDF")),
          );
        }
        return;
      }

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

  void _showJatGuideModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: AppColors.gold, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Guide JAT · Tableaux & Tirage",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            "Pilotage direct des tableaux & tirage au sort certifié",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildJatGuideStepCard(
                        step: "1",
                        icon: Icons.cloud_sync_rounded,
                        accentColor: AppColors.gold,
                        title: "Zéro Ressaisie · Connecté à Ten'Up",
                        description: "Le tournoi, ses catégories (DH, DD, DX) et vos coordonnées JAT sont déjà automatiquement synchronisés. Aucun besoin de recréer le tournoi !",
                      ),
                      const SizedBox(height: 12),
                      _buildJatGuideStepCard(
                        step: "2",
                        icon: Icons.content_paste_rounded,
                        accentColor: const Color(0xFF38BDF8),
                        title: "Importation Instantanée des Paires",
                        description: "Dans l'onglet 'Paires', appuyez sur 'Coller' pour importer votre listing de Ten'Up en 1 clic. Tous les séparateurs et numéros de lignes sont automatiquement reconnus.",
                      ),
                      const SizedBox(height: 12),
                      _buildJatGuideStepCard(
                        step: "3",
                        icon: Icons.casino_rounded,
                        accentColor: AppColors.coral,
                        title: "Cérémonie du Tirage au Sort FFT",
                        description: "Effectuez le tirage en direct devant les joueurs avec les règles France FFT (TS1 en bas, TS2 en haut). L'animation génère automatiquement le Procès-Verbal horodaté.",
                      ),
                      const SizedBox(height: 12),
                      _buildJatGuideStepCard(
                        step: "4",
                        icon: Icons.sports_score_rounded,
                        accentColor: const Color(0xFF22C55E),
                        title: "Gestion des Tableaux & Résultats",
                        description: "Basculez entre Vue Arbre et Vue Liste avec filtres par tour (1/8, Quarts, Demis, Finale). Saisissez les scores, validez les vainqueurs et lancez les appels de terrains.",
                      ),
                      const SizedBox(height: 12),
                      _buildJatGuideStepCard(
                        step: "5",
                        icon: Icons.picture_as_pdf_rounded,
                        accentColor: const Color(0xFFA855F7),
                        title: "Export PV Global MOJA & WhatsApp",
                        description: "Générez d'un seul geste le dossier PDF A4 complet (tous tableaux DH, DD, DX) avec signature JAT ou copiez le texte formaté prêt à coller dans MOJA.",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: const Text("Compris, c'est parti !", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJatGuideStepCard({
    required String step,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor, width: 1.2),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accentColor, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadOrleansLandscapePdf() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                ),
                SizedBox(width: 12),
                Text(
                  "Téléchargement du Dossier A4 Paysage...",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: AppColors.gold,
            duration: Duration(seconds: 2),
          ),
        );
      }

      Uint8List? pdfBytes;
      try {
        final byteData = await rootBundle.load('assets/documents/dossier_orleans_20equipes_paysage.pdf');
        pdfBytes = byteData.buffer.asUint8List();
      } catch (e) {
        debugPrint("Asset load fallback: $e");
      }

      if (kIsWeb) {
        // En Web, ouverture directe par URL ou Data URI sans aucun plugin requis
        bool opened = false;
        try {
          final uri = Uri.parse('/dossier_orleans_20equipes_paysage.pdf');
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}

        if (!opened && pdfBytes != null) {
          try {
            final dataUri = Uri.dataFromBytes(pdfBytes, mimeType: 'application/pdf');
            await launchUrl(dataUri, mode: LaunchMode.externalApplication);
            opened = true;
          } catch (_) {}
        }

        if (!opened) {
          final uri = Uri.parse('https://beach-tennis-216f4.web.app/dossier_orleans_20equipes_paysage.pdf');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        // Sur mobile / desktop
        bool done = false;
        if (pdfBytes != null) {
          try {
            done = await Printing.sharePdf(
              bytes: pdfBytes,
              filename: 'Dossier_Tournoi_BTCO_Orleans_20Equipes_Paysage.pdf',
            );
          } catch (e) {
            debugPrint("Printing.sharePdf fallback: $e");
          }
        }
        if (!done) {
          final uri = Uri.parse('https://beach-tennis-216f4.web.app/dossier_orleans_20equipes_paysage.pdf');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "✅ Dossier A4 Paysage (20 équipes + Poule 17-20) ouvert !",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Lien direct : https://beach-tennis-216f4.web.app/dossier_orleans_20equipes_paysage.pdf"),
            backgroundColor: AppColors.gold,
          ),
        );
      }
    }
  }

  Future<void> _showExportShareModal() async {
    try {
      TournamentBracket? currentBracket = _currentBracket;
      if (currentBracket == null) {
        final doc = await _bracketRef.get();
        if (doc.exists && doc.data() != null) {
          currentBracket = TournamentBracket.fromMap(doc.data()!, widget.tournament.id);
        }
      }

      // Récupérer toutes les épreuves du tournoi (DH, DD, DX)
      List<TournamentBracket> allBrackets = [];
      try {
        final allDocs = await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournament.id)
            .collection('brackets')
            .get();

        allBrackets = allDocs.docs
            .map((d) => TournamentBracket.fromMap(d.data(), widget.tournament.id))
            .toList();
      } catch (e) {
        debugPrint("Error fetching all brackets: $e");
      }

      if (allBrackets.isEmpty && currentBracket != null) {
        allBrackets = [currentBracket];
      }

      final activeBracket = currentBracket ?? (allBrackets.isNotEmpty ? allBrackets.first : null);
      if (activeBracket == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucune donnée de tournoi à exporter")),
          );
        }
        return;
      }

      final currentCatLabel = _categories.isNotEmpty
          ? (_categories.firstWhere(
              (c) => c['key'] == _selectedCategory,
              orElse: () => _categories.first,
            )['label'] as String? ?? 'DD')
          : 'DD';

      final singleSummaryText = TournamentPdfService.generateTextSummary(
        tournament: widget.tournament,
        bracket: activeBracket,
      );

      final fullSummaryText = TournamentPdfService.generateFullTournamentTextSummary(
        tournament: widget.tournament,
        brackets: allBrackets,
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
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.ios_share_rounded, color: AppColors.gold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Exporter & Clôturer",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              "Dossier global ou épreuve spécifique",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // SECTION 1 : DOSSIER GLOBAL COMPLET (TOUTES ÉPREUVES RÉUNIES)
                        const Row(
                          children: [
                            Icon(Icons.folder_special_rounded, color: AppColors.gold, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "BILAN GÉNÉRAL · TOUTES ÉPREUVES RÉUNIES",
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // DOSSIER OFFICIEL A4 PAYSAGE DYNAMIQUE (TOUS TOURNOIS)
                        _buildExportOptionCard(
                          icon: Icons.picture_as_pdf_rounded,
                          accentColor: AppColors.gold,
                          title: "Dossier Officiel A4 Paysage (Arbre & Résultats)",
                          subtitle: "Format panoramique officiel pour affichage club et homologation FFT",
                          badge: "A4 PAYSAGE HOMOLOGATION",
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      ),
                                      SizedBox(width: 12),
                                      Text("Génération du Dossier A4 Paysage...", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  backgroundColor: AppColors.gold,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                            try {
                              await TournamentPdfService.generateAndExportLandscapePdf(
                                tournament: widget.tournament,
                                bracket: activeBracket,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("✅ Dossier Paysage généré avec succès !"),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Erreur export paysage : $e"), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // ARCHIVE SPÉCIALE ORLÉANS (uniquement si le tournoi concerne Orléans / BTCO)
                        if (widget.tournament.name.toLowerCase().contains('orléans') ||
                            widget.tournament.name.toLowerCase().contains('orleans') ||
                            widget.tournament.name.toLowerCase().contains('btco')) ...[
                          _buildExportOptionCard(
                            icon: Icons.picture_as_pdf_rounded,
                            accentColor: AppColors.gold,
                            title: "Archive Spécifique Orléans (20 Équipes Paysage)",
                            subtitle: "Arbre 20 équipes complet (Barrages + 1/8) + Poule 17-20 + Visa JAT",
                            badge: "SPÉCIAL ORLÉANS BTCO",
                            onTap: () {
                              Navigator.pop(ctx);
                              _downloadOrleansLandscapePdf();
                            },
                          ),
                          const SizedBox(height: 10),
                        ],

                        _buildExportOptionCard(
                          icon: Icons.auto_stories_rounded,
                          accentColor: AppColors.gold,
                          title: "Dossier Complet Toutes Épreuves (PDF A4)",
                          subtitle: "Tous les tableaux (DH + DD + DX), palmarès général et signature JAT",
                          badge: "RECOMMANDÉ JAT",
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      ),
                                      SizedBox(width: 12),
                                      Text("Génération et téléchargement du PDF...", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  backgroundColor: AppColors.gold,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                            try {
                              await TournamentPdfService.generateAndExportFullTournamentPdf(
                                tournament: widget.tournament,
                                brackets: allBrackets,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("✅ Dossier PDF téléchargé avec succès !"),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Erreur export PDF : $e"), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        _buildExportOptionCard(
                          icon: Icons.chat_bubble_rounded,
                          accentColor: const Color(0xFF25D366),
                          title: "Partager le Bilan Global sur WhatsApp",
                          subtitle: "Palmarès et podiums de toutes les catégories en un seul message",
                          badge: "WHATSAPP GLOBAL",
                          onTap: () {
                            Navigator.pop(ctx);
                            _safeShareText(
                              text: fullSummaryText,
                              subject: "Bilan Officiel ${widget.tournament.name}",
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        _buildExportOptionCard(
                          icon: Icons.copy_all_rounded,
                          accentColor: const Color(0xFF38BDF8),
                          title: "Copier le Procès-Verbal Global (MOJA / Ligue)",
                          subtitle: "Format texte complet de tous les tableaux prêt à coller",
                          badge: "MOJA OFFICIEL",
                          onTap: () {
                            Navigator.pop(ctx);
                            Clipboard.setData(ClipboardData(text: fullSummaryText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("📋 Procès-Verbal Global copié ! Prêt pour MOJA."),
                                backgroundColor: AppColors.gold,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        // SECTION 2 : ÉPREUVE SÉLECTIONNÉE
                        Row(
                          children: [
                            const Icon(Icons.sports_tennis_rounded, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "ÉPREUVE EN COURS : ${currentCatLabel.toUpperCase()}",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        _buildExportOptionCard(
                          icon: Icons.picture_as_pdf_rounded,
                          accentColor: Colors.white,
                          title: "Feuille FFT de cette épreuve (PDF)",
                          subtitle: "Tableau imprimable uniquement pour $currentCatLabel",
                          badge: "CETTE ÉPREUVE",
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      ),
                                      SizedBox(width: 12),
                                      Text("Génération de la feuille PDF...", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  backgroundColor: AppColors.gold,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                            try {
                              await _exportPdf();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("✅ Feuille PDF téléchargée avec succès !"),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Erreur export PDF : $e"), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        _buildExportOptionCard(
                          icon: Icons.casino_rounded,
                          accentColor: AppColors.gold,
                          title: "Cérémonie & PV Certifié du Tirage",
                          subtitle: "Horodatage certifié et PV de tirage de cette épreuve",
                          badge: "EFFET WOW",
                          onTap: () {
                            Navigator.pop(ctx);
                            _openDrawCeremony(activeBracket);
                          },
                        ),
                        const SizedBox(height: 10),

                        _buildExportOptionCard(
                          icon: Icons.chat_bubble_outline_rounded,
                          accentColor: const Color(0xFF25D366),
                          title: "Partager uniquement $currentCatLabel sur WhatsApp",
                          subtitle: "Résultats et podiums spécifiques de cette catégorie",
                          badge: "COMMUNAUTÉ",
                          onTap: () {
                            Navigator.pop(ctx);
                            _safeShareText(
                              text: singleSummaryText,
                              subject: "Procès-Verbal FFT $currentCatLabel",
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bouton secondaire pour voir l'aperçu du texte
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showTextSummaryPreview(fullSummaryText);
                      },
                      icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 16),
                      label: const Text(
                        "Consulter l'aperçu brut du Procès-Verbal",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
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

  Widget _buildExportOptionCard({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  void _showTextSummaryPreview(String summaryText) {
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
                          _safeShareText(
                            text: summaryText,
                            subject: "Procès-Verbal FFT ${widget.tournament.name}",
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
      padding: const EdgeInsets.symmetric(horizontal: 11.4, vertical: 7.6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat['key'];
            final isMixte = cat['key'] == 'double_mixtes';
            final activeColor = isMixte ? AppColors.gold : AppColors.coral;

            return Padding(
              padding: const EdgeInsets.only(right: 7.6),
              child: InkWell(
                onTap: () {
                  if (_selectedCategory != cat['key']) {
                    setState(() {
                      _selectedCategory = cat['key'];
                      _tabController.index = 0;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(13),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 13.3, vertical: 7.6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(13),
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
                            size: 14.25,
                            color: isSelected ? activeColor : Colors.white70,
                          ),
                          const SizedBox(width: 5.7),
                          Text(
                            cat['formatCode'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              fontSize: 11.9,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 5.7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.75, vertical: 1.4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5.7),
                            ),
                            child: Text(
                              cat['badge'] as String,
                              style: TextStyle(
                                color: isSelected ? activeColor : Colors.white54,
                                fontSize: 8.55,
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
  // SYSTÈME D'ACCOMPAGNEMENT PAS-À-PAS JAT (TOUR DE CONTRÔLE OFFICIELLE FFT)
  // ==========================================

  void _openCourtSchedule([TournamentBracket? bracket]) {
    final b = bracket ?? _currentBracket;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourtScheduleScreen(
          tournament: widget.tournament,
          isAuthorized: _isJat,
          initialCategories: {_selectedCategory == 'double_messieurs' ? 'DH' : (_selectedCategory == 'double_dames' ? 'DD' : 'DX')},
          initialNumCourts: b?.numCourts ?? 4,
          bracket: b,
          onApplyCourtAssignments: (Map<String, int> matchCourts) async {
            if (b == null) return;
            final updatedMain = b.mainMatches.map((m) {
              if (matchCourts.containsKey(m.id)) {
                return m.copyWith(court: matchCourts[m.id]);
              }
              return m;
            }).toList();

            final updatedConsolation = b.consolationMatches.map((m) {
              if (matchCourts.containsKey(m.id)) {
                return m.copyWith(court: matchCourts[m.id]);
              }
              return m;
            }).toList();

            final updatedPools = b.pools.map((p) {
              final updatedPoolMatches = p.matches.map((m) {
                if (matchCourts.containsKey(m.id)) {
                  return m.copyWith(court: matchCourts[m.id]);
                }
                return m;
              }).toList();
              return p.copyWith(matches: updatedPoolMatches);
            }).toList();

            final updatedBracket = b.copyWith(
              mainMatches: updatedMain,
              consolationMatches: updatedConsolation,
              pools: updatedPools,
              updatedAt: DateTime.now(),
            );

            await _saveBracket(updatedBracket);
          },
        ),
      ),
    );
  }

  void _showLockedStepAlert(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.amberAccent, width: 1.2),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  JatWorkflowStatus _getWorkflowStatus(TournamentBracket bracket) {
    final pairCount = bracket.pairs.length;
    final step1Complete = pairCount >= 4;
    final hasMatches = bracket.mainMatches.isNotEmpty || bracket.pools.isNotEmpty;
    final step2Complete = hasMatches;

    int totalMatches = 0;
    int completedMatches = 0;
    int inProgressMatches = 0;
    bool anyCourtAssigned = false;

    if (bracket.format == 'pools_and_bracket') {
      for (final p in bracket.pools) {
        totalMatches += p.matches.length;
        for (final m in p.matches) {
          if (m.isCompleted) completedMatches++;
          if (m.isInProgress) inProgressMatches++;
          if (m.court != null && m.court! > 0) anyCourtAssigned = true;
        }
      }
      totalMatches += bracket.mainMatches.length;
      for (final m in bracket.mainMatches) {
        if (m.isCompleted) completedMatches++;
        if (m.isInProgress) inProgressMatches++;
        if (m.court != null && m.court! > 0) anyCourtAssigned = true;
      }
    } else {
      totalMatches = bracket.mainMatches.length + bracket.consolationMatches.length;
      for (final m in bracket.mainMatches) {
        if (m.isCompleted) completedMatches++;
        if (m.isInProgress) inProgressMatches++;
        if (m.court != null && m.court! > 0) anyCourtAssigned = true;
      }
      for (final m in bracket.consolationMatches) {
        if (m.isCompleted) completedMatches++;
        if (m.isInProgress) inProgressMatches++;
        if (m.court != null && m.court! > 0) anyCourtAssigned = true;
      }
    }

    final step3Complete = step2Complete && (anyCourtAssigned || totalMatches == 0);
    final step4Complete = totalMatches > 0 && completedMatches == totalMatches;
    final step5Complete = step4Complete && (bracket.status == 'finished' || bracket.status == 'homologated');

    int currentStep = 0;
    String nextTitle = '';
    String nextSubtitle = '';
    IconData nextIcon = Icons.arrow_forward_rounded;
    VoidCallback onNext = () {};

    if (!step1Complete) {
      currentStep = 0;
      nextTitle = "Inscrire les Paires";
      nextSubtitle = "Ajoutez au moins 4 paires (actuel: $pairCount) avant le tirage.";
      nextIcon = Icons.group_add_rounded;
      onNext = () => _tabController.animateTo(2);
    } else if (!step2Complete) {
      currentStep = 1;
      nextTitle = "Effectuer le Tirage au Sort";
      nextSubtitle = "$pairCount paires prêtes. Lancez la cérémonie officielle FFT.";
      nextIcon = Icons.casino_rounded;
      onNext = () => _openDrawCeremony(bracket);
    } else if (!step3Complete) {
      currentStep = 2;
      nextTitle = "Affecter Terrains & Horaires";
      nextSubtitle = "Organisez les rotations sur les ${bracket.numCourts} terrains.";
      nextIcon = Icons.calendar_month_rounded;
      onNext = () => _openCourtSchedule(bracket);
    } else if (!step4Complete) {
      currentStep = 3;
      nextTitle = "Saisir les Scores en Direct";
      nextSubtitle = "$completedMatches / $totalMatches matches terminés. Lancez les rencontres.";
      nextIcon = Icons.sports_tennis_rounded;
      onNext = () => _tabController.animateTo(0);
    } else {
      currentStep = 4;
      nextTitle = "Télécharger Dossier & Clôturer";
      nextSubtitle = "Tous les matches sont joués ! Exportez le rapport officiel FFT.";
      nextIcon = Icons.verified_rounded;
      onNext = () => _showExportShareModal();
    }

    return JatWorkflowStatus(
      currentStep: currentStep,
      step1Complete: step1Complete,
      step2Complete: step2Complete,
      step3Complete: step3Complete,
      step4Complete: step4Complete,
      step5Complete: step5Complete,
      totalMatches: totalMatches,
      completedMatches: completedMatches,
      inProgressMatches: inProgressMatches,
      pairCount: pairCount,
      nextActionTitle: nextTitle,
      nextActionSubtitle: nextSubtitle,
      nextActionIcon: nextIcon,
      onNextAction: onNext,
    );
  }

  Widget _buildJatWorkflowStepper(TournamentBracket bracket) {
    final status = _getWorkflowStatus(bracket);
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || (widget.tournament.country ?? '').toUpperCase() == 'BR';

    final steps = [
      {'title': isBr ? 'Inscrição' : '1. Paires', 'icon': Icons.groups_rounded, 'complete': status.step1Complete, 'index': 0},
      {'title': isBr ? 'Sorteio' : '2. Tirage', 'icon': Icons.casino_rounded, 'complete': status.step2Complete, 'index': 1},
      {'title': isBr ? 'Quadras' : '3. Terrains', 'icon': Icons.calendar_month_rounded, 'complete': status.step3Complete, 'index': 2},
      {'title': isBr ? 'Placares' : '4. Scores', 'icon': Icons.sports_tennis_rounded, 'complete': status.step4Complete, 'index': 3},
      {'title': isBr ? 'Encerramento' : '5. Clôture', 'icon': Icons.verified_rounded, 'complete': status.step5Complete, 'index': 4},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne des 5 étapes
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                // Connecteur entre étapes
                final stepBefore = index ~/ 2;
                final isDone = (steps[stepBefore]['complete'] as bool);
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: isDone ? Colors.greenAccent : Colors.white24,
                  ),
                );
              }

              final stepIdx = index ~/ 2;
              final s = steps[stepIdx];
              final isComplete = s['complete'] as bool;
              final isCurrent = status.currentStep == stepIdx;
              final isLocked = !isComplete && !isCurrent && stepIdx > status.currentStep;

              Color circleBg;
              Color iconColor;
              Border? circleBorder;

              if (isComplete) {
                circleBg = Colors.greenAccent.withValues(alpha: 0.2);
                iconColor = Colors.greenAccent;
                circleBorder = Border.all(color: Colors.greenAccent, width: 1.4);
              } else if (isCurrent) {
                circleBg = AppColors.gold.withValues(alpha: 0.3);
                iconColor = AppColors.gold;
                circleBorder = Border.all(color: AppColors.gold, width: 2);
              } else {
                circleBg = Colors.white.withValues(alpha: 0.05);
                iconColor = Colors.white38;
                circleBorder = Border.all(color: Colors.white12, width: 1);
              }

              return InkWell(
                onTap: () {
                  if (stepIdx == 0) {
                    _tabController.animateTo(2);
                  } else if (stepIdx == 1) {
                    if (!status.step1Complete) {
                      _showLockedStepAlert("Inscrivez au moins 4 paires avant de procéder au tirage.");
                    } else {
                      _openDrawCeremony(bracket);
                    }
                  } else if (stepIdx == 2) {
                    if (!status.step2Complete) {
                      _showLockedStepAlert("Générez le tableau ou les poules avant de configurer les terrains.");
                    } else {
                      _openCourtSchedule(bracket);
                    }
                  } else if (stepIdx == 3) {
                    if (!status.step2Complete) {
                      _showLockedStepAlert("Générez le tableau avant de renseigner les scores.");
                    } else {
                      _tabController.animateTo(0);
                    }
                  } else if (stepIdx == 4) {
                    if (!status.step4Complete) {
                      _showLockedStepAlert("Tous les matches doivent être terminés (${status.completedMatches}/${status.totalMatches}) avant de clôturer.");
                    } else {
                      _showExportShareModal();
                    }
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: circleBg,
                          border: circleBorder,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AppColors.gold.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isComplete
                              ? Icons.check_rounded
                              : (isLocked ? Icons.lock_outline_rounded : (s['icon'] as IconData)),
                          color: iconColor,
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s['title'] as String,
                        style: TextStyle(
                          color: isCurrent
                              ? AppColors.gold
                              : (isComplete ? Colors.white : Colors.white38),
                          fontSize: 9.5,
                          fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Barre récapitulative fine en bas du stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  status.step5Complete
                      ? Icons.verified_rounded
                      : (status.currentStep >= 3 ? Icons.sports_tennis_rounded : Icons.info_outline_rounded),
                  color: status.step5Complete ? Colors.greenAccent : AppColors.gold,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Étape ${status.currentStep + 1}/5 : ${status.nextActionTitle}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (status.totalMatches > 0)
                  Text(
                    "${status.completedMatches}/${status.totalMatches} matches (${((status.completedMatches / status.totalMatches) * 100).round()}%)",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    "${status.pairCount} paires",
                    style: TextStyle(
                      color: status.step1Complete ? Colors.greenAccent : Colors.amberAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJatStickyActionBar(TournamentBracket bracket) {
    final status = _getWorkflowStatus(bracket);
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || (widget.tournament.country ?? '').toUpperCase() == 'BR';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Indicateur d'étape + action recommandée
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          isBr ? "ETAPA ${status.currentStep + 1}/5" : "ÉTAPE ${status.currentStep + 1}/5",
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isBr ? "Ação recomendada" : "Action recommandée",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status.nextActionTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    status.nextActionSubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Bouton CTA principal
            InkWell(
              onTap: status.onNextAction,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.nextActionIcon, color: Colors.black, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      isBr ? "Continuar" : "Exécuter",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJatSetupWizard(TournamentBracket bracket) {
    final status = _getWorkflowStatus(bracket);
    final isPoolFormat = bracket.format == 'pools_and_bracket';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      physics: const BouncingScrollPhysics(),
      children: [
        // Carte d'entête Tour de Contrôle
        _buildGlassCard(
          radius: 16,
          padding: const EdgeInsets.all(16),
          backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.75),
          borderColor: AppColors.gold.withValues(alpha: 0.35),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.sports_score_rounded, color: AppColors.gold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TOUR DE CONTRÔLE JAT",
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Assistant de configuration pas-à-pas conforme aux règles FFT.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Carte 1 : Inscriptions & Paires
        _buildGlassCard(
          radius: 14,
          padding: const EdgeInsets.all(14),
          borderColor: status.step1Complete ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.amberAccent.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status.step1Complete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: status.step1Complete ? Colors.greenAccent : Colors.amberAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "1. Inscriptions & Vérification des Paires",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (status.step1Complete ? Colors.greenAccent : Colors.amberAccent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${status.pairCount} paires (min 4)",
                      style: TextStyle(
                        color: status.step1Complete ? Colors.greenAccent : Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Enregistrez les équipes avec leurs classements FFT officiels. Le système calcule automatiquement le poids des équipes et détermine les têtes de série (TS1, TS2, etc.).",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, height: 1.3),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.group_add_rounded, size: 16),
                  label: const Text("Gérer la Liste des Paires"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _tabController.animateTo(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Carte 2 : Cérémonie de Tirage au Sort & Arbre
        _buildGlassCard(
          radius: 14,
          padding: const EdgeInsets.all(14),
          borderColor: status.step2Complete
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : (status.step1Complete ? AppColors.gold.withValues(alpha: 0.5) : Colors.white12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status.step2Complete ? Icons.check_circle_rounded : Icons.casino_rounded,
                    color: status.step2Complete
                        ? Colors.greenAccent
                        : (status.step1Complete ? AppColors.gold : Colors.white38),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPoolFormat
                          ? "2. Tirage des Poules & Phase Finale"
                          : "2. Cérémonie du Tirage au Sort FFT",
                      style: TextStyle(
                        color: status.step1Complete ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                status.step1Complete
                    ? "Toutes les conditions sont remplies ! Lancez le tirage au sort public officiel avec répartition équitable des têtes de série et exempts (BYE)."
                    : "⚠️ Pré-requis non atteint : ajoutez au moins 4 paires avant de pouvoir effectuer le tirage au sort.",
                style: TextStyle(
                  color: status.step1Complete ? Colors.white.withValues(alpha: 0.7) : Colors.amberAccent.withValues(alpha: 0.8),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.casino_rounded, size: 16),
                  label: Text(
                    status.step1Complete ? "Lancer le Tirage au Sort FFT" : "Tirage verrouillé (min 4 paires)",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status.step1Complete ? AppColors.gold : Colors.white12,
                    foregroundColor: status.step1Complete ? Colors.black : Colors.white38,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: status.step1Complete ? () => _openDrawCeremony(bracket) : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Carte 3 : Terrains & Rotations
        _buildGlassCard(
          radius: 14,
          padding: const EdgeInsets.all(14),
          borderColor: Colors.white12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "3. Planning des Terrains & Rotations",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    "${bracket.numCourts} courts",
                    style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Attribuez les terrains et organisez la rotation des matches sur les ${bracket.numCourts} courts pour garantir le temps de repos des joueurs.",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, height: 1.3),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text("Configurer les Terrains & Horaires"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openCourtSchedule(bracket),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bouton Check-list Officielle FFT
        InkWell(
          onTap: () => _showJatChecklistModal(context, bracket),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.checklist_rounded, color: Colors.greenAccent, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ouvrir la Check-list Officielle FFT",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Audit en direct des 7 points réglementaires du Beach Tennis",
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showJatChecklistModal(BuildContext context, TournamentBracket bracket) {
    final status = _getWorkflowStatus(bracket);
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || (widget.tournament.country ?? '').toUpperCase() == 'BR';

    final checks = [
      {
        'title': '1. Inscriptions & Licences FFT vérifiées',
        'desc': '${status.pairCount} paires enregistrées avec classements officiels.',
        'pass': status.step1Complete,
        'action': 'Gérer paires',
        'onTap': () {
          Navigator.pop(context);
          _tabController.animateTo(2);
        },
      },
      {
        'title': '2. Quota réglementaire atteint',
        'desc': status.pairCount >= 4
            ? 'Format (${bracket.format == 'pools_and_bracket' ? 'Poules + Arbre' : 'Élimination directe'}) conforme au nombre d\'équipes.'
            : 'Minimum de 4 paires requis pour homologuer l\'épreuve.',
        'pass': status.step1Complete,
        'action': 'Vérifier',
        'onTap': () {
          Navigator.pop(context);
          _tabController.animateTo(2);
        },
      },
      {
        'title': '3. Têtes de série calculées au poids FFT',
        'desc': 'Somme des classements des deux partenaires respectée (TS1 en haut, TS2 en bas).',
        'pass': bracket.pairs.any((p) => p.seed != null && p.seed! > 0) || status.pairCount >= 4,
        'action': 'Voir paires',
        'onTap': () {
          Navigator.pop(context);
          _tabController.animateTo(2);
        },
      },
      {
        'title': '4. Tirage au sort officiel & Arbre généré',
        'desc': status.step2Complete
            ? 'Arbre officiel en place avec gestion automatique des exempts (BYE).'
            : 'Le tirage public n\'a pas encore été validé.',
        'pass': status.step2Complete,
        'action': 'Tirage',
        'onTap': () {
          Navigator.pop(context);
          if (status.step1Complete) {
            _openDrawCeremony(bracket);
          } else {
            _showLockedStepAlert("Inscrivez au moins 4 paires avant de procéder au tirage.");
          }
        },
      },
      {
        'title': '5. Attribution des terrains & Rotations',
        'desc': '${bracket.numCourts} terrains configurés avec respect des temps de repos.',
        'pass': status.step3Complete,
        'action': 'Terrains',
        'onTap': () {
          Navigator.pop(context);
          _openCourtSchedule(bracket);
        },
      },
      {
        'title': '6. Feuilles de matches & Validation scores',
        'desc': '${status.completedMatches} / ${status.totalMatches} matches terminés et validés.',
        'pass': status.step4Complete,
        'action': 'Scores',
        'onTap': () {
          Navigator.pop(context);
          _tabController.animateTo(0);
        },
      },
      {
        'title': '7. Rapport d\'Homologation & Dossier FFT',
        'desc': 'Génération du dossier officiel A4 paysage et clôture des résultats.',
        'pass': status.step5Complete,
        'action': 'Exporter',
        'onTap': () {
          Navigator.pop(context);
          _showExportShareModal();
        },
      },
    ];

    final passedCount = checks.where((c) => c['pass'] as bool).length;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Poignée supérieure
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // En-tête de la Check-list
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.checklist_rounded, color: Colors.greenAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBr ? "Check-list Oficial Árbitro FFT" : "Check-list Officielle JAT FFT",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            "Guide réglementaire FFT en 7 points",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (passedCount == 7 ? Colors.greenAccent : (passedCount >= 4 ? AppColors.gold : Colors.amberAccent)).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (passedCount == 7 ? Colors.greenAccent : (passedCount >= 4 ? AppColors.gold : Colors.amberAccent)).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        "$passedCount / 7 Conformes",
                        style: TextStyle(
                          color: passedCount == 7 ? Colors.greenAccent : (passedCount >= 4 ? AppColors.gold : Colors.amberAccent),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Liste des 7 points de contrôle
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: checks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final c = checks[index];
                    final pass = c['pass'] as bool;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pass ? Colors.greenAccent.withValues(alpha: 0.35) : Colors.white12,
                          width: 1.1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pass ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: pass ? Colors.greenAccent : Colors.amberAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['title'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c['desc'] as String,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 10.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.gold,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: c['onTap'] as VoidCallback,
                            child: Text(
                              c['action'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
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
  }

  // ==========================================
  // BARRE DE PROGRESSION DU TOURNOI
  // ==========================================
  Widget _buildTournamentProgressBar(TournamentBracket bracket) {
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || (widget.tournament.country ?? '').toUpperCase() == 'BR';
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
      for (final p in bracket.pools) {
        totalMatches += p.matches.length;
        completedMatches += p.matches.where((m) => m.isCompleted).length;
      }
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
            isBr
                ? "$completedMatches / $totalMatches jogos finalizados ($percent%)"
                : "$completedMatches / $totalMatches matches terminés ($percent%)",
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
    final user = context.watch<AppState>().currentUser;
    final isBr = user?.isBrazilian == true || (widget.tournament.country ?? '').toUpperCase() == 'BR';

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
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: const Icon(Icons.grid_view_rounded, size: 16),
                  text: bracket.pools.length == 1
                      ? (isBr ? "Grupo Único" : "Poule Unique")
                      : (bracket.pools.length >= 3
                          ? (isBr ? "Grupos & 5-7" : "Poules & 5-7")
                          : (isBr ? "Grupos A & B" : "Poules A & B")),
                ),
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: const Icon(Icons.emoji_events_rounded, size: 16),
                  text: bracket.pools.length == 1
                      ? (isBr ? "Pódio & Classificação" : "Podium & Classement")
                      : (isBr ? "Fase Final" : "Phase Finale"),
                ),
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: const Icon(Icons.people_alt_rounded, size: 16),
                  text: isBr ? "Duplas ($pairsCount)" : "Paires ($pairsCount)",
                ),
              ]
            : [
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: const Icon(Icons.account_tree_rounded, size: 16),
                  text: isBr ? "Chave Principal" : "Principal",
                ),
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: Icon(
                    bracket.pools.isNotEmpty
                        ? Icons.grid_view_rounded
                        : Icons.shield_outlined,
                    size: 16,
                  ),
                  text: bracket.pools.isNotEmpty
                      ? (isBr ? "Grupo 17-20" : "Poule 17-20")
                      : (isBr ? "Consolação" : "Consolante"),
                ),
                Tab(
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: const Icon(Icons.people_alt_rounded, size: 16),
                  text: isBr ? "Duplas ($pairsCount)" : "Paires ($pairsCount)",
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
      if (_isJat) {
        return _buildJatSetupWizard(bracket);
      }
      return _buildEmptyState(
        title: "Poules non générées",
        subtitle: "Le juge-arbitre n'a pas encore publié les poules de ce tableau.",
        actionText: null,
        onAction: null,
      );
    }

    return Column(
      children: [
        if (_selectedSwapSlot != null) _buildSwapActiveBanner(bracket),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
            physics: const BouncingScrollPhysics(),
            children: [
              for (final pool in bracket.pools) ...[
                _buildPoolSection(pool, bracket),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
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
          child: Row(
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
            match: match,
            slot: 1,
            bracket: bracket,
            poolId: pool.id,
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
            match: match,
            slot: 2,
            bracket: bracket,
            poolId: pool.id,
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
  // PODIUM & CLASSEMENT POULE UNIQUE
  // ==========================================
  Widget _buildSinglePoolPodiumTab(TournamentPool pool) {
    final standings = pool.calculateStandings();
    final completedMatches = pool.matches.where((m) => m.isCompleted).length;
    final totalMatches = pool.matches.length;
    final isFinished = completedMatches == totalMatches && totalMatches > 0;
    final winner = (isFinished && standings.isNotEmpty) ? standings.first.pair : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const BouncingScrollPhysics(),
      children: [
        if (winner != null) ...[
          _buildChampionBanner(winner),
          const SizedBox(height: 16),
        ],

        // Info FFT Poule Unique
        _buildGlassCard(
          radius: 14,
          padding: const EdgeInsets.all(12),
          backgroundColor: AppColors.gold.withValues(alpha: 0.1),
          borderColor: AppColors.gold.withValues(alpha: 0.35),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFinished
                      ? "🏆 Tournoi terminé ! Voici le palmarès officiel de la Poule Unique."
                      : "📊 Formule Poule Unique FFT ($totalMatches matches) : Le classement final de la poule détermine le podium et les points FFT du tournoi ($completedMatches/$totalMatches matches joués).",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Carte Classement / Podium
        _buildGlassCard(
          radius: 18,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "CLASSEMENT OFFICIEL",
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFinished
                          ? Colors.green.withValues(alpha: 0.2)
                          : AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFinished ? Colors.green : AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      isFinished ? "TERMINÉ" : "EN COURS",
                      style: TextStyle(
                        color: isFinished ? Colors.greenAccent : AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              for (int i = 0; i < standings.length; i++) ...[
                _buildPodiumStandingRow(i + 1, standings[i]),
                if (i < standings.length - 1)
                  const Divider(color: Colors.white10, height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumStandingRow(int rank, PoolStanding st) {
    String rankBadge;
    Color rankColor;
    if (rank == 1) {
      rankBadge = "🥇 1ère";
      rankColor = AppColors.gold;
    } else if (rank == 2) {
      rankBadge = "🥈 2ème";
      rankColor = Colors.grey.shade300;
    } else if (rank == 3) {
      rankBadge = "🥉 3ème";
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankBadge = "$rank e";
      rankColor = Colors.white54;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: rankColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              rankBadge,
              style: TextStyle(color: rankColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${st.pair.player1Name} / ${st.pair.player2Name}",
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Poids FFT : ${st.pair.weight} pts ${st.pair.seed != null ? '· [TS${st.pair.seed}]' : ''}",
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${st.won}V - ${st.lost}D (${st.points} pts)",
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                "Sets: ${st.diffSets > 0 ? '+${st.diffSets}' : st.diffSets} | Jeux: ${st.diffGames > 0 ? '+${st.diffGames}' : st.diffGames}",
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ONGLET PHASE FINALE CROISÉE (POULES)
  // ==========================================
  Widget _buildFinalPhaseTab(TournamentBracket bracket) {
    if (bracket.pools.length == 1 && bracket.mainMatches.isEmpty) {
      return _buildSinglePoolPodiumTab(bracket.pools.first);
    }
    if (bracket.mainMatches.isEmpty) {
      return _buildEmptyState(
        title: "Phase Finale non programmée",
        subtitle:
            "Les matches de phase finale apparaîtront dès que les poules seront configurées.",
      );
    }

    final isSemis = bracket.finalPhaseType == 'crossover_semis';
    final hasDFMatches = bracket.mainMatches.any((m) => m.matchCode == 'DF1' || m.matchCode == 'DF2');
    final finaleMatches = bracket.mainMatches.where((m) => m.matchCode == 'FINALE').toList();
    final finaleMatch = finaleMatches.isNotEmpty ? finaleMatches.first : null;
    final hasP78 = bracket.mainMatches.any((m) => m.matchCode == 'PLACE_7_8');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_selectedSwapSlot != null) ...[
          _buildSwapActiveBanner(bracket),
          const SizedBox(height: 12),
        ],
        // Carte Champion si la Grande Finale est terminée
        if (finaleMatch != null && finaleMatch.isCompleted && finaleMatch.winner != null) ...[
          _buildChampionBanner(finaleMatch.winner!),
          const SizedBox(height: 16),
        ],

        // Bandeau d'information dynamique
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
                  isSemis
                      ? "Formule Demi-Finales Croisées : 1er A vs 2e B & 1er B vs 2e A. Vainqueurs en Grande Finale, perdants en Petite Finale."
                      : "Formule Finales Directes FFT (1 jour) : 1er A vs 1er B en Finale, 2e A vs 2e B en 3/4, 3e A vs 3e B en 5/6.",
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

        // Section Demi-finales (uniquement si crossover_semis)
        if (isSemis || hasDFMatches) ...[
          _buildSectionHeader("DEMI-FINALES CROISÉES", AppColors.gold, Icons.emoji_events_rounded),
          const SizedBox(height: 8),
          ...bracket.mainMatches
              .where((m) => m.matchCode == 'DF1' || m.matchCode == 'DF2')
              .map((m) => _buildFinalPhaseMatchCard(m, bracket)),
          const SizedBox(height: 16),
        ],

        // Section Finales
        _buildSectionHeader(
          isSemis ? "GRANDE FINALE & PETITE FINALE (3/4)" : "GRANDE FINALE (PLACES 1 & 2)",
          AppColors.coral,
          Icons.military_tech_rounded,
        ),
        const SizedBox(height: 8),
        ...bracket.mainMatches
            .where((m) => m.matchCode == 'FINALE')
            .map((m) => _buildFinalPhaseMatchCard(m, bracket)),

        const SizedBox(height: 16),
        _buildSectionHeader("PETITE FINALE (PLACES 3 & 4)", AppColors.gold, Icons.workspace_premium_rounded),
        const SizedBox(height: 8),
        ...bracket.mainMatches
            .where((m) => m.matchCode == 'PLACE_3_4')
            .map((m) => _buildFinalPhaseMatchCard(m, bracket)),

        const SizedBox(height: 16),
        _buildSectionHeader("MATCH DE CLASSEMENT (PLACES 5 & 6)", Colors.white70, Icons.low_priority_rounded),
        const SizedBox(height: 8),
        ...bracket.mainMatches
            .where((m) => m.matchCode == 'PLACE_5_6')
            .map((m) => _buildFinalPhaseMatchCard(m, bracket)),

        // Match Places 7 & 8 (si poules de 4)
        if (hasP78) ...[
          const SizedBox(height: 16),
          _buildSectionHeader("MATCH DE CLASSEMENT (PLACES 7 & 8)", Colors.white60, Icons.low_priority_rounded),
          const SizedBox(height: 8),
          ...bracket.mainMatches
              .where((m) => m.matchCode == 'PLACE_7_8')
              .map((m) => _buildFinalPhaseMatchCard(m, bracket)),
        ],
      ],
    );
  }

  Widget _buildChampionBanner(TournamentPair winner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.35),
            AppColors.gold.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🏆 VAINQUEURS DU TOURNOI",
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  winner.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
      if (_isJat) {
        return _buildJatSetupWizard(bracket);
      }
      return _buildEmptyState(
        title: "Tableau principal vide",
        subtitle: "Le juge-arbitre n'a pas encore publié l'arbre de ce tournoi.",
        actionText: null,
        onAction: null,
      );
    }

    final Map<int, List<BracketMatch>> rounds = {};
    for (var m in bracket.mainMatches) {
      rounds.putIfAbsent(m.roundIndex, () => []).add(m);
    }
    final sortedRoundKeys = rounds.keys.toList()..sort();

    return Column(
      children: [
        if (_selectedSwapSlot != null) _buildSwapActiveBanner(bracket),
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
    if (bracket.pools.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        physics: const BouncingScrollPhysics(),
        children: [
          if (_selectedSwapSlot != null) ...[
            _buildSwapActiveBanner(bracket),
            const SizedBox(height: 12),
          ],
          for (final pool in bracket.pools) ...[
            _buildPoolSection(pool, bracket),
            const SizedBox(height: 20),
          ],
        ],
      );
    }

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
        if (_selectedSwapSlot != null) _buildSwapActiveBanner(bracket),
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
          if (_isJat) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "💡 Configuration JAT : Maintenez appuyé sur une paire pour la déplacer ou la permuter avec une autre dans l'arbre.",
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 4),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: AppColors.gold, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Permuter",
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          // Raccourcis & Filtres de Tours directs (Pills Tous, 1/8, Quarts, Demis, Finale)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Pill "Tous"
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedRoundFilter = null);
                      if (_isTreeMode && horizontalController.hasClients) {
                        horizontalController.animateTo(
                          0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _selectedRoundFilter == null
                            ? AppColors.gold
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedRoundFilter == null
                              ? AppColors.gold
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        "Tous",
                        style: TextStyle(
                          color: _selectedRoundFilter == null ? Colors.black : Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Pills pour chaque tour du tableau
                  ...sortedRoundKeys.asMap().entries.map((entry) {
                    final i = entry.key;
                    final roundIdx = entry.value;
                    final roundList = rounds[roundIdx];
                    if (roundList == null || roundList.isEmpty) return const SizedBox.shrink();
                    final rawRoundName = roundList.first.roundName;

                    // Abréviation claire et compacte : 1/16, 1/8, Quarts, Demis, Finale
                    String shortName = rawRoundName;
                    final rLower = rawRoundName.toLowerCase();
                    if (rLower.contains('1/16') || rLower.contains('16')) {
                      shortName = '1/16';
                    } else if (rLower.contains('1/8') || rLower.contains('8')) {
                      shortName = '1/8';
                    } else if (rLower.contains('quart') || rLower.contains('1/4') || rLower.contains('qf')) {
                      shortName = 'Quarts';
                    } else if (rLower.contains('demi') || rLower.contains('1/2') || rLower.contains('sf')) {
                      shortName = 'Demis';
                    } else if (rLower.contains('final')) {
                      shortName = 'Finale 🏆';
                    }

                    final isSelected = _selectedRoundFilter == roundIdx;

                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedRoundFilter = roundIdx);
                        if (_isTreeMode) {
                          _scrollToRound(horizontalController, i);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.gold : Colors.white12,
                          ),
                        ),
                        child: Text(
                          shortName,
                          style: TextStyle(
                            color: isSelected ? Colors.black : AppColors.gold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
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
                final matches = rounds[roundIdx] ?? [];
                if (matches.isEmpty) return const SizedBox.shrink();
                final roundName = matches.first.roundName.toUpperCase();
                final isFinalRound = sortedRoundKeys.isNotEmpty && roundIdx == sortedRoundKeys.last;

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
    final displayRoundKeys = _selectedRoundFilter != null && sortedRoundKeys.contains(_selectedRoundFilter)
        ? [_selectedRoundFilter!]
        : sortedRoundKeys;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const BouncingScrollPhysics(),
      children: [
        for (final roundIdx in displayRoundKeys) ...[
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
              (rounds[roundIdx]?.isNotEmpty == true)
                  ? rounds[roundIdx]!.first.roundName.toUpperCase()
                  : "TOUR",
              style: TextStyle(
                color: isConsolation ? AppColors.coral : AppColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (rounds[roundIdx] != null)
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
                    match: match,
                    slot: 1,
                    bracket: bracket,
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
                    match: match,
                    slot: 2,
                    bracket: bracket,
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
  // BANDEAU MODE PERMUTATION ACTIF (JAT)
  // ==========================================
  Widget _buildSwapActiveBanner(TournamentBracket bracket) {
    if (_selectedSwapSlot == null) return const SizedBox.shrink();

    final sourcePairName = _selectedSwapSlot!.pair?.displayName ?? "Slot ${_selectedSwapSlot!.slot}";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold,
            AppColors.gold.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_calls_rounded, color: Colors.black, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "MODE PERMUTATION ACTIF (JAT)",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  "Paire sélectionnée : $sourcePairName",
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  "Touchez la paire de destination pour permuter les deux places",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedSwapSlot = null);
            },
            icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16),
            label: const Text(
              "Annuler",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EXÉCUTION PERMUTATION DE DEUX PAIRES (JAT)
  // ==========================================
  Future<void> _executePairSwap({
    required BracketPairSlot source,
    required BracketPairSlot target,
    required TournamentBracket bracket,
  }) async {
    if (source.match.id == target.match.id && source.slot == target.slot) {
      setState(() => _selectedSwapSlot = null);
      return;
    }

    HapticFeedback.heavyImpact();

    // Vérifier si un des matches a déjà été joué avec un score enregistré
    final sourceHasScore = source.match.isCompleted && !source.match.isBye && (source.match.score?.isNotEmpty ?? false);
    final targetHasScore = target.match.isCompleted && !target.match.isBye && (target.match.score?.isNotEmpty ?? false);

    if (sourceHasScore || targetHasScore) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 24),
              SizedBox(width: 8),
              Text(
                "Match déjà joué",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: const Text(
            "Au moins un des matches sélectionnés possède déjà un résultat enregistré.\n\n"
            "Permuter ces paires réinitialisera le score et le statut de ce match.\n\n"
            "Voulez-vous continuer ?",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirmer la permutation", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => _selectedSwapSlot = null);
        return;
      }
    }

    try {
      final updatedBracket = BracketGeneratorService.swapPairs(
        bracket: bracket,
        matchIdA: source.match.id,
        slotA: source.slot,
        matchIdB: target.match.id,
        slotB: target.slot,
        poolIdA: source.poolId,
        poolIdB: target.poolId,
      );

      setState(() {
        _selectedSwapSlot = null;
      });

      await _saveBracket(updatedBracket);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F5132),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Paires permutées avec succès : ${source.pair?.displayName ?? 'Slot'} ⇄ ${target.pair?.displayName ?? 'Slot'}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la permutation : $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ==========================================
  // LIGNE DE PAIRE DANS LA CARTE (AVEC DRAG & DROP ET PERMUTATION JAT)
  // ==========================================
  Widget _buildPairRow(
    TournamentPair? pair,
    bool isWinner,
    bool isCompleted, {
    String? fallbackLabel,
    BracketMatch? match,
    int? slot,
    TournamentBracket? bracket,
    String? poolId,
  }) {
    Widget content;
    if (pair == null) {
      content = Row(
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
    } else if (pair.isBye) {
      content = const Row(
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
    } else {
      content = Row(
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

    if (match == null || slot == null || bracket == null || !_isJat) {
      return content;
    }

    final isSelectedSource = _selectedSwapSlot != null &&
        _selectedSwapSlot!.match.id == match.id &&
        _selectedSwapSlot!.slot == slot;

    final isTargetCandidate = _selectedSwapSlot != null && !isSelectedSource;

    final currentSlot = BracketPairSlot(
      match: match,
      slot: slot,
      pair: pair,
      poolId: poolId,
    );

    Widget rowWrapper = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: isSelectedSource || isTargetCandidate ? 6 : 4,
        vertical: isSelectedSource || isTargetCandidate ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: isSelectedSource
            ? AppColors.gold.withValues(alpha: 0.25)
            : (isTargetCandidate ? AppColors.gold.withValues(alpha: 0.08) : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: isSelectedSource
            ? Border.all(color: AppColors.gold, width: 2.0)
            : (isTargetCandidate
                ? Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.2)
                : null),
        boxShadow: isSelectedSource
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(child: content),
          if (isSelectedSource) ...[
            const SizedBox(width: 6),
            const Icon(Icons.swap_horizontal_circle, color: AppColors.gold, size: 18),
          ] else if (isTargetCandidate) ...[
            const SizedBox(width: 6),
            const Icon(Icons.touch_app_rounded, color: AppColors.gold, size: 16),
          ] else if (_selectedSwapSlot == null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: "Appui long pour permuter",
              child: Icon(
                Icons.swap_vert_rounded,
                color: Colors.white.withValues(alpha: 0.25),
                size: 14,
              ),
            ),
          ],
        ],
      ),
    );

    Widget dragTarget = DragTarget<BracketPairSlot>(
      onWillAcceptWithDetails: (details) {
        final src = details.data;
        return src.match.id != match.id || src.slot != slot;
      },
      onAcceptWithDetails: (details) {
        _executePairSwap(
          source: details.data,
          target: currentSlot,
          bracket: bracket,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        if (isHovered) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold, width: 2.2),
            ),
            child: rowWrapper,
          );
        }
        return rowWrapper;
      },
    );

    Widget draggable = LongPressDraggable<BracketPairSlot>(
      data: currentSlot,
      delay: const Duration(milliseconds: 250),
      onDragStarted: () {
        HapticFeedback.heavyImpact();
        setState(() => _selectedSwapSlot = currentSlot);
      },
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pair?.displayName ?? fallbackLabel ?? "Paire",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: dragTarget,
      ),
      child: dragTarget,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        HapticFeedback.heavyImpact();
        setState(() => _selectedSwapSlot = currentSlot);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Paire prête à permuter : ${pair?.displayName ?? 'Slot'}. Touchez une autre paire pour échanger leurs places.",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.grey.shade900,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: "Annuler",
              textColor: AppColors.gold,
              onPressed: () => setState(() => _selectedSwapSlot = null),
            ),
          ),
        );
      },
      onTap: _selectedSwapSlot != null
          ? () {
              if (isSelectedSource) {
                HapticFeedback.lightImpact();
                setState(() => _selectedSwapSlot = null);
              } else {
                _executePairSwap(
                  source: _selectedSwapSlot!,
                  target: currentSlot,
                  bracket: bracket,
                );
              }
            }
          : null,
      child: draggable,
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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCourtChip(null, "Aucun", selectedCourt == null, () {
                              setSheetState(() => selectedCourt = null);
                            }),
                            const SizedBox(width: 6),
                            for (int c = 1; c <= (bracket.numCourts > 0 ? bracket.numCourts : 4); c++) ...[
                              _buildCourtChip(c, "Court $c", selectedCourt == c, () {
                                setSheetState(() => selectedCourt = c);
                              }),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
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
          // Bouton Cérémonie Tirage au Sort (Effet WOW)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppColors.gold, Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.casino_rounded, color: Colors.black, size: 20),
              label: const Text(
                "🎲 Cérémonie de Tirage au Sort (Effet WOW & PV Certifié)",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black, letterSpacing: 0.3),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _openDrawCeremony(bracket),
            ),
          ),
          // Actions JAT
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_rounded, size: 15, color: Colors.black),
                  label: const Text(
                    "Ajouter Paire",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black),
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
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.file_upload_outlined, size: 15, color: Colors.white),
                  label: const Text(
                    "Import Excel / CSV",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showImportPairsDialog(bracket),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.gavel_rounded, size: 15, color: AppColors.gold),
                  label: const Text(
                    "Règlement",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.gold),
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
            subtitle: "Cliquez sur 'Ajouter une Paire', 'Import Excel' ou lancez la génération automatique.",
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
            if (_isJat) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.gold),
                tooltip: "Modifier la paire",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showEditPairDialog(pair, bracket),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                tooltip: "Supprimer la paire",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDeletePair(pair, bracket),
              ),
            ],
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
                Builder(
                  builder: (context) {
                    final maxCourt = bracket.numCourts > 0
                        ? (court != null && court! > bracket.numCourts ? court! : bracket.numCourts)
                        : (court != null ? (court! > 4 ? court! : 4) : 4);
                    return DropdownButton<int?>(
                      value: court,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem(value: null, child: Text("Aucun terrain")),
                        for (int c = 1; c <= maxCourt; c++)
                          DropdownMenuItem(value: c, child: Text("Terrain $c")),
                      ],
                      onChanged: (val) => setDlgState(() => court = val),
                    );
                  },
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
  void _showAddPairDialog(TournamentBracket bracket) async {
    final newPair = await AddPairAutocompleteDialog.show(
      context,
      category: _selectedCategory,
    );
    if (newPair == null) return;

    final pairs = List<TournamentPair>.from(bracket.pairs)..add(newPair);
    await _saveBracket(bracket.copyWith(pairs: pairs));
  }

  // ==========================================
  // DIALOG : MODIFICATION D'UNE PAIRE (JAT EN DIRECT)
  // ==========================================
  void _showEditPairDialog(TournamentPair pair, TournamentBracket bracket) {
    final p1Controller = TextEditingController(text: pair.player1Name);
    final p2Controller = TextEditingController(text: pair.player2Name);
    final r1Controller = TextEditingController(text: "${pair.player1Rank}");
    final r2Controller = TextEditingController(text: "${pair.player2Rank}");
    final seedController = TextEditingController(text: pair.seed != null ? "${pair.seed}" : "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: AppColors.gold, size: 20),
            SizedBox(width: 8),
            Text(
              "Modifier la paire",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: p1Controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nom & Prénom Joueur 1",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: r1Controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Classement FFT Joueur 1",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: p2Controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nom & Prénom Joueur 2",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: r2Controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Classement FFT Joueur 2",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seedController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Tête de série (optionnel, ex: 1, 2)",
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: "Laisser vide si non tête de série",
                  hintStyle: TextStyle(color: Colors.white30),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
            label: const Text("Supprimer", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeletePair(pair, bracket);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (p1Controller.text.trim().isEmpty || p2Controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              final seedVal = int.tryParse(seedController.text.trim());
              final updatedPair = pair.copyWith(
                player1Name: p1Controller.text.trim(),
                player1Rank: int.tryParse(r1Controller.text.trim()) ?? pair.player1Rank,
                player2Name: p2Controller.text.trim(),
                player2Rank: int.tryParse(r2Controller.text.trim()) ?? pair.player2Rank,
                seed: seedVal,
                clearSeed: seedVal == null,
              );

              final updated = BracketGeneratorService.updatePair(
                bracket: bracket,
                updatedPair: updatedPair,
              );
              await _saveBracket(updated);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ Paire modifiée et mise à jour dans tous les matches !"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              "Enregistrer",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CONFIRMATION DE SUPPRESSION D'UNE PAIRE
  // ==========================================
  void _confirmDeletePair(TournamentPair pair, TournamentBracket bracket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text(
              "Supprimer la paire ?",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Voulez-vous vraiment retirer la paire « ${pair.displayName} » du tableau ?\nCette action retirera la paire des poules et du tableau.",
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              final updated = BracketGeneratorService.deletePair(
                bracket: bracket,
                pairId: pair.id,
              );
              await _saveBracket(updated);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("🗑️ Paire « ${pair.displayName} » supprimée."),
                    backgroundColor: Colors.redAccent,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOG : IMPORTER DES PAIRES (EXCEL / TEN'UP / COPIER-COLLER)
  // ==========================================
  void _showImportPairsDialog(TournamentBracket bracket) {
    final textController = TextEditingController();
    bool replaceExisting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.file_upload_outlined, color: AppColors.gold, size: 22),
              SizedBox(width: 8),
              Text(
                "Importer des paires (Excel / CSV)",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Collez votre liste depuis Excel, un fichier CSV ou Ten'Up (1 paire par ligne) :",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Text(
                      "Formats acceptés :\n"
                      "• Copier-Coller Excel / Tableur (Colonnes : Nom 1, Rang 1, Nom 2, Rang 2)\n"
                      "• Fichier CSV (Séparateurs tabulations, points-virgules ';' ou virgules ',')\n"
                      "• Format texte : Nom 1 / Nom 2 ou Nom 1 (250) / Nom 2 (400)",
                      style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (!mounted) return;
                            if (data != null && data.text != null && data.text!.isNotEmpty) {
                              setDlgState(() {
                                textController.text = data.text!;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Le presse-papiers est vide.")),
                              );
                            }
                          },
                          icon: const Icon(Icons.content_paste_rounded, size: 14, color: AppColors.gold),
                          label: const Text("Coller", style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.gold),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setDlgState(() {
                              textController.text =
                                  "1\tArgaud\t274\tBernard\t434\n"
                                  "2\tNguyen\t665\tMateos\t397\n"
                                  "3\tDupont (120) / Martin (340)\n"
                                  "4\tDurand (450) - Leroy (520)\n"
                                  "5\tGomez (180) & Fernandez (210)\n"
                                  "6\tMoreau / Lambert\n"
                                  "7\tRoux (310) ; Blanc (400)\n"
                                  "8\tFontaine / Girard";
                            });
                          },
                          icon: const Icon(Icons.science_rounded, size: 14, color: Colors.white70),
                          label: const Text("Exemple Test", style: TextStyle(color: Colors.white70, fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: "Exemple :\nArgaud\t274\tBernard\t434\nNguyen\t665\tMateos\t397\nOu :\nDupont / Martin\nDurand (120) / Leroy (340)",
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Theme(
                    data: ThemeData(unselectedWidgetColor: Colors.white60),
                    child: CheckboxListTile(
                      value: replaceExisting,
                      onChanged: (val) => setDlgState(() => replaceExisting = val ?? false),
                      title: const Text(
                        "Remplacer les paires existantes",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      subtitle: const Text(
                        "Si décoché, les nouvelles paires seront ajoutées à la suite.",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.gold,
                      checkColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final text = textController.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("⚠️ Veuillez coller ou saisir une liste de paires avant d'importer."),
                      backgroundColor: Colors.orangeAccent,
                    ),
                  );
                  return;
                }

                final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
                final parsedPairs = <TournamentPair>[];

                for (final line in lines) {
                  // Nettoyer les numéros de ligne au début (ex: "1.", "1 -", "#1")
                  var cleanLine = line.replaceFirst(RegExp(r'^\#?\d+[\.\)\-\:\s]\s*'), '').trim();
                  if (cleanLine.isEmpty) cleanLine = line;

                  // 1. Format Tabulation Excel ou Colonnes CSV (; ou ,) : Joueur 1 [sep] Rang 1 [sep] Joueur 2 [sep] Rang 2
                  String? colSep;
                  if (cleanLine.contains('\t')) {
                    colSep = '\t';
                  } else if (cleanLine.contains(';') && cleanLine.split(';').length >= 4) {
                    colSep = ';';
                  } else if (cleanLine.contains(',') && cleanLine.split(',').length >= 4) {
                    colSep = ',';
                  }

                  if (colSep != null) {
                    var cols = cleanLine.split(colSep).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
                    if (cols.length >= 5 && RegExp(r'^\#?\d+\.?$').hasMatch(cols[0])) {
                      cols = cols.sublist(1);
                    }
                    if (cols.length >= 4) {
                      final p1 = cols[0];
                      final r1 = int.tryParse(cols[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 500;
                      final p2 = cols[2];
                      final r2 = int.tryParse(cols[3].replaceAll(RegExp(r'[^0-9]'), '')) ?? 500;
                      parsedPairs.add(TournamentPair(
                        id: "pair_${DateTime.now().millisecondsSinceEpoch}_${parsedPairs.length}",
                        player1Name: p1,
                        player1Rank: r1,
                        player2Name: p2,
                        player2Rank: r2,
                      ));
                      continue;
                    } else if (cols.length >= 2) {
                      parsedPairs.add(TournamentPair(
                        id: "pair_${DateTime.now().millisecondsSinceEpoch}_${parsedPairs.length}",
                        player1Name: cols[0],
                        player1Rank: 500,
                        player2Name: cols[1],
                        player2Rank: 500,
                      ));
                      continue;
                    }
                  }

                  // 2. Format avec délimiteurs : / ou ; ou & ou " et " ou | ou -
                  String? delim;
                  if (cleanLine.contains('/')) {
                    delim = '/';
                  } else if (cleanLine.contains(';')) {
                    delim = ';';
                  } else if (cleanLine.contains('&')) {
                    delim = '&';
                  } else if (cleanLine.toLowerCase().contains(' et ')) {
                    delim = RegExp(r'\s+et\s+', caseSensitive: false).pattern;
                  } else if (cleanLine.contains('|')) {
                    delim = '|';
                  } else if (cleanLine.contains(' - ')) {
                    delim = ' - ';
                  }

                  if (delim != null) {
                    final parts = cleanLine.split(RegExp(delim));
                    if (parts.length >= 2) {
                      final p1Raw = parts[0].trim();
                      final p2Raw = parts[1].trim();

                      final r1Match = RegExp(r'[\(\[\#](\d+)[\)\]]?').firstMatch(p1Raw);
                      final r2Match = RegExp(r'[\(\[\#](\d+)[\)\]]?').firstMatch(p2Raw);
                      final p1Name = p1Raw.replaceAll(RegExp(r'[\(\[\#]\d+[\)\]]?'), '').trim();
                      final p2Name = p2Raw.replaceAll(RegExp(r'[\(\[\#]\d+[\)\]]?'), '').trim();
                      final r1 = r1Match != null ? int.tryParse(r1Match.group(1)!) ?? 500 : 500;
                      final r2 = r2Match != null ? int.tryParse(r2Match.group(1)!) ?? 500 : 500;

                      if (p1Name.isNotEmpty && p2Name.isNotEmpty) {
                        parsedPairs.add(TournamentPair(
                          id: "pair_${DateTime.now().millisecondsSinceEpoch}_${parsedPairs.length}",
                          player1Name: p1Name,
                          player1Rank: r1,
                          player2Name: p2Name,
                          player2Rank: r2,
                        ));
                        continue;
                      }
                    }
                  }
                }

                if (parsedPairs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("⚠️ Aucune paire n'a pu être extraite. Vérifiez le format."),
                      backgroundColor: Colors.orangeAccent,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);

                List<TournamentPair> finalPairs;
                if (replaceExisting) {
                  finalPairs = parsedPairs;
                } else {
                  finalPairs = [...bracket.pairs, ...parsedPairs];
                }

                await _saveBracket(bracket.copyWith(pairs: finalPairs));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("✅ ${parsedPairs.length} paires importées avec succès !"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text("Importer", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOG : GENERER LES TABLEAUX / POULES
  // ==========================================
  // ==========================================
  // WIZARD INTERACTIF : CONFIGURATION DU TOURNOI PAR LE JAT
  // ==========================================
  void _showGenerateBracketDialog(TournamentBracket bracket) {
    // 1. Récupération et tri initial des paires
    final allPairs = bracket.pairs.isNotEmpty
        ? List<TournamentPair>.from(bracket.pairs)
        : (bracket.pools.isNotEmpty
            ? bracket.pools.expand((p) => p.pairs).toList()
            : <TournamentPair>[]);

    // Tri initial par têtes de série puis somme des classements
    allPairs.sort((a, b) {
      if (a.seed != null && b.seed != null) return a.seed!.compareTo(b.seed!);
      if (a.seed != null) return -1;
      if (b.seed != null) return 1;
      return a.weight.compareTo(b.weight);
    });

    String selectedFormat = _selectedCategory == 'double_mixtes'
        ? 'elimination'
        : (allPairs.length >= 3 && allPairs.length <= 6 ? 'single_pool' : 'pools_and_bracket');
    String selectedPhaseType = bracket.finalPhaseType;

    // Répartition Serpentine initiale
    List<TournamentPair> pouleA = [];
    List<TournamentPair> pouleB = [];

    void applySerpentine() {
      pouleA.clear();
      pouleB.clear();
      for (int i = 0; i < allPairs.length; i++) {
        final mod4 = i % 4;
        if (mod4 == 0 || mod4 == 3) {
          pouleA.add(allPairs[i]);
        } else {
          pouleB.add(allPairs[i]);
        }
      }
    }

    applySerpentine();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.98),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Poignée supérieure
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Titre & Sous-titre
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.settings_suggest_rounded, color: AppColors.gold, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Configuration du Tournoi (JAT)",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              "Définissez les règles et la formule avant lancement automatique",
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contenu défilable
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // 1. Choix du Format Général
                        const Text(
                          "1. FORMULE GÉNÉRALE",
                          style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            _buildWizardOptionCard(
                              title: "🏆 Poule Unique (Toutes Rondes / Round-Robin)",
                              subtitle: "Toutes les équipes dans 1 seule poule. 1er Champion 🥇, 2e Finaliste 🥈. Idéal 3 à 6 équipes (ex: DD).",
                              isSelected: selectedFormat == 'single_pool',
                              icon: Icons.view_headline_rounded,
                              onTap: () => setDlgState(() => selectedFormat = 'single_pool'),
                            ),
                            const SizedBox(height: 8),
                            _buildWizardOptionCard(
                              title: "⚡ 2 Poules (A & B) + Phase Finale",
                              subtitle: "2 Poules distinctes avec Finales directes (1er A vs 1er B) ou Demi-finales croisées.",
                              isSelected: selectedFormat == 'pools_and_bracket',
                              icon: Icons.grid_view_rounded,
                              onTap: () => setDlgState(() => selectedFormat = 'pools_and_bracket'),
                            ),
                            const SizedBox(height: 8),
                            _buildWizardOptionCard(
                              title: "🌳 Tableau Arbre (Élimination Directe FFT)",
                              subtitle: "Tableau classique 8/16 paires avec têtes de série, BYEs et consolante officielle.",
                              isSelected: selectedFormat == 'elimination',
                              icon: Icons.account_tree_rounded,
                              onTap: () => setDlgState(() => selectedFormat = 'elimination'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        if (selectedFormat == 'single_pool') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      "POULE UNIQUE (${allPairs.length} PAIRES)",
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Toutes les paires se rencontrent une fois. Le classement FFT (victoires, sets, jeux) détermine directement le podium officiel : 1er Champion 🥇, 2e Finaliste 🥈, 3e Place 🥉.",
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        if (selectedFormat == 'pools_and_bracket') ...[
                          // 2. Choix de la Phase Finale
                          const Text(
                            "2. DÉROULÉ DE LA PHASE FINALE",
                            style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 8),
                          _buildWizardOptionCard(
                            title: "⚡ Finales Directes (Recommandé FFT 1 jour)",
                            subtitle: "1er A vs 1er B en Grande Finale · 2e A vs 2e B en 3/4 · 3e A vs 3e B en 5/6 · Pas de demis.",
                            isSelected: selectedPhaseType == 'direct_finals',
                            icon: Icons.bolt_rounded,
                            onTap: () => setDlgState(() => selectedPhaseType = 'direct_finals'),
                          ),
                          const SizedBox(height: 8),
                          _buildWizardOptionCard(
                            title: "🏆 Demi-Finales Croisées (Format 2 jours / Championnat)",
                            subtitle: "1er A vs 2e B et 1er B vs 2e A en Demis · Vainqueurs en Finale · Perdants en Petite Finale.",
                            isSelected: selectedPhaseType == 'crossover_semis',
                            icon: Icons.emoji_events_rounded,
                            onTap: () => setDlgState(() => selectedPhaseType = 'crossover_semis'),
                          ),
                          const SizedBox(height: 18),

                          // 3. Répartition des Paires dans les Poules (Ajustable)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "3. RÉPARTITION DES PAIRES",
                                style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.gold),
                                label: const Text("Tirage Serpentine FFT", style: TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  setDlgState(() => applySerpentine());
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Poule A
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("POULE A", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "${pouleA.length} paires",
                                        style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (pouleA.isEmpty)
                                  const Text("Aucune paire dans la poule A", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic))
                                else
                                  for (final p in pouleA)
                                    _buildWizardPairRow(
                                      pair: p,
                                      actionLabel: "➡️ Poule B",
                                      onAction: () {
                                        setDlgState(() {
                                          pouleA.remove(p);
                                          pouleB.add(p);
                                        });
                                      },
                                    ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Poule B
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("POULE B", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.coral.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "${pouleB.length} paires",
                                        style: const TextStyle(color: AppColors.coral, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (pouleB.isEmpty)
                                  const Text("Aucune paire dans la poule B", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic))
                                else
                                  for (final p in pouleB)
                                    _buildWizardPairRow(
                                      pair: p,
                                      actionLabel: "⬅️ Poule A",
                                      onAction: () {
                                        setDlgState(() {
                                          pouleB.remove(p);
                                          pouleA.add(p);
                                        });
                                      },
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Actions : Annuler ou Valider
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Annuler", style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (selectedFormat == 'single_pool') {
                              if (allPairs.length < 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Une poule unique nécessite au moins 2 paires."), backgroundColor: Colors.orangeAccent),
                                );
                                return;
                              }
                            } else if (selectedFormat == 'pools_and_bracket' && (pouleA.length < 2 || pouleB.length < 2)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Chaque poule doit contenir au minimum 2 paires pour générer des matches."), backgroundColor: Colors.orangeAccent),
                              );
                              return;
                            } else if (selectedFormat == 'elimination' && allPairs.length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Veuillez inscrire ou importer au moins 2 paires pour générer le tableau."), backgroundColor: Colors.orangeAccent),
                              );
                              return;
                            }

                            Navigator.pop(ctx);

                            TournamentBracket generated;
                            if (selectedFormat == 'single_pool') {
                              generated = BracketGeneratorService.generatePoolsAndBracket(
                                tournamentId: widget.tournament.id,
                                category: _selectedCategory,
                                pouleAPairs: allPairs,
                                pouleBPairs: const [], // Poule Unique !
                                finalPhaseType: 'direct_finals',
                              );
                            } else if (selectedFormat == 'pools_and_bracket') {
                              generated = BracketGeneratorService.generatePoolsAndBracket(
                                tournamentId: widget.tournament.id,
                                category: _selectedCategory,
                                pouleAPairs: pouleA,
                                pouleBPairs: pouleB,
                                finalPhaseType: selectedPhaseType,
                              );
                            } else {
                              generated = BracketGeneratorService.generateBracket(
                                tournamentId: widget.tournament.id,
                                category: _selectedCategory,
                                registeredPairs: allPairs,
                              );
                            }

                            await _saveBracket(generated);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("🚀 Tournoi configuré et démarré avec succès !"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            "Démarrer le Tournoi 🚀",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWizardOptionCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.gold : Colors.white12,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : icon,
              color: isSelected ? AppColors.gold : Colors.white60,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppColors.gold : Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10.5,
                      height: 1.3,
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

  Widget _buildWizardPairRow({
    required TournamentPair pair,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          if (pair.seed != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "TS${pair.seed}",
                style: const TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pair.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Poids : ${pair.weight} (J1: #${pair.player1Rank} · J2: #${pair.player2Rank})",
                  style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
            ),
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
