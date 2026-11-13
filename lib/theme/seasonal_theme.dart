import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Les différentes saisons et ambiances de l'année pour BeachMatch.
enum SeasonalThemeMode {
  standard,
  christmas,  // 24 Nov - 26 Déc (Noël & Fêtes)
  newYear,    // 27 Déc - 15 Jan (Nouvel An & Meilleurs Vœux)
  carnaval,   // 10 Fév - 25 Fév (Carnaval do Brasil & Tropic Vibes)
  spring,     // 20 Mar - 20 Avr (Printemps & Retour sur le Sable)
  summer,     // 15 Juin - 31 Août (Grand Été & Summer Tour)
  halloween,  // 24 Oct - 02 Nov (Halloween sur le sable)
}

/// Gestionnaire perpétuel et 100% automatique des saisons pour BeachMatch.
/// Basé sur la date du calendrier : bascule automatiquement sans aucune mise à jour requise !
class SeasonalTheme {
  /// Détecte la saison actuelle selon le jour et le mois en cours.
  static SeasonalThemeMode get currentMode {
    final now = DateTime.now();
    final m = now.month;
    final d = now.day;

    // 1. Noël & Fêtes (24 novembre au 26 décembre)
    if ((m == 11 && d >= 24) || (m == 12 && d <= 26)) {
      return SeasonalThemeMode.christmas;
    }

    // 2. Nouvel An & Saison Nouvelle (27 décembre au 15 janvier)
    if ((m == 12 && d >= 27) || (m == 1 && d <= 15)) {
      return SeasonalThemeMode.newYear;
    }

    // 3. Carnaval do Brasil (10 février au 25 février)
    if (m == 2 && d >= 10 && d <= 25) {
      return SeasonalThemeMode.carnaval;
    }

    // 4. Printemps & Retour sur le Sable (20 mars au 20 avril)
    if ((m == 3 && d >= 20) || (m == 4 && d <= 20)) {
      return SeasonalThemeMode.spring;
    }

    // 5. Grand Été & Summer Tour (15 juin au 31 août)
    if ((m == 6 && d >= 15) || m == 7 || m == 8) {
      return SeasonalThemeMode.summer;
    }

    // 6. Halloween sur le sable (24 octobre au 2 novembre)
    if ((m == 10 && d >= 24) || (m == 11 && d <= 2)) {
      return SeasonalThemeMode.halloween;
    }

    // 7. Reste de l'année : Mode standard élégant
    return SeasonalThemeMode.standard;
  }

  /// Est-on en période de Noël ?
  static bool get isChristmasSeason => currentMode == SeasonalThemeMode.christmas;

  /// Y a-t-il une ambiance thématique active actuellement ?
  static bool get hasActiveTheme => currentMode != SeasonalThemeMode.standard;

  /// Texte festif affiché sur le badge du splash screen.
  static String get splashBadgeText {
    switch (currentMode) {
      case SeasonalThemeMode.christmas:
        return "ÉDITION NOËL & FÊTES 🎄";
      case SeasonalThemeMode.newYear:
        return "NOUVELLE ANNÉE & VŒUX ✨";
      case SeasonalThemeMode.carnaval:
        return "CARNAVAL & RHYTHM ON SAND 🎭";
      case SeasonalThemeMode.spring:
        return "RETOUR SUR LE SABLE ☀️";
      case SeasonalThemeMode.summer:
        return "SUMMER TOUR OFFICIEL 🔥";
      case SeasonalThemeMode.halloween:
        return "HALLOWEEN SUR LE SABLE 🎃";
      case SeasonalThemeMode.standard:
        return "L'ÉCOSYSTÈME BEACH TENNIS";
    }
  }
}

/// Overlay de particules d'ambiance 100% automatique et fluide (60/120 FPS).
class SeasonalOverlay extends StatefulWidget {
  final int numberOfParticles;
  final double maxSpeed;

  const SeasonalOverlay({
    super.key,
    this.numberOfParticles = 36,
    this.maxSpeed = 1.4,
  });

  @override
  State<SeasonalOverlay> createState() => _SeasonalOverlayState();
}

class _Particle {
  double x;
  double y;
  double radius;
  double speed;
  double swing;
  double swingSpeed;
  double opacity;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.swing,
    required this.swingSpeed,
    required this.opacity,
    required this.color,
  });
}

