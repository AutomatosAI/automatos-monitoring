FROM grafana/grafana:10.4.0

# Provisioning configs
COPY monitoring/grafana/provisioning /etc/grafana/provisioning

# Dashboards
COPY monitoring/grafana/dashboards /var/lib/grafana/dashboards

# Railway-specific datasource overrides (uses railway.internal DNS)
COPY railway/grafana/datasources-railway.yml /etc/grafana/provisioning/datasources/datasources.yml

ENV GF_USERS_ALLOW_SIGN_UP=false
ENV GF_AUTH_ANONYMOUS_ENABLED=false
ENV GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/platform-overview.json

EXPOSE 3000
