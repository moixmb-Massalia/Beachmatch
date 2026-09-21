"""
BeachMatch - YouTube Live Scoreboard Tracker (Robot IA Vision 100% Automatique)
-------------------------------------------------------------------------------
1. Découvre automatiquement les matchs programmés, en direct et terminés
   sur les chaînes officielles (PlayBT, FFTennis...).
2. Extrait le tournoi, le tour, les équipes et le genre directement depuis le titre.
3. Crée les documents Firestore sans aucune saisie manuelle.
4. Lit le score en direct sur le flux vidéo via RapidOCR toutes les 30s.
"""

import os
import sys
import time
import re
import argparse
import subprocess
import tempfile
import shutil
from datetime import datetime, timezone

from PIL import Image
from rapidocr_onnxruntime import RapidOCR
import firebase_admin
from firebase_admin import credentials, firestore

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

CHANNELS = [
    {"name": "PlayBT", "url": "https://www.youtube.com/@ProgramaPLAYBT/streams"},
    {"name": "FFTennis", "url": "https://www.youtube.com/@FFTennis/streams"},
]

def init_firebase():
    """Initialise Firebase pour GitHub Actions (Secret JSON) ou local."""
    if firebase_admin._apps:
        return firestore.client()

    env_creds = os.environ.get('FIREBASE_SERVICE_ACCOUNT')
    if env_creds:
        try:
            import json
            cred_dict = json.loads(env_creds)
            project_id = cred_dict.get('project_id', 'beach-tennis-216f4')
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred, {'projectId': project_id})
            print(f"🔑 Firebase initialisé via Secret ({project_id}).")
            return firestore.client()
        except Exception as e:
            print(f"⚠️ Erreur chargement JSON env : {e}")

    local_paths = [
        r'C:\Users\Medha\Downloads\beach-tennis-216f4-firebase-adminsdk-fbsvc-bf4a39311c.json',
        os.path.join(os.getcwd(), 'firebase-service-account.json'),
    ]

    for p in local_paths:
        if os.path.exists(p):
            cred = credentials.Certificate(p)
            firebase_admin.initialize_app(cred)
            print(f"🔑 Firebase initialisé via : {p}")
            return firestore.client()

    raise RuntimeError("❌ Impossible d'initialiser Firebase. Aucune clé trouvée.")

def parse_match_title(title):
    """Extrait Tournoi, Tour, Équipes et Tableau (DH/DD) depuis le titre de la vidéo."""
    res = {
        'round': 'Match Pro',
        'team1': 'Équipe 1',
        'team2': 'Équipe 2',
        'tournament': 'World Tour',
        'draw': 'DH'
    }

    # 1. Extraction du Tour (FINAL, SEMIFINAL, QUARTAS...)
    round_match = re.match(r'^(FINAL(?:E)?|SEMIFINAL|DEMI(?:-)?FINALE|QUART(?:AS)?(?: DE FINAL)?):\s*', title, re.I)
    rest = title
    if round_match:
        raw_round = round_match.group(1).upper()
        if 'FINAL' in raw_round and 'SEMI' not in raw_round and 'DEMI' not in raw_round and 'QUART' not in raw_round:
            res['round'] = 'Finale 🏆'
        elif 'SEMI' in raw_round or 'DEMI' in raw_round:
            res['round'] = '1/2 Finale'
        elif 'QUART' in raw_round:
            res['round'] = '1/4 Finale'
        rest = title[round_match.end():]

    # 2. Extraction du Tournoi (après le dernier tiret -)
    if ' - ' in rest:
        parts = rest.rsplit(' - ', 1)
        rest = parts[0].strip()
        res['tournament'] = parts[1].strip()

    # 3. Extraction des Équipes (séparées par X ou VS)
    team_split = re.split(r'\s+[xX]\s+|\s+vs\s+|\s+VS\s+', rest)
    if len(team_split) == 2:
        res['team1'] = team_split[0].strip().title()
        res['team2'] = team_split[1].strip().title()

    # 4. Détection Double Dames (DD) vs Double Hommes (DH)
    fem_names = ['julia', 'mariana', 'ana', 'graziele', 'giulia', 'ninny', 'sophia', 'vitoria', 'patricia', 'flaminia', 'elena', 'nicole', 'dames']
    t_lower = (res['team1'] + ' ' + res['team2'] + ' ' + title).lower()
    if any(name in t_lower for name in fem_names):
        res['draw'] = 'DD'
    else:
        res['draw'] = 'DH'

    return res

