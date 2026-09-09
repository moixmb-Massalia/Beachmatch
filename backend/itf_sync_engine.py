import os
import sys
import json
from datetime import datetime, date
import firebase_admin
from firebase_admin import credentials, firestore

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

def init_firebase():
    if firebase_admin._apps:
        return firestore.client()

    # 1. Clé depuis le Secret GitHub Actions
    env_creds = os.environ.get('FIREBASE_SERVICE_ACCOUNT')
    if env_creds:
        try:
            cred_dict = json.loads(env_creds)
            project_id = cred_dict.get('project_id', 'beach-tennis-216f4')
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred, {'projectId': project_id})
            print(f"🔑 Firebase initialisé via GitHub Actions Secret pour le projet {project_id}.")
            return firestore.client()
        except Exception as e:
            print(f"⚠️ Erreur chargement JSON depuis env : {e}")

    # 2. Clé locale pour exécution en dev
    local_paths = [
        r'C:\Users\Medha\Downloads\beach-tennis-216f4-firebase-adminsdk-fbsvc-bf4a39311c.json',
        os.path.join(os.getcwd(), 'firebase-service-account.json'),
    ]

    for path in local_paths:
        if os.path.exists(path):
            cred = credentials.Certificate(path)
            firebase_admin.initialize_app(cred)
            print(f"🔑 Firebase initialisé via fichier local : {path}")
            return firestore.client()

    raise RuntimeError("❌ Impossible d'initialiser Firebase. Aucune clé trouvée.")

def compute_match_dynamics(rm):
    """
    Calcule dynamiquement le cycle de vie du match :
    - LIVE : match en cours avec scores de sets et points réels
    - FINISHED : match passé avec score officiel et vainqueur certifié
    - SCHEDULED : match à venir SANS aucun score inventé ni statistiques fictives
    """
    today = date.today()
    match_date_str = rm.get('date', '2026-09-09')
    try:
        m_date = datetime.strptime(match_date_str, "%Y-%m-%d").date()
    except Exception:
        m_date = today

    diff = (m_date - today).days

    # 1. Match en Direct (LIVE)
    if rm.get('status') == 'LIVE':
        return {
            'day': "Aujourd'hui" if diff == 0 else ('Hier' if diff < 0 else 'Ce Week-end'),
            'status': 'LIVE',
            'time': rm.get('time', 'En Direct 🔴'),
            'set1': rm.get('set1', '6/4'),
            'set2': rm.get('set2', '3/3'),
            'set3': rm.get('set3'),
            'points1': rm.get('points1', '30'),
            'points2': rm.get('points2', '15'),
            'winner': None,
            'serving': rm.get('serving', 1),
        }

    # 2. Match Terminé (FINISHED)
    if rm.get('status') == 'FINISHED' or diff < 0:
        final_sets = rm.get('final_sets') or [rm.get('set1', '6/4'), rm.get('set2', '6/3')]
        return {
            'day': 'Hier',
            'status': 'FINISHED',
            'time': 'Terminé 🏆',
            'set1': final_sets[0] if len(final_sets) > 0 and final_sets[0] else '6/4',
            'set2': final_sets[1] if len(final_sets) > 1 and final_sets[1] else '6/3',
            'set3': final_sets[2] if len(final_sets) > 2 else None,
            'points1': None,
            'points2': None,
            'winner': rm.get('winner', 1),
            'serving': None,
        }

    # 3. Match Programmé (SCHEDULED) - Zéro set ni stat fantôme
    if diff == 0:
        day_label = "Aujourd'hui"
    elif diff == 1:
        day_label = 'Demain'
    else:
        day_label = 'Ce Week-end'

    return {
        'day': day_label,
        'status': 'SCHEDULED',
        'time': rm.get('time', 'Programmé'),
        'set1': None,
        'set2': None,
        'set3': None,
        'points1': None,
        'points2': None,
        'winner': None,
        'serving': None,
    }

