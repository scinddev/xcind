ARG BASHVER=latest
FROM bash:${BASHVER}

LABEL org.opencontainers.image.version="0.0.3"
LABEL org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache coreutils jq docker-cli docker-cli-compose

COPY . /opt/xcind
RUN /opt/xcind/install.sh /usr/local

WORKDIR /workspace
ENTRYPOINT ["xcind-compose"]