def discover_channel_matches(db=None, max_per_channel=5):
    """
    Scanne les chaînes YouTube pour découvrir les matchs sans aucune saisie humaine.
    Retourne la liste des matchs découverts et le premier match LIVE s'il y en a un.
    """
    print("\n📡 Découverte automatique des matchs sur YouTube...")
    discovered = []
    active_live_match = None

    for ch in CHANNELS:
        print(f"  🔍 Scan {ch['name']}...")
        cmd = [
            "yt-dlp",
            "--js-runtimes", "node",
            "--flat-playlist",
            "--print", "%(id)s|%(live_status)s|%(title)s",
            "--playlist-end", str(max_per_channel),
            ch["url"]
        ]

        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            for line in res.stdout.strip().split('\n'):
                if not line or '|' not in line:
                    continue
                parts = line.split('|', 2)
                vid_id = parts[0].strip()
                live_status = parts[1].strip().lower()
                title = parts[2].strip() if len(parts) > 2 else ""

                # Filtre : s'assurer que c'est bien du Beach Tennis (notamment sur FFTennis)
                if ch["name"] == "FFTennis" and not any(kw in title.lower() for kw in ["beach", "bt1000", "bt2000", "bt500", "bt200"]):
                    continue

                parsed = parse_match_title(title)
                status = 'SCHEDULED'
                time_str = 'Programmé'

                if live_status == 'is_live':
                    status = 'LIVE'
                    time_str = 'En Direct 🔴'
                elif live_status == 'was_live':
                    status = 'FINISHED'
                    time_str = 'Terminé 🏆'

                match_obj = {
                    'id': f"yt_{vid_id}",
                    'videoId': vid_id,
                    'tournamentId': re.sub(r'[^a-zA-Z0-9_]', '_', parsed['tournament'].lower())[:30],
                    'tournamentName': parsed['tournament'],
                    'round': parsed['round'],
                    'draw': parsed['draw'],
                    'team1': parsed['team1'],
                    'team2': parsed['team2'],
                    'status': status,
                    'time': time_str,
                    'streamUrl': f"https://www.youtube.com/watch?v={vid_id}",
                    'date': datetime.now(timezone.utc).strftime('%Y-%m-%d'),
                }

                discovered.append(match_obj)
                print(f"    ➔ [{match_obj['status']}] {match_obj['round']} : {match_obj['team1']} vs {match_obj['team2']} ({match_obj['tournamentName']})")

                # Enregistrement dans Firestore si disponible
                if db:
                    ref = db.collection('pro_matches').document(match_obj['id'])
                    ref.set({
                        **match_obj,
                        'updatedAt': firestore.SERVER_TIMESTAMP,
                    }, merge=True)

                if status == 'LIVE' and not active_live_match:
                    active_live_match = match_obj

        except Exception as e:
            print(f"  ⚠️ Erreur scan {ch['name']} : {e}")

    print(f"✅ {len(discovered)} match(s) synchronisé(s) automatiquement depuis YouTube.\n")
    return discovered, active_live_match

def parse_scoreboard_detections(ocr_items):
    """Extrait les scores depuis l'OCR."""
    lines = [item[1].strip() for item in ocr_items]

    def clean_game_digit(val):
        if val.upper() in ['D', 'O', 'Q']:
            return '0'
        if val.isdigit() and 0 <= int(val) <= 7:
            return val
        return None

    def clean_point(val):
        if val in ['0', '15', '30', '40', 'AD']:
            return val
        if val == '50' or val == '3O':
            return '30'
        return val if val.isdigit() else None

    teams = []
    digits = []

    for text in lines:
        cleaned_digit = clean_game_digit(text)
        cleaned_pt = clean_point(text)
        if cleaned_digit is not None:
            digits.append(cleaned_digit)
        elif cleaned_pt is not None:
            digits.append(cleaned_pt)
        elif len(text) > 3 and not any(tag in text for tag in ['#', 'SERIES', 'WORLD', 'BONVOY', 'WORK']):
            teams.append(text)

    score_data = {}
    if len(teams) >= 2:
        score_data['team1'] = teams[0]
        score_data['team2'] = teams[1]

    if len(digits) >= 2:
        score_data['games1'] = digits[0]
        score_data['games2'] = digits[1]
        if len(digits) >= 4:
            score_data['points1'] = digits[2]
            score_data['points2'] = digits[3]

    return score_data

