# Office Suite Dev Environment

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)
[![Traefik](https://img.shields.io/badge/traefik-v3.0-orange.svg)](https://traefik.io/)
[![SSL](https://img.shields.io/badge/SSL-mkcert-green.svg)](https://github.com/FiloSottile/mkcert)

Une suite bureautique locale complète pour le développement et les tests, utilisant **Nextcloud**, **OnlyOffice**, **HedgeDoc**, et **Keycloak** avec un reverse proxy **Traefik** et des certificats SSL locaux via **mkcert**.

---

## Services inclus

- **Traefik** : reverse proxy HTTPS avec dashboard  
- **Nextcloud** : stockage et collaboration cloud  
- **OnlyOffice** : édition de documents en ligne  
- **HedgeDoc** : prise de notes collaborative  
- **Keycloak** : gestion de l’authentification et OAuth2  
- **PostgreSQL** : base de données pour Nextcloud et HedgeDoc  

---

## Prérequis

- [Docker Desktop](https://www.docker.com/products/docker-desktop) (Windows)  
- [Docker Compose v2+](https://docs.docker.com/compose/install/)  
- [Chocolatey](https://chocolatey.org/) (optionnel pour mkcert)  
- [mkcert](https://github.com/FiloSottile/mkcert) pour SSL local  

---

## Installation

### 1. Cloner le projet

```bash
git clone https://github.com/<username>/office-suite.git
cd office-suite
```

### 2. Installer mkcert et générer les certificats

```powershell
choco install mkcert
mkcert -install
mkcert nextcloud.localhost office.localhost notes.localhost auth.localhost
```

Les certificats seront placés dans `./traefik/certs`.

### 3. Configurer le fichier `.env`

Crée un fichier `.env` à la racine :

```env
NETWORK_NAME=office_net

NEXTCLOUD_DB_USER=nextcloud
NEXTCLOUD_DB_PASSWORD=changeme
NEXTCLOUD_DB_NAME=nextcloud_db

HEDGEDOC_DB_USER=hedgedoc
HEDGEDOC_DB_PASSWORD=changeme
HEDGEDOC_DB_NAME=hedgedoc_db

JWT_SECRET=secretjwt123

KEYCLOAK_USER=admin
KEYCLOAK_PASSWORD=changeme
```

### 4. Modifier le fichier hosts (Windows)

Ajouter les entrées :

```text
127.0.0.1 nextcloud.localhost
127.0.0.1 office.localhost
127.0.0.1 notes.localhost
127.0.0.1 auth.localhost
```

**Astuce CMD admin** :

```cmd
echo 127.0.0.1 nextcloud.localhost >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 office.localhost >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 notes.localhost >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 auth.localhost >> C:\Windows\System32\drivers\etc\hosts
```

---

## Lancer la suite

```bash
docker compose --env-file .env up -d
```

- Traefik : `https://localhost:8089`  
- Nextcloud : `https://nextcloud.localhost`  
- OnlyOffice : `https://office.localhost`  
- HedgeDoc : `https://notes.localhost`  
- Keycloak : `https://auth.localhost`  

---

## Utilisation

- Tous les services communiquent via le réseau Docker `office_net`.  
- Nextcloud et HedgeDoc utilisent PostgreSQL pour la persistance des données.  
- OnlyOffice nécessite `JWT_SECRET` pour l’authentification interne.  
- Traefik gère le HTTPS avec les certificats mkcert.  

---

## Arrêter et nettoyer

```bash
docker compose --env-file .env down -v
```

---

## Structure du projet

```
office-suite/
│
├─ .devcontainer/        # Configuration VS Code / JetBrains
├─ traefik/
│   ├─ traefik.yml       # Configuration Traefik
│   └─ certs/            # Certificats mkcert
├─ docker-compose.yml
├─ .env
└─ README.md
```

---

## Sécurité

- Les certificats mkcert sont **locaux** et ne doivent pas être utilisés en production.  
- Pour un déploiement public, configure Traefik avec Let's Encrypt officiel.  

---

## Licence

MIT License

---

## Auteurs

Geovany Batista Polo LAGUERRE | Data Scientist 

