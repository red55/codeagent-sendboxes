ARG IMAGE=
FROM ${IMAGE}

ARG GO_VERSION=1.26.2
ENV GOPATH=/usr/local/go

RUN apt-get update && apt-get install -y --no-install-recommends build-essential linux-source && rm -rf /var/lib/apt/lists/*
RUN curl -o tmp.zip  -sL https://github.com/protocolbuffers/protobuf/releases/download/v34.1/protoc-34.1-linux-x86_64.zip \
    && unzip -d /usr tmp.zip \
    && rm tmp.zip
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p $GOPATH && (curl -sL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xzvf -)
ENV PATH="${GOPATH}/bin:${PATH}"

RUN chown 1000:1000 -R $GOPATH && go install golang.org/x/tools/gopls@v0.21.1 && \
    go install github.com/bufbuild/buf/cmd/buf@v1.68.2
