#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Robot ITF/CBT & Tournois JAT Sync Engine
Délègue l'ingestion certifiée à sync_beachscore_certified_feed
"""

import sys
import os

# Ajout du dossier parent au path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sync_beachscore_certified_feed import main as run_certified_sync

def run_sync():
    print("🚀 [ITF Cron] Exécution du robot de synchronisation certifié BeachScore...")
    run_certified_sync()

if __name__ == '__main__':
    run_sync()
