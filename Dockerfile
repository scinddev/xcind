ARG BASHVER=latest
FROM bash:${BASHVER}

LABEL org.opencontainers.image.version="0.1.1"
LABEL org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache coreutils jq yq docker-cli docker-cli-compose

COPY . /opt/xcind
RUN /opt/xcind/install.sh /usr/local

WORKDIR /workspace
ENTRYPOINT ["xcind-compose"]
