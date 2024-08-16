# hadolint global ignore=DL3006,SC2002
ARG BASE_IMAGE

FROM $BASE_IMAGE AS base

# Install apt packages and add GitHub to known hosts for private repositories
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
  gosu \
  ssh \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p ~/.ssh \
  && ssh-keyscan github.com >> ~/.ssh/known_hosts

# Copy files
COPY autoware/setup-dev-env.sh autoware/ansible-galaxy-requirements.yaml autoware/amd64.env autoware/arm64.env /autoware/
COPY autoware/ansible/ /autoware/ansible/
WORKDIR /autoware

# Set up base environment
RUN --mount=type=ssh \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  ./setup-dev-env.sh -y --module base --runtime openadkit \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && rm -rf "$HOME"/.cache \
  && echo "source /opt/ros/${ROS_DISTRO}/setup.bash" > /etc/bash.bashrc

FROM base AS rosdep-depend
ARG ROS_DISTRO

WORKDIR /autoware

# Generate install package lists
COPY autoware/src/core /autoware/src/core
RUN rosdep update && rosdep keys --ignore-src --from-paths src \
    | xargs rosdep resolve --rosdistro ${ROS_DISTRO} \
    | grep -v '^#' \
    | sed 's/ \+/\n/g'\
    | sort \
    > /rosdep-core-depend-packages.txt \
  && cat /rosdep-core-depend-packages.txt

COPY autoware/src /autoware/src
RUN rosdep keys --ignore-src --from-paths src \
    | xargs rosdep resolve --rosdistro ${ROS_DISTRO} \
    | grep -v '^#' \
    | sed 's/ \+/\n/g'\
    | sort \
    > /rosdep-universe-depend-packages.txt \
  && cat /rosdep-universe-depend-packages.txt

RUN rosdep keys --dependency-types=exec --ignore-src --from-paths src \
    | xargs rosdep resolve --rosdistro ${ROS_DISTRO} \
    | grep -v '^#' \
    | sed 's/ \+/\n/g'\
    | sort \
    > /rosdep-exec-depend-packages.txt \
  && cat /rosdep-exec-depend-packages.txt

FROM base AS autoware-core-base

# Set up development environment
RUN --mount=type=ssh \
  ./setup-dev-env.sh -y --module all --no-nvidia --no-cuda-drivers openadkit \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

RUN --mount=type=bind,from=rosdep-depend,source=/rosdep-core-depend-packages.txt,target=/tmp/rosdep-core-depend-packages.txt \
  apt-get update \
  && cat /tmp/rosdep-core-depend-packages.txt | xargs apt-get install -y --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

FROM base AS autoware-universe-base

# Set up development environment
RUN --mount=type=ssh \
  ./setup-dev-env.sh -y --module all --no-nvidia --no-cuda-drivers openadkit \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

RUN --mount=type=bind,from=rosdep-depend,source=/rosdep-universe-depend-packages.txt,target=/tmp/rosdep-universe-depend-packages.txt \
  apt-get update \
  && cat /tmp/rosdep-universe-depend-packages.txt | xargs apt-get install -y --no-install-recommends \
  && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

FROM autoware-universe-base AS autoware-universe-cuda-base

# TODO(youtalk): Create playbook only for installing NVIDIA drivers
RUN --mount=type=ssh \
  ./setup-dev-env.sh -y --module all --no-cuda-drivers openadkit \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache

FROM base AS runtime-base

# Set up runtime environment
RUN --mount=type=ssh \
  ./setup-dev-env.sh -y --module all --no-nvidia --no-cuda-drivers --runtime openadkit \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache \
  && find /usr/lib/$LIB_DIR-linux-gnu -name "*.a" -type f -delete \
  && find / -name "*.o" -type f -delete \
  && find / -name "*.h" -type f -delete \
  && find / -name "*.hpp" -type f -delete \
  && rm -rf /autoware/ansible \
    /root/.local/pipx /opt/ros/"$ROS_DISTRO"/include /etc/apt/sources.list.d/cuda*.list \
    /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/nvidia-docker.list \
    /usr/include /usr/share/doc /usr/lib/gcc /usr/lib/jvm /usr/lib/llvm*

RUN --mount=type=bind,from=rosdep-depend,source=/rosdep-exec-depend-packages.txt,target=/tmp/rosdep-exec-depend-packages.txt \
  apt-get update \
  && cat /tmp/rosdep-exec-depend-packages.txt | xargs apt-get install -y --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

FROM runtime-base AS runtime-cuda-base

# TODO(youtalk): Create playbook only for installing NVIDIA drivers and downloaded artifacts
RUN --mount=type=ssh \
  ./setup-dev-env.sh -y --module all --download-artifacts --no-cuda-drivers --runtime openadkit \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* "$HOME"/.cache \
  && find /usr/lib/$LIB_DIR-linux-gnu -name "*.a" -type f -delete \
  && find / -name "*.o" -type f -delete \
  && find / -name "*.h" -type f -delete \
  && find / -name "*.hpp" -type f -delete \
  && rm -rf /autoware/ansible \
    /root/.local/pipx /opt/ros/"$ROS_DISTRO"/include /etc/apt/sources.list.d/cuda*.list \
    /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/nvidia-docker.list \
    /usr/include /usr/share/doc /usr/lib/gcc /usr/lib/jvm /usr/lib/llvm*
