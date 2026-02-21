#!/usr/bin/env bash
set -euo pipefail

# ---- Create folders/files (safe if volume-mounted) ----
export WORKSPACE="${WORKSPACE:-/home/ros/workspace}"
export ROS1_WS="${ROS1_WS:-$WORKSPACE/ros1_ws}"
export ROS2_WS="${ROS2_WS:-$WORKSPACE/ros2_ws}"

mkdir -p "$ROS1_WS/src" "$ROS2_WS/src" "$WORKSPACE/shared" "/home/ros/.ros"

# Ensure shell init files exist (some base images don't create them for volume users)
touch "/home/ros/.bashrc" "/home/ros/.zshrc"

# Ensure system ROS selector is sourced for interactive shells
if ! grep -q "ros_select.sh" "/home/ros/.bashrc"; then
  echo '[ -f /etc/profile.d/ros_select.sh ] && . /etc/profile.d/ros_select.sh' >> "/home/ros/.bashrc"
fi
if ! grep -q "ros_select.sh" "/home/ros/.zshrc"; then
  echo '[ -f /etc/profile.d/ros_select.sh ] && . /etc/profile.d/ros_select.sh' >> "/home/ros/.zshrc"
fi

# ---- Select default ROS version for this container process ----
# Set ROS_DEFAULT_VERSION=1 or 2 via docker-compose environment if desired.
export ROS_DEFAULT_VERSION="${ROS_DEFAULT_VERSION:-1}"
# Source selector into this process so subsequent commands have ROS env.
# (This affects only this entrypoint process and children, not your host.)
if [ -f /etc/profile.d/ros_select.sh ]; then
  # shellcheck disable=SC1091
  . /etc/profile.d/ros_select.sh
fi

# ---- Optional GPU visibility check (non-fatal) ----
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "[INFO] GPU detected in container (nvidia-smi):"
  nvidia-smi || true
else
  echo "[WARN] nvidia-smi not found. Container likely not started with GPU support."
fi

# ---- Project auto-setup ----
SHARED_DIR="$WORKSPACE/shared"
DEVO_DIR="$SHARED_DIR/DEVO-point-cloud"
EMVS_DIR="$SHARED_DIR/rpg_emvs"
EMVS_WS="$SHARED_DIR/emvs_ws"

# Ensure conda is available (installed in image)
if [ -f /opt/conda/etc/profile.d/conda.sh ]; then
  # shellcheck disable=SC1091
  . /opt/conda/etc/profile.d/conda.sh
fi

# 1) Clone repos if missing
if [ ! -d "$DEVO_DIR/.git" ]; then
  echo "[SETUP] Cloning DEVO-point-cloud..."
  git clone --recursive https://github.com/FiveTe/DEVO-point-cloud.git "$DEVO_DIR"
fi

if [ ! -d "$EMVS_DIR/.git" ]; then
  echo "[SETUP] Cloning rpg_emvs..."
  git clone https://github.com/uzh-rpg/rpg_emvs.git "$EMVS_DIR"
fi

# 2) Build rpg_emvs (ROS1 / Noetic) if not built yet
if [ ! -f "$EMVS_WS/devel/setup.bash" ]; then
  echo "[SETUP] Building rpg_emvs (catkin)..."
  set +u
  source /opt/ros/noetic/setup.bash
  set -u

  mkdir -p "$EMVS_WS/src"
  cd "$EMVS_WS"

  catkin config --init --mkdirs --extend /opt/ros/noetic --merge-devel --cmake-args -DCMAKE_BUILD_TYPE=Release

  cd "$EMVS_WS/src"
  ln -sf "$EMVS_DIR" rpg_emvs

  # Pull extra dependencies listed by the repo (into emvs_ws/src)
  vcs-import < rpg_emvs/dependencies.yaml

  cd "$EMVS_WS"
  catkin build mapper_emvs
fi

# 3) Install DEVO conda env + package if not installed yet
if ! conda env list | awk '{print $1}' | grep -qx "devo"; then
  echo "[SETUP] Creating conda env for DEVO..."
  cd "$DEVO_DIR"
  conda env create -f environment.yml
fi

# Activate and ensure DEVO is installed
cd "$DEVO_DIR"
conda activate devo

# Ensure Eigen exists (only if missing)
if [ ! -d "$DEVO_DIR/thirdparty/eigen-3.4.0" ] && [ ! -d "$DEVO_DIR/thirdparty/eigen-eigen-3.4.0" ]; then
  echo "[SETUP] Downloading Eigen..."
  wget -O /tmp/eigen-3.4.0.zip https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.zip
  unzip -o /tmp/eigen-3.4.0.zip -d "$DEVO_DIR/thirdparty"
  rm -f /tmp/eigen-3.4.0.zip
fi

# Install DEVO into the env (editable or regular; choose one)
pip install -U pip
pip install .

conda deactivate
cd "/home/ros"
echo "[SETUP] Done."

# ---- VNC/noVNC ----
VNC_PASS="${VNC_PASS:-ros}"
mkdir -p ~/.vnc
echo "${VNC_PASS}" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true
vncserver -kill :1 >/dev/null 2>&1 || true
rm -f ~/.vnc/*.pid ~/.vnc/*.log ~/.Xauthority || true

export DISPLAY="${DISPLAY:-:1}"
vncserver "${DISPLAY}" -geometry "${VNC_GEOMETRY:-1440x900}" -depth "${VNC_DEPTH:-24}" -localhost no
websockify --web=/usr/share/novnc/ "${NOVNC_PORT:-6080}" localhost:"${VNC_PORT:-5901}" &

echo "[INFO] ROS default: ROS_VERSION=${ROS_VERSION:-?} ROS_DISTRO=${ROS_DISTRO:-?} (set ROS_DEFAULT_VERSION=1|2)"
echo "[INFO] VNC on port ${VNC_PORT:-5901}, noVNC on port ${NOVNC_PORT:-6080}"
echo "[INFO] noVNC URL: http://localhost:${NOVNC_PORT:-6080}/vnc.html"
echo "[INFO] VNC password: ${VNC_PASS}"

tail -f /dev/null
