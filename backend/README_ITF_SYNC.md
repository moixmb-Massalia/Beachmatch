# 🤖 ITF Beach Tennis Sync Engine (Automatisation 24h/24)

Ce module permet de synchroniser automatiquement le calendrier et les résultats des tournois d'élite de l'ITF Beach Tennis World Tour vers Firebase Firestore pour les 5 pays majeurs :
🇧🇷 **Brésil**, 🇫🇷 **France**, 🇮🇹 **Italie**, 🇪🇸 **Espagne**, 🇷🇪 **La Réunion**.

---

## ⚡ 1. Fonctionnement Automatique (GitHub Actions Cron)

Le workflow `.github/workflows/itf_sync_cron.yml` s'exécute automatiquement **toutes les 6 heures** sur les serveurs gratuits de GitHub.

### 🔑 Comment configurer le Secret GitHub en 1 minute :
1. Ouvre ton dépôt GitHub BeachMatch.
2. Va dans **Settings** ➔ **Secrets and variables** ➔ **Actions**.
3. Clique sur **New repository secret**.
4. Renseigne :
   * **Name** : `FIREBASE_SERVICE_ACCOUNT`
   * **Secret** : Le contenu texte complet de ton fichier JSON de clé Firebase (`beach-tennis-216f4-firebase-adminsdk-fbsvc-bf4a39311c.json`).
5. Clique sur **Add secret**.

C'est tout ! Dès lors, GitHub mettra à jour Firebase automatiquement sans que tu n'aies rien d'autre à faire.

---

## 💻 2. Lancement Manuel en Local sur ta Machine

Tu peux également tester ou lancer la synchronisation manuellement à tout moment depuis ton terminal :

```bash
python backend/itf_sync_engine.py
```
