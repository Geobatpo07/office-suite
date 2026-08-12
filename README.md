### Office Suite Dev Environment

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)
[![Traefik](https://img.shields.io/badge/traefik-v3.7-orange.svg)](https://traefik.io/)
[![SSL](https://img.shields.io/badge/SSL-mkcert%20%7C%20openssl-green.svg)](https://github.com/FiloSottile/mkcert)

A complete local office suite for development and testing, using **Nextcloud**, **OnlyOffice**, **HedgeDoc**, and **Keycloak** behind a **Traefik** reverse proxy with local SSL certificates.

---

### Included Services

- **Traefik**: HTTPS reverse proxy with dashboard
- **Nextcloud**: cloud storage and collaboration
- **OnlyOffice**: online document editing
- **HedgeDoc**: collaborative note-taking, with OAuth2 login against Keycloak pre-configured out of the box
- **OnlyOffice ↔ Nextcloud connector**: pre-wired on first boot — open and co-edit `.docx`/`.xlsx`/`.pptx` files directly from Nextcloud's Files app, no manual setup
- **Keycloak**: authentication and OAuth2 management, as SSO for both HedgeDoc and Nextcloud out of the box
- **Mailpit**: local SMTP catch-all — password resets, share notifications and Keycloak account emails are all pre-wired to land here instead of a real inbox
- **Calendar, Contacts, Talk**: pre-installed Nextcloud apps for CalDAV/CardDAV and chat/video calls, the latter backed by a local coturn STUN/TURN server
- **PostgreSQL**: database for Nextcloud and HedgeDoc — metadata only for Nextcloud (see MinIO below), full data for HedgeDoc
- **Redis**: Nextcloud's distributed cache and file-locking backend — pre-wired on first boot
- **MinIO**: S3-compatible object storage, configured as Nextcloud's **primary** file storage — every file a user uploads is stored here, not on a local disk; Postgres only ever holds the metadata (filenames, folders, sharing info)
- Every service has a CPU/memory ceiling (`deploy.resources.limits` in `docker-compose.yml`) so one runaway container (OnlyOffice's conversion process is the usual suspect) can't starve the rest of the stack or your host
- **Backups**: `scripts/backup.sh` / `scripts/restore.sh` — one command each, see [Backups](#backups) below

---

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) (Windows), with Docker Engine 29+ / Docker Compose v2+
- Either [mkcert](https://github.com/FiloSottile/mkcert) (needs admin rights and, on Windows, Chocolatey or a manual install), **or** nothing extra at all — this repo ships a Docker-based certificate generator that needs no local install and no admin rights (see step 2 below).

---

### Installation

#### 1. Clone the project

```bash
git clone https://github.com/Geobatpo07/office-suite.git
cd office-suite
```

#### 2. Generate local TLS certificates

Traefik needs one certificate per domain in `./traefik/certs/` before the first start. Pick one option.

**Option A — mkcert** (if you have admin rights / Chocolatey):

```powershell
choco install mkcert
mkcert -install
mkcert -cert-file traefik/certs/nextcloud.crt -key-file traefik/certs/nextcloud.key nextcloud.localhost
mkcert -cert-file traefik/certs/office.crt     -key-file traefik/certs/office.key     office.localhost
mkcert -cert-file traefik/certs/notes.crt      -key-file traefik/certs/notes.key      notes.localhost
mkcert -cert-file traefik/certs/auth.crt       -key-file traefik/certs/auth.key       auth.test
mkcert -cert-file traefik/certs/mail.crt       -key-file traefik/certs/mail.key       mail.localhost
mkcert -cert-file traefik/certs/storage.crt    -key-file traefik/certs/storage.key    storage.localhost
```

`coturn` (Talk's STUN/TURN server) and `redis` need no certificate — neither is routed through Traefik at all: `coturn` is plain UDP/TCP (see the note in step 4), and Nextcloud only ever talks to Redis over the internal Docker network, never over HTTPS.

Keycloak's own certificate covers `auth.test`, not `auth.localhost` like the other three — see the note in step 4.

**Option B — bundled OpenSSL generator** (no admin rights, no install — used when mkcert isn't available):

```bash
mkdir -p traefik/certs
docker run --rm -v "$PWD/traefik/certs:/certs" -v "$PWD/traefik/gen-certs.sh:/gen-certs.sh:ro" \
  --entrypoint sh alpine/openssl /gen-certs.sh
```

This creates a local CA plus one certificate per domain. To avoid a browser warning, import `traefik/certs/ca.crt` into your OS/browser's trusted root certificate store. Either way, `traefik/certs/` is gitignored (it contains private keys) — every clone must regenerate it.

Traefik's dynamic config watcher doesn't reliably pick up a brand-new certificate file on its own (observed on Docker Desktop for Windows) — if you add a domain's cert after Traefik is already running, `docker compose restart traefik` to be sure.

#### 3. Configure the `.env` file

```bash
cp .env.example .env
```

Then replace every `changeme` value with a random secret, e.g. `openssl rand -hex 24` (PowerShell: `[System.Convert]::ToHexString((1..24|%{Get-Random -Max 256}))`) — **except `HEDGEDOC_OAUTH_SECRET`**, which must stay equal to the client secret baked into [`keycloak/realm-office.json`](keycloak/realm-office.json) (imported automatically on first boot). If you want a private value there too, edit that JSON file *before* the first `docker compose up` and keep both in sync.

`.env` is gitignored — never commit it.

#### 4. Edit the hosts file

Chrome and Firefox already resolve `*.localhost` to `127.0.0.1` on their own (RFC 6761), so entries for `nextcloud.localhost`/`office.localhost`/`notes.localhost` are only needed for tools that don't (e.g. `curl` on Windows) or other browsers. **`auth.test` is different and always needs an entry**, in every browser: it deliberately isn't under `.localhost` (see the note in `docker-compose.yml`'s `keycloak` service — in short, PHP/curl inside the Nextcloud container hardcodes any `*.localhost` host to loopback, which silently breaks Nextcloud's SSO calls to Keycloak; `.test` doesn't have that problem, but it also isn't auto-resolved by anything).

```text
127.0.0.1 nextcloud.localhost
127.0.0.1 office.localhost
127.0.0.1 notes.localhost
127.0.0.1 auth.test
```

Admin CMD tip (Windows):

```cmd
echo 127.0.0.1 nextcloud.localhost >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 office.localhost >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 notes.localhost >> C:\Windows\System32\drivers\etc\hosts
echo 127.0.0.1 auth.test >> C:\Windows\System32\drivers\etc\hosts
```

No entry is needed for `coturn`: Nextcloud Talk is deliberately configured to reach it at `localhost:3478` directly — WebRTC media goes straight from the browser to coturn over UDP, which Traefik can't proxy (there's no HTTP host header on that traffic to route by), so this only works when the browser runs on the same machine as Docker Desktop.

---

### Start the suite

```bash
docker compose --env-file .env up -d
```

- Traefik dashboard: `http://localhost:8089/dashboard/` (no auth — local dev only)
- Nextcloud: `https://nextcloud.localhost:8443` — login with `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD` from `.env`, or click "Log in with Keycloak"
- OnlyOffice: `https://office.localhost:8443` — no standalone login; open a document from Nextcloud's Files app instead (click any `.docx`/`.xlsx`/`.pptx`, or "+ > Document/Spreadsheet/Presentation" to create one)
- HedgeDoc: `https://notes.localhost:8443` — click "Sign in via Keycloak"
- Keycloak: `https://auth.test:8443/admin/` — login with `KEYCLOAK_USER` / `KEYCLOAK_PASSWORD` from `.env`
- Mailpit: `https://mail.localhost:8443` — every email Nextcloud or Keycloak sends (password resets, share notifications, account emails) shows up here instead of a real inbox
- MinIO console: `https://storage.localhost:8443` — login with `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `.env`; the `nextcloud` bucket holds the actual bytes of every file in Nextcloud (auto-created on first boot)

Calendar, Contacts and Talk show up as regular Nextcloud apps in the top-left app switcher — no separate URL. Talk's audio/video calls work between two browser tabs on the same machine out of the box (coturn is pre-configured); calling from a different device on your LAN needs `localhost:3478` in Nextcloud's Talk admin settings changed to that machine's actual LAN IP. Redis has no UI — it's purely an internal cache/locking backend for Nextcloud.

#### Logging into HedgeDoc or Nextcloud via Keycloak

On first boot, Keycloak automatically imports [`keycloak/realm-office.json`](keycloak/realm-office.json): a dedicated `office` realm containing the `hedgedoc-client` and `nextcloud-client` OAuth clients, and one demo user, **`demo` / `demo`**. Use those credentials on either app's "Sign in via Keycloak" button. Logging into Nextcloud this way auto-creates a matching Nextcloud account on first login (username `demo`, from the `preferred_username` claim). This account is an intentionally public placeholder — delete it or add real users via the Keycloak admin console for anything beyond local testing.

---

### Usage

- All services communicate via the Docker network `office_net`.
- Nextcloud and HedgeDoc use PostgreSQL for data persistence; OnlyOffice and Keycloak have their own dedicated volumes.
- Nextcloud's storage is split three ways, deliberately: **Postgres** holds metadata only (filenames, folders, sharing/permissions — the `oc_filecache` table and friends); **MinIO** holds every file's actual bytes, as Nextcloud's primary object storage (not an optional external mount — `nextcloud_data` itself no longer contains real file content); **Redis** holds the distributed cache and the file-locking state that keeps concurrent edits/uploads consistent.
- The ONLYOFFICE connector app, Keycloak SSO, SMTP, Redis caching/locking, Calendar, Contacts and Talk (`nextcloud/hooks/post-installation/*.sh`) are installed and configured automatically the first time Nextcloud boots.
- MinIO as primary storage is different from the other hooks above: it's set via `OBJECTSTORE_S3_*` environment variables on the `nextcloud` service, read only by Nextcloud's own installer, not a post-installation hook. Object storage has to be in place *before* the first user/file exists — Nextcloud does not support converting an already-installed local-storage instance to object storage in place. This only matters if you ever change the MinIO variables after the first boot: they'll have no effect on an existing install, since by then `config/config.php` is already written. A fresh clone is unaffected — it's always a first boot.
- Keycloak's own SMTP settings are applied by the one-shot `keycloak-init` service: Keycloak's file-based realm import silently drops the `smtpServer` block for a brand-new realm (a known limitation — the fields parse fine, they just don't end up on the imported realm), so `keycloak/configure-smtp.sh` sets them via the admin REST API instead, right after Keycloak comes up.
- Nextcloud trusts the local CA on every container start (see the custom `entrypoint:` on the `nextcloud` service) so its PHP/curl backend can call `https://auth.test:8443` for SSO without a certificate error.
- Traefik terminates HTTPS using the certificates generated in step 2.

---

### Stop and clean up

```bash
docker compose --env-file .env down -v
```

`-v` also deletes all data volumes (documents, notes, Keycloak realms/users, databases) — drop it to keep your data across restarts.

---

### Backups

```bash
bash scripts/backup.sh
```

Creates `backups/<UTC timestamp>/` containing: a `pg_dump` of both Postgres databases (`nextcloud-db.sql`, `hedgedoc-db.sql`, dumped with `--no-owner --no-acl` so a restore always lands on whatever role runs it, regardless of what owns the tables in the source), and a tar of every volume holding user data (`nextcloud_data`, `minio_data`, `hedgedoc_uploads`, `onlyoffice_data`, `onlyoffice_db`, `keycloak_data` — `onlyoffice_log` and `redis_data` are skipped, both are disposable). `nextcloud_data` alone is **not** a full Nextcloud backup: since MinIO is Nextcloud's primary storage, the actual bytes of every file live in `minio_data`, not there — `nextcloud_data` only holds the app code, config, and installed apps. Nextcloud is put into maintenance mode only for the few seconds it takes to tar `nextcloud_data`, so no in-flight upload gets archived half-written; the script always turns it back off before exiting, even on failure.

`backups/` is gitignored — it holds real user data and must not end up in the public repo. Move backups you want to keep somewhere durable (external disk, cloud storage) yourself; this script only produces them locally. It does **not** back up `.env` — without the same `NEXTCLOUD_DB_PASSWORD`/`HEDGEDOC_DB_PASSWORD`/etc. that were live at backup time, app containers can't reconnect to a restored database. Keep `.env` backed up separately (password manager or vault), never next to the archive itself.

To restore:

```bash
bash scripts/restore.sh backups/<timestamp>
```

This is destructive — it stops the stack, wipes and replaces the 6 volumes above, and drops/recreates both databases from the dumps, then brings everything back up. It asks for a typed `yes` confirmation first (skip the prompt with a trailing `--yes` for scripted use). Run it from a clone whose `.env` already matches the one that produced the backup.

---

### Project structure

```
office-suite/
│
├─ .devcontainer/          # VS Code / JetBrains configuration
├─ keycloak/
│   ├─ realm-office.json   # Auto-imported realm: hedgedoc-client, nextcloud-client, demo user
│   └─ configure-smtp.sh   # One-shot: sets the realm's SMTP config via the admin API
├─ nextcloud/
│   └─ hooks/post-installation/
│       ├─ onlyoffice.sh     # Auto-installs & configures the ONLYOFFICE connector app
│       ├─ keycloak-sso.sh   # Auto-installs & configures Keycloak SSO (user_oidc)
│       ├─ redis.sh          # Auto-configures Redis as the cache/locking backend
│       ├─ smtp.sh           # Auto-configures outgoing mail to point at Mailpit
│       ├─ groupware.sh      # Auto-installs Calendar and Contacts
│       └─ talk.sh           # Auto-installs Talk and points it at coturn
├─ traefik/
│   ├─ traefik.yml         # Traefik static configuration
│   ├─ dynamic/
│   │   └─ tls.yml         # Traefik dynamic configuration (TLS certificates)
│   ├─ gen-certs.sh        # OpenSSL-based certificate generator (mkcert alternative)
│   └─ certs/              # Generated certificates (gitignored, not shipped)
├─ scripts/
│   ├─ backup.sh           # Dumps both databases + tars every data volume
│   └─ restore.sh          # Disaster recovery: restores a backup.sh output (destructive)
├─ backups/                # Local backups (gitignored, not shipped)
├─ docker-compose.yml
├─ .env.example            # Template — copy to .env and fill in real secrets
├─ .env                    # Your local secrets (gitignored, not shipped)
└─ README.md
```

---

### Security

- Certificates generated in step 2 are **local-only, self-signed** and must not be used in production. For a public deployment, configure Traefik with Let's Encrypt instead.
- The Traefik dashboard (`:8089`) and Mailpit's inbox (`mail.localhost`) have no authentication — fine for local dev, not for anything network-reachable. Every email sent by Nextcloud or Keycloak (including password-reset links) is visible to anyone who can reach Mailpit.
- `keycloak/realm-office.json` ships placeholder OAuth client secrets (for both `hedgedoc-client` and `nextcloud-client`) and a `demo`/`demo` user, by design, so the stack works out of the box on a fresh clone. Rotate or remove them if this environment becomes reachable by anyone but you.
- Every other secret in `.env` is randomly generated locally and gitignored — rotate it if it's ever exposed (e.g. accidentally committed).
- `coturn` runs without TLS/DTLS (plain `turn:`, not `turns:`) for simplicity — fine for local dev, not for a TURN server reachable beyond your own machine.
- Every service is capped with `deploy.resources.limits` (see `docker-compose.yml`); a container hitting its memory limit gets OOM-killed and restarted (`restart: unless-stopped`) rather than degrading the whole host. Adjust the values if your machine has less than ~8 GB free for Docker or you hit OOM kills under normal use.
- `backups/` contains complete, unencrypted copies of every user's files, notes, and database rows. Treat it with the same care as production data even in a dev setup, and never commit it (it's gitignored) or upload it anywhere `.env` isn't equally protected.
- MinIO (`storage.localhost`) and Redis both require credentials (`MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`, `REDIS_PASSWORD` in `.env`) — unlike the Traefik dashboard and Mailpit, these are not wide open by default.
- `minio` runs on `cgr.dev/chainguard/minio:latest`, not the official `minio/minio` image — MinIO Inc. stopped publishing free Docker images in late 2025 and archived that repository. Chainguard's free tier only offers the rolling `latest` tag, not version-pinned releases like every other image in this stack, so `docker compose pull` can silently bring in a newer MinIO version. Watch MinIO's release notes if that matters to you.

---

### License

MIT License

---

### Authors

Geovany Batista Polo LAGUERRE | Data Scientist
