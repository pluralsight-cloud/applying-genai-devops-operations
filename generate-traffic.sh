#!/bin/bash

# ──────────────────────────────────────────────────────────────
# generate-traffic.sh
#
# Generates synthetic traffic against the payment-api by calling
# its public endpoints in a loop. Useful for populating metrics,
# exercising the service, and smoke-testing a deployment.
#
# Usage:
#   ./generate-traffic.sh <BASE_URL> [options]
#
# Examples:
#   ./generate-traffic.sh http://localhost:3000
#   ./generate-traffic.sh https://payment-api.example.com -d 120 -c 5
#   ./generate-traffic.sh http://localhost:3000 --duration 60 --concurrency 10 --delay 0.2
#
# Options:
#   -d, --duration <seconds>     How long to generate traffic (default: 60).
#                                Use 0 to run until interrupted (Ctrl-C).
#   -c, --concurrency <n>        Number of parallel workers (default: 4).
#   -r, --delay <seconds>        Delay between requests per worker (default: 0.1).
#   -h, --help                   Show this help message.
# ──────────────────────────────────────────────────────────────

set -u

# ── Defaults ──────────────────────────────────────────────────
DURATION=60
CONCURRENCY=4
DELAY=0.1
BASE_URL=""

usage() {
  sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# ── Parse arguments ───────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--duration)
      DURATION="$2"; shift 2 ;;
    -c|--concurrency)
      CONCURRENCY="$2"; shift 2 ;;
    -r|--delay)
      DELAY="$2"; shift 2 ;;
    -h|--help)
      usage 0 ;;
    -*)
      echo "Unknown option: $1" >&2; usage 1 ;;
    *)
      if [[ -z "$BASE_URL" ]]; then
        BASE_URL="$1"; shift
      else
        echo "Unexpected argument: $1" >&2; usage 1
      fi
      ;;
  esac
done

if [[ -z "$BASE_URL" ]]; then
  echo "Error: BASE_URL is required." >&2
  echo "" >&2
  usage 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required but not installed." >&2
  exit 1
fi

# Strip any trailing slash from the base URL.
BASE_URL="${BASE_URL%/}"

# ── Counters (shared via temp files across subshells) ─────────
TMP_DIR="$(mktemp -d)"
SUCCESS_FILE="$TMP_DIR/success"
ERROR_FILE="$TMP_DIR/error"
echo 0 > "$SUCCESS_FILE"
echo 0 > "$ERROR_FILE"

cleanup() {
  # Stop workers and print a summary on exit.
  RUNNING=0
  kill 0 2>/dev/null
  local ok err
  ok="$(cat "$SUCCESS_FILE" 2>/dev/null || echo 0)"
  err="$(cat "$ERROR_FILE" 2>/dev/null || echo 0)"
  echo ""
  echo "──────────────────────────────────────────"
  echo "Traffic generation complete."
  echo "  Successful responses (2xx/3xx): $ok"
  echo "  Error responses (4xx/5xx/fail): $err"
  echo "──────────────────────────────────────────"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# Generate a random amount between 1.00 and 500.00.
random_amount() {
  awk 'BEGIN { srand(); printf "%.2f", 1 + rand() * 499 }'
}

# Make a request, record the result, and log a one-line summary.
# Args: METHOD PATH [JSON_BODY]
do_request() {
  local method="$1" path="$2" body="${3:-}"
  local code

  if [[ -n "$body" ]]; then
    code="$(curl -s -o /dev/null -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" \
      -H 'Content-Type: application/json' \
      -d "$body" 2>/dev/null)"
  else
    code="$(curl -s -o /dev/null -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" 2>/dev/null)"
  fi

  # An empty code means curl failed to connect.
  if [[ -z "$code" ]]; then
    code="000"
  fi

  if [[ "$code" =~ ^[23] ]]; then
    flock "$SUCCESS_FILE" -c "echo \$(( \$(cat $SUCCESS_FILE) + 1 )) > $SUCCESS_FILE" 2>/dev/null \
      || echo $(( $(cat "$SUCCESS_FILE") + 1 )) > "$SUCCESS_FILE"
  else
    flock "$ERROR_FILE" -c "echo \$(( \$(cat $ERROR_FILE) + 1 )) > $ERROR_FILE" 2>/dev/null \
      || echo $(( $(cat "$ERROR_FILE") + 1 )) > "$ERROR_FILE"
  fi

  printf '[%s] %-4s %-28s -> %s\n' "$(date '+%H:%M:%S')" "$method" "$path" "$code"
}

# One full cycle of mixed, realistic traffic.
worker_cycle() {
  local amount tx
  amount="$(random_amount)"

  # Health/readiness checks (lightweight, frequent).
  do_request GET  "/health"
  do_request GET  "/ready"

  # Checkout flow.
  do_request POST "/api/checkout" "{\"amount\": $amount}"

  # Direct payment processing.
  amount="$(random_amount)"
  do_request POST "/api/payment/process" "{\"amount\": $amount}"

  # Status lookup (uses a random id; service returns a status either way).
  tx="tx_$RANDOM$RANDOM"
  do_request GET  "/api/payment/status?transactionId=$tx"

  # Occasional invalid request to generate some 4xx traffic.
  if (( RANDOM % 5 == 0 )); then
    do_request POST "/api/checkout" "{\"amount\": -1}"
  fi

  # Misc endpoints.
  do_request GET  "/test"
}

# A single worker loops until the deadline (or forever if duration is 0).
worker() {
  while :; do
    if [[ "$DURATION" -ne 0 && "$(date +%s)" -ge "$DEADLINE" ]]; then
      break
    fi
    worker_cycle
    sleep "$DELAY"
  done
}

# ── Run ───────────────────────────────────────────────────────
START="$(date +%s)"
DEADLINE=$(( START + DURATION ))

echo "──────────────────────────────────────────"
echo "Generating traffic against: $BASE_URL"
if [[ "$DURATION" -eq 0 ]]; then
  echo "  Duration:    until interrupted (Ctrl-C)"
else
  echo "  Duration:    ${DURATION}s"
fi
echo "  Concurrency: $CONCURRENCY worker(s)"
echo "  Delay:       ${DELAY}s between requests per worker"
echo "──────────────────────────────────────────"

for ((i = 0; i < CONCURRENCY; i++)); do
  worker &
done

wait
