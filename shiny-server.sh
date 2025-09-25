#!/bin/sh
# Pick Cloud Run's PORT or fall back to 8080 locally
PORT="${PORT:-8080}"
sed -i "s/__PORT__/${PORT}/" /etc/shiny-server/shiny-server.conf

exec shiny-server >> /var/log/shiny-server.log 2>&1
