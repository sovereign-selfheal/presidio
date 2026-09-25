#!/usr/bin/env bash
# Smoke test of a built image: start it, wait for /health, then check that both NER
# models (en, it) find the expected entities.
#
# Usage: tests/smoke.sh <image>        (needs podman, curl and python3)
set -euo pipefail

image="${1:?Usage: $0 <image>}"
port="${SMOKE_PORT:-3000}"
name="presidio-smoke-$$"

cleanup() { podman rm -f "${name}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

podman run -d --name "${name}" -p "127.0.0.1:${port}:3000" "${image}" >/dev/null

# The analyzer loads two spaCy models at start-up: this can take a minute.
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 3
done
curl -fsS "http://127.0.0.1:${port}/health" >/dev/null || {
  echo "FAIL: /health does not answer" >&2
  podman logs "${name}" >&2 || true
  exit 1
}
echo "PASS: /health"

# check <language> <text> <entity types that must be found...>
check() {
  local lang="$1" text="$2"
  shift 2
  local body
  body=$(python3 -c 'import json, sys; print(json.dumps({"text": sys.argv[1], "language": sys.argv[2]}))' "${text}" "${lang}")
  curl -fsS -H 'Content-Type: application/json' -d "${body}" "http://127.0.0.1:${port}/analyze" |
    python3 -c '
import json, sys
found = {e["entity_type"] for e in json.load(sys.stdin)}
missing = [t for t in sys.argv[2:] if t not in found]
status = "FAIL" if missing else "PASS"
print(f"{status}: [{sys.argv[1]}] found {sorted(found)}, missing {missing}")
sys.exit(1 if missing else 0)
' "${lang}" "$@"
}

check en "Mario Rossi lives in Rome and works in London." PERSON LOCATION
check it "Mario Rossi abita a Roma e lavora a Milano." PERSON LOCATION
