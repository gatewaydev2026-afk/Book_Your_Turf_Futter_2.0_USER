#!/usr/bin/env bash
# Book Your Turf – compute the 11-char SMS Retriever app hash
# Usage:
#   ./tools/sms_app_hash.sh deployment_cert.der            # Play Store (App signing key certificate)
#   ./tools/sms_app_hash.sh --keystore <file> <alias> <storepass>
set -euo pipefail
PKG="com.bookyourturf.app"
TMP=$(mktemp)
if [[ "${1:-}" == "--keystore" ]]; then
  keytool -exportcert -keystore "$2" -alias "$3" -storepass "$4" > "$TMP"
else
  cp "$1" "$TMP"
fi
python3 - "$PKG" "$TMP" <<'PY'
import sys, hashlib, base64
pkg, path = sys.argv[1], sys.argv[2]
cert = open(path, 'rb').read()
digest = hashlib.sha256(f"{pkg} {cert.hex()}".encode()).digest()
print(base64.b64encode(digest[:9]).decode()[:11])
PY
rm -f "$TMP"
