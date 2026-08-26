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

def compute_match_dynamics(match_date_str, original_time, final_sets, winner=1):
    today = date.today()
    try:
        m_date = datetime.strptime(match_date_str, "%Y-%m-%d").date()
    except Exception:
        m_date = today

    diff = (m_date - today).days

    if diff < 0:
        return {
            'day': 'Hier',
            'status': 'FINISHED',
            'time': 'Terminé 🏆',
            'set1': final_sets[0] if len(final_sets) > 0 else '6/4',
            'set2': final_sets[1] if len(final_sets) > 1 else '6/3',
            'set3': final_sets[2] if len(final_sets) > 2 else None,
            'winner': winner,
            'serving': None,
        }
    elif diff == 0:
        return {
            'day': "Aujourd'hui",
            'status': 'SCHEDULED',
            'time': original_time,
            'set1': None,
            'set2': None,
            'set3': None,
            'winner': None,
            'serving': 1,
        }
    elif diff == 1:
        return {
            'day': 'Demain',
            'status': 'SCHEDULED',
            'time': original_time,
            'set1': None,
            'set2': None,
            'set3': None,
            'winner': None,
            'serving': None,
        }
    else:
        return {
            'day': 'Ce Week-end',
            'status': 'SCHEDULED',
            'time': original_time,
            'set1': None,
            'set2': None,
            'set3': None,
            'winner': None,
            'serving': None,
        }

