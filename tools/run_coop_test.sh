#!/usr/bin/env bash
# End-to-end test: 1 headless dedicated server + 6 headless clients in 3 rooms (real game code, scripted input).
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
bot() { # role class name [extra args...]
  local role=$1 cls=$2 name=$3; shift 3
  "$GODOT" --headless "${PATHARG[@]}" -- --autotest --connect=127.0.0.1:$PORT --role=$role --class=$cls --profile=$name --name=$name \
    ${BOT_ARGS:-} "$@" --expect=${EXPECT:-4} --report="$OUT/$name.json" --timeout=240 > "$OUT/$name.log" 2>&1 &
  PIDS+=($!)
}
PIDS=()
# Room "Alpha": full squad of 4 (leader deploys 8 s after everyone is ready so the prober can inspect the full room)
bot leader assault Leader --room=Alpha --deploy-delay=8; sleep 1
bot casualty medic Casualty1 --room=Alpha
bot member support Support1 --room=Alpha
bot leaver recon Leaver1 --room=Alpha
# 5th client: room browser filters, full-room rejection, password room "Bravo", room cleanup
sleep 1; bot prober assault Prober1
# 6th client: wrong password on "Bravo", then runs a second concurrent mission alone in room "Charlie"
sleep 6; EXPECT=1 bot leader recon Leader2 --room=Charlie --probe-password-room=Bravo
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
