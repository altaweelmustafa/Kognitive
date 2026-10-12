#!/bin/sh
# Copies backend/ to the server and restarts the service.
# Asks for the server password (ssh, then sudo).
set -e
HOST=${KOGNITIV_HOST:-debian@100.105.90.110}
DIR=apps/kognitiv/backend
cd "$(dirname "$0")/../backend"
tar --exclude .venv --exclude '*.db' --exclude __pycache__ --exclude .pytest_cache -czf - . |
  ssh "$HOST" "mkdir -p $DIR && tar -xzf - -C $DIR && cd $DIR && python3 -m venv .venv && .venv/bin/pip install -q -r requirements.txt"
ssh -t "$HOST" "sudo systemctl restart kognitiv-backend && sleep 2 && systemctl is-active kognitiv-backend"
