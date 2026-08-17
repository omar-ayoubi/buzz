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

# Render can bounce Postgres while this container is already starting:
# service resume wakes the DB after the web dyno, and a Blueprint sync can
# issue a fast shutdown mid-deploy. buzz-relay treats the first failed
# handshake as fatal (`expected to read 5 bytes, got 0 bytes at EOF`), so
# retry here and keep PID 1 alive until Postgres accepts connections.
max_attempts="${BUZZ_START_RETRIES:-15}"
attempt=1
while :; do
  /usr/local/bin/buzz-relay && exit 0
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "buzz-relay failed after ${max_attempts} attempts" >&2
    exit 1
  fi
  echo "buzz-relay exited; retry ${attempt}/${max_attempts} in 4s (waiting for Postgres)" >&2
  attempt=$((attempt + 1))
  sleep 4
done