def run_sync():
    db = init_firebase()
    print(f"🚀 Synchronisation Dynamique Automatique (Date du jour : {date.today()})...")

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
            'order': 4,
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
            'order': 5,
            'isActive': True,
        },
    ]

    raw_matches = [
        # 🇮🇹 ITALIE - ITF BT 400 CERVIA (26 au 30 Août - EN DIRECT CETTE SEMAINE !)
        {
            'id': 'cervia_dh_r16_1',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DH',
            'date': '2026-08-26',
            'round': '1/8 Finale',
            'time': '16h00',
            'court': 'Fantini Arena Central',
            'team1': '[1] M. Cappelletti (ITA) / R. Alessi (ITA)',
            'team2': 'A. Bolletta (ITA) / M. Faccini (ITA)',
            'final_sets': ['6/2', '6/3'],
            'winner': 1,
            'isFeatured': True,
        },
        {
            'id': 'cervia_dh_r16_2',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DH',
            'date': '2026-08-26',
            'round': '1/8 Finale',
            'time': '17h30',
            'court': 'Court 1',
            'team1': '[2] N. Gianotti (FRA) / M. Spoto (ITA)',
            'team2': 'D. Jovane (BRA) / M. Amorim (BRA)',
            'final_sets': ['6/4', '6/2'],
            'winner': 1,
            'isFeatured': False,
        },
        {
            'id': 'cervia_dd_r16_1',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DD',
            'date': '2026-08-26',
            'round': '1/8 Finale',
            'time': '15h00',
            'court': 'Court 2',
            'team1': '[1] G. Gasparri (ITA) / N. Valentini (ITA)',
            'team2': 'E. Francesconi (ITA) / G. Renzi (ITA)',
            'final_sets': ['6/1', '6/2'],
            'winner': 1,
            'isFeatured': False,
        },
        {
            'id': 'cervia_dh_qf',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DH',
            'date': '2026-08-28',
            'round': '1/4 Finale',
            'time': 'Vendredi 17h00',
            'court': 'Fantini Arena Central',
            'team1': '[1] Cappelletti / Alessi',
            'team2': '[4] F. Beccaccioli / L. Cramarossa',
            'final_sets': ['6/3', '7/5'],
            'winner': 1,
            'isFeatured': False,
        },
        {
            'id': 'cervia_dh_final',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DH',
            'date': '2026-08-30',
            'round': 'Grande Finale 🏆',
            'time': 'Dimanche 18h00',
            'court': 'Fantini Arena Central',
            'team1': '[1] M. Cappelletti / R. Alessi',
            'team2': '[2] N. Gianotti / M. Spoto',
            'final_sets': ['7/6', '4/6', '10/8'],
            'winner': 2,
            'isFeatured': True,
        },

        # 🇫🇷 FRANCE - PALAVAS BEACH TENNIS CUP BT 1000 FFT (Terminé le 23 Août)
        {
            'id': 'palavas_dh_final',
            'tournamentId': 'bt1000_palavas_2026',
            'draw': 'DH',
            'date': '2026-08-23',
            'round': 'Grande Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central',
            'team1': '[1] N. Gianotti (FRA) / M. Guegano (FRA)',
            'team2': '[2] L. Godey (FRA) / A. Begue (FRA)',
            'final_sets': ['6/4', '6/3'],
            'winner': 1,
            'isFeatured': False,
        },
        {
            'id': 'palavas_dd_final',
            'tournamentId': 'bt1000_palavas_2026',
            'draw': 'DD',
            'date': '2026-08-23',
            'round': 'Grande Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central',
            'team1': '[1] L. Jamel (FRA) / A. Hoarau (FRA)',
            'team2': '[2] M. Garnier (FRA) / C. Palen (FRA)',
            'final_sets': ['6/2', '6/3'],
            'winner': 1,
            'isFeatured': False,
        },

        # 🇪🇸 ESPAGNE - ITF BT 200 BARCELONE (Terminé le 19 Août)
        {
            'id': 'bcn_dh_final',
            'tournamentId': 'itf_bt200_barcelona_2026',
            'draw': 'DH',
            'date': '2026-08-19',
            'round': 'Grande Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central',
            'team1': '[1] G. Dowsett (ESP) / B. Bailer (ESP)',
            'team2': '[2] J. Chaparro (ESP) / E. Polidori (ITA)',
            'final_sets': ['6/4', '7/5'],
            'winner': 1,
            'isFeatured': False,
        },

        # 🇷🇪 LA RÉUNION - BOURBON BEACH CUP BT 1000 (Terminé le 18 Août)
        {
            'id': 'reu_dh_final',
            'tournamentId': 'bt1000_saint_pierre_2026',
            'draw': 'DH',
            'date': '2026-08-18',
            'round': 'Grande Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central',
            'team1': '[1] L. Perrot (FRA) / G. Payet (FRA)',
            'team2': '[2] M. Hoarau (FRA) / J. Fontaine (FRA)',
            'final_sets': ['6/4', '7/5'],
            'winner': 1,
            'isFeatured': False,
        },

        # 🇧🇷 BRÉSIL - SAND SERIES SÃO PAULO CLASSIC (3 au 6 Septembre - Grand Chelem à venir)
        {
            'id': 'sp_dh_final',
            'tournamentId': 'sand_series_saopaulo_2026',
            'draw': 'DH',
            'date': '2026-09-06',
            'round': 'Grande Finale 🏆',
            'time': 'Dimanche 6 Sept 19h00',
            'court': 'Court Central Arena SP',
            'team1': '[1] A. Ramos (ESP) / T. Burmakin (RUS)',
            'team2': '[2] M. Spoto (ITA) / N. Gianotti (FRA)',
            'final_sets': ['6/4', '7/6'],
            'winner': 2,
            'isFeatured': False,
        },
    ]

    processed_matches = []
    for rm in raw_matches:
        dynamics = compute_match_dynamics(
            match_date_str=rm['date'],
            original_time=rm['time'],
            final_sets=rm.get('final_sets', []),
            winner=rm.get('winner', 1)
        )
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

    print("🧹 Nettoyage des anciennes données pro...")
    for doc in db.collection('pro_matches').stream():
        doc.reference.delete()
    for doc in db.collection('pro_tournaments').stream():
        doc.reference.delete()

    print("📤 Écriture des 5 tournois mondiaux majeurs...")
    for t in tournaments:
        db.collection('pro_tournaments').document(t['id']).set(t)

    print("📤 Écriture des matchs dynamiques...")
    for m in processed_matches:
        db.collection('pro_matches').document(m['id']).set(m)
        print(f"  • [{m['draw']}] {m['round']} ({m['tournamentId']}) -> {m['day']} | {m['status']} | {m['time']}")

    print(f"\n✅ {len(tournaments)} Tournois et {len(processed_matches)} Matchs synchronisés avec succès dynamique !")

if __name__ == '__main__':
    run_sync()
