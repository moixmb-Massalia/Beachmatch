class BeachRacket {
  final String id;
  final String brand;
  final String model;
  final String material;
  final String balance; // 'En tête', 'Neutre', 'En manche'
  final String surface; // 'Sablée', 'Lisse'
  final int thicknessMm; // 20, 21, 22
  final int weightGrams; // 320-345
  final int powerScore; // 0 - 100
  final int controlScore; // 0 - 100
  final int spinScore; // 0 - 100
  final int maneuverabilityScore; // 0 - 100
  final String playStyle;
  final String? description;

  const BeachRacket({
    required this.id,
    required this.brand,
    required this.model,
    required this.material,
    required this.balance,
    required this.surface,
    this.thicknessMm = 20,
    this.weightGrams = 330,
    required this.powerScore,
    required this.controlScore,
    required this.spinScore,
    required this.maneuverabilityScore,
    required this.playStyle,
    this.description,
  });

  String get fullName => "$brand $model";

  double get power => (powerScore / 10.0);
  double get control => (controlScore / 10.0);
  double get spin => (spinScore / 10.0);
  double get maneuverability => (maneuverabilityScore / 10.0);

  Map<String, dynamic> toMap() {
    return {
      'racket': fullName,
      'racketBrand': brand,
      'racketModel': model,
      'racketMaterial': material,
      'racketBalance': balance,
      'racketSurface': surface,
      'racketThickness': thicknessMm,
      'racketWeight': weightGrams,
      'racketPower': powerScore,
      'racketControl': controlScore,
      'racketSpin': spinScore,
      'racketManeuverability': maneuverabilityScore,
      'racketPlayStyle': playStyle,
    };
  }
}

typedef BeachRacketPreset = BeachRacket;

class BeachRacketService {
  static List<String> get brands => famousBrands;

  static const List<String> famousBrands = [
    "Drop Shot",
    "Heroe's",
    "Nox",
    "Sexy Brand",
    "Vision",
    "Quicksand",
    "MBET / Rakkettone",
    "Turquoise",
    "Zhero",
    "Kombat",
    "Varlion",
    "Wilson",
    "Dunlop",
    "Autre",
  ];

