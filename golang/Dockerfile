ARG IMAGE=
FROM ${IMAGE}

ARG GO_VERSION=1.26.2
ENV GOPATH=/usr/local/go

RUN sudo apt-get update && sudo apt-get install -y build-essential linux-source && sudo rm -rf /var/lib/apt/lists/*
RUN curl -o tmp.zip  -sL https://github.com/protocolbuffers/protobuf/releases/download/v34.1/protoc-34.1-linux-x86_64.zip \
    && sudo unzip -d /usr tmp.zip \
    && rm tmp.zip
RUN sudo mkdir -p $GOPATH && (curl -sL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | sudo tar -C /usr/local -xzvf -)
ENV PATH="${GOPATH}/bin:${PATH}"

RUN sudo chown 1000:1000 -R $GOPATH && go install golang.org/x/tools/gopls@latest && \
    go install github.com/bufbuild/buf/cmd/buf@latest
