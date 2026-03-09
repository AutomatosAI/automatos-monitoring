FROM prom/prometheus:v2.51.0

USER root

COPY prometheus-railway.yml /etc/prometheus/prometheus.yml
COPY rules /etc/prometheus/rules
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9090

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
