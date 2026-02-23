#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$SCRIPT_DIR/docker"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
IMAGE_NAME="devo_pc_pipline_image"
SERVICE_NAME="ros-desktop"
CONTAINER_NAME="DEVO_PC_pipline"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

wait_for_user_to_read_hints() {
  local seconds=10
  echo "Starting in ${seconds}s... press Ctrl+C to cancel."
  while ((seconds > 0)); do
    printf "\rStarting in %2ss... press Ctrl+C to cancel." "$seconds"
    sleep 1
    ((seconds--))
  done
  printf "\rStarting now...                             \n"
}

ask_build_cache_mode() {
  while true; do
    read -r -p "Build with Docker cache? [Y/n]: " choice
    case "${choice:-Y}" in
      [Yy]|[Yy][Ee][Ss]) BUILD_NO_CACHE=0; return 0 ;;
      [Nn]|[Nn][Oo]) BUILD_NO_CACHE=1; return 0 ;;
      *)
        echo "Please answer y (with cache) or n (without cache)."
        ;;
    esac
  done
}

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or not in PATH. Please install Docker first."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is not available."
  echo "Please install/enable Docker Compose v2 and try again."
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose file not found: $COMPOSE_FILE"
  exit 1
fi

if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "Image '$IMAGE_NAME' exists. Starting container..."
  echo "Hint: initial container setup may still take up to ~20 minutes on first run."
  echo "Check logs if needed:"
  echo "  docker compose -f \"$COMPOSE_FILE\" logs -f $SERVICE_NAME"
  echo "  docker logs -f $CONTAINER_NAME"
  wait_for_user_to_read_hints
  (cd "$COMPOSE_DIR" && docker compose up -d)
else
  echo "Image '$IMAGE_NAME' not found. Building image and starting container..."
  echo "Hint: image build time depends on your machine and can take a while."
  echo "Hint: after build, first-run initialization in the container can take up to ~20 minutes."
  ask_build_cache_mode
  if [[ "$BUILD_NO_CACHE" -eq 1 ]]; then
    BUILD_FLAGS="--no-cache"
    echo "Build mode: without Docker cache."
  else
    BUILD_FLAGS=""
    echo "Build mode: with Docker cache."
  fi
  echo "Check logs if needed:"
  echo "  docker compose -f \"$COMPOSE_FILE\" logs -f $SERVICE_NAME"
  echo "  docker logs -f $CONTAINER_NAME"
  wait_for_user_to_read_hints
  (cd "$COMPOSE_DIR" && env UID="$HOST_UID" GID="$HOST_GID" docker compose build $BUILD_FLAGS && docker compose up -d)
fi

echo "Container startup command completed."
