"""
BeachMatch - YouTube Live Scoreboard Tracker (Robot IA Vision)
---------------------------------------------------------------
Surveille les chaînes YouTube de Beach Tennis (PlayBT, ITF, FFTennis)
et met à jour automatiquement les scores en direct dans Firestore.
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

# Chaînes officielles surveillées
CHANNELS = [
    {"name": "PlayBT", "url": "https://www.youtube.com/@playbtoficial/live", "priority": 1},
    {"name": "ITF Beach Tennis", "url": "https://www.youtube.com/@ITFBeachTennisTour/live", "priority": 2},
    {"name": "FFTennis", "url": "https://www.youtube.com/@FFTennis/live", "priority": 3},
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

def check_active_live_stream():
    """Vérifie si une des chaînes surveillées est actuellement en direct."""
    print("🔍 Recherche d'un direct sur les chaînes de Beach Tennis...")
    for ch in CHANNELS:
        cmd = [
            "yt-dlp",
            "--js-runtimes", "node",
            "--print", "%(is_live)s|%(id)s|%(title)s",
            "--no-playlist",
            ch["url"]
        ]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
            out = res.stdout.strip()
            if out and "|" in out:
                parts = out.split("|", 2)
                is_live = parts[0].strip().lower() == "true"
                vid_id = parts[1].strip()
                title = parts[2].strip() if len(parts) > 2 else ""
                if is_live and vid_id:
                    print(f"  🔴 DIRECT TROUVÉ sur {ch['name']} : '{title}' (ID: {vid_id})")
                    return {
                        "channel": ch["name"],
                        "video_id": vid_id,
                        "url": f"https://www.youtube.com/watch?v={vid_id}",
                        "title": title
                    }
        except Exception as e:
            print(f"  ⚠️ Erreur vérification {ch['name']} : {e}")

    print("  ⚪ Aucun direct actif sur les chaînes cibles pour le moment.")
    return None

def parse_scoreboard_detections(ocr_items):
    """
    Extrait les données de score (équipes, jeux, points) depuis les détections OCR.
    Format type :
      - 'GASPA/VALEN'
      - '2' ou 'D' (jeu)
      - '30' ou '40' (point)
      - 'CHOW/MARCH'
      - '5' (jeu)
      - '0' (point)
    """
    lines = [item[1].strip() for item in ocr_items]
    
    # Nettoyage et reconnaissance des chiffres
    def clean_game_digit(val):
        # OCR confond parfois '0' avec 'D', 'O', 'Q'
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

    # Extraction des noms et chiffres
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

def track_stream(video_url, match_id=None, db=None, max_duration_sec=10800, poll_interval=30):
    """
    Boucle principale de tracking du stream YouTube :
    Capture un fragment toutes les 30s, lit le bandeau, met à jour Firestore.
    """
    print(f"\n🚀 Démarrage du tracking en direct : {video_url}")
    engine = RapidOCR()
    temp_dir = tempfile.mkdtemp(prefix="bt_live_")

    try:
        start_time = time.time()
        last_score_str = ""

        # Détermination du document Firestore cible
        if db:
            if not match_id:
                match_id = f"live_yt_{int(time.time())}"
            doc_ref = db.collection('pro_matches').document(match_id)
            doc_ref.set({
                'id': match_id,
                'status': 'LIVE',
                'streamUrl': video_url,
                'time': 'En Direct 🔴',
                'date': datetime.now(timezone.utc).strftime('%Y-%m-%d'),
                'updatedAt': firestore.SERVER_TIMESTAMP,
            }, merge=True)
            print(f"📡 Match Firestore initialisé : pro_matches/{match_id}")

        frame_idx = 0
        while time.time() - start_time < max_duration_sec:
            frame_idx += 1
            clip_path = os.path.join(temp_dir, f"clip_{frame_idx}.mp4")
            frame_path = os.path.join(temp_dir, f"frame_{frame_idx}.jpg")
            crop_path = os.path.join(temp_dir, f"crop_{frame_idx}.jpg")

            # 1. Télécharger un mini segment de 2 secondes
            # Format 311 (720p HLS) ou fallback 230 (360p HLS)
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
                print(f"[{datetime.now().strftime('%H:%M:%S')}] ⚠️ Flux indisponible ou terminé.")
                time.sleep(poll_interval)
                continue

            # 2. Extraire 1 frame
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
                # 3. Découpe du bandeau (coin supérieur gauche)
                with Image.open(frame_path) as img:
                    w, h = img.size
                    crop_box = (0, 0, int(w * 0.35), int(h * 0.25))
                    crop_img = img.crop(crop_box)
                    crop_img.save(crop_path)

                # 4. OCR par RapidOCR
                ocr_result, _ = engine(crop_path)
                if ocr_result:
                    score = parse_scoreboard_detections(ocr_result)
                    current_score_str = f"{score.get('games1', '?')}-{score.get('games2', '?')} ({score.get('points1', '')}-{score.get('points2', '')})"
                    
                    if current_score_str != last_score_str:
                        last_score_str = current_score_str
                        print(f"[{datetime.now().strftime('%H:%M:%S')}] 🎾 SCORE MIS À JOUR : {score.get('team1', 'Équipe 1')} [{score.get('games1', '0')}] vs {score.get('team2', 'Équipe 2')} [{score.get('games2', '0')}] | Points: {score.get('points1', '')}-{score.get('points2', '')}")
                        
                        if db and ('games1' in score or 'team1' in score):
                            update_data = {
                                'status': 'LIVE',
                                'set1': f"{score.get('games1', '0')}/{score.get('games2', '0')}",
                                'points1': score.get('points1', ''),
                                'points2': score.get('points2', ''),
                                'updatedAt': firestore.SERVER_TIMESTAMP,
                            }
                            if 'team1' in score:
                                update_data['team1'] = score['team1']
                            if 'team2' in score:
                                update_data['team2'] = score['team2']
                            
                            db.collection('pro_matches').document(match_id).update(update_data)
                else:
                    # Scoreboard temporairement masqué (caméra gros plan, ralenti)
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] ⏳ Bandeau score temporairement masqué (ralenti/plan large)")

            # Nettoyage fichiers temporaires pour garder 0 Mo d'espace disque
            for f in [clip_path, frame_path, crop_path]:
                if os.path.exists(f):
                    try: os.remove(f)
                    except Exception: pass

            time.sleep(poll_interval)

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)
        print("🧹 Nettoyage terminé.")

def main():
    parser = argparse.ArgumentParser(description="Robot IA Live YouTube Tracker pour BeachMatch")
    parser.add_argument("--url", help="URL directe d'une vidéo ou d'un live YouTube à suivre", default=None)
    parser.add_argument("--match-id", help="ID du document Firestore à mettre à jour", default=None)
    parser.add_argument("--interval", type=int, help="Intervalle entre chaque capture (secondes)", default=30)
    parser.add_argument("--test-once", action="store_true", help="Capture et analyse 1 seule frame pour test")
    args = parser.parse_args()

    db = None
    try:
        db = init_firebase()
    except Exception as e:
        print(f"ℹ️ Exécution sans écriture Firestore : {e}")

    target_url = args.url
    if not target_url:
        live_info = check_active_live_stream()
        if live_info:
            target_url = live_info["url"]
        else:
            print("🏁 Rien à faire pour l'instant. Fin du robot.")
            return

    if args.test_once:
        print("🧪 Mode test 1-frame...")
        track_stream(target_url, match_id=args.match_id, db=db, max_duration_sec=35, poll_interval=1)
    else:
        track_stream(target_url, match_id=args.match_id, db=db, poll_interval=args.interval)

if __name__ == '__main__':
    main()
