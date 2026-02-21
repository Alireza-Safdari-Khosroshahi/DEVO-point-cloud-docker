# DEVO-point-cloud-docker

This repository provides a Dockerized environment for working with the DEVO-point-cloud and rpg_emvs projects, primarily focusing on ROS 1 Noetic with GPU acceleration. It sets up a complete desktop environment (XFCE) accessible via VNC and a web browser (noVNC), along with all necessary dependencies and tools.

## Features

*   **GPU Accelerated:** Built on `nvidia/cuda` base image, enabling full GPU support within the container.
*   **ROS 1 Noetic & ROS 2 Foxy:** Includes both ROS distributions, with ROS 1 Noetic set as the default.
*   **Desktop Environment:** XFCE desktop accessible via VNC or noVNC.
*   **Automated Setup:** Automatically clones and builds `rpg_emvs` and sets up the `DEVO-point-cloud` conda environment.
*   **Persistent Workspace:** Mounts a local `workspace` directory for persistent data and project files.
*   **Convenient Access:** VNC and noVNC (web-based VNC) are pre-configured for easy remote access.

## Prerequisites

*   **Docker:** Ensure Docker is installed and running on your system.
*   **NVIDIA GPU & NVIDIA Container Toolkit:** For GPU acceleration, you must have an NVIDIA GPU and the NVIDIA Container Toolkit installed. Follow the official NVIDIA Docker documentation for installation.

## Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/Alireza-Safdari-Khosroshahi/DEVO-point-cloud-docker.git
    cd DEVO-point-cloud-docker/docker
    ```
2.  **Build the Docker image:**
    From the root of this repository, run:
    ```bash
    docker-compose build
    ```
    This will build the `devo_pc_pipline_image` image. This might take some time as it installs all dependencies and sets up the environment.

3.  **Start the container:**
    ```bash
    docker-compose up -d
    ```
    This command starts the `ros-desktop` service in detached mode (`-d`). The `entrypoint.sh` script will automatically run, performing initial setup like cloning repositories, building `rpg_emvs`, and setting up the `DEVO-point-cloud` conda environment.

    *The first time you run `docker-compose up -d`, it will perform significant setup inside the container (cloning repos, building, installing conda env). This can take several minutes. Subsequent starts will be much faster as these steps are skipped if the directories/environments already exist.*

## Usage

Once the container is running, you can access the desktop environment and work with the projects.

### Accessing the Desktop (VNC/noVNC)

The container exposes a graphical desktop environment (XFCE) which can be accessed via VNC or a web browser (noVNC).

*   **VNC Client:**
    *   Connect your VNC client to `localhost:5901`.
    *   The default VNC password is `ros`.
    *   You can change the VNC password by setting the `VNC_PASS` environment variable in `docker-compose.yml`.

*   **noVNC (Web Browser):**
    *   Open your web browser and navigate to `http://localhost:6080/vnc.html`.
    *   The default VNC password is `ros`.

### Inside the Container

You can exec into the running container to access the terminal:

```bash
docker exec -it DEVO_PC_pipline zsh
```

Once inside, you will find:

*   **ROS Environment:** The ROS 1 Noetic environment is sourced by default. You can switch between ROS versions using the `use_ros1` and `use_ros2` commands in your shell.
*   **Workspace:** Your mounted `workspace` directory is located at `/home/ros/workspace`.
    *   `~/workspace/ros1_ws`: ROS 1 workspace.
    *   `~/workspace/ros2_ws`: ROS 2 workspace.
    *   `~/workspace/shared/DEVO-point-cloud`: Cloned DEVO-point-cloud repository.
    *   `~/workspace/shared/rpg_emvs`: Cloned rpg_emvs repository.
    *   `~/workspace/shared/emvs_ws`: Catkin workspace for `rpg_emvs` build.
*   **Conda Environment:** The `devo` conda environment for `DEVO-point-cloud` is available.
    *   Activate it using `conda activate devo`.
    *   Deactivate it using `conda deactivate`.
*   **GPU Check:** You can run `gpu-check` in the terminal to verify that GPU acceleration is active.

### Stopping the Container

To stop the running container:

```bash
docker-compose down
```
This will stop and remove the container, but it will preserve the `workspace` directory on your host machine.

## Customization

*   **VNC Settings:** You can adjust `VNC_PASS`, `VNC_GEOMETRY`, and `VNC_DEPTH` in `docker-compose.yml` to customize your VNC experience.
*   **ROS Default Version:** Change `ROS_DEFAULT_VERSION` in `docker-compose.yml` to `2` if you prefer ROS 2 Foxy to be sourced by default on container startup.
*   **Workspace:** The `workspace` directory is mounted from your host. You can place your own ROS packages or other project files here to make them accessible inside the container.

## Project Structure

```
.
├── LICENSE
├── README.md
├── .git/...
└── docker/
    ├── docker-compose.yml
    ├── Dockerfile
    └── entrypoint.sh
```

**Note:** The `workspace` directory will be created in the root of this repository on your host machine when you first run `docker-compose up -d`. This is where all the project-specific code and builds will reside.

## Developers

*   Alireza Safdari @ TU Berlin - alireza.safdarikhosroshahi@campus.tu-berlin.de
*   Sajad Ashraf @ TU Berlin - sajad.ashraf@campus.tu-berlin.de

## Contact

For questions, issues, or contributions, please open an issue on the GitHub repository or contact the developers.


