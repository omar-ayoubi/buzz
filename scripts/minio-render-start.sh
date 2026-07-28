#!/bin/sh
# Start MinIO, create the Buzz media bucket, then keep the server in the foreground.
set -eu

PORT="${PORT:-10000}"
BUCKET="${BUZZ_S3_BUCKET:-buzz-media}"
DATA_DIR="${MINIO_DATA_DIR:-/data}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:?MINIO_ROOT_USER is required}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD is required}"

mkdir -p "${DATA_DIR}"

minio server "${DATA_DIR}" --address "0.0.0.0:${PORT}" &
MINIO_PID=$!

cleanup() {
  kill "${MINIO_PID}" 2>/dev/null || true
}
trap cleanup INT TERM

echo "Waiting for MinIO on :${PORT}..."
i=0
until mc alias set local "http://127.0.0.1:${PORT}" "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "${i}" -ge 60 ]; then
    echo "MinIO did not become ready in time" >&2
    cleanup
    exit 1
  fi
  sleep 1
done

mc mb --ignore-existing "local/${BUCKET}"
mc anonymous set none "local/${BUCKET}" || true
echo "Bucket ready: ${BUCKET}"

wait "${MINIO_PID}"
