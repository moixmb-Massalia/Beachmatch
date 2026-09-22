import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/beachy_service.dart';
import '../theme/colors.dart';
import 'beachy_chat_modal.dart';

/// Bulle flottante interactive représentant Beachy (Guide Officiel & Arbitre IA)
/// - Déplaçable librement par l'utilisateur (Draggable)
/// - Magnétisme intelligent sur les bords gauche/droite
/// - Mode fantôme / translucide (30% d'opacité) au repos pour ne JAMAIS masquer de texte
/// - Bulle d'accroche explicite et rétractable pour guider l'utilisateur en cas de doute
class BeachyFloatingBubble extends StatefulWidget {
  final Function(BeachyAction action)? onActionSelected;

  const BeachyFloatingBubble({super.key, this.onActionSelected});

  @override
  State<BeachyFloatingBubble> createState() => _BeachyFloatingBubbleState();
}

class _BeachyFloatingBubbleState extends State<BeachyFloatingBubble> with TickerProviderStateMixin {
  static const double _bubbleSize = 52.0;

  // Positionnement dynamique
  double? _x;
  double? _y;
  bool _initialized = false;
  bool _isDragging = false;
  bool _isDockedLeft = false;
  bool _isMinimized = false;

  // État de repos (Ghost mode pour ne pas gêner la lecture)
  bool _isIdle = false;
  Timer? _idleTimer;

  // Bulle d'accroche d'orientation (Guide explicite)
  bool _showGuidePill = true;
  Timer? _guidePillTimer;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  late AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();

    // Animation de respiration douce
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 3.0, end: 10.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Afficher la bulle d'orientation "Un doute ? Je te guide !" au démarrage pendant 5s
    _guidePillTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showGuidePill = false);
      }
    });

    _startIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _guidePillTimer?.cancel();
    _pulseController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isDragging) {
        setState(() {
          _isIdle = true;
          _showGuidePill = false;
        });
      }
    });
  }

  void _wakeUp() {
    _startIdleTimer();
    if (_isIdle || !_showGuidePill) {
      setState(() {
        _isIdle = false;
      });
    }
  }

  void _openChat() {
    HapticFeedback.selectionClick();
    _wakeUp();
    BeachyChatModal.show(
      context,
      onActionSelected: widget.onActionSelected,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;

      // Position par défaut : au-dessus de la barre de navigation, sur le bord droit
      _x = size.width - _bubbleSize - 12.0;
      _y = size.height - padding.bottom - 165.0;
      _isDockedLeft = false;
      _initialized = true;
    }
  }

  void _onPanStart(DragStartDetails details) {
    _idleTimer?.cancel();
    _guidePillTimer?.cancel();
    setState(() {
      _isDragging = true;
      _isIdle = false;
      _showGuidePill = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_x == null || _y == null) return;
    setState(() {
      _x = _x! + details.delta.dx;
      _y = _y! + details.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails details, Size screenSize, EdgeInsets padding) {
    if (_x == null || _y == null) return;

    final double midX = screenSize.width / 2;
    final bool snapLeft = (_x! + _bubbleSize / 2) < midX;

    // Limites verticales sécurisées (ne dépasse pas sous l'AppBar ni sous la BottomNavBar)
    final double minY = padding.top + 60.0;
    final double maxY = screenSize.height - padding.bottom - 125.0;
    final double clampedY = _y!.clamp(minY, maxY);

    final double targetX = snapLeft ? 8.0 : screenSize.width - _bubbleSize - 8.0;

    final startOffset = Offset(_x!, _y!);
    final endOffset = Offset(targetX, clampedY);

    _snapAnimation = Tween<Offset>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() {
            _x = _snapAnimation!.value.dx;
            _y = _snapAnimation!.value.dy;
          });
        }
      });

    _snapController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _isDragging = false;
          _isDockedLeft = snapLeft;
        });
        _startIdleTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _x == null || _y == null) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // Calcul de la position avec léger décalage au bord en mode inactif (hug border)
    double renderX = _x!;
    if (_isIdle && !_isDragging) {
      // Se glisse élégamment contre le bord pour libérer au maximum l'espace central
      renderX = _isDockedLeft ? -12.0 : (screenSize.width - _bubbleSize + 12.0);
    }

    // Opacité : 100% lors de l'interaction, 30% en mode inactif (Ghost mode)
    final double targetOpacity = _isIdle ? 0.30 : 1.0;

    return Positioned(
      left: renderX,
      top: _y!,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: (details) => _onPanEnd(details, screenSize, padding),
        onTap: () {
          if (_isIdle) {
            _wakeUp();
          } else {
            _openChat();
          }
        },
        onDoubleTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _isMinimized = !_isMinimized;
            _wakeUp();
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: targetOpacity,
          duration: const Duration(milliseconds: 300),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Si ancré à droite : afficher la pilule d'orientation À GAUCHE de Beachy
              if (!_isDockedLeft && _showGuidePill && !_isDragging) ...[
                _buildGuidePill(),
                const SizedBox(width: 8),
              ],

              // L'avatar / bouton Beachy
              _buildBubbleAvatar(),

              // Si ancré à gauche : afficher la pilule d'orientation À DROITE de Beachy
              if (_isDockedLeft && _showGuidePill && !_isDragging) ...[
                const SizedBox(width: 8),
                _buildGuidePill(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bulle d'orientation explicite ("Un doute ? Je te guide !")
  Widget _buildGuidePill() {
    return GestureDetector(
      onTap: _openChat,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.90),
                  const Color(0xFF1E293B).withValues(alpha: 0.90),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_rounded, color: AppColors.gold, size: 14),
                SizedBox(width: 5),
                Text(
                  "Un doute ? Je te guide ! 🧭",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Avatar interactif de Beachy avec halo et statut en ligne
  Widget _buildBubbleAvatar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _isDragging ? 1.12 : (_isIdle ? 0.95 : _scaleAnimation.value);
        final glow = _isIdle ? 0.0 : _glowAnimation.value;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: _isMinimized ? 32 : _bubbleSize,
            height: _isMinimized ? 32 : _bubbleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.coral, AppColors.gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                if (!_isIdle)
                  BoxShadow(
                    color: AppColors.coral.withValues(alpha: 0.45),
                    blurRadius: glow,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            padding: const EdgeInsets.all(2.2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_bubbleSize / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF132032),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        "🏖️",
                        style: TextStyle(fontSize: _isMinimized ? 15 : 22),
                      ),
                      // Mini pastille boussole / en ligne
                      if (!_isMinimized)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF132032),
                                width: 1.8,
                              ),
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
      },
    );
  }
}
