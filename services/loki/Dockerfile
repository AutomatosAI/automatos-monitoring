FROM grafana/loki:2.9.4

USER root

COPY loki-config.yaml /etc/loki/config.yaml
COPY rules /loki/rules
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3100

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
