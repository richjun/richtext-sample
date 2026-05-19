#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> flutter build web --release"
flutter build web --release

echo "==> serving build/web on :8000"
( cd build/web && python3 -m http.server 8000 ) &
SERVE_PID=$!
trap "kill $SERVE_PID 2>/dev/null || true" EXIT

# wait for server (up to 30s)
for _ in $(seq 1 60); do
  if curl -s http://localhost:8000 >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

echo "==> playwright tests"
cd verify
npx playwright test --reporter=list