def track_live_match(match_obj, db=None, max_duration_sec=10800, poll_interval=30):
    """Suit le score du match LIVE en temps réel toutes les 30s."""
    video_url = match_obj['streamUrl']
    match_id = match_obj['id']
    print(f"\n🎾 DÉMARRAGE DU TRACKING EN DIRECT pour {match_obj['team1']} vs {match_obj['team2']}")

    engine = RapidOCR()
    temp_dir = tempfile.mkdtemp(prefix="bt_live_")

    try:
        start_time = time.time()
        last_score_str = ""

        frame_idx = 0
        while time.time() - start_time < max_duration_sec:
            frame_idx += 1
            clip_path = os.path.join(temp_dir, f"clip_{frame_idx}.mp4")
            frame_path = os.path.join(temp_dir, f"frame_{frame_idx}.jpg")
            crop_path = os.path.join(temp_dir, f"crop_{frame_idx}.jpg")

            cmd_dl = [
                "yt-dlp",
                "--js-runtimes", "node",
                "-f", "311/230/bestvideo[height<=720]/best",
                "--download-sections", "*00:00:00-00:00:02",
                "-o", clip_path,
                "--force-overwrites",
                video_url
            ]

            res_dl = subprocess.run(cmd_dl, capture_output=True, text=True, timeout=25)
            if not os.path.exists(clip_path) or os.path.getsize(clip_path) == 0:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 🏁 Fin du live détectée. Match archivé.")
                if db:
                    db.collection('pro_matches').document(match_id).update({
                        'status': 'FINISHED',
                        'time': 'Terminé 🏆',
                        'updatedAt': firestore.SERVER_TIMESTAMP,
                    })
                break

            cmd_ff = [
                "ffmpeg",
                "-ss", "00:00:01",
                "-i", clip_path,
                "-vframes", "1",
                "-q:v", "2",
                "-y",
                frame_path
            ]
            subprocess.run(cmd_ff, capture_output=True, timeout=10)

            if os.path.exists(frame_path) and os.path.getsize(frame_path) > 0:
                with Image.open(frame_path) as img:
                    w, h = img.size
                    crop_box = (0, 0, int(w * 0.35), int(h * 0.25))
                    crop_img = img.crop(crop_box)
                    crop_img.save(crop_path)

                ocr_result, _ = engine(crop_path)
                if ocr_result:
                    score = parse_scoreboard_detections(ocr_result)
                    current_score_str = f"{score.get('games1', '?')}-{score.get('games2', '?')} ({score.get('points1', '')}-{score.get('points2', '')})"

                    if current_score_str != last_score_str:
                        last_score_str = current_score_str
                        print(f"[{datetime.now().strftime('%H:%M:%S')}] 🎾 SCORE : [{score.get('games1', '0')}] vs [{score.get('games2', '0')}] | Points: {score.get('points1', '')}-{score.get('points2', '')}")

                        if db and 'games1' in score:
                            db.collection('pro_matches').document(match_id).update({
                                'status': 'LIVE',
                                'set1': f"{score.get('games1', '0')}/{score.get('games2', '0')}",
                                'points1': score.get('points1', ''),
                                'points2': score.get('points2', ''),
                                'updatedAt': firestore.SERVER_TIMESTAMP,
                            })

            for f in [clip_path, frame_path, crop_path]:
                if os.path.exists(f):
                    try: os.remove(f)
                    except Exception: pass

            time.sleep(poll_interval)

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

def main():
    parser = argparse.ArgumentParser(description="Robot IA Vision 100% Automatique Beach Tennis")
    parser.add_argument("--url", help="URL manuelle pour forcer le tracking d'un match spécifique", default=None)
    parser.add_argument("--interval", type=int, help="Intervalle entre chaque capture (secondes)", default=30)
    args = parser.parse_args()

    db = None
    try:
        db = init_firebase()
    except Exception as e:
        print(f"ℹ️ Exécution sans écriture Firestore : {e}")

    # Si une URL manuelle est fournie, on la suit directement
    if args.url:
        match_obj = {
            'id': f"yt_manual_{int(time.time())}",
            'streamUrl': args.url,
            'team1': 'Équipe 1',
            'team2': 'Équipe 2',
        }
        track_live_match(match_obj, db=db, poll_interval=args.interval)
        return

    # Sinon : MODE AUTO-DISCOVERY 100% SANS SAISIE
    discovered, live_match = discover_channel_matches(db=db)

    if live_match:
        track_live_match(live_match, db=db, poll_interval=args.interval)
    else:
        print("🏁 Tous les matchs récents sont synchronisés dans Firestore. Aucun live en cours. Repos du robot.")

if __name__ == '__main__':
    main()
