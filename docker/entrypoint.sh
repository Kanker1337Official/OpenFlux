#!/bin/sh
set -eu

role="${ROLE:-exit-node}"
transport="${TRANSPORT:-vyandex}"
listen="${SOCKS5_LISTEN:-:1080}"
codec="${CODEC:-batched}"
mode="${MODE:-l4}"

case "$role" in
  client|exit-node|exit) ;;
  *)
    echo "ROLE must be client, exit-node or exit (got '$role')" >&2
    exit 2
    ;;
esac

if [ "$role" = exit ]; then
  role=exit-node
fi

case "$transport" in
  yandex|vyandex|oneme|cupsonline|mailru) ;;
  *)
    echo "TRANSPORT invalid: $transport" >&2
    exit 2
    ;;
esac

case "$codec" in
  batched|legacy) ;;
  *)
    echo "CODEC must be batched or legacy (got '$codec')" >&2
    exit 2
    ;;
esac

case "$mode" in
  l3|l4|proxy|raw)
    if [ "$mode" = proxy ]; then mode=l4; fi
    if [ "$mode" = raw ]; then mode=l3; fi
    ;;
  *)
    echo "MODE must be l4 or l3 (got '$mode')" >&2
    exit 2
    ;;
esac

set -- "--$role" --transport "$transport" --codec "$codec"

if [ "$role" = exit-node ]; then
  set -- "$@" --mode "$mode"
fi

if [ "$role" = client ]; then
  set -- "$@" --socks5 "$listen"
fi

if [ -n "${URL:-}" ]; then
  set -- "$@" --url "$URL"
fi
if [ -n "${MAX_TOKEN:-}" ]; then
  set -- "$@" --maxToken "$MAX_TOKEN"
fi
if [ -n "${MAX_UID:-}" ]; then
  set -- "$@" --maxUid "$MAX_UID"
fi
if [ -n "${LOCAL_IP:-}" ]; then
  set -- "$@" --local-ip "$LOCAL_IP"
fi
case "${DEBUG:-0}" in
  1|true|yes) set -- "$@" --debug ;;
esac

if [ "$role" = exit-node ]; then
  echo "[entrypoint] dropping outbound TCP RSTs inside the container netns"
  if ! iptables -A OUTPUT -p tcp --tcp-flags RST RST -j DROP; then
    echo "[entrypoint] WARNING: iptables failed (missing NET_ADMIN?)" >&2
  fi
fi

echo "[entrypoint] exec: openflux $*"
exec openflux "$@"
