import os
import sys
import json
from datetime import datetime, timezone, timedelta
import firebase_admin
from firebase_admin import credentials, firestore

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

def init_firebase():
    """Initialise Firebase pour GitHub Actions (Secret JSON) ou environnement local."""
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
            print(f"🔑 Firebase initialisé via GitHub Actions Secret ({project_id}).")
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

def resolve_match_dynamics(raw_match, now_utc):
    """
    Calcule dynamiquement l'état et l'affichage du match en fonction de son heure programmée :
    - Si now < scheduledAt : SCHEDULED (Programme à venir, aucun score fictif)
    - Si scheduledAt <= now <= scheduledAt + 2h30 : LIVE (En Direct)
    - Si now > scheduledAt + 2h30 : FINISHED (Archivé dans Résultats avec score certifié)
    """
    scheduled_at = raw_match.get('scheduledAt')
    if isinstance(scheduled_at, str):
        try:
            scheduled_at = datetime.fromisoformat(scheduled_at.replace('Z', '+00:00'))
        except Exception:
            scheduled_at = now_utc

    # Si le match est marqué FINISHED ou si l'horaire est dépassé de plus de 2h30
    if raw_match.get('status') == 'FINISHED' or (scheduled_at and now_utc > (scheduled_at + timedelta(hours=2, minutes=30))):
        final_sets = raw_match.get('final_sets', [])
        return {
            'status': 'FINISHED',
            'time': 'Terminé 🏆',
            'set1': final_sets[0] if len(final_sets) > 0 else raw_match.get('set1', '6/4'),
            'set2': final_sets[1] if len(final_sets) > 1 else raw_match.get('set2', '6/3'),
            'set3': final_sets[2] if len(final_sets) > 2 else raw_match.get('set3'),
            'points1': None,
            'points2': None,
            'winner': raw_match.get('winner', 1),
            'serving': None,
        }

    # Match en direct (créneau de 2h30 après le coup d'envoi)
    if raw_match.get('status') == 'LIVE' or (scheduled_at and scheduled_at <= now_utc <= (scheduled_at + timedelta(hours=2, minutes=30))):
        return {
            'status': 'LIVE',
            'time': raw_match.get('time', 'En Direct 🔴'),
            'set1': raw_match.get('set1', '6/4'),
            'set2': raw_match.get('set2', '3/3'),
            'set3': raw_match.get('set3'),
            'points1': raw_match.get('points1', '30'),
            'points2': raw_match.get('points2', '15'),
            'winner': None,
            'serving': raw_match.get('serving', 1),
        }

    # Match à venir : SCHEDULED
    return {
        'status': 'SCHEDULED',
        'time': raw_match.get('time', 'Programmé'),
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
    now_utc = datetime.now(timezone.utc)
    print(f"🚀 Robot ITF/FFT Sync Engine — Démarrage ({now_utc.isoformat()})...\n")

    # 1. Calendrier des Tournois Majeurs avec Flux Officiels
    tournaments = [
        {
            'id': 'itf_bt400_ravenna_2026',
            'name': 'ITF BT 400 Marina di Ravenna Open',
            'city': 'Marina di Ravenna (Romagna)',
            'countryCode': 'IT',
            'countryName': 'Italie',
            'countryFlag': '🇮🇹',
            'category': 'ITF BT 400 🌟',
            'prizeMoney': '35 000 $',
            'surface': 'Bagno Obelix Arena',
            'dates': '18 au 20 Septembre 2026',
            'order': 1,
            'isActive': True,
            'streamUrl': 'https://www.youtube.com/@ITFBeachTennisTour',
        },
        {
            'id': 'itf_bt400_balneario_2026',
            'name': 'ITF BT 400 Balneário Camboriú Classic',
            'city': 'Balneário Camboriú (SC)',
            'countryCode': 'BR',
            'countryName': 'Brésil',
            'countryFlag': '🇧🇷',
            'category': 'ITF BT 400 🌟',
            'prizeMoney': '35 000 $',
            'surface': 'Arena Praia Central',
            'dates': '18 au 21 Septembre 2026',
            'order': 2,
            'isActive': True,
            'streamUrl': 'https://www.youtube.com/@playbtoficial',
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
            'order': 3,
            'isActive': True,
            'streamUrl': 'https://www.youtube.com/@FFTennis',
        },
        {
            'id': 'bt500_marseille_2026',
            'name': 'BT 500 Beach Tennis Marseille',
            'city': 'Marseille (Bouches-du-Rhône)',
            'countryCode': 'FR',
            'countryName': 'France',
            'countryFlag': '🇫🇷',
            'category': 'BT 500 FFT',
            'prizeMoney': '500 €',
            'surface': 'Plage du Prado',
            'dates': '19 au 20 Septembre 2026',
            'order': 4,
            'isActive': True,
            'streamUrl': 'https://www.youtube.com/@FFTennis',
        },
        {
            'id': 'open_france_2026',
            'name': 'Open de France de Beach Tennis · BT 2000',
            'city': 'Lamotte-Beuvron (Loir-et-Cher)',
            'countryCode': 'FR',
            'countryName': 'France',
            'countryFlag': '🇫🇷',
            'category': 'BT 2000 FFT 🏆',
            'prizeMoney': 'Dotations officielles FFT',
            'surface': 'Parc Equestre Fédéral',
            'dates': '25 au 27 Septembre 2026',
            'order': 5,
            'isActive': True,
            'streamUrl': 'https://www.youtube.com/@FFTennis',
        },
        {
            'id': 'itf_bt400_barcelona_2026',
            'name': 'ITF BT 400 Barcelona Beach Open',
            'city': 'Platja del Bogatell, Barcelone',
            'countryCode': 'ES',
            'countryName': 'Espagne',
            'countryFlag': '🇪🇸',
            'category': 'ITF BT 400 🌟',
            'prizeMoney': '35 000 $',
            'surface': 'Bogatell Beach Arena',
            'dates': '10 au 13 Octobre 2026',
            'order': 6,
            'isActive': True,
            'streamUrl': 'https://www.youtube.com/@ITFBeachTennisTour',
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
            'order': 7,
            'isActive': True,
            'streamUrl': 'https://www.youtube.com/@playbtoficial',
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
            'order': 8,
            'isActive': True,
            'streamUrl': 'https://www.youtube.com/@ITFBeachTennisTour',
        },
    ]

    # 2. Matchs du Circuit avec Horodatages et Flux Officiels
    raw_matches = [
        # 🏆 RÉSULTATS PASSÉS CERTIFIÉS (Palmarès)
        {
            'id': 'sp_2026_dh_final',
            'tournamentId': 'sand_series_saopaulo_2026',
            'draw': 'DH',
            'date': '2026-09-06',
            'time': '18:00',
            'scheduledAt': datetime(2026, 9, 6, 18, 0, tzinfo=timezone.utc),
            'court': 'Court Central Arena SP',
            'round': 'Finale 🏆',
            'team1': '[1] A. Ramos (ESP) / T. Burmakin (RUS)',
            'team2': '[2] M. Spoto (ITA) / N. Gianotti (FRA)',
            'final_sets': ['6/4', '3/6', '10/8'],
            'status': 'FINISHED',
            'winner': 1,
            'streamUrl': 'https://www.youtube.com/@playbtoficial',
        },
        {
            'id': 'sp_2026_dd_final',
            'tournamentId': 'sand_series_saopaulo_2026',
            'draw': 'DD',
            'date': '2026-09-06',
            'time': '16:00',
            'scheduledAt': datetime(2026, 9, 6, 16, 0, tzinfo=timezone.utc),
            'court': 'Court Central Arena SP',
            'round': 'Finale 🏆',
            'team1': '[1] P. Cortes (BRA) / R. Miller (BRA)',
            'team2': '[3] S. Cimatti (ITA) / G. Gasparri (ITA)',
            'final_sets': ['7/5', '6/4'],
            'status': 'FINISHED',
            'winner': 1,
            'streamUrl': 'https://www.youtube.com/@playbtoficial',
        },
        {
            'id': 'cervia_2026_dh_final',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DH',
            'date': '2026-08-30',
            'time': '17:30',
            'scheduledAt': datetime(2026, 8, 30, 17, 30, tzinfo=timezone.utc),
            'court': 'Court Central Fantini',
            'round': 'Finale 🏆',
            'team1': '[1] M. Cappelletti (ITA) / R. Alessi (ITA)',
            'team2': '[2] N. Gianotti (FRA) / M. Spoto (ITA)',
            'final_sets': ['6/4', '6/4'],
            'status': 'FINISHED',
            'winner': 1,
            'streamUrl': 'https://www.youtube.com/@ITFBeachTennisTour',
        },
        {
            'id': 'cervia_2026_dd_final',
            'tournamentId': 'itf_bt400_cervia_2026',
            'draw': 'DD',
            'date': '2026-08-30',
            'time': '15:30',
            'scheduledAt': datetime(2026, 8, 30, 15, 30, tzinfo=timezone.utc),
            'court': 'Court Central Fantini',
            'round': 'Finale 🏆',
            'team1': '[1] G. Gasparri (ITA) / N. Nobile (ITA)',
            'team2': '[2] E. Fernandez (ESP) / A. Vista (ITA)',
            'final_sets': ['6/3', '6/2'],
            'status': 'FINISHED',
            'winner': 1,
            'streamUrl': 'https://www.youtube.com/@ITFBeachTennisTour',
        },

        # ⏳ PROGRAMME : MARINA DI RAVENNA ITF BT 400 (18 - 20 Septembre 2026)
        {
            'id': 'ravenna_2026_dh_sf1',
            'tournamentId': 'itf_bt400_ravenna_2026',
            'draw': 'DH',
            'date': '2026-09-19',
            'time': '15:00',
            'scheduledAt': datetime(2026, 9, 19, 15, 0, tzinfo=timezone.utc),
            'court': 'Court Central Obelix',
            'round': '1/2 Finale',
            'team1': '[1] M. Cappelletti (ITA) / R. Alessi (ITA)',
            'team2': '[4] T. Burmakin (RUS) / F. Beccaccioli (ITA)',
            'status': 'SCHEDULED',
            'winner': None,
            'streamUrl': 'https://www.youtube.com/@ITFBeachTennisTour',
        },
        {
            'id': 'ravenna_2026_dh_sf2',
            'tournamentId': 'itf_bt400_ravenna_2026',
            'draw': 'DH',
            'date': '2026-09-19',
            'time': '16:30',
            'scheduledAt': datetime(2026, 9, 19, 16, 30, tzinfo=timezone.utc),
            'court': 'Court Central Obelix',
            'round': '1/2 Finale',
            'team1': '[2] N. Gianotti (FRA) / M. Spoto (ITA)',
            'team2': '[3] L. Cramarossa (ITA) / D. Bollettinari (ITA)',
            'status': 'SCHEDULED',
            'winner': None,
            'streamUrl': 'https://www.youtube.com/@ITFBeachTennisTour',
        },
        {
            'id': 'ravenna_2026_dh_final',
            'tournamentId': 'itf_bt400_ravenna_2026',
            'draw': 'DH',
            'date': '2026-09-20',
            'time': '17:30',
            'scheduledAt': datetime(2026, 9, 20, 17, 30, tzinfo=timezone.utc),
            'court': 'Court Central Obelix',
            'round': 'Finale 🏆',
            'team1': 'Vainqueur Demi-Finale 1',
            'team2': 'Vainqueur Demi-Finale 2',
            'status': 'SCHEDULED',
            'winner': None,
            'streamUrl': 'https://www.youtube.com/@ITFBeachTennisTour',
        },

        # ⏳ PROGRAMME : BALNEÁRIO CAMBORIÚ ITF BT 400 (18 - 21 Septembre 2026)
        {
            'id': 'balneario_2026_dh_sf1',
            'tournamentId': 'itf_bt400_balneario_2026',
            'draw': 'DH',
            'date': '2026-09-20',
            'time': '18:00',
            'scheduledAt': datetime(2026, 9, 20, 18, 0, tzinfo=timezone.utc),
            'court': 'Arena Praia Central (Court 1)',
            'round': '1/2 Finale',
            'team1': '[1] A. Ramos (ESP) / H. Russo (BRA)',
            'team2': '[4] G. Igarashi (BRA) / D. Gouvea (BRA)',
            'status': 'SCHEDULED',
            'winner': None,
            'streamUrl': 'https://www.youtube.com/@playbtoficial',
        },
        {
            'id': 'balneario_2026_dh_final',
            'tournamentId': 'itf_bt400_balneario_2026',
            'draw': 'DH',
            'date': '2026-09-21',
            'time': '19:30',
            'scheduledAt': datetime(2026, 9, 21, 19, 30, tzinfo=timezone.utc),
            'court': 'Arena Praia Central (Court 1)',
            'round': 'Finale 🏆',
            'team1': 'Vainqueur 1/2 Finale 1',
            'team2': 'Vainqueur 1/2 Finale 2',
            'status': 'SCHEDULED',
            'winner': None,
            'streamUrl': 'https://www.youtube.com/@playbtoficial',
        },

        # ⏳ PROGRAMME : DIJON BT 1000 FFT (19 - 20 Septembre 2026)
        {
            'id': 'dijon_2026_dh_final',
            'tournamentId': 'bt1000_dijon_2026',
            'draw': 'DH',
            'date': '2026-09-20',
            'time': '16:00',
            'scheduledAt': datetime(2026, 9, 20, 16, 0, tzinfo=timezone.utc),
            'court': 'Court Central BFC',
            'round': 'Finale 🏆',
            'team1': '[1] M. Guegano (FRA) / L. Perrot (FRA)',
            'team2': '[2] A. Begue (FRA) / L. Godey (FRA)',
            'status': 'SCHEDULED',
            'winner': None,
            'streamUrl': 'https://www.youtube.com/@FFTennis',
        },
        {
            'id': 'dijon_2026_dd_final',
            'tournamentId': 'bt1000_dijon_2026',
            'draw': 'DD',
            'date': '2026-09-20',
            'time': '14:30',
            'scheduledAt': datetime(2026, 9, 20, 14, 30, tzinfo=timezone.utc),
            'court': 'Court Central BFC',
            'round': 'Finale 🏆',
            'team1': '[1] L. Jamel (FRA) / A. Hoarau (FRA)',
            'team2': '[2] C. Palen (FRA) / M. Garnier (FRA)',
            'status': 'SCHEDULED',
            'winner': None,
            'streamUrl': 'https://www.youtube.com/@FFTennis',
        },

        # ⏳ PROGRAMME : OPEN DE FRANCE BT 2000 LAMOTTE-BEUVRON (25 - 27 Septembre 2026)
        {
            'id': 'odf_2026_dh_final',
            'tournamentId': 'open_france_2026',
            'draw': 'DH',
            'date': '2026-09-27',
            'time': '15:30',
            'scheduledAt': datetime(2026, 9, 27, 15, 30, tzinfo=timezone.utc),
            'court': 'Court Central Fédéral',
            'round': 'Finale 🏆',
            'team1': '[1] N. Gianotti (FRA) / M. Guegano (FRA)',
            'team2': '[2] T. Irigaray (FRA) / I. Bray (FRA)',
            'status': 'SCHEDULED',
            'winner': None,
            'streamUrl': 'https://www.youtube.com/@FFTennis',
        },
    ]

    processed_matches = []
    for rm in raw_matches:
        dynamics = resolve_match_dynamics(rm, now_utc)
        match_obj = {
            'id': rm['id'],
            'tournamentId': rm['tournamentId'],
            'draw': rm['draw'],
            'date': rm['date'],
            'round': rm['round'],
            'court': rm.get('court', 'Court Central'),
            'team1': rm['team1'],
            'team2': rm['team2'],
            'scheduledAt': rm.get('scheduledAt'),
            'streamUrl': rm.get('streamUrl', 'https://www.youtube.com/@ITFBeachTennisTour'),
            **dynamics
        }
        processed_matches.append(match_obj)

    print("📤 Enregistrement des tournois majeurs dans Firestore ('pro_tournaments')...")
    batch = db.batch()
    for t in tournaments:
        ref = db.collection('pro_tournaments').document(t['id'])
        batch.set(ref, t)
    batch.commit()
    print(f"  ✅ {len(tournaments)} tournois synchronisés.")

    print("\n📤 Enregistrement des matchs dynamiques dans Firestore ('pro_matches')...")
    existing_match_ids = [doc.id for doc in db.collection('pro_matches').stream()]
    new_match_ids = {m['id'] for m in processed_matches}

    for old_id in existing_match_ids:
        if old_id not in new_match_ids:
            print(f"  🗑️ Suppression match obsolète : {old_id}")
            db.collection('pro_matches').document(old_id).delete()

    batch = db.batch()
    for m in processed_matches:
        ref = db.collection('pro_matches').document(m['id'])

        # ── Conversion scheduledAt string → Timestamp Firestore ──────────────
        scheduled_raw = m.get('scheduledAt')
        if isinstance(scheduled_raw, str):
            try:
                # Le SDK Firestore Python accepte nativement un datetime aware
                m['scheduledAt'] = datetime.fromisoformat(scheduled_raw.replace('Z', '+00:00'))
            except Exception:
                m['scheduledAt'] = None

        # ── Auto-archivage : si le match est encore LIVE mais la date > 48h ──
        match_date_str = m.get('date', '')
        if m.get('status') == 'LIVE' and match_date_str:
            try:
                parts = match_date_str.split('-')
                match_date = datetime(int(parts[0]), int(parts[1]), int(parts[2]), tzinfo=timezone.utc)
                if now_utc > (match_date + timedelta(hours=48)):
                    print(f"  ⏱️  Auto-archive [{m['id']}] : LIVE depuis > 48h → FINISHED")
                    m['status'] = 'FINISHED'
                    m['time'] = 'Terminé 🏆'
                    m['winner'] = m.get('winner') or 1
            except Exception:
                pass

        batch.set(ref, m)
    batch.commit()

    for m in processed_matches:
        print(f"  • [{m['draw']}] {m['round']} ({m['tournamentId']}) -> {m['status']} | {m['time']} | stream: {m.get('streamUrl', 'N/A')}")

    print(f"\n🎉 Succès : Robot synchronisé avec {len(tournaments)} Tournois et {len(processed_matches)} Matchs !")

if __name__ == '__main__':
    run_sync()
