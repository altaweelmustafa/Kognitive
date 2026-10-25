#!/bin/sh
# Builds the website and copies it to the server, where the backend serves it
# at its own address (http://100.105.90.110:8000/ on the tailnet).
# Deploy the backend first if it has changed (scripts/deploy_backend.sh).
# Asks for the server password. No restart needed.
set -e
HOST=${KOGNITIV_HOST:-debian@100.105.90.110}
DIR=apps/kognitiv/backend/web
cd "$(dirname "$0")/.."
# The website talks to the server it was loaded from, so no API address is
# baked in. CanvasKit is bundled rather than fetched from Google's CDN.
flutter build web --release --no-web-resources-cdn
tar -C build/web -czf - . |
  ssh "$HOST" "rm -rf $DIR.new && mkdir -p $DIR.new && tar -xzf - -C $DIR.new && rm -rf $DIR && mv $DIR.new $DIR"
echo "Website deployed: http://${HOST#*@}:8000/"
