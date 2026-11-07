#!/usr/bin/env bash
# Offline test harness for ssh-sshhole.nse.
#
# Serves fake SSH identification banners on local ports and runs the script
# against them, asserting the expected verdict for each banner shape. No real
# SSH server and no bypass are involved -- it only checks the detection logic.
#
# Usage: ./run_tests.sh [path-to-ssh-sshhole.nse]   (default: ../ssh-sshhole.nse)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
NSE=${1:-$HERE/../ssh-sshhole.nse}
SRV=$HERE/banner_server.py
PORT=${BASE_PORT:-13900}
fails=0

command -v nmap >/dev/null || { echo "nmap not found"; exit 2; }
[ -f "$NSE" ] || { echo "script not found: $NSE"; exit 2; }

# nmap derives a script's ID from its filename. If an identically named copy is
# installed system-wide, "--script <path>" clashes ("duplicate script ID"). Copy
# the target to a uniquely named temp file so we always test THIS file in isolation.
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT
TESTNSE="$TMPD/ssh-sshhole-selftest.nse"
cp "$NSE" "$TESTNSE"

run() { # banner  expected-substring  label
  local banner="$1" expect="$2" label="$3" port=$((PORT++))
  python3 "$SRV" "$port" "$banner" >/dev/null 2>&1 &
  local pid=$!; sleep 0.4
  local out
  out=$(nmap -p "$port" -Pn -sV --script "$TESTNSE" 127.0.0.1 2>/dev/null \
        | grep -E 'VULNERABLE|NOT_VULNERABLE|Not OpenSSH')
  kill "$pid" 2>/dev/null
  if printf '%s' "$out" | grep -qF "$expect"; then
    printf 'PASS  %-34s %s\n' "$label" "$(printf '%s' "$out" | head -1 | sed 's/^ *| *//')"
  else
    printf 'FAIL  %-34s got: %s\n' "$label" "$out"; fails=$((fails+1))
  fi
}

run "SSH-2.0-OpenSSH_10.3"                      "VULNERABLE: LIKELY"   "alpine-shape (no p, no tag)"
run "SSH-2.0-OpenSSH_9.9"                       "VULNERABLE: LIKELY"   "alpine-shape older"
run "SSH-2.0-OpenSSH_10.3p1"                    "VULNERABLE: POSSIBLE" "bare portable"
run "SSH-2.0-OpenSSH_10.3p1 Debian-2+deb12u3"   "NOT_VULNERABLE"       "debian tag"
run "SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13"    "NOT_VULNERABLE"       "ubuntu tag"
run "SSH-2.0-OpenSSH_9.3p1 FreeBSD-20240806"    "NOT_VULNERABLE"       "freebsd tag"
run "SSH-2.0-OpenSSH_7.3p1"                     "VULNERABLE: POSSIBLE" "lower boundary (7.3p1)"
run "SSH-2.0-OpenSSH_7.2p1"                     "NOT_VULNERABLE"       "below range (7.2p1)"
run "SSH-2.0-OpenSSH_10.6p1"                    "VULNERABLE: POSSIBLE" "upper boundary (10.6p1)"
run "SSH-2.0-OpenSSH_10.6p2"                    "NOT_VULNERABLE"       "fixed (10.6p2)"
run "SSH-2.0-dropbear_2022.83"                  "Not OpenSSH"          "non-openssh"

echo
if [ "$fails" -eq 0 ]; then echo "all tests passed"; else echo "$fails test(s) failed"; fi
exit "$fails"
