#!/bin/sh
# ============================================================
# Generation des certificats TLS locaux pour la stack office-suite
# Fallback a mkcert (pas d'admin / choco requis).
# Cree une CA locale + 1 certificat par domaine attendu par traefik.yml
# Pour faire disparaitre l'avertissement du navigateur, importer
# traefik/certs/ca.crt dans "Autorites de certification racines de confiance".
# ============================================================
set -e
cd /certs

if [ ! -f ca.key ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout ca.key -out ca.crt \
    -subj "/CN=Office Suite Local CA/O=office-suite/C=HT" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign"
fi

gen() {
  name="$1"; host="$2"
  [ -f "${name}.crt" ] && return 0
  openssl req -newkey rsa:2048 -nodes -keyout "${name}.key" -out "${name}.csr" \
    -subj "/CN=${host}/O=office-suite"
  cat > "${name}.ext" <<EOF
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${host},DNS:localhost,IP:127.0.0.1
EOF
  openssl x509 -req -in "${name}.csr" -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out "${name}.crt" -days 825 -sha256 -extfile "${name}.ext"
  rm -f "${name}.csr" "${name}.ext"
}

gen nextcloud nextcloud.localhost
gen office     office.localhost
gen notes      notes.localhost
gen auth       auth.localhost

chmod 644 *.crt *.key
ls -l /certs