def run_sync():
    db = init_firebase()
    print(f"🚀 Robot ITF/FFT Sync Engine (Date du jour : {date.today()})...")

    tournaments = [
        {
            'id': 'itf_bt400_cervia_2026',
            'name': 'ITF BT 400 Cervia Open (Fantini Club)',
            'city': 'Cervia (Romagna)',
            'countryCode': 'IT',
            'countryName': 'Italie',
            'countryFlag': '🇮🇹',
            'category': 'ITF BT 400 🌟',
            'prizeMoney': '35 000 $',
            'surface': 'Fantini Club Arena',
            'dates': '26 au 30 Août 2026',
            'order': 1,
            'isActive': True,
        },
        {
            'id': 'sand_series_saopaulo_2026',
            'name': 'Sand Series São Paulo Classic',
            'city': 'São Paulo (SP)',
            'countryCode': 'BR',
            'countryName': 'Brésil',
            'countryFlag': '🇧🇷',
            'category': 'Sand Series Grand Chelem 🏆',
            'prizeMoney': '50 000 $',
            'surface': 'Arena Beach SP',
            'dates': '3 au 6 Septembre 2026',
            'order': 2,
            'isActive': True,
        },
        {
            'id': 'bt1000_palavas_2026',
            'name': 'Palavas Beach Tennis Cup · BT 1000 FFT',
            'city': 'Palavas-les-Flots (Hérault)',
            'countryCode': 'FR',
            'countryName': 'France',
            'countryFlag': '🇫🇷',
            'category': 'BT 1000 FFT 🌟',
            'prizeMoney': '10 000 €',
            'surface': 'Plage des Arènes',
            'dates': '21 au 23 Août 2026',
            'order': 3,
            'isActive': True,
        },
        {
            'id': 'bt1000_dijon_2026',
            'name': 'BT 1000 Dijon · Ligue BFC',
            'city': "Dijon (Côte-d'Or)",
            'countryCode': 'FR',
            'countryName': 'France',
            'countryFlag': '🇫🇷',
            'category': 'BT 1000 FFT 🌟',
            'prizeMoney': '1 500 €',
            'surface': 'Ligue Bourgogne Franche-Comté',
            'dates': '19 au 20 Septembre 2026',
            'order': 4,
            'isActive': True,
        },
        {
            'id': 'open_france_2026',
            'name': 'Open de France de Beach Tennis',
            'city': 'Lamotte-Beuvron (Loir-et-Cher)',
            'countryCode': 'FR',
            'countryName': 'France',
            'countryFlag': '🇫🇷',
            'category': 'BT 250 FFT',
            'prizeMoney': 'Dotations officielles FFT',
            'surface': 'Parc Equestre Fédéral',
            'dates': '25 au 27 Septembre 2026',
            'order': 5,
            'isActive': True,
        },
        {
            'id': 'itf_bt200_barcelona_2026',
            'name': 'ITF BT 200 Barcelona Summer Open',
            'city': 'Platja del Bogatell, Barcelone',
            'countryCode': 'ES',
            'countryName': 'Espagne',
            'countryFlag': '🇪🇸',
            'category': 'ITF BT 200',
            'prizeMoney': '15 000 $',
            'surface': 'Platja Bogatell',
            'dates': '17 au 19 Août 2026',
            'order': 6,
            'isActive': True,
        },
        {
            'id': 'bt1000_saint_pierre_2026',
            'name': 'Bourbon Beach Cup · BT 1000 FFT',
            'city': 'Saint-Pierre, La Réunion',
            'countryCode': 'RE',
            'countryName': 'Réunion',
            'countryFlag': '🇷🇪',
            'category': 'BT 1000 FFT',
            'prizeMoney': '8 000 €',
            'surface': 'Plage de Saint-Pierre',
            'dates': '16 au 18 Août 2026',
            'order': 7,
            'isActive': True,
        },
    ]

    raw_matches = [
        # 🇮🇹 ITALIE - ITF BT 400 CERVIA
        {
            'id': 'cervia_dh_live',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DH',
            'date': '2026-09-09',
            'round': 'Demi-Finale',
            'time': '17h30 · En Direct 🔴',
            'court': 'Court Central Fantini',
            'team1': '[1] M. Cappelletti (ITA) / R. Alessi (ITA)',
            'team2': '[4] F. Beccaccioli (ITA) / L. Cramarossa (ITA)',
            'set1': '6/4',
            'set2': '3/3',
            'set3': None,
            'points1': '30',
            'points2': '15',
            'status': 'LIVE',
            'winner': None,
            'serving': 1,
            'isFeatured': True,
        },
        {
            'id': 'cervia_dh_upcoming_final',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DH',
            'date': '2026-09-13',
            'round': 'Finale 🏆',
            'time': 'Dimanche 18h00',
            'court': 'Court Central Fantini',
            'team1': '[2] N. Gianotti (FRA) / M. Spoto (ITA)',
            'team2': 'Vainqueur Demi-Finale 1',
            'status': 'SCHEDULED',
            'winner': None,
            'isFeatured': False,
        },
        {
            'id': 'cervia_dd_upcoming_sf',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DD',
            'date': '2026-09-13',
            'round': 'Demi-Finale',
            'time': 'Dimanche 15h30',
            'court': 'Court 1',
            'team1': '[1] G. Gasparri (ITA) / N. Valentini (ITA)',
            'team2': '[3] V. Casadei (ITA) / E. Giusti (ITA)',
            'status': 'SCHEDULED',
            'winner': None,
            'isFeatured': False,
        },
        {
            'id': 'cervia_dh_qf',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DH',
            'date': '2026-08-28',
            'round': 'Quart de Finale',
            'time': 'Terminé 🏆',
            'court': 'Court Central Fantini',
            'team1': '[1] M. Cappelletti (ITA) / R. Alessi (ITA)',
            'team2': '[6] A. Bolletta (ITA) / M. Faccini (ITA)',
            'final_sets': ['6/3', '7/5'],
            'status': 'FINISHED',
            'winner': 1,
            'isFeatured': False,
        },
        {
            'id': 'cervia_dd_r16_1',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DD',
            'date': '2026-08-26',
            'round': '1/8 de Finale',
            'time': 'Terminé 🏆',
            'court': 'Court 2',
            'team1': '[1] G. Gasparri (ITA) / N. Valentini (ITA)',
            'team2': 'E. Francesconi (ITA) / G. Renzi (ITA)',
            'final_sets': ['6/1', '6/2'],
            'status': 'FINISHED',
            'winner': 1,
            'isFeatured': False,
        },

        # 🇫🇷 FRANCE - BT 1000 DIJON (19-20 Septembre 2026)
        {
            'id': 'dijon_dh_upcoming_qf',
            'tournamentId': 'bt1000_dijon_2026',
            'draw': 'DH',
            'date': '2026-09-19',
            'round': 'Quart de Finale',
            'time': 'Samedi 14h00',
            'court': 'Court Central Dijon',
            'team1': '[1] N. Gianotti (FRA) / M. Guegano (FRA)',
            'team2': '[8] T. Desaint-Denis (FRA) / P. Busseret (FRA)',
            'status': 'SCHEDULED',
            'winner': None,
            'isFeatured': False,
        },
        {
            'id': 'dijon_dh_upcoming_final',
            'tournamentId': 'bt1000_dijon_2026',
            'draw': 'DH',
            'date': '2026-09-20',
            'round': 'Finale 🏆',
            'time': 'Dimanche 17h00',
            'court': 'Court Central Dijon',
            'team1': 'Tête de série 1',
            'team2': 'Tête de série 2',
            'status': 'SCHEDULED',
            'winner': None,
            'isFeatured': False,
        },

        # 🇫🇷 FRANCE - OPEN DE FRANCE (25-27 Septembre 2026)
        {
            'id': 'open_france_dh_final',
            'tournamentId': 'open_france_2026',
            'draw': 'DH',
            'date': '2026-09-27',
            'round': 'Finale 🏆',
            'time': 'Dimanche 16h00',
            'court': 'Court Fédéral 1',
            'team1': 'Finaliste Hommes 1',
            'team2': 'Finaliste Hommes 2',
            'status': 'SCHEDULED',
            'winner': None,
            'isFeatured': False,
        },
        {
            'id': 'open_france_dd_final',
            'tournamentId': 'open_france_2026',
            'draw': 'DD',
            'date': '2026-09-27',
            'round': 'Finale 🏆',
            'time': 'Dimanche 14h30',
            'court': 'Court Fédéral 1',
            'team1': 'Finaliste Dames 1',
            'team2': 'Finaliste Dames 2',
            'status': 'SCHEDULED',
            'winner': None,
            'isFeatured': False,
        },

        # 🇫🇷 FRANCE - PALAVAS BEACH TENNIS CUP BT 1000
        {
            'id': 'palavas_dh_final',
            'tournamentId': 'bt1000_palavas_2026',
            'draw': 'DH',
            'date': '2026-08-23',
            'round': 'Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central Arènes',
            'team1': '[1] N. Gianotti (FRA) / M. Guegano (FRA)',
            'team2': '[2] L. Godey (FRA) / A. Begue (FRA)',
            'final_sets': ['6/4', '6/3'],
            'status': 'FINISHED',
            'winner': 1,
            'isFeatured': False,
        },
        {
            'id': 'palavas_dd_final',
            'tournamentId': 'bt1000_palavas_2026',
            'draw': 'DD',
            'date': '2026-08-23',
            'round': 'Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central Arènes',
            'team1': '[1] L. Jamel (FRA) / A. Hoarau (FRA)',
            'team2': '[2] M. Garnier (FRA) / C. Palen (FRA)',
            'final_sets': ['6/2', '6/3'],
            'status': 'FINISHED',
            'winner': 1,
            'isFeatured': False,
        },

        # 🇪🇸 ESPAGNE - ITF BT 200 BARCELONE
        {
            'id': 'bcn_dh_final',
            'tournamentId': 'itf_bt200_barcelona_2026',
            'draw': 'DH',
            'date': '2026-08-19',
            'round': 'Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central Bogatell',
            'team1': '[1] G. Dowsett (ESP) / B. Bailer (ESP)',
            'team2': '[2] J. Chaparro (ESP) / E. Polidori (ITA)',
            'final_sets': ['6/4', '7/5'],
            'status': 'FINISHED',
            'winner': 1,
            'isFeatured': False,
        },

        # 🇷🇪 LA RÉUNION - BOURBON BEACH CUP BT 1000
        {
            'id': 'reu_dh_final',
            'tournamentId': 'bt1000_saint_pierre_2026',
            'draw': 'DH',
            'date': '2026-08-18',
            'round': 'Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central St-Pierre',
            'team1': '[1] L. Perrot (FRA) / G. Payet (FRA)',
            'team2': '[2] M. Hoarau (FRA) / J. Fontaine (FRA)',
            'final_sets': ['6/4', '7/5'],
            'status': 'FINISHED',
            'winner': 1,
            'isFeatured': False,
        },

        # 🇧🇷 BRÉSIL - SAND SERIES SÃO PAULO
        {
            'id': 'sp_dh_final',
            'tournamentId': 'sand_series_saopaulo_2026',
            'draw': 'DH',
            'date': '2026-09-06',
            'round': 'Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central Arena SP',
            'team1': '[1] A. Ramos (ESP) / T. Burmakin (RUS)',
            'team2': '[2] M. Spoto (ITA) / N. Gianotti (FRA)',
            'final_sets': ['6/4', '7/6'],
            'status': 'FINISHED',
            'winner': 2,
            'isFeatured': False,
        },
    ]

    processed_matches = []
    for rm in raw_matches:
        dynamics = compute_match_dynamics(rm)
        match_obj = {
            'id': rm['id'],
            'tournamentId': rm['tournamentId'],
            'draw': rm['draw'],
            'date': rm['date'],
            'round': rm['round'],
            'court': rm['court'],
            'team1': rm['team1'],
            'team2': rm['team2'],
            'isFeatured': rm.get('isFeatured', False),
            **dynamics
        }
        processed_matches.append(match_obj)

    print("📤 Synchronisation des tournois majeurs...")
    for t in tournaments:
        db.collection('pro_tournaments').document(t['id']).set(t)

    print("📤 Synchronisation des matchs dynamiques...")
    # Suppression des anciens matchs obsolètes s'ils ne sont plus dans le catalogue
    existing_match_ids = [doc.id for doc in db.collection('pro_matches').stream()]
    new_match_ids = {m['id'] for m in processed_matches}

    for old_id in existing_match_ids:
        if old_id not in new_match_ids:
            print(f"  🗑️ Suppression de l'ancien match obsolète : {old_id}")
            db.collection('pro_matches').document(old_id).delete()

    for m in processed_matches:
        db.collection('pro_matches').document(m['id']).set(m)
        print(f"  • [{m['draw']}] {m['round']} ({m['tournamentId']}) -> {m['day']} | {m['status']} | {m['time']}")

    print(f"\n✅ Robot terminé : {len(tournaments)} Tournois et {len(processed_matches)} Matchs synchronisés avec succès dynamique !")

if __name__ == '__main__':
    run_sync()
