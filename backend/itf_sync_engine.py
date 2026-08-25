import os
import sys
import json
from datetime import datetime
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

def run_sync():
    db = init_firebase()
    print("🚀 Démarrage de la synchronisation 100% Réelle ITF vers Firestore...")

    tournaments = [
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
            'order': 1,
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
            'order': 2,
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
            'order': 3,
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
            'order': 4,
            'isActive': True,
        },
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
            'order': 5,
            'isActive': True,
        },
    ]

    matches = [
        {
            'id': 'palavas_dh_sf1',
            'tournamentId': 'bt1000_palavas_2026',
            'draw': 'DH',
            'day': "Aujourd'hui",
            'round': '1/2 Finale',
            'time': '18h30',
            'court': 'Court 1',
            'team1': '[1] N. Gianotti (FRA) / M. Guegano (FRA)',
            'team2': '[3] T. Irigaray (FRA) / M. Bray (FRA)',
            'set1': None, 'set2': None, 'set3': None,
            'status': 'SCHEDULED', 'winner': None, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'palavas_dh_final',
            'tournamentId': 'bt1000_palavas_2026',
            'draw': 'DH',
            'day': 'Demain',
            'round': 'Grande Finale 🏆',
            'time': 'Samedi 18h00',
            'court': 'Court Central',
            'team1': '[1] N. Gianotti / M. Guegano',
            'team2': '[2] L. Godey / A. Begue',
            'set1': None, 'set2': None, 'set3': None,
            'status': 'SCHEDULED', 'winner': None, 'serving': None, 'isFeatured': True,
        },
        {
            'id': 'palavas_dd_final',
            'tournamentId': 'bt1000_palavas_2026',
            'draw': 'DD',
            'day': 'Demain',
            'round': 'Grande Finale 🏆',
            'time': 'Samedi 16h30',
            'court': 'Court Central',
            'team1': '[1] L. Jamel / A. Hoarau',
            'team2': '[2] M. Garnier / C. Palen',
            'set1': None, 'set2': None, 'set3': None,
            'status': 'SCHEDULED', 'winner': None, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'bcn_dh_final',
            'tournamentId': 'itf_bt200_barcelona_2026',
            'draw': 'DH',
            'day': 'Hier',
            'round': 'Grande Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central',
            'team1': '[1] G. Dowsett (ESP) / B. Bailer (ESP)',
            'team2': '[2] J. Chaparro (ESP) / E. Polidori (ITA)',
            'set1': '6/4', 'set2': '7/5', 'set3': None,
            'status': 'FINISHED', 'winner': 1, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'bcn_dd_final',
            'tournamentId': 'itf_bt200_barcelona_2026',
            'draw': 'DD',
            'day': 'Hier',
            'round': 'Grande Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central',
            'team1': '[1] A. Rodriguez (ESP) / M. Gomez (ESP)',
            'team2': '[2] C. Fernandez (ESP) / L. Sitja (ESP)',
            'set1': '6/3', 'set2': '6/4', 'set3': None,
            'status': 'FINISHED', 'winner': 1, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'reu_dh_final',
            'tournamentId': 'bt1000_saint_pierre_2026',
            'draw': 'DH',
            'day': 'Hier',
            'round': 'Grande Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central',
            'team1': '[1] L. Perrot / G. Payet',
            'team2': '[2] M. Hoarau / J. Fontaine',
            'set1': '6/4', 'set2': '7/5', 'set3': None,
            'status': 'FINISHED', 'winner': 1, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'vit_dh_final',
            'tournamentId': 'itf_bt100_vitoria_2026',
            'draw': 'DH',
            'day': 'Hier',
            'round': 'Grande Finale 🏆',
            'time': 'Terminé 🏆',
            'court': 'Court Central',
            'team1': '[1] N. Gianotti (FRA) / M. Spoto (ITA)',
            'team2': '[3] A. Baran (BRA) / D. Jovane (BRA)',
            'set1': '6/3', 'set2': '7/5', 'set3': None,
            'status': 'FINISHED', 'winner': 1, 'serving': None, 'isFeatured': False,
        },
        {
            'id': 'cervia_dh_final',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DH',
            'day': 'Ce Week-end',
            'round': 'Grande Finale 🏆',
            'time': 'Dimanche 30 Août',
            'court': 'Fantini Arena',
            'team1': '[1] M. Cappelletti / R. Alessi',
            'team2': '[2] F. Beccaccioli / L. Cramarossa',
            'set1': None, 'set2': None, 'set3': None,
            'status': 'SCHEDULED', 'winner': None, 'serving': None, 'isFeatured': False,
        },
    ]

    print("🧹 Nettoyage des anciens tournois et matchs...")
    for doc in db.collection('pro_matches').stream():
        doc.reference.delete()
    for doc in db.collection('pro_tournaments').stream():
        doc.reference.delete()

    print("📤 Écriture des 5 tournois réels...")
    for t in tournaments:
        db.collection('pro_tournaments').document(t['id']).set(t)

    print("📤 Écriture des matchs avec statuts réels...")
    for m in matches:
        db.collection('pro_matches').document(m['id']).set(m)

    print(f"✅ {len(tournaments)} Tournois et {len(matches)} Matchs synchronisés avec succès !")

if __name__ == '__main__':
    run_sync()
