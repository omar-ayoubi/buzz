#!/bin/sh
# Render-friendly entrypoint for the official ghcr.io/block/buzz image.
# Derives public URLs from RENDER_EXTERNAL_HOSTNAME and composes the S3 endpoint
# from the private MinIO hostport Render injects.
set -eu

if [ -n "${RENDER_EXTERNAL_HOSTNAME:-}" ]; then
  export RELAY_URL="${RELAY_URL:-wss://${RENDER_EXTERNAL_HOSTNAME}}"
  export BUZZ_MEDIA_BASE_URL="${BUZZ_MEDIA_BASE_URL:-https://${RENDER_EXTERNAL_HOSTNAME}/media}"
  export BUZZ_CORS_ORIGINS="${BUZZ_CORS_ORIGINS:-https://${RENDER_EXTERNAL_HOSTNAME}}"
  export BUZZ_MEDIA_SERVER_DOMAIN="${BUZZ_MEDIA_SERVER_DOMAIN:-${RENDER_EXTERNAL_HOSTNAME}}"
fi

# Render routes public traffic to $PORT (default 10000).
export BUZZ_BIND_ADDR="${BUZZ_BIND_ADDR:-0.0.0.0:${PORT:-10000}}"

# Blueprint injects MINIO_HOSTPORT as "hostname:port" (no scheme).
if [ -n "${MINIO_HOSTPORT:-}" ] && [ -z "${BUZZ_S3_ENDPOINT:-}" ]; then
  export BUZZ_S3_ENDPOINT="http://${MINIO_HOSTPORT}"
fi

mkdir -p "${BUZZ_GIT_REPO_PATH:-/data/git}"

exec /usr/local/bin/buzz-relay
