ARG IMAGE=
FROM ${IMAGE}
RUN --mount=type=cache,target=/home/agent/.cache/pip \
    pip3 install --break-system-packages \
    netaddr==1.3.0 ansible-pylibssh==1.4.0 mitogen==0.3.47 ansible-lint==26.4.0 ansible==13.5.0
