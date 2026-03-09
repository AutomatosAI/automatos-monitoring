FROM grafana/loki:2.9.4

COPY monitoring/loki/local-config.yaml /etc/loki/config.yaml

EXPOSE 3100

ENTRYPOINT ["/usr/bin/loki"]
CMD ["-config.file=/etc/loki/config.yaml"]
