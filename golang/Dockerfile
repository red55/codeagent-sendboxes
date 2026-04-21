ARG IMAGE=
FROM ${IMAGE}

ARG GO_VERSION=1.26.2
ENV GOPATH=/usr/local/go
ENV GOCACHE=/home/agent/.cache/go-build

USER root
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y --no-install-recommends build-essential linux-source
RUN --mount=type=tmpfs,target=./tmp \
    curl -o ./tmp/tmp.zip  -sL https://github.com/protocolbuffers/protobuf/releases/download/v34.1/protoc-34.1-linux-x86_64.zip \
    && unzip -d /usr ./tmp/tmp.zip \
    && rm ./tmp/tmp.zip

# as we already set SHELL options in base/Dockerfile
# hadolint ignore=DL4006
RUN --mount=type=cache,target=/home/agent/.cache/go-build \
    mkdir -p $GOPATH && \
    (curl -sL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xzvf -) && \
    chown 1000:1000 $GOPATH $GOCACHE && \
    chown 1000:1000 -R $GOPATH $GOCACHE

USER agent
ENV PATH="${GOPATH}/bin:${PATH}"
RUN --mount=type=cache,target=/home/agent/.cache/go-build \
    go install golang.org/x/tools/gopls@v0.21.1 && \
    go install github.com/bufbuild/buf/cmd/buf@v1.68.2
