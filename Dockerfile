# Everything a scratch image cannot provide for itself: an unprivileged
# account and the CA certificates cloudflared needs to reach Cloudflare.
FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 AS builder

# hadolint ignore=DL3018
RUN apk upgrade --no-cache \
  && apk add --no-cache ca-certificates

RUN adduser -s /bin/true -u 1000 -D -h /app app \
  && sed -i -r "/^(app|root)/!d" /etc/group /etc/passwd \
  && sed -i -r 's#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd \
  && mkdir -m 1777 /emptytmp

#
# ---
#

# The official cloudflared image, for the binary.
#
# Upstream built cloudflared from a git submodule pinned to whatever commit
# happened to be checked in — no tag, no release, no signature, and a Go
# toolchain in the build. The binary here is Cloudflare's own release, and
# because it is statically linked there is nothing to copy but the file.
FROM cloudflare/cloudflared:2026.10.0@sha256:9b49eed8f62806d5d45ddf59ecefb5710429598ea6d3fcccd2af938f621b2b07 AS cf

#
# ---
#

FROM scratch

LABEL org.opencontainers.image.source="https://github.com/irondragonservices/iron-cloudflared"
LABEL org.opencontainers.image.description="Hardened base image for running cloudflared"

# add-in our unprivileged user
COPY --from=builder /etc/passwd /etc/group /etc/shadow /etc/

# add-in our CA certificates, to validate Cloudflare's
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# cloudflared writes nothing but needs somewhere to put a temp file if asked
COPY --from=builder --chown=1000:1000 /emptytmp /tmp

# the binary itself
COPY --from=cf /usr/local/bin/cloudflared /app

# run as our unprivileged user instead of root
USER app

ENTRYPOINT ["/app"]
CMD ["--no-autoupdate", "tunnel", "run"]
