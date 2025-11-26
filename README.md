### Office Suite Dev Environment

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)
[![Traefik](https://img.shields.io/badge/traefik-v3.0-orange.svg)](https://traefik.io/)
[![SSL](https://img.shields.io/badge/SSL-mkcert-green.svg)](https://github.com/FiloSottile/mkcert)

A complete local office suite for development and testing, using **Nextcloud**, **OnlyOffice**, **HedgeDoc**, and **Keycloak** behind a **Traefik** reverse proxy with local SSL certificates via **mkcert**.

---

### Included Services

- **Traefik**: HTTPS reverse proxy with dashboard  
- **Nextcloud**: cloud storage and collaboration  
- **OnlyOffice**: online document editing  
- **HedgeDoc**: collaborative note-taking  
- **Keycloak**: authentication and OAuth2 management  
- **PostgreSQL**: database for Nextcloud and HedgeDoc  

---

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) (Windows)  
- [Docker Compose v2+](https://docs.docker.com/compose/install/)  
- [Chocolatey](https://chocolatey.org/) (optional for mkcert)  
- [mkcert](https://github.com/FiloSottile/mkcert) for local SSL  

---

### Installation

#### 1. Clone the project

```bash
git clone https://github.com/Geobatpo07/office-suite.git
cd office-suite
```

#### 2. Install mkcert and generate certificates

```powershell
choco install mkcert
mkcert -install
mkcert nextcloud.localhost office.localhost notes.localhost auth.localhost
```

Certificates will be placed in `./traefik/certs`.

#### 3. Configure the `.env` file

Create a `.env` file at the project root:

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

#### 4. Edit the hosts file (Windows)

Add these entries:

```text
127.0.0.1 nextcloud.localhost
127.0.0.1 office.localhost
127.0.0.1 notes.localhost
127.0.0.1 auth.localhost
```

Admin CMD tip:

```cmd
echo 127.0.0.1 nextcloud.localhost >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 office.localhost >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 notes.localhost >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 auth.localhost >> C:\Windows\System32\drivers\etc\hosts
```

---

### Start the suite

```bash
docker compose --env-file .env up -d
```

- Traefik: `https://localhost:8089`  
- Nextcloud: `https://nextcloud.localhost`  
- OnlyOffice: `https://office.localhost`  
- HedgeDoc: `https://notes.localhost`  
- Keycloak: `https://auth.localhost`  

---

### Usage

- All services communicate via the Docker network `office_net`.  
- Nextcloud and HedgeDoc use PostgreSQL for data persistence.  
- OnlyOffice requires `JWT_SECRET` for internal authentication.  
- Traefik handles HTTPS using mkcert certificates.  

---

### Stop and clean up

```bash
docker compose --env-file .env down -v
```

---

### Project structure

```
office-suite/
│
├─ .devcontainer/        # VS Code / JetBrains configuration
├─ traefik/
│   ├─ traefik.yml       # Traefik configuration
│   └─ certs/            # mkcert certificates
├─ docker-compose.yml
├─ .env
└─ README.md
```

---

### Security

- mkcert certificates are **local** and must not be used in production.  
- For a public deployment, configure Traefik with official Let’s Encrypt.  

---

### License

MIT License

---

### Authors

Geovany Batista Polo LAGUERRE | Data Scientist
