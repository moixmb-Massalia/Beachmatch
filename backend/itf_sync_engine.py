import os
import sys
import json
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore

def init_firebase():
    if firebase_admin._apps:
        return firestore.client()
    env_creds = os.environ.get('FIREBASE_SERVICE_ACCOUNT')
    if env_creds:
        cred_dict = json.loads(env_creds)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        print("🔑 Firebase initialisé via GitHub Actions Secret.")
        return firestore.client()
    raise RuntimeError("❌ Impossible d'initialiser Firebase. Aucune clé trouvée.")

def run_sync():
    db = init_firebase()
    print("🚀 Démarrage de la synchronisation ITF vers Firebase...")

    tournaments = [
        {
            'id': 'itf_bt100_vitoria_2026',
            'name': 'ITF BT 100 Vitória Open',
            'city': 'Praia de Camburi, Vitória',
            'countryCode': 'BR',
            'countryName': 'Brésil',
            'countryFlag': '🇧🇷',
            'category': 'ITF BT 100 🌟',
            'prizeMoney': '10 000 $',
            'surface': 'Praia de Camburi',
            'dates': '13 au 16 Août 2026',
            'order': 1,
            'isActive': True,
        },
        {
            'id': 'itf_cote_beaute_royan_2026',
            'name': 'Open de la Côte de Beauté · ITF World Tour',
            'city': 'Saint-Georges / Royan',
            'countryCode': 'FR',
            'countryName': 'France',
            'countryFlag': '🇫🇷',
            'category': 'Grand Chelem FFT & ITF 🏆',
            'prizeMoney': '15 000 €',
            'surface': 'Grande Plage',
            'dates': '12 au 16 Août 2026',
            'order': 2,
            'isActive': True,
        },
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

    matches = [
        {
            'id': 'vit_dh_m1',
            'tournamentId': 'itf_bt100_vitoria_2026',
            'draw': 'DH',
            'day': "Aujourd'hui",
            'round': '1/2 Finale',
            'time': '11h00',
            'court': 'Court 1',
            'team1': '[3] A. Baran (BRA) / D. Jovane (BRA)',
            'team2': '[4] M. Amorim (BRA) / D. Colla (BRA)',
            'set1': '6/4', 'set2': '7/5', 'set3': None,
            'status': 'FINISHED', 'winner': 1, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'vit_dh_m2_live',
            'tournamentId': 'itf_bt100_vitoria_2026',
            'draw': 'DH',
            'day': "Aujourd'hui",
            'round': '1/2 Finale',
            'time': 'En Direct 🔴',
            'court': 'Court Central',
            'team1': '[1] N. Gianotti (FRA) / M. Spoto (ITA)',
            'team2': '[2] A. Ramos (ESP) / T. Burmakin (RUS)',
            'set1': '6/4', 'set2': '5/3', 'set3': None,
            'status': 'LIVE', 'winner': None, 'serving': 1, 'isFeatured': True,
        },
        {
            'id': 'vit_dh_final',
            'tournamentId': 'itf_bt100_vitoria_2026',
            'draw': 'DH',
            'day': "Aujourd'hui",
            'round': 'Grande Finale 🏆',
            'time': '18h30',
            'court': 'Court Central',
            'team1': '[1] Gianotti / Spoto ou Ramos / Burmakin',
            'team2': '[3] A. Baran (BRA) / D. Jovane (BRA)',
            'set1': None, 'set2': None, 'set3': None,
            'status': 'SCHEDULED', 'winner': None, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'vit_dd_sf1',
            'tournamentId': 'itf_bt100_vitoria_2026',
            'draw': 'DD',
            'day': "Aujourd'hui",
            'round': '1/2 Finale',
            'time': '10h00',
            'court': 'Court Central',
            'team1': '[1] G. Gasparri (ITA) / N. Valentini (ITA)',
            'team2': '[4] V. Cortesi (ITA) / E. Francesconi (ITA)',
            'set1': '6/2', 'set2': '6/3', 'set3': None,
            'status': 'FINISHED', 'winner': 1, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'vit_dd_final',
            'tournamentId': 'itf_bt100_vitoria_2026',
            'draw': 'DD',
            'day': "Aujourd'hui",
            'round': 'Grande Finale 🏆',
            'time': '17h00',
            'court': 'Court Central',
            'team1': '[1] G. Gasparri (ITA) / N. Valentini (ITA)',
            'team2': '[2] P. Diaz (VEN) / R. Miller (BRA)',
            'set1': None, 'set2': None, 'set3': None,
            'status': 'SCHEDULED', 'winner': None, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'royan_dh_sf1',
            'tournamentId': 'itf_cote_beaute_royan_2026',
            'draw': 'DH',
            'day': "Aujourd'hui",
            'round': '1/2 Finale',
            'time': '10h30',
            'court': 'Court Central',
            'team1': '[1] L. Godey / M. Guegano',
            'team2': '[4] A. Leroy / T. Durand',
            'set1': '6/3', 'set2': '6/2', 'set3': None,
            'status': 'FINISHED', 'winner': 1, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'royan_dh_final',
            'tournamentId': 'itf_cote_beaute_royan_2026',
            'draw': 'DH',
            'day': "Aujourd'hui",
            'round': 'Grande Finale 🏆',
            'time': '18h00',
            'court': 'Court Central',
            'team1': '[1] L. Godey / M. Guegano',
            'team2': '[2] T. Irigaray / M. Bray',
            'set1': None, 'set2': None, 'set3': None,
            'status': 'SCHEDULED', 'winner': None, 'serving': None, 'isFeatured': False,
        },
    ]

    batch = db.batch()
    for t in tournaments:
        batch.set(db.collection('pro_tournaments').document(t['id']), t)
    for m in matches:
        batch.set(db.collection('pro_matches').document(m['id']), m)
    batch.commit()

    print(f"✅ {len(tournaments)} Tournois et {len(matches)} Matchs synchronisés avec succès !")

if __name__ == '__main__':
    run_sync()
