#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
     🔥 BEACHSCORE DAILY & REALTIME SYNC ENGINE (Robot Scores & Alertes 1 min)
================================================================================
Ce robot :
1. ⏱️ Actualise le statut des matchs (SCHEDULED -> LIVE -> FINISHED) selon l'heure réelle.
2. 🔔 Scrute la collection 'match_reminders' pour déclencher les alertes à 1 MINUTE DU DÉBUT.
3. 📲 Crée les notifications push dans la collection 'notifications' et met à jour le statut.
================================================================================
"""

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

    env_creds = os.environ.get('FIREBASE_SERVICE_ACCOUNT')
    if env_creds:
        try:
            cred_dict = json.loads(env_creds)
            project_id = cred_dict.get('project_id', 'beach-tennis-216f4')
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred, {'projectId': project_id})
            print(f"🔑 [Auth] Firebase initialisé via GitHub Actions Secret ({project_id}).")
            return firestore.client()
        except Exception as e:
            print(f"⚠️ [Auth] Erreur chargement JSON depuis env : {e}")

    local_paths = [
        r'C:\Users\Medha\Downloads\beach-tennis-216f4-firebase-adminsdk-fbsvc-bf4a39311c.json',
        os.path.join(os.getcwd(), 'firebase-service-account.json'),
    ]

    for path in local_paths:
        if os.path.exists(path):
            cred = credentials.Certificate(path)
            firebase_admin.initialize_app(cred)
            print(f"🔑 [Auth] Firebase initialisé via fichier local : {path}")
            return firestore.client()

    raise RuntimeError("❌ Impossible d'initialiser Firebase. Aucune clé trouvée.")

def main():
    print("=" * 80)
    print("     🔥 DÉBUT DU CYCLE BEACHSCORE DAILY & ALERTES 1 MINUTE")
    print("=" * 80)
    
    db = init_firebase()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    today_str = now.strftime('%Y-%m-%d')
    
    # 0. CONSOLIDATION CERTIFIÉE MONDE, BRÉSIL & TOURNOIS JAT
    print("\n[0] CONSOLIDATION CERTIFIÉE MONDE, BRÉSIL & TOURNOIS JAT...")
    try:
        try:
            from backend.sync_beachscore_certified_feed import (
                clean_junk_matches,
                seed_certified_tournaments,
                seed_itf_and_cbt_matches,
                sync_in_app_jat_tournaments,
            )
        except ImportError:
            from sync_beachscore_certified_feed import (
                clean_junk_matches,
                seed_certified_tournaments,
                seed_itf_and_cbt_matches,
                sync_in_app_jat_tournaments,
            )
        clean_junk_matches(db)
        seed_certified_tournaments(db)
        seed_itf_and_cbt_matches(db)
        sync_in_app_jat_tournaments(db)
        print("  ✅ Synchronisation certifiée réussie.")
    except Exception as e:
        print(f"  ⚠️ Erreur lors de la synchro certifiée : {e}")

    # 1. SYNCHRONISATION DES STATUTS DE MATCHS (pro_matches)
    print("\n[1] SYNCHRONISATION DES MATCHS PRO...")
    matches = list(db.collection('pro_matches').stream())
    print(f"  • Total matchs analysés : {len(matches)}")
    
    updated_matches = 0
    for m in matches:
        d = m.to_dict()
        mid = m.id
        status = d.get('status', 'SCHEDULED')
        date_str = d.get('date', '')
        time_str = d.get('time', '12:00')
        
        # Résolution de l'heure du match
        match_dt = None
        if d.get('scheduledAt'):
            try:
                s_at = d.get('scheduledAt')
                if hasattr(s_at, 'to_datetime'):
                    match_dt = s_at.to_datetime()
                elif isinstance(s_at, datetime):
                    match_dt = s_at
            except Exception:
                pass
        
        if not match_dt and date_str:
            try:
                clean_time = time_str.replace('h', ':').split(':')
                hour = int(clean_time[0])
                minute = int(clean_time[1]) if len(clean_time) > 1 else 0
                parts = [int(p) for p in date_str.split('-')]
                match_dt = datetime(parts[0], parts[1], parts[2], hour, minute)
            except Exception:
                pass
                
        if match_dt:
            if hasattr(match_dt, 'tzinfo') and match_dt.tzinfo is not None:
                match_dt = match_dt.astimezone(timezone.utc).replace(tzinfo=None)

            # Si le match s'est achevé (heure de fin dépassée de plus de 2h30)
            if now > match_dt + timedelta(hours=2, minutes=30) and status != 'FINISHED':
                db.collection('pro_matches').document(mid).update({
                    'status': 'FINISHED',
                    'updatedAt': firestore.SERVER_TIMESTAMP,
                })
                updated_matches += 1
                print(f"  [ARCHIVAGE TERMINÉ] {d.get('team1')} vs {d.get('team2')} -> FINISHED")
            # Si le match est en cours
            elif match_dt <= now <= match_dt + timedelta(hours=2, minutes=30) and status != 'LIVE' and status != 'FINISHED':
                db.collection('pro_matches').document(mid).update({
                    'status': 'LIVE',
                    'updatedAt': firestore.SERVER_TIMESTAMP,
                })
                updated_matches += 1
                print(f"  [PASSAGE EN DIRECT] {d.get('team1')} vs {d.get('team2')} -> LIVE")
                
    print(f"  ✅ {updated_matches} statut(s) de match mis à jour.")

    # 2. VÉRIFICATION DES ALERTES 1 MINUTE (match_reminders)
    print("\n[2] VÉRIFICATION DES ALERTES 1 MINUTE (match_reminders)...")
    reminders = list(db.collection('match_reminders').where('status', '==', 'PENDING').stream())
    print(f"  • Total rappels en attente : {len(reminders)}")
    
    triggered_alerts = 0
    for r in reminders:
        rd = r.to_dict()
        rid = r.id
        alert_at = rd.get('alertAt')
        
        alert_dt = None
        if alert_at:
            if hasattr(alert_at, 'to_datetime'):
                alert_dt = alert_at.to_datetime()
            elif isinstance(alert_at, datetime):
                alert_dt = alert_at
            if alert_dt and hasattr(alert_dt, 'tzinfo') and alert_dt.tzinfo is not None:
                alert_dt = alert_dt.astimezone(timezone.utc).replace(tzinfo=None)
            
        # Si l'alerte (1 minute avant le coup d'envoi) est atteinte ou passée
        if alert_dt and now >= alert_dt:
            team1 = rd.get('team1', 'Paire 1')
            team2 = rd.get('team2', 'Paire 2')
            tourney = rd.get('tournamentName', 'Tournoi Beach Tennis')
            court = rd.get('court', 'Court Central')
            user_id = rd.get('userId', 'anonymous')
            
            # 1. Enregistrement dans les notifications in-app
            db.collection('notifications').add({
                'userId': user_id,
                'title': "⚡ Coup d'envoi dans 1 minute !",
                'body': f"{team1} vs {team2} sur le {court} ({tourney}) va démarrer !",
                'matchId': rd.get('matchId'),
                'type': 'MATCH_ALERT_1_MIN',
                'read': False,
                'createdAt': firestore.SERVER_TIMESTAMP,
            })
            
            # 2. Clôture de l'alerte
            db.collection('match_reminders').document(rid).update({
                'status': 'SENT',
                'sentAt': firestore.SERVER_TIMESTAMP,
            })
            
            triggered_alerts += 1
            print(f"  [ALERTE DÉCLENCHÉE 1 MIN] {team1} vs {team2} pour utilisateur {user_id}")
            
    print(f"  ✅ {triggered_alerts} alerte(s) 1 minute déclenchée(s).")
    print("=" * 80)

if __name__ == '__main__':
    main()
