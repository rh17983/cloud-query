FROM debian:bookworm-slim

ARG CQ_VERSION=cli-v6.29.7

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL "https://github.com/cloudquery/cloudquery/releases/download/${CQ_VERSION}/cloudquery_linux_amd64" -o /usr/local/bin/cloudquery \
 && chmod +x /usr/local/bin/cloudquery \
 && mkdir -p /config /work

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/cloudquery"]
CMD ["sync", "/config"]
