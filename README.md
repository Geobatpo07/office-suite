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
- **PostgreSQL**: database for Nextcloud and HedgeDoc

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
```

Keycloak's own certificate covers `auth.test`, not `auth.localhost` like the other three — see the note in step 4.

**Option B — bundled OpenSSL generator** (no admin rights, no install — used when mkcert isn't available):

```bash
mkdir -p traefik/certs
docker run --rm -v "$PWD/traefik/certs:/certs" -v "$PWD/traefik/gen-certs.sh:/gen-certs.sh:ro" \
  --entrypoint sh alpine/openssl /gen-certs.sh
```

This creates a local CA plus one certificate per domain. To avoid a browser warning, import `traefik/certs/ca.crt` into your OS/browser's trusted root certificate store. Either way, `traefik/certs/` is gitignored (it contains private keys) — every clone must regenerate it.

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

#### Logging into HedgeDoc or Nextcloud via Keycloak

On first boot, Keycloak automatically imports [`keycloak/realm-office.json`](keycloak/realm-office.json): a dedicated `office` realm containing the `hedgedoc-client` and `nextcloud-client` OAuth clients, and one demo user, **`demo` / `demo`**. Use those credentials on either app's "Sign in via Keycloak" button. Logging into Nextcloud this way auto-creates a matching Nextcloud account on first login (username `demo`, from the `preferred_username` claim). This account is an intentionally public placeholder — delete it or add real users via the Keycloak admin console for anything beyond local testing.

---

### Usage

- All services communicate via the Docker network `office_net`.
- Nextcloud and HedgeDoc use PostgreSQL for data persistence; OnlyOffice and Keycloak have their own dedicated volumes.
- The ONLYOFFICE connector app and Keycloak SSO (`nextcloud/hooks/post-installation/*.sh`) are installed and configured automatically the first time Nextcloud boots.
- Nextcloud trusts the local CA on every container start (see the custom `entrypoint:` on the `nextcloud` service) so its PHP/curl backend can call `https://auth.test:8443` for SSO without a certificate error.
- Traefik terminates HTTPS using the certificates generated in step 2.

---

### Stop and clean up

```bash
docker compose --env-file .env down -v
```

`-v` also deletes all data volumes (documents, notes, Keycloak realms/users, databases) — drop it to keep your data across restarts.

---

### Project structure

```
office-suite/
│
├─ .devcontainer/          # VS Code / JetBrains configuration
├─ keycloak/
│   └─ realm-office.json   # Auto-imported realm: hedgedoc-client + demo user
├─ nextcloud/
│   └─ hooks/post-installation/
│       ├─ onlyoffice.sh     # Auto-installs & configures the ONLYOFFICE connector app
│       └─ keycloak-sso.sh   # Auto-installs & configures Keycloak SSO (user_oidc)
├─ traefik/
│   ├─ traefik.yml         # Traefik static configuration
│   ├─ dynamic/
│   │   └─ tls.yml         # Traefik dynamic configuration (TLS certificates)
│   ├─ gen-certs.sh        # OpenSSL-based certificate generator (mkcert alternative)
│   └─ certs/              # Generated certificates (gitignored, not shipped)
├─ docker-compose.yml
├─ .env.example            # Template — copy to .env and fill in real secrets
├─ .env                    # Your local secrets (gitignored, not shipped)
└─ README.md
```

---

### Security

- Certificates generated in step 2 are **local-only, self-signed** and must not be used in production. For a public deployment, configure Traefik with Let's Encrypt instead.
- The Traefik dashboard (`:8089`) has no authentication — fine for local dev, not for anything network-reachable.
- `keycloak/realm-office.json` ships placeholder OAuth client secrets (for both `hedgedoc-client` and `nextcloud-client`) and a `demo`/`demo` user, by design, so the stack works out of the box on a fresh clone. Rotate or remove them if this environment becomes reachable by anyone but you.
- Every other secret in `.env` is randomly generated locally and gitignored — rotate it if it's ever exposed (e.g. accidentally committed).

---

### License

MIT License

---

### Authors

Geovany Batista Polo LAGUERRE | Data Scientist
