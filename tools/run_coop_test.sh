#!/usr/bin/env bash
# End-to-end co-op test: 1 headless dedicated server + 4 headless clients (real game code, scripted input).
# Usage: tools/run_coop_test.sh [godot-binary-or-exported-client] [server-binary]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${1:-godot}"
SERVER="${2:-$GODOT}"
PORT="${PORT:-27900}"
OUT="${OUT:-$ROOT/build/test}"
mkdir -p "$OUT"
rm -f "$OUT"/*.json "$OUT"/*.log
DATA="${DATA:-$OUT/server_data}"
PATHARG=()
[ "$GODOT" = "godot" ] && PATHARG=(--path "$ROOT/game")
SPATHARG=()
[ "$SERVER" = "godot" ] && SPATHARG=(--path "$ROOT/game")

"$SERVER" --headless "${SPATHARG[@]}" -- --server --port=$PORT --data-dir="$DATA" --allow-test-commands --log-file="$OUT/server.log" > "$OUT/server.stdout" 2>&1 &
SPID=$!
sleep ${SERVER_BOOT:-2}
bot() { # role class name
  "$GODOT" --headless "${PATHARG[@]}" -- --autotest --connect=127.0.0.1:$PORT --role=$1 --class=$2 --profile=$3 --name=$3 \
    ${BOT_ARGS:-} --expect=4 --report="$OUT/$3.json" --timeout=200 > "$OUT/$3.log" 2>&1 &
  PIDS+=($!)
}
PIDS=()
bot leader assault Leader; sleep 0.5
bot casualty medic Casualty1
bot member support Support1
bot leaver recon Leaver1
wait "${PIDS[@]}"
sleep 1
kill $SPID 2>/dev/null; wait $SPID 2>/dev/null
echo "---- results"
FAIL=0
for f in "$OUT"/*.json; do
  python3 -I - "$f" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
bad=[c for c in d["checks"] if not c["ok"]]
print(f'{d["role"]:9s} {len(d["checks"])-len(bad)}/{len(d["checks"])} passed' + ("" if not bad else "  FAILED: " + ", ".join(c["name"]+"("+c["detail"]+")" for c in bad)))
sys.exit(1 if bad else 0)
PY
  [ $? -ne 0 ] && FAIL=1
done
grep -cE "SCRIPT ERROR" "$OUT"/*.log "$OUT"/server.stdout | sed 's/^/script errors: /'
ls "$DATA"/profiles 2>/dev/null | sed 's/^/profile: /'
exit $FAIL
