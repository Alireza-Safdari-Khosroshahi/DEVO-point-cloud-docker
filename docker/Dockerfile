# syntax=docker/dockerfile:1
# NVIDIA CUDA base image (host must have an NVIDIA GPU + NVIDIA Container Toolkit installed)
# CUDA version: 11.4
FROM nvidia/cuda:11.4.3-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Let the NVIDIA runtime expose GPU devices + driver capabilities
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics

# Base tools + desktop/VNC dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 lsb-release ca-certificates sudo \
    python3 python3-pip \
    git vim nano fish zsh \
    xfce4 xfce4-terminal dbus-x11 x11-xserver-utils \
    tigervnc-standalone-server tigervnc-common \
    novnc websockify \
    libgl1-mesa-glx libgl1-mesa-dri libglu1-mesa \
    pciutils \
  && rm -rf /var/lib/apt/lists/*

# ---- Force GitHub SSH -> HTTPS (for vcs-import) ----
RUN git config --system url."https://github.com/".insteadOf "git@github.com:" \
 && git config --system url."https://github.com/".insteadOf "ssh://git@github.com/"
ENV GIT_TERMINAL_PROMPT=0

# Create user
ARG USER=ros
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} ${USER} && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USER} \
 && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}

# ROS apt keys + sources
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common \
 && rm -rf /var/lib/apt/lists/*

# ROS 1 Noetic repo (Ubuntu 20.04)
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - \
 && echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros1.list

# ROS 2 Foxy repo (Ubuntu 20.04)
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key | apt-key add - \
 && echo "deb http://packages.ros.org/ros2/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros2.list

# Install ROS1 + ROS2 + common build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-noetic-desktop-full \
    ros-noetic-rosbridge-server \
    python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool build-essential \
    ros-foxy-desktop \
    python3-colcon-common-extensions \
    # --- add for rpg_emvs ---
    python3-catkin-tools python3-vcstool \
    ros-noetic-pcl-ros \
    # --- add for DEVO + general ---
    wget unzip cmake pkg-config \
  && rm -rf /var/lib/apt/lists/*

# rosdep init (system-wide)
RUN mkdir -p /etc/ros/rosdep/sources.list.d \
 && rosdep init \
 && rosdep update

# ===== ROS environment selector (system-wide) =====
# Provides:
# - use_ros1 / use_ros2 functions for interactive shells
# - default sourcing via ROS_DEFAULT_VERSION (1 or 2), defaults to 1 (ROS1 Noetic)

# Make bash and zsh load /etc/profile.d scripts for non-login shells as well.
RUN bash -lc "printf '\n# Load system ROS selector\n[ -f /etc/profile.d/ros_select.sh ] && . /etc/profile.d/ros_select.sh\n' >> /etc/skel/.bashrc" \
 && bash -lc "printf '\n# Load system ROS selector\n[ -f /etc/profile.d/ros_select.sh ] && . /etc/profile.d/ros_select.sh\n' >> /etc/skel/.zshrc"

# VNC/noVNC settings
ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV NOVNC_PORT=6080
ENV VNC_GEOMETRY=1440x900
ENV VNC_DEPTH=24

# Set XFCE as session for VNC
RUN mkdir -p /etc/X11/xinit && \
    printf '#!/bin/sh\nstartxfce4\n' > /etc/X11/xinit/xinitrc && chmod +x /etc/X11/xinit/xinitrc

# Helpful GPU check utility
RUN printf '#!/bin/sh\nset -e\nif command -v nvidia-smi >/dev/null 2>&1; then\n  nvidia-smi\nelse\n  echo "nvidia-smi not found (GPU runtime likely not enabled)"\n  exit 1\nfi\n' \
  > /usr/local/bin/gpu-check && chmod +x /usr/local/bin/gpu-check

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch to user and initialize default dotfiles
USER ${USER}
WORKDIR /home/${USER}

# Ensure user's shell init files exist and source ros_select.sh
RUN bash -lc "touch ~/.bashrc ~/.zshrc && \
  grep -q 'ros_select.sh' ~/.bashrc || echo '[ -f /etc/profile.d/ros_select.sh ] && . /etc/profile.d/ros_select.sh' >> ~/.bashrc && \
  grep -q 'ros_select.sh' ~/.zshrc  || echo '[ -f /etc/profile.d/ros_select.sh ] && . /etc/profile.d/ros_select.sh'  >> ~/.zshrc"

# ---- Miniconda (for DEVO) ----
USER root
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

RUN curl -fsSL -o /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
 && bash /tmp/miniconda.sh -b -p $CONDA_DIR \
 && rm -f /tmp/miniconda.sh \
 && $CONDA_DIR/bin/conda config --system --set auto_activate_base false \
 && $CONDA_DIR/bin/conda clean -afy \
 && chown -R ros:ros $CONDA_DIR

# Make conda available in interactive shells (bash + zsh, for new users)
RUN printf '\n# Conda\n[ -f /opt/conda/etc/profile.d/conda.sh ] && . /opt/conda/etc/profile.d/conda.sh\n' \
  >> /etc/skel/.bashrc \
 && printf '\n# Conda\n[ -f /opt/conda/etc/profile.d/conda.sh ] && . /opt/conda/etc/profile.d/conda.sh\n' \
  >> /etc/skel/.zshrc

# Make conda available for the existing ros user (bash + zsh)
USER ros
RUN printf '\n# Conda\n[ -f /opt/conda/etc/profile.d/conda.sh ] && . /opt/conda/etc/profile.d/conda.sh\n' \
  >> /home/ros/.bashrc \
 && printf '\n# Conda\n[ -f /opt/conda/etc/profile.d/conda.sh ] && . /opt/conda/etc/profile.d/conda.sh\n' \
  >> /home/ros/.zshrc

USER ros

RUN RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
 && sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' /home/ros/.zshrc \
 && printf '\n# Convenience aliases\nalias ll="ls -alF"\n' >> /home/ros/.zshrc

RUN sed -i 's/^plugins=(git)/plugins=(git docker)/' /home/ros/.zshrc
USER root
RUN chsh -s /usr/bin/zsh ros
SHELL ["/usr/bin/zsh", "-lc"]
USER ros
ENTRYPOINT ["/entrypoint.sh"]
