import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../theme/seasonal_theme.dart';

/// Écran de démarrage d'accueil ultra-premium, immersif et animé.
/// Conçu pour offrir une expérience fluide, cinématographique et luxueuse
/// rappelant l'univers chaleureux du Beach Tennis (coucher de soleil, sable, océan).
class BeachMatchPremiumSplash extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const BeachMatchPremiumSplash({
    super.key,
    this.onAnimationComplete,
  });

  @override
  State<BeachMatchPremiumSplash> createState() => _BeachMatchPremiumSplashState();
}

class _BeachMatchPremiumSplashState extends State<BeachMatchPremiumSplash>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _entranceController;
  late final AnimationController _progressController;

  late final Animation<double> _pulseAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _bgZoomAnimation;

  int _statusIndex = 0;
  final List<String> _statusMessages = const [
    "Préparation des courts de sable...",
    "Synchronisation des tournois & classements...",
    "Connexion à l'arène BeachMatch...",
  ];

  @override
  void initState() {
    super.initState();

    // 1. Contrôleur de pulsation fluide (halo néon or / cyan)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 18.0, end: 38.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // 2. Contrôleur d'entrée en scène cinématographique
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _bgZoomAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutQuad),
    );

    // 3. Barre de progression dynamique
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _entranceController.forward();
    _progressController.forward();

    // Rotation dynamique du statut de chargement
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _statusIndex = 1);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _statusIndex = 2);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌅 1. Décor d'arrière-plan immersif avec zoom cinématique subtil
          AnimatedBuilder(
            animation: _bgZoomAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _bgZoomAnimation.value,
                child: Image.asset(
                  'assets/images/beach_sunset_players_1785052273648.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF070B14)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 🌌 2. Gradient de fondu luxury avec vignette nocturne & lueur océanique
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF070B14).withValues(alpha: 0.78),
                  const Color(0xFF0B1220).withValues(alpha: 0.65),
                  const Color(0xFF060911).withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ☀️ 3. Halo lumineux radial chaud au centre (effet soleil couchant)
          Center(
            child: Container(
              width: size.width * 0.85,
              height: size.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.16),
                    const Color(0xFF00E5FF).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // 🌟 Ambiance saisonnière 100% automatique (particules festives selon la saison)
          if (SeasonalTheme.hasActiveTheme)
            const Positioned.fill(
              child: IgnorePointer(
                child: SeasonalOverlay(
                  numberOfParticles: 42,
                  maxSpeed: 1.5,
                ),
              ),
            ),

          // 💎 4. Carte centrale Glassmorphism avec animations coordonnées
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1626).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 36,
                            offset: const Offset(0, 16),
                          ),
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            blurRadius: 40,
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 🎾 Logo circulaire officiel avec halo néon pulsant & bonnet de Noël saisonnier
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _pulseAnimation.value,
                                    child: Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFB800),
                                            Color(0xFFFF5E36),
                                            Color(0xFF00D2FF),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.gold.withValues(alpha: 0.45),
                                            blurRadius: _glowAnimation.value,
                                            spreadRadius: 2,
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                            blurRadius: _glowAnimation.value * 1.3,
                                            spreadRadius: -2,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(3.0),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF0F141E),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Image.asset(
                                          'assets/images/app_icon_circular.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Image.asset(
                                            'assets/images/app_icon.jpg',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              decoration: const BoxDecoration(
                                                gradient: AppColors.brandGradient,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.sports_tennis_rounded,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (SeasonalTheme.hasActiveTheme)
                                const Positioned(
                                  top: -14,
                                  right: 0,
                                  child: SeasonalLogoBadge(
                                    size: 48,
                                  ),
                                ),
                            ],
                          ),

                              const SizedBox(height: 22),

                              // 🏷️ Titre typographique haute précision
                              Text(
                                "BEACHMATCH",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 6),

                              // 🎖️ Badge Subtitle Glassmorphism
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      SeasonalTheme.splashBadgeText,
                                      style: GoogleFonts.outfit(
                                        color: AppColors.gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 28),

                              // ⏳ Barre de chargement ultra-fine animée
                              SizedBox(
                                width: 220,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: AnimatedBuilder(
                                    animation: _progressController,
                                    builder: (context, child) {
                                      return LinearProgressIndicator(
                                        value: _progressController.value,
                                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00E5FF),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // 💬 Message d'état dynamique fluide
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.0, 0.25),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  _statusMessages[_statusIndex],
                                  key: ValueKey<int>(_statusIndex),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ℹ️ 5. Versioning discret au bas de l'écran
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Text(
                "v1.0.90 · Official Tournament Edition",
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