class _SeasonalOverlayState extends State<SeasonalOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();
  late final SeasonalThemeMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = SeasonalTheme.currentMode;

    if (_mode == SeasonalThemeMode.standard) {
      _controller = AnimationController(vsync: this);
      return;
    }

    final colors = _getPaletteForMode(_mode);

    for (int i = 0; i < widget.numberOfParticles; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          radius: _getRadiusForMode(_mode),
          speed: _random.nextDouble() * widget.maxSpeed + 0.5,
          swing: _random.nextDouble() * 0.02 + 0.005,
          swingSpeed: _random.nextDouble() * 2.0 + 1.0,
          opacity: _random.nextDouble() * 0.45 + 0.35,
          color: colors[_random.nextInt(colors.length)],
        ),
      );
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  List<Color> _getPaletteForMode(SeasonalThemeMode mode) {
    switch (mode) {
      case SeasonalThemeMode.christmas:
        return [Colors.white, const Color(0xFFE2E8F0)];
      case SeasonalThemeMode.newYear:
        return [const Color(0xFFFFD700), const Color(0xFFFFF4B8), Colors.white]; // Or & étincelles
      case SeasonalThemeMode.carnaval:
        return [const Color(0xFFFFD700), const Color(0xFF00E5FF), const Color(0xFFFF2E93)]; // Tropical
      case SeasonalThemeMode.spring:
        return [const Color(0xFFFFC0CB), const Color(0xFFFDE047), Colors.white]; // Pétales & soleil
      case SeasonalThemeMode.summer:
        return [const Color(0xFFFFD700), const Color(0xFFFF8C00), const Color(0xFF00E5FF)]; // Soleil & vagues
      case SeasonalThemeMode.halloween:
        return [const Color(0xFFFB923C), const Color(0xFFA855F7), const Color(0xFFF97316)]; // Braises & nuit
      case SeasonalThemeMode.standard:
        return [Colors.transparent];
    }
  }

  double _getRadiusForMode(SeasonalThemeMode mode) {
    if (mode == SeasonalThemeMode.newYear) return _random.nextDouble() * 1.8 + 0.8;
    if (mode == SeasonalThemeMode.summer) return _random.nextDouble() * 2.0 + 1.0;
    return _random.nextDouble() * 2.4 + 1.2;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == SeasonalThemeMode.standard) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SeasonalParticlePainter(particles: _particles),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SeasonalParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _SeasonalParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;

    for (final p in particles) {
      p.y += (p.speed / size.height) * 1.5;
      if (p.y > 1.0) {
        p.y = -0.05;
        p.x = math.Random().nextDouble();
      }

      final currentX = (p.x + math.sin(p.y * math.pi * 4 * p.swingSpeed) * p.swing) * size.width;
      final currentY = p.y * size.height;

      paint.color = p.color.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(currentX, currentY), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Accessoire automatique festif sur le logo selon la période de l'année.
class SeasonalLogoBadge extends StatelessWidget {
  final double size;

  const SeasonalLogoBadge({
    super.key,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final mode = SeasonalTheme.currentMode;

    switch (mode) {
      case SeasonalThemeMode.christmas:
        // Bonnet de Noël
        return Transform.rotate(
          angle: -0.22,
          child: CustomPaint(
            size: Size(size, size * 0.82),
            painter: _SantaHatPainter(),
          ),
        );

      case SeasonalThemeMode.newYear:
        // Étoile scintillante dorée de Nouvel An
        return Transform.rotate(
          angle: 0.15,
          child: CustomPaint(
            size: Size(size * 0.75, size * 0.75),
            painter: _NewYearStarPainter(),
          ),
        );

      case SeasonalThemeMode.summer:
      case SeasonalThemeMode.carnaval:
        // Lunettes de soleil de plage ultra stylées
        return CustomPaint(
          size: Size(size * 0.9, size * 0.45),
          painter: _SunglassesPainter(),
        );

      case SeasonalThemeMode.halloween:
        // Mini citrouille fun avec lunettes de soleil
        return CustomPaint(
          size: Size(size * 0.75, size * 0.75),
          painter: _HalloweenPumpkinPainter(),
        );

      case SeasonalThemeMode.spring:
      case SeasonalThemeMode.standard:
        return const SizedBox.shrink();
    }
  }
}

// -------------------------------------------------------------
// PAINTERS VECTORIELS ULTRA NETS & LÉGERS (RETINA READY)
// -------------------------------------------------------------

/// 1. Bonnet de Noël
class _SantaHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ombre douce
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final shadowPath = Path()
      ..moveTo(w * 0.1, h * 0.75)
      ..quadraticBezierTo(w * 0.5, h * 0.05, w * 0.95, h * 0.5)
      ..lineTo(w * 0.85, h * 0.85)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Cône rouge
    final redPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final hatPath = Path()
      ..moveTo(w * 0.15, h * 0.72)
      ..quadraticBezierTo(w * 0.35, h * 0.08, w * 0.85, h * 0.12)
      ..quadraticBezierTo(w * 0.98, h * 0.40, w * 0.88, h * 0.72)
      ..close();
    canvas.drawPath(hatPath, redPaint);

    // Fourrure blanche
    final brimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final brimRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.65, w * 0.84, h * 0.28),
      Radius.circular(h * 0.14),
    );
    canvas.drawRRect(brimRect, brimPaint);

    // Pompon
    canvas.drawCircle(Offset(w * 0.88, h * 0.16), w * 0.12, brimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 2. Étoile étincelante de Nouvel An
class _NewYearStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final starPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFBEB), Color(0xFFFFD700), Color(0xFFF59E0B)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Étoile 4 branches scintillante
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(center.dx, center.dy, w, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, h)
      ..quadraticBezierTo(center.dx, center.dy, 0, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, 0)
      ..close();

    canvas.drawPath(path, starPaint);
    canvas.drawCircle(center, w * 0.14, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3. Lunettes de soleil d'été et Carnaval
class _SunglassesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final framePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final lensPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0284C7), Color(0xFF0F172A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Verre gauche
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.05, h * 0.15, w * 0.40, h * 0.75),
      const Radius.circular(8),
    );
    canvas.drawRRect(leftRect, lensPaint);
    canvas.drawRRect(leftRect, framePaint);

    // Verre droit
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.55, h * 0.15, w * 0.40, h * 0.75),
      const Radius.circular(8),
    );
    canvas.drawRRect(rightRect, lensPaint);
    canvas.drawRRect(rightRect, framePaint);

    // Pont central
    canvas.drawLine(
      Offset(w * 0.45, h * 0.35),
      Offset(w * 0.55, h * 0.35),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 4. Mini citrouille d'Halloween
class _HalloweenPumpkinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final orangePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Corps de la citrouille
    canvas.drawOval(Rect.fromLTWH(w * 0.15, h * 0.20, w * 0.70, h * 0.70), orangePaint);

    // Petite tige verte
    final stemPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.44, h * 0.05, w * 0.12, h * 0.20),
        const Radius.circular(3),
      ),
      stemPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
