#!/usr/bin/env bash
set -euo pipefail

# ---- Create folders/files (safe if volume-mounted) ----
export WORKSPACE="${WORKSPACE:-/home/ros/workspace}"
export ROS1_WS="${ROS1_WS:-$WORKSPACE/ros1_ws}"
export ROS2_WS="${ROS2_WS:-$WORKSPACE/ros2_ws}"

# Create directories as the 'ros' user
mkdir -p "$ROS1_WS/src" "$ROS2_WS/src" "$WORKSPACE/shared" "/home/ros/.ros"
touch "/home/ros/.bashrc" "/home/ros/.zshrc"

# Ensure system ROS selector is sourced
if ! grep -q "ros_select.sh" "/home/ros/.bashrc"; then
  echo '[ -f /etc/profile.d/ros_select.sh ] && . /etc/profile.d/ros_select.sh' >> "/home/ros/.bashrc"
fi
if ! grep -q "ros_select.sh" "/home/ros/.zshrc"; then
  echo '[ -f /etc/profile.d/ros_select.sh ] && . /etc/profile.d/ros_select.sh' >> "/home/ros/.zshrc"
fi

# ---- SSH Setup (Strictly in /home/ros) ----
mkdir -p /home/ros/.ssh
chmod 700 /home/ros/.ssh
touch /home/ros/.ssh/known_hosts
chmod 600 /home/ros/.ssh/known_hosts

# Add github.com key to known_hosts if not present
ssh-keygen -F github.com >/dev/null 2>&1 || ssh-keyscan -H github.com >> /home/ros/.ssh/known_hosts

# ---- Select default ROS version ----
export ROS_DEFAULT_VERSION="${ROS_DEFAULT_VERSION:-1}"
if [ -f /etc/profile.d/ros_select.sh ]; then
  . /etc/profile.d/ros_select.sh
fi

# ---- GPU visibility check ----
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "[INFO] GPU detected in container (nvidia-smi):"
  nvidia-smi || true
fi

# ---- Project auto-setup ----
SHARED_DIR="$WORKSPACE/shared"
DEVO_DIR="$SHARED_DIR/DEVO-point-cloud"
EMVS_DIR="$SHARED_DIR/rpg_emvs"
EMVS_WS="$SHARED_DIR/emvs_ws"

if [ -f /opt/conda/etc/profile.d/conda.sh ]; then
  . /opt/conda/etc/profile.d/conda.sh
fi

# 1) Clone repos if missing
# Redirection ensures https is used even for ssh urls
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"

if [ ! -d "$DEVO_DIR/.git" ]; then
  echo "[SETUP] Cloning DEVO-point-cloud..."
  git clone --recursive https://github.com/FiveTe/DEVO-point-cloud.git "$DEVO_DIR"
fi

if [ ! -d "$EMVS_DIR/.git" ]; then
  echo "[SETUP] Cloning rpg_emvs..."
  git clone https://github.com/uzh-rpg/rpg_emvs.git "$EMVS_DIR"
fi

# 2) Build rpg_emvs (ROS1 / Noetic)
if [ ! -f "$EMVS_WS/devel/setup.bash" ]; then
  echo "[SETUP] Building rpg_emvs (catkin)..."

  # --- CRITICAL: isolate from Conda ---
  unset PYTHONPATH
  set +u
  if command -v conda >/dev/null 2>&1; then
    conda deactivate || true
  fi
  source /opt/ros/noetic/setup.bash
  set -u

  # Create workspace structure (keep build artifacts on volume)
  mkdir -p "$EMVS_WS/src"
  cd "$EMVS_WS"

  # Find correct empy executable
  EMPY_BIN="$(command -v empy || command -v empy3)"

  # Configure catkin workspace
  catkin config --init --mkdirs --extend /opt/ros/noetic --merge-devel \
    --cmake-args \
      -DCMAKE_BUILD_TYPE=Release \
      -DPYTHON_EXECUTABLE=/usr/bin/python3 \
      -DEMPY_EXECUTABLE="${EMPY_BIN}"

  # Link EMVS repo into src
  cd "$EMVS_WS/src"
  ln -sf "$EMVS_DIR" rpg_emvs

  # Ensure HTTPS is used for dependencies
  sed -i 's#git@github.com:#https://github.com/#g' rpg_emvs/dependencies.yaml
  vcs-import < rpg_emvs/dependencies.yaml

  # Skip packages that require libcaer and missing python build tool
  cd "$EMVS_WS"
  catkin config --skiplist davis_ros_driver dvs_ros_driver dvxplorer_ros_driver minkindr_python

  # Build
  catkin build
fi

# Always source EMVS overlay (even if it already existed)
source /opt/ros/noetic/setup.bash
source "$EMVS_WS/devel/setup.bash"

# Optional: make it persistent for interactive shells
grep -q "$EMVS_WS/devel/setup.bash" /home/ros/.bashrc || echo "source $EMVS_WS/devel/setup.bash" >> /home/ros/.bashrc
grep -q "$EMVS_WS/devel/setup.bash" /home/ros/.zshrc  || echo "source $EMVS_WS/devel/setup.bash"  >> /home/ros/.zshrc

# 3) Install DEVO conda env
if ! conda env list | awk '{print $1}' | grep -qx "devo"; then
  echo "[SETUP] Creating conda env for DEVO..."
  cd "$DEVO_DIR"
  conda env create -f environment.yml
fi

cd "$DEVO_DIR"
conda activate devo

echo "[SETUP] Installing DEVO core dependencies (torch, etc.)..."
conda install -y pytorch torchvision torchaudio cudatoolkit=11.3 -c pytorch

if [ ! -d "$DEVO_DIR/thirdparty/eigen-3.4.0" ] && [ ! -d "$DEVO_DIR/thirdparty/eigen-eigen-3.4.0" ]; then
  echo "[SETUP] Downloading Eigen..."
  wget -O /tmp/eigen-3.4.0.zip https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.zip
  unzip -o /tmp/eigen-3.4.0.zip -d "$DEVO_DIR/thirdparty"
  rm -f /tmp/eigen-3.4.0.zip
fi

pip install -U pip
pip install --no-build-isolation .
pip install -U open3d
pip install -U rosbags
conda deactivate

cd "/home/ros"

echo -e "\e[32m"
echo "=========================================="
echo "✓ Setup complete!"
echo "✓ Build finished and environment ready"
echo "=========================================="
echo "Starting VNC server..."
echo -e "\e[0m"

# ---- VNC/noVNC ----
VNC_PASS="${VNC_PASS:-ros}"
mkdir -p ~/.vnc
echo "${VNC_PASS}" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true
vncserver -kill :1 >/dev/null 2>&1 || true

vncserver :1 -geometry "${VNC_GEOMETRY:-1440x900}" -depth "${VNC_DEPTH:-24}" -localhost no
websockify --web=/usr/share/novnc/ "${NOVNC_PORT:-6080}" localhost:"${VNC_PORT:-5901}" &

exec "${SHELL:-/usr/bin/zsh}" -l