FROM prom/alertmanager:v0.27.0

COPY alertmanager-railway.yml /etc/alertmanager/alertmanager.yml
COPY entrypoint.sh /entrypoint.sh

EXPOSE 9093

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
