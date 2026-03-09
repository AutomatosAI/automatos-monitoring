FROM prom/alertmanager:v0.27.0

COPY monitoring/alertmanager/alertmanager-railway.yml /etc/alertmanager/alertmanager.yml

# The ingest token will be mounted/injected via Railway volume or env var at runtime.
# For now, create the directory and use a startup script to write the token from env.
COPY railway/alertmanager/entrypoint.sh /entrypoint.sh

EXPOSE 9093

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
