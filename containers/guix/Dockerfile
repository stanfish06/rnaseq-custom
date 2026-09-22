FROM debian:bookworm-slim

ARG GUIX_VERSION=1.5.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl netbase xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://ftp.gnu.org/gnu/guix/guix-binary-${GUIX_VERSION}.x86_64-linux.tar.xz" -o /tmp/guix.tar.xz \
 && tar --warning=no-timestamp -xf /tmp/guix.tar.xz -C / \
 && rm /tmp/guix.tar.xz \
 && mkdir -p /root/.config/guix \
 && ln -sf /var/guix/profiles/per-user/root/current-guix /root/.config/guix/current \
 && ln -sf /root/.config/guix/current/bin/guix /usr/local/bin/guix \
 && ln -sf /root/.config/guix/current/bin/guix-daemon /usr/local/bin/guix-daemon \
 && groupadd --system guixbuild \
 && for i in $(seq -w 1 10); do \
      useradd --system --no-create-home -g guixbuild -G guixbuild -d /var/empty -s /usr/sbin/nologin -c "Guix build user $i" guixbuilder$i; \
    done

ENV SSL_CERT_DIR=/etc/ssl/certs \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

ENTRYPOINT ["/usr/local/bin/entrypoint"]
