/// Répertoire exhaustif des villes et régions où se déroulent les tournois officiels de Beach Tennis.
/// Utilisé pour la barre intelligente de suggestion et de localisation dans le profil.
class TournamentCity {
  final String name;
  final String country;
  final String flag;
  final String? region;

  const TournamentCity({
    required this.name,
    required this.country,
    required this.flag,
    this.region,
  });

  String get label => region != null ? '$flag $name ($region)' : '$flag $name';
  String get simpleLabel => '$flag $name';
}

const List<TournamentCity> kTournamentCities = [
  // --- FRANCE MÉTROPOLITAINE 🇫🇷 ---
  TournamentCity(name: 'Marseille', country: 'France', flag: '🇫🇷', region: 'PACA'),
  TournamentCity(name: 'Toulon', country: 'France', flag: '🇫🇷', region: 'PACA'),
  TournamentCity(name: 'Nice', country: 'France', flag: '🇫🇷', region: 'PACA'),
  TournamentCity(name: 'Peypin', country: 'France', flag: '🇫🇷', region: 'PACA'),
  TournamentCity(name: 'Montpellier', country: 'France', flag: '🇫🇷', region: 'Occitanie'),
  TournamentCity(name: 'Narbonne', country: 'France', flag: '🇫🇷', region: 'Occitanie'),
  TournamentCity(name: 'Palavas-les-Flots', country: 'France', flag: '🇫🇷', region: 'Occitanie'),
  TournamentCity(name: 'Toulouse', country: 'France', flag: '🇫🇷', region: 'Occitanie'),
  TournamentCity(name: 'Bordeaux', country: 'France', flag: '🇫🇷', region: 'Nouvelle-Aquitaine'),
  TournamentCity(name: 'Arcachon', country: 'France', flag: '🇫🇷', region: 'Nouvelle-Aquitaine'),
  TournamentCity(name: 'Carcans', country: 'France', flag: '🇫🇷', region: 'Nouvelle-Aquitaine'),
  TournamentCity(name: 'Saint-Georges-de-Didonne', country: 'France', flag: '🇫🇷', region: 'Nouvelle-Aquitaine'),
  TournamentCity(name: 'Royan', country: 'France', flag: '🇫🇷', region: 'Nouvelle-Aquitaine'),
  TournamentCity(name: 'La Rochelle', country: 'France', flag: '🇫🇷', region: 'Nouvelle-Aquitaine'),
  TournamentCity(name: 'Limoges', country: 'France', flag: '🇫🇷', region: 'Nouvelle-Aquitaine'),
  TournamentCity(name: 'Saint-Pardoux', country: 'France', flag: '🇫🇷', region: 'Nouvelle-Aquitaine'),
  TournamentCity(name: 'Paris', country: 'France', flag: '🇫🇷', region: 'Île-de-France'),
  TournamentCity(name: 'Champs-sur-Marne', country: 'France', flag: '🇫🇷', region: 'Île-de-France'),
  TournamentCity(name: 'Champagne-sur-Seine', country: 'France', flag: '🇫🇷', region: 'Île-de-France'),
  TournamentCity(name: 'Montmeyran', country: 'France', flag: '🇫🇷', region: 'Auvergne-Rhône-Alpes'),
  TournamentCity(name: 'Lyon', country: 'France', flag: '🇫🇷', region: 'Auvergne-Rhône-Alpes'),
  TournamentCity(name: 'Dijon', country: 'France', flag: '🇫🇷', region: 'Bourgogne-Franche-Comté'),
  TournamentCity(name: 'Auxerre', country: 'France', flag: '🇫🇷', region: 'Bourgogne-Franche-Comté'),
  TournamentCity(name: 'Joigny', country: 'France', flag: '🇫🇷', region: 'Bourgogne-Franche-Comté'),
  TournamentCity(name: 'Appoigny', country: 'France', flag: '🇫🇷', region: 'Bourgogne-Franche-Comté'),
  TournamentCity(name: 'Strasbourg', country: 'France', flag: '🇫🇷', region: 'Grand Est'),
  TournamentCity(name: 'Mulhouse', country: 'France', flag: '🇫🇷', region: 'Grand Est'),
  TournamentCity(name: 'Nantes', country: 'France', flag: '🇫🇷', region: 'Pays de la Loire'),
  TournamentCity(name: 'Pornichet', country: 'France', flag: '🇫🇷', region: 'Pays de la Loire'),
  TournamentCity(name: 'La Baule', country: 'France', flag: '🇫🇷', region: 'Pays de la Loire'),
  TournamentCity(name: 'Saint-Malo', country: 'France', flag: '🇫🇷', region: 'Bretagne'),
  TournamentCity(name: 'Cinq-Mars-la-Pile', country: 'France', flag: '🇫🇷', region: 'Centre-Val de Loire'),
  TournamentCity(name: 'Pra Loup', country: 'France', flag: '🇫🇷', region: 'Alpes'),

  // --- OUTRE-MER (DOM-TOM) 🌴 ---
  TournamentCity(name: 'Saint-Pierre', country: 'La Réunion', flag: '🇷🇪', region: 'Sud'),
  TournamentCity(name: 'Saint-Paul', country: 'La Réunion', flag: '🇷🇪', region: 'Ouest'),
  TournamentCity(name: 'Saint-Gilles-les-Bains', country: 'La Réunion', flag: '🇷🇪', region: 'Brisants'),
  TournamentCity(name: 'L\'Étang-Salé', country: 'La Réunion', flag: '🇷🇪', region: 'Sud'),
  TournamentCity(name: 'Sainte-Clotilde', country: 'La Réunion', flag: '🇷🇪', region: 'Nord'),
  TournamentCity(name: 'Baie Orientale', country: 'Saint-Martin', flag: '🌴', region: 'Caraïbes'),
  TournamentCity(name: 'Saint-Barthélemy', country: 'Saint-Barthélemy', flag: '🌴', region: 'Caraïbes'),
  TournamentCity(name: 'Schoelcher', country: 'Martinique', flag: '🌴', region: 'Caraïbes'),
  TournamentCity(name: 'Le Gosier', country: 'Guadeloupe', flag: '🌴', region: 'Caraïbes'),
  TournamentCity(name: 'Nouméa', country: 'Nouvelle-Calédonie', flag: '🇳🇨', region: 'Pacifique'),
  TournamentCity(name: 'Poindimié', country: 'Nouvelle-Calédonie', flag: '🇳🇨', region: 'Pacifique'),

  // --- ITALIE 🇮🇹 ---
  TournamentCity(name: 'Cervia', country: 'Italie', flag: '🇮🇹', region: 'Émilie-Romagne'),
  TournamentCity(name: 'Marina di Ravenna', country: 'Italie', flag: '🇮🇹', region: 'Émilie-Romagne'),
  TournamentCity(name: 'Cesenatico', country: 'Italie', flag: '🇮🇹', region: 'Émilie-Romagne'),
  TournamentCity(name: 'Cesena', country: 'Italie', flag: '🇮🇹', region: 'Émilie-Romagne'),
  TournamentCity(name: 'Terracina', country: 'Italie', flag: '🇮🇹', region: 'Latium'),
  TournamentCity(name: 'Lido di Ostia (Rome)', country: 'Italie', flag: '🇮🇹', region: 'Latium'),
  TournamentCity(name: 'Viareggio', country: 'Italie', flag: '🇮🇹', region: 'Toscane'),
  TournamentCity(name: 'Cagliari', country: 'Italie', flag: '🇮🇹', region: 'Sardaigne'),

  // --- ESPAGNE 🇪🇸 ---
  TournamentCity(name: 'Las Palmas de Gran Canaria', country: 'Espagne', flag: '🇪🇸', region: 'Canaries'),
  TournamentCity(name: 'Santa Cruz de Tenerife', country: 'Espagne', flag: '🇪🇸', region: 'Canaries'),
  TournamentCity(name: 'Alicante', country: 'Espagne', flag: '🇪🇸', region: 'Valence'),
  TournamentCity(name: 'Barcelone', country: 'Espagne', flag: '🇪🇸', region: 'Catalogne'),
  TournamentCity(name: 'Torredembarra', country: 'Espagne', flag: '🇪🇸', region: 'Catalogne'),
  TournamentCity(name: 'Gijón', country: 'Espagne', flag: '🇪🇸', region: 'Asturies'),
  TournamentCity(name: 'Collado Mediano', country: 'Espagne', flag: '🇪🇸', region: 'Madrid'),
  TournamentCity(name: 'Menorca', country: 'Espagne', flag: '🇪🇸', region: 'Baléares'),

  // --- BRÉSIL 🇧🇷 ---
  TournamentCity(name: 'São Paulo', country: 'Brésil', flag: '🇧🇷', region: 'São Paulo'),
  TournamentCity(name: 'Rio de Janeiro (Copacabana)', country: 'Brésil', flag: '🇧🇷', region: 'Rio de Janeiro'),
  TournamentCity(name: 'Fortaleza', country: 'Brésil', flag: '🇧🇷', region: 'Ceará'),
  TournamentCity(name: 'Cuiabá', country: 'Brésil', flag: '🇧🇷', region: 'Mato Grosso'),
  TournamentCity(name: 'Brasília', country: 'Brésil', flag: '🇧🇷', region: 'Distrito Federal'),
  TournamentCity(name: 'Balneário Camboriú', country: 'Brésil', flag: '🇧🇷', region: 'Santa Catarina'),
  TournamentCity(name: 'Florianópolis', country: 'Brésil', flag: '🇧🇷', region: 'Santa Catarina'),
  TournamentCity(name: 'Santos', country: 'Brésil', flag: '🇧🇷', region: 'São Paulo'),
  TournamentCity(name: 'Campinas', country: 'Brésil', flag: '🇧🇷', region: 'São Paulo'),
  TournamentCity(name: 'Ribeirão Preto', country: 'Brésil', flag: '🇧🇷', region: 'São Paulo'),
  TournamentCity(name: 'Franca', country: 'Brésil', flag: '🇧🇷', region: 'São Paulo'),
  TournamentCity(name: 'Curitiba', country: 'Brésil', flag: '🇧🇷', region: 'Paraná'),
  TournamentCity(name: 'Belo Horizonte', country: 'Brésil', flag: '🇧🇷', region: 'Minas Gerais'),
  TournamentCity(name: 'Porto Alegre', country: 'Brésil', flag: '🇧🇷', region: 'Rio Grande do Sul'),
  TournamentCity(name: 'Salvador', country: 'Brésil', flag: '🇧🇷', region: 'Bahia'),
  TournamentCity(name: 'Palmas', country: 'Brésil', flag: '🇧🇷', region: 'Tocantins'),
  TournamentCity(name: 'Vitória', country: 'Brésil', flag: '🇧🇷', region: 'Espírito Santo'),
  TournamentCity(name: 'Natal', country: 'Brésil', flag: '🇧🇷', region: 'Rio Grande do Norte'),
  TournamentCity(name: 'Goiânia', country: 'Brésil', flag: '🇧🇷', region: 'Goiás'),
  TournamentCity(name: 'Manaus', country: 'Brésil', flag: '🇧🇷', region: 'Amazonas'),
  TournamentCity(name: 'Marechal Deodoro', country: 'Brésil', flag: '🇧🇷', region: 'Alagoas'),

  // --- ARUBA & VENEZUELA 🇦🇼 🇻🇪 ---
  TournamentCity(name: 'Eagle Beach', country: 'Aruba', flag: '🇦🇼', region: 'Caraïbes'),
  TournamentCity(name: 'Bushiri Beach', country: 'Aruba', flag: '🇦🇼', region: 'Caraïbes'),
  TournamentCity(name: 'Caracas', country: 'Venezuela', flag: '🇻🇪', region: 'Capitale'),
  TournamentCity(name: 'Lechería', country: 'Venezuela', flag: '🇻🇪', region: 'Anzoátegui'),
  TournamentCity(name: 'Isla de Margarita', country: 'Venezuela', flag: '🇻🇪', region: 'Nueva Esparta'),
  TournamentCity(name: 'Barquisimeto', country: 'Venezuela', flag: '🇻🇪', region: 'Lara'),
  TournamentCity(name: 'Puerto Cabello', country: 'Venezuela', flag: '🇻🇪', region: 'Carabobo'),
];
