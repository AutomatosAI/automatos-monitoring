FROM prom/prometheus:v2.51.0

COPY prometheus-railway.yml /etc/prometheus/prometheus.yml
COPY rules /etc/prometheus/rules

EXPOSE 9090

ENTRYPOINT ["/bin/prometheus"]
CMD ["--config.file=/etc/prometheus/prometheus.yml", \
     "--storage.tsdb.path=/prometheus", \
     "--storage.tsdb.retention.time=15d", \
     "--web.enable-lifecycle", \
     "--web.enable-admin-api"]
