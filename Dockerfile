# hadolint global ignore=DL3006,SC2002
ARG BASE_IMAGE

FROM $BASE_IMAGE AS base

# https://github.com/astuff/pacmod3?tab=readme-ov-file#installation
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    apt-transport-https \
  && rm -rf /var/lib/apt/lists/* \
  && sh -c 'echo "deb [trusted=yes] https://s3.amazonaws.com/autonomoustuff-repo/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/autonomoustuff-public.list' \
  && apt-get update

FROM base AS rosdep-depend
ARG ROS_DISTRO

WORKDIR /autoware

# Generate install package lists
COPY src/core /autoware/src/core
RUN rosdep update && rosdep keys --ignore-src --from-paths src \
    | xargs rosdep resolve --rosdistro ${ROS_DISTRO} \
    | grep -v '^#' \
    | sed 's/ \+/\n/g'\
    | sort \
    > /rosdep-core-depend-packages.txt \
  && cat /rosdep-core-depend-packages.txt

COPY src /autoware/src
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

RUN --mount=type=bind,from=rosdep-depend,source=/rosdep-core-depend-packages.txt,target=/tmp/rosdep-core-depend-packages.txt \
  apt-get update \
  && cat /tmp/rosdep-core-depend-packages.txt | xargs apt-get install -y --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

FROM base AS autoware-universe-base

RUN --mount=type=bind,from=rosdep-depend,source=/rosdep-universe-depend-packages.txt,target=/tmp/rosdep-universe-depend-packages.txt \
  apt-get update \
  && cat /tmp/rosdep-universe-depend-packages.txt | xargs apt-get install -y --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

FROM base AS runtime-base

RUN --mount=type=bind,from=rosdep-depend,source=/rosdep-exec-depend-packages.txt,target=/tmp/rosdep-exec-depend-packages.txt \
  apt-get update \
  && cat /tmp/rosdep-exec-depend-packages.txt | xargs apt-get install -y --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*
