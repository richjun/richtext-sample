#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> flutter build web --release"
flutter build web --release

echo "==> killing any stale http.server on :8000"
pkill -9 -f "http.server 8000" 2>/dev/null || true
sleep 0.5

echo "==> serving build/web on :8000"
# exec replaces the subshell so $! is the python pid (otherwise the trap kills
# the subshell and orphans python, leaving the port bound but unresponsive).
( cd build/web && exec python3 -m http.server 8000 ) &
SERVE_PID=$!
cleanup() {
  kill "$SERVE_PID" 2>/dev/null || true
  pkill -9 -f "http.server 8000" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# wait for server (up to 30s) — must get a real HTTP 200, not just a TCP accept
for _ in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ || echo 000)
  if [ "$code" = "200" ]; then
    echo "server up (HTTP $code)"
    break
  fi
  sleep 0.5
done

echo "==> playwright tests"
cd verify
npx playwright test --reporter=list
