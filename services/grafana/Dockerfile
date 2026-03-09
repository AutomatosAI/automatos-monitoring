FROM grafana/grafana:10.4.0

USER root

COPY provisioning /etc/grafana/provisioning
COPY dashboards /var/lib/grafana/dashboards

# Railway-specific datasource overrides (uses railway.internal DNS)
COPY datasources-railway.yml /etc/grafana/provisioning/datasources/datasources.yml

# Railway volumes mount as root — entrypoint fixes ownership at runtime
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV GF_USERS_ALLOW_SIGN_UP=false
ENV GF_AUTH_ANONYMOUS_ENABLED=false
ENV GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/platform-overview.json

EXPOSE 3000

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
