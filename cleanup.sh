#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/docker/docker-compose.yml" ]]; then
  PROJECT_ROOT="$SCRIPT_DIR"
  COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
elif [[ -f "$SCRIPT_DIR/../docker/docker-compose.yml" ]]; then
  PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
else
  PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
fi

WORKSPACE_DIR="$PROJECT_ROOT/workspace"
IMAGE_NAME="devo_pc_pipline_image"
CONTAINER_NAME="DEVO_PC_pipline"

DO_DOCKER_CLEAN=true
DO_WORKSPACE_CLEAN=true
ASSUME_YES=false

usage() {
  cat <<'EOF'
Usage: cleanup.sh [OPTIONS]

Options:
  --docker-only      Clean Docker artifacts only
  --workspace-only   Clean project workspace only
  -y, --yes          Skip confirmation prompt
  -h, --help         Show this help

Notes:
  - Docker cleanup removes only this project's resources:
      docker compose down --remove-orphans --rmi local
      docker rm -f DEVO_PC_pipline (if present)
      docker rmi devo_pc_pipline_image (if present)
  - Workspace cleanup removes contents of:
      <project-root>/workspace/*
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker-only)
      DO_DOCKER_CLEAN=true
      DO_WORKSPACE_CLEAN=false
      shift
      ;;
    --workspace-only)
      DO_DOCKER_CLEAN=false
      DO_WORKSPACE_CLEAN=true
      shift
      ;;
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$DO_DOCKER_CLEAN" == false && "$DO_WORKSPACE_CLEAN" == false ]]; then
  echo "Nothing to clean."
  exit 0
fi

echo "Cleanup plan:"
if [[ "$DO_DOCKER_CLEAN" == true ]]; then
  echo "  - Docker artifacts (containers/images/networks/cache)"
fi
if [[ "$DO_WORKSPACE_CLEAN" == true ]]; then
  echo "  - Workspace contents: $WORKSPACE_DIR/*"
fi

if [[ "$ASSUME_YES" == false ]]; then
  read -r -p "Proceed? [y/N]: " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Canceled."
    exit 0
  fi
fi

if [[ "$DO_DOCKER_CLEAN" == true ]]; then
  if command -v docker >/dev/null 2>&1; then
    echo "[cleanup] Removing Docker resources related to this project only..."

    if docker compose version >/dev/null 2>&1 && [[ -f "$COMPOSE_FILE" ]]; then
      echo "[cleanup] Stopping compose services..."
      # Ensure we `cd` into the directory that contains the docker-compose.yml
      COMPOSE_DIR="$(dirname "$COMPOSE_FILE")"
      (cd "$COMPOSE_DIR" && docker compose down --remove-orphans --rmi local || true)
    fi

    if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
      echo "[cleanup] Removing container: $CONTAINER_NAME"
      docker rm -f "$CONTAINER_NAME" || true
    fi

    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
      echo "[cleanup] Removing image: $IMAGE_NAME"
      docker rmi "$IMAGE_NAME" || true
    fi
  else
    echo "[cleanup] Docker not found. Skipping Docker cleanup."
  fi
fi

if [[ "$DO_WORKSPACE_CLEAN" == true ]]; then
  if [[ -d "$WORKSPACE_DIR" ]]; then
    echo "[cleanup] Removing workspace contents..."
    rm -rf "${WORKSPACE_DIR:?}/"*
  else
    echo "[cleanup] Workspace directory not found: $WORKSPACE_DIR"
  fi
fi

echo "Cleanup completed."