  static const List<BeachRacket> catalog = [
    // DROP SHOT
    BeachRacket(
      id: "ds_conqueror_10",
      brand: "Drop Shot",
      model: "Conqueror 10 / 11 24K",
      material: "Carbon 24K TeXtreme",
      balance: "En tête",
      surface: "Sablée",
      thicknessMm: 22,
      weightGrams: 335,
      powerScore: 96,
      controlScore: 84,
      spinScore: 92,
      maneuverabilityScore: 82,
      playStyle: "Attaquant & Smash Puissant 💥",
      description: "La raquette mythique offensive, rigide et dévastatrice pour les finisseurs.",
    ),
    BeachRacket(
      id: "ds_canyon_pro",
      brand: "Drop Shot",
      model: "Canyon Pro 12K",
      material: "Carbon 12K + EVA Pro",
      balance: "Neutre",
      surface: "Sablée",
      thicknessMm: 22,
      weightGrams: 330,
      powerScore: 90,
      controlScore: 92,
      spinScore: 88,
      maneuverabilityScore: 88,
      playStyle: "Polyvalent & Précision Chirurgicale 🎯",
      description: "Équilibre parfait entre puissance sous contrôle et tolérance.",
    ),
    BeachRacket(
      id: "ds_explorer_pro",
      brand: "Drop Shot",
      model: "Explorer Pro 3K",
      material: "Carbon 3K + EVA Soft",
      balance: "Neutre",
      surface: "Sablée",
      thicknessMm: 20,
      weightGrams: 325,
      powerScore: 82,
      controlScore: 94,
      spinScore: 86,
      maneuverabilityScore: 94,
      playStyle: "Toucher, Contrôle & Confort 🛡️",
      description: "Grande maniabilité en 20mm avec un sweet spot élargi pour défendre et placer.",
    ),
    BeachRacket(
      id: "ds_legend_12k",
      brand: "Drop Shot",
      model: "Legend Pro 12K",
      material: "Carbon 12K",
      balance: "En tête",
      surface: "Sablée",
      thicknessMm: 22,
      weightGrams: 335,
      powerScore: 93,
      controlScore: 87,
      spinScore: 90,
      maneuverabilityScore: 85,
      playStyle: "Attaquant & Sortie de Balle Rapide ⚡",
    ),

    // HEROE'S
    BeachRacket(
      id: "heroes_predator",
      brand: "Heroe's",
      model: "Predator 12K",
      material: "Carbon 12K + Black EVA",
      balance: "Neutre / Tête",
      surface: "Sablée",
      thicknessMm: 20,
      weightGrams: 330,
      powerScore: 94,
      controlScore: 88,
      spinScore: 95,
      maneuverabilityScore: 88,
      playStyle: "Attaquant Spin & Volée Agressive 🌪️",
      description: "L'arme de prédilection sur le circuit pro pour imprimer des effets dévastateurs.",
    ),
    BeachRacket(
      id: "heroes_revenge",
      brand: "Heroe's",
      model: "Revenge 15K",
      material: "Carbon 15K",
      balance: "Neutre",
      surface: "Sablée",
      thicknessMm: 20,
      weightGrams: 330,
      powerScore: 91,
      controlScore: 91,
      spinScore: 90,
      maneuverabilityScore: 90,
      playStyle: "Polyvalent Tout-Terrain 🎯",
    ),
    BeachRacket(
      id: "heroes_h_kevlar",
      brand: "Heroe's",
      model: "H-Kevlar Pro",
      material: "Kevlar Dual + Carbon",
      balance: "En manche",
      surface: "Sablée",
      thicknessMm: 20,
      weightGrams: 325,
      powerScore: 83,
      controlScore: 97,
      spinScore: 91,
      maneuverabilityScore: 96,
      playStyle: "Maître du Toucher & Amorties 🪶",
      description: "Absorption des chocs remarquable et feeling feutré pour les lobs et amorties.",
    ),
    BeachRacket(
      id: "heroes_ghost",
      brand: "Heroe's",
      model: "Ghost Carbon",
      material: "Carbon 3K",
      balance: "Neutre",
      surface: "Sablée",
      thicknessMm: 20,
      weightGrams: 325,
      powerScore: 86,
      controlScore: 92,
      spinScore: 89,
      maneuverabilityScore: 92,
      playStyle: "Vitesse de Bras & Réflexes ⚡",
    ),

    // NOX
    BeachRacket(
      id: "nox_ar10_tempo",
      brand: "Nox",
      model: "AR10 Tempo (Antomi Ramos Signature)",
      material: "Carbon 12K + HR3 Soft Core",
      balance: "En tête",
      surface: "Sablée Rough Surface",
      thicknessMm: 20,
      weightGrams: 335,
      powerScore: 97,
      controlScore: 89,
      spinScore: 96,
      maneuverabilityScore: 86,
      playStyle: "Pro Tour & Puissance Maximale ⚡",
      description: "Créée avec le numéro 1 mondial Antomi Ramos pour dominer le filet et smasher.",
    ),
    BeachRacket(
      id: "nox_ml10_sand",
      brand: "Nox",
      model: "ML10 Pro Cup Beach",
      material: "Silver Carbon 3K",
      balance: "Neutre",
      surface: "Sablée",
      thicknessMm: 22,
      weightGrams: 330,
      powerScore: 89,
      controlScore: 93,
      spinScore: 88,
      maneuverabilityScore: 90,
      playStyle: "Régularité & Maîtrise du Filet 🎯",
      description: "Le toucher légendaire Nox adapté à la plage pour une précision absolue.",
    ),
    BeachRacket(
      id: "nox_titanium",
      brand: "Nox",
      model: "Titanium Sand Pro",
      material: "Titanium Carbon 18K",
      balance: "En tête",
      surface: "Sablée",
      thicknessMm: 20,
      weightGrams: 335,
      powerScore: 95,
      controlScore: 86,
      spinScore: 92,
      maneuverabilityScore: 84,
      playStyle: "Attaquant Détonant 💣",
    ),

    // SEXY BRAND
    BeachRacket(
      id: "sexy_woody",
      brand: "Sexy Brand",
      model: "Woody 3K MegaGrit",
      material: "Carbon 3K + Retro Wood",
      balance: "Neutre",
      surface: "Sablée MegaGrit",
      thicknessMm: 20,
      weightGrams: 330,
      powerScore: 87,
      controlScore: 95,
      spinScore: 98,
      maneuverabilityScore: 90,
      playStyle: "Toucher & Spin Extrême 🌀",
      description: "La surface MegaGrit mondialement réputée pour faire tourner la balle au service.",
    ),
    BeachRacket(
      id: "sexy_carbon_retro",
      brand: "Sexy Brand",
      model: "Carbon Retro 12K",
      material: "Carbon 12K",
      balance: "Neutre / Tête",
      surface: "Sablée MegaGrit",
      thicknessMm: 20,
      weightGrams: 335,
      powerScore: 93,
      controlScore: 89,
      spinScore: 97,
      maneuverabilityScore: 87,
      playStyle: "Effets Dévastateurs & Vitesse 🌪️",
    ),

    // VISION
    BeachRacket(
      id: "vision_super_carbon",
      brand: "Vision",
      model: "Super Carbon 12K",
      material: "Carbon 12K",
      balance: "Neutre",
      surface: "Sablée",
      thicknessMm: 20,
      weightGrams: 330,
      powerScore: 91,
      controlScore: 91,
      spinScore: 90,
      maneuverabilityScore: 90,
      playStyle: "Polyvalent d'Élite 🎯",
    ),
    BeachRacket(
      id: "vision_power_18k",
      brand: "Vision",
      model: "Power Carbon 18K",
      material: "Carbon 18K Extra Rigid",
      balance: "En tête",
      surface: "Sablée",
      thicknessMm: 22,
      weightGrams: 340,
      powerScore: 98,
      controlScore: 80,
      spinScore: 91,
      maneuverabilityScore: 80,
      playStyle: "Canon de Frappe Ultra Lourd 💥",
    ),

    // QUICKSAND
    BeachRacket(
      id: "quicksand_no_look",
      brand: "Quicksand",
      model: "No Look Classic 12K",
      material: "Carbon 12K",
      balance: "En tête",
      surface: "Sablée Futura",
      thicknessMm: 22,
      weightGrams: 335,
      powerScore: 95,
      controlScore: 86,
      spinScore: 90,
      maneuverabilityScore: 85,
      playStyle: "Smash & Frappes Lourdes 💥",
      description: "Puissance de smash colossale avec une absorption anti-vibrations brevetée.",
    ),
    BeachRacket(
      id: "quicksand_spyn",
      brand: "Quicksand",
      model: "Spyn Carbon 3K",
      material: "Carbon 3K",
      balance: "Neutre",
      surface: "Sablée Rough",
      thicknessMm: 20,
      weightGrams: 325,
      powerScore: 85,
      controlScore: 94,
      spinScore: 96,
      maneuverabilityScore: 92,
      playStyle: "Spin & Précision Chirurgicale 🌀",
    ),

    // TURQUOISE
    BeachRacket(
      id: "turquoise_black_death",
      brand: "Turquoise",
      model: "Black Death 24K",
      material: "Carbon 24K Triaxial",
      balance: "En tête",
      surface: "Sablée",
      thicknessMm: 22,
      weightGrams: 340,
      powerScore: 98,
      controlScore: 82,
      spinScore: 92,
      maneuverabilityScore: 81,
      playStyle: "Attaque Pure & Revers Foudroyant ⚡",
    ),
    BeachRacket(
      id: "turquoise_wave",
      brand: "Turquoise",
      model: "Wave Carbon 12K",
      material: "Carbon 12K",
      balance: "Neutre",
      surface: "Sablée",
      thicknessMm: 20,
      weightGrams: 330,
      powerScore: 90,
      controlScore: 92,
      spinScore: 90,
      maneuverabilityScore: 90,
      playStyle: "Polyvalent & Sensations Pures 🌊",
    ),

    // MBET / RAKKETTONE
    BeachRacket(
      id: "mbet_davi",
      brand: "MBET / Rakkettone",
      model: "Davi Pro 15K",
      material: "Carbon 15K",
      balance: "Neutre",
      surface: "Sablée",
      thicknessMm: 20,
      weightGrams: 330,
      powerScore: 92,
      controlScore: 90,
      spinScore: 91,
      maneuverabilityScore: 89,
      playStyle: "Rythme & Contre-Attaque ⚡",
    ),
  ];

