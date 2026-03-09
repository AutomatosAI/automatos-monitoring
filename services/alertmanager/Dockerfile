FROM prom/alertmanager:v0.27.0

USER root

COPY alertmanager-railway.yml /etc/alertmanager/alertmanager.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9093

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
