# syntax=docker/dockerfile:1
ARG IMAGE=
FROM docker.io/library/node:25-trixie

ENV DEBIAN_FRONTEND=noninteractive


RUN [ "$GITHUB_ACTIONS" = "true" ] || \
    sed -i -E 's#https?://([a-z0-9.-]+.)?debian.org/debian#https://mirror.yandex.ru/debian#g' \
    /etc/apt/sources.list.d/debian.sources

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=/home/agent/.local/bin:/usr/local/share/npm-global/bin:$PATH
ENV NO_PROXY=localhost,127.0.0.1,::1,172.17.0.0/16
ENV no_proxy=${NO_PROXY}

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=bind,source=./prepare-sandbox.bash,target=/tmp/prepare-sandbox.bash \
    /bin/bash -c 'source /tmp/prepare-sandbox.bash'


USER root
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
RUN apt-get update \
    && apt-get install -yy --no-install-recommends \
    dnsutils \
    docker-buildx-plugin \
    docker-ce-cli \
    docker-compose-plugin \
    git \
    jq \
    less \
    lsof \
    make \
    procps \
    psmisc \
    ripgrep \
    rsync \
    socat \
    sudo \
    unzip \
    gh \
    bc \
    default-jdk-headless \
    man-db \
    nodejs \
    npm \
    python3 \
    python3-pip \
    containerd.io docker-ce \
    unzip mc tshark sqlite3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install --break-system-packages --no-cache-dir pyright uv
RUN npm i -g bun@1.3.13
RUN chown -R agent:agent /usr/local/share/npm-global
LABEL com.docker.sandboxes.start-docker=true


USER agent
ENV BASH_ENV=/etc/sandbox-persistent.sh
ENV PATH=/home/agent/.bun/bin:$PATH

WORKDIR /home/agent/workspace