  static const List<String> materials = [
    'Carbon 24K TeXtreme',
    'Carbon 18K',
    'Carbon 15K',
    'Carbon 12K',
    'Carbon 3K',
    'Kevlar Dual',
    'Fibre de verre',
  ];

  static const List<String> balances = [
    'En tête',
    'Neutre',
    'En manche',
  ];

  static const List<String> surfaces = [
    'Sablée',
    'Lisse',
  ];

  /// Recherche intelligente par texte libre et filtre de marque
  static List<BeachRacket> search(String query, {String? brand}) {
    var results = catalog;
    if (brand != null && brand.isNotEmpty && brand != 'Toutes') {
      results = results.where((r) => r.brand.toLowerCase() == brand.toLowerCase()).toList();
    }
    if (query.trim().isEmpty) return results;
    final q = query.toLowerCase().trim();
    return results.where((r) {
      return r.brand.toLowerCase().contains(q) ||
          r.model.toLowerCase().contains(q) ||
          r.material.toLowerCase().contains(q) ||
          r.playStyle.toLowerCase().contains(q);
    }).toList();
  }

  static Map<String, double> calculateSpecs({
    required String material,
    required String balance,
    required String surface,
    required int weightGrams,
  }) {
    final custom = detectOrBuildCustom(
      brand: 'Custom',
      model: 'Custom',
      material: material,
      balance: balance,
      surface: surface,
      weightGrams: weightGrams,
    );
    return {
      'power': custom.power,
      'control': custom.control,
      'spin': custom.spin,
      'maneuverability': custom.maneuverability,
    };
  }

