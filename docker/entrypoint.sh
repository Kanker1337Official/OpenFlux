#!/bin/sh
set -eu

role="${ROLE:-exit-node}"
transport="${TRANSPORT:-vyandex}"
codec="${CODEC:-batched}"
mode="${MODE:-l4}"

if [ "$role" = exit ]; then
  role=exit-node
fi

set -- "--$role" --transport "$transport" --codec "$codec" --mode "$mode"

[ -n "${URL:-}" ] && set -- "$@" --url "$URL"
[ -n "${MAX_TOKEN:-}" ] && set -- "$@" --maxToken "$MAX_TOKEN"
[ -n "${MAX_UID:-}" ] && set -- "$@" --maxUid "$MAX_UID"
case "${DEBUG:-0}" in
  1|true|yes) set -- "$@" --debug ;;
esac

echo "[entrypoint] dropping outbound TCP RSTs inside the container netns"
iptables -A OUTPUT -p tcp --tcp-flags RST RST -j DROP 2>/dev/null || \
  echo "[entrypoint] WARNING: iptables failed (missing NET_ADMIN?)" >&2

RESTART_EVERY="${RESTART_EVERY:-7200}"

while true; do
  echo "[entrypoint] exec: openflux $*"
  openflux "$@" &
  pid=$!
  echo "[entrypoint] pid=$pid, restart in ${RESTART_EVERY}s"
  sleep "$RESTART_EVERY" &
  sleep_pid=$!
  wait "$pid" || true
  kill "$sleep_pid" 2>/dev/null || true
  wait "$sleep_pid" 2>/dev/null || true
  if kill -0 "$pid" 2>/dev/null; then
    echo "[entrypoint] scheduled restart, killing $pid"
    kill "$pid" 2>/dev/null || true
    sleep 2
    kill -9 "$pid" 2>/dev/null || true
  fi
  echo "[entrypoint] restarting openflux"
  sleep 3
done
