#!/bin/sh
set -eu

role="${ROLE:-exit-node}"
transport="${TRANSPORT:-vyandex}"
codec="${CODEC:-batched}"
mode="${MODE:-l4}"
RESTART_EVERY="${RESTART_EVERY:-7200}"

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

while true; do
  echo "[entrypoint] exec: timeout ${RESTART_EVERY}s openflux $*"
  timeout "$RESTART_EVERY" openflux "$@" || true
  echo "[entrypoint] killed after ${RESTART_EVERY}s, restarting in 3s"
  sleep 3
done