  static String deducePlayStyle({
    required double power,
    required double control,
    required String balance,
  }) {
    return _computePlayStyle(
      power: (power * 10).round(),
      control: (control * 10).round(),
      spin: 85,
      balance: balance,
    );
  }

  /// Détecte intelligemment les caractéristiques d'une raquette saisie librement
  static BeachRacket detectOrBuildCustom({
    required String brand,
    required String model,
    String? material,
    String? balance,
    String? surface,
    int? thicknessMm,
    int? weightGrams,
  }) {
    // 1. Chercher d'abord une correspondance exacte ou approchée dans le catalogue officiel
    final q = "$brand $model".toLowerCase();
    for (final r in catalog) {
      if (q.contains(r.model.toLowerCase()) || r.fullName.toLowerCase() == q) {
        return r;
      }
    }

    // 2. Déduction intelligente basée sur les mots-clés
    final mat = material ?? _deduceMaterial(q);
    final bal = balance ?? _deduceBalance(q);
    final surf = surface ?? (q.contains('lisse') ? 'Lisse' : 'Sablée');
    final thick = thicknessMm ?? (q.contains('22') ? 22 : 20);
    final weight = weightGrams ?? (bal == 'En tête' ? 335 : 330);

    // Calcul dynamique des scores
    int power = 85;
    int control = 85;
    int spin = 85;
    int maneuverability = 85;

    if (mat.contains('24K') || mat.contains('18K')) {
      power += 10;
      control -= 4;
    } else if (mat.contains('12K') || mat.contains('15K')) {
      power += 6;
      control += 3;
    } else if (mat.contains('3K')) {
      power -= 2;
      control += 7;
    } else if (mat.contains('Kevlar')) {
      control += 10;
      maneuverability += 5;
    } else if (mat.contains('Fibre')) {
      control += 8;
      power -= 6;
    }

    if (bal == 'En tête') {
      power += 6;
      maneuverability -= 6;
    } else if (bal == 'En manche') {
      maneuverability += 8;
      control += 5;
      power -= 6;
    }

    if (surf == 'Sablée') {
      spin += 8;
    }

    final playStyle = _computePlayStyle(power: power, control: control, spin: spin, balance: bal);

    return BeachRacket(
      id: "custom_${DateTime.now().millisecondsSinceEpoch}",
      brand: brand.trim().isNotEmpty ? brand.trim() : "Custom",
      model: model.trim().isNotEmpty ? model.trim() : "Beach Tennis Pro",
      material: mat,
      balance: bal,
      surface: surf,
      thicknessMm: thick,
      weightGrams: weight,
      powerScore: power.clamp(60, 99),
      controlScore: control.clamp(60, 99),
      spinScore: spin.clamp(60, 99),
      maneuverabilityScore: maneuverability.clamp(60, 99),
      playStyle: playStyle,
    );
  }

  static String _deduceMaterial(String text) {
    if (text.contains('24k')) return 'Carbon 24K';
    if (text.contains('18k')) return 'Carbon 18K';
    if (text.contains('15k')) return 'Carbon 15K';
    if (text.contains('12k')) return 'Carbon 12K';
    if (text.contains('3k')) return 'Carbon 3K';
    if (text.contains('kevlar')) return 'Kevlar Dual';
    if (text.contains('fibre') || text.contains('fiber')) return 'Fibre de verre';
    return 'Carbon 12K';
  }

  static String _deduceBalance(String text) {
    if (text.contains('tete') || text.contains('tête') || text.contains('head') || text.contains('smash')) {
      return 'En tête';
    }
    if (text.contains('manche') || text.contains('control') || text.contains('contrôle')) {
      return 'En manche';
    }
    return 'Neutre';
  }

  static String _computePlayStyle({
    required int power,
    required int control,
    required int spin,
    required String balance,
  }) {
    if (power >= 93 && balance == 'En tête') {
      return "Attaquant Pur & Smash Foudroyant 💥";
    }
    if (spin >= 94) {
      return "Maître des Effets & Lift Tranchant 🌪️";
    }
    if (control >= 92) {
      return "Contrôleur Tactique & Placement Chirurgical 🎯";
    }
    if (power >= 90) {
      return "Attaquant Rapide & Volée Agressive ⚡";
    }
    return "Polyvalent Équilibré Tout-Terrain 🛡️";
  }
}
