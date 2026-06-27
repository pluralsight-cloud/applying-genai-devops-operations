#!/bin/bash

# ── Configuration ─────────────────────────────────────────
PROMETHEUS_URL="http://[YOUR_PROMETHEUS_LB_URL]:9090"
APP_LABEL="payment-api"
CONTAINER_NAME="payment-api"
METRICS_DIR="./metrics"
# Time ranges
NOW=$(date -u +%s)
SEVEN_DAYS_AGO=$(date -u -d '7 days ago' +%s)
THIRTY_DAYS_AGO=$(date -u -d '30 days ago' +%s)
STEP_1H="3600"
# ──────────────────────────────────────────────────────────

mkdir -p $METRICS_DIR

BASE="$PROMETHEUS_URL/api/v1"

echo "Verifying Prometheus is reachable..."
curl -sf "$PROMETHEUS_URL/-/healthy" > /dev/null \
  || { echo "ERROR: Prometheus not reachable at $PROMETHEUS_URL"; exit 1; }

echo "Exporting RPS time series (7 days, 1h resolution)..."
curl -sG "$BASE/query_range" \
  --data-urlencode "query=sum(rate(http_requests_total{job=\"$APP_LABEL\"}[5m]))" \
  --data-urlencode "start=$SEVEN_DAYS_AGO" \
  --data-urlencode "end=$NOW" \
  --data-urlencode "step=$STEP_1H" \
  -o $METRICS_DIR/rps-7d-1h.json

echo "Exporting RPS time series (30 days, 1h resolution)..."
curl -sG "$BASE/query_range" \
  --data-urlencode "query=sum(rate(http_requests_total{job=\"$APP_LABEL\"}[5m]))" \
  --data-urlencode "start=$THIRTY_DAYS_AGO" \
  --data-urlencode "end=$NOW" \
  --data-urlencode "step=$STEP_1H" \
  -o $METRICS_DIR/rps-30d-1h.json

echo "Exporting CPU utilisation — absolute cores (7 days, 1h resolution)..."
curl -sG "$BASE/query_range" \
  --data-urlencode "query=sum(rate(container_cpu_usage_seconds_total{pod=~\"$APP_LABEL.*\",container=\"$CONTAINER_NAME\"}[5m]))" \
  --data-urlencode "start=$SEVEN_DAYS_AGO" \
  --data-urlencode "end=$NOW" \
  --data-urlencode "step=$STEP_1H" \
  -o $METRICS_DIR/cpu-cores-7d-1h.json

echo "Exporting CPU utilisation — % of limit (7 days, 1h resolution)..."
curl -sG "$BASE/query_range" \
  --data-urlencode "query=sum(rate(container_cpu_usage_seconds_total{pod=~\"$APP_LABEL.*\",container=\"$CONTAINER_NAME\"}[5m])) / sum(kube_pod_container_resource_limits{pod=~\"$APP_LABEL.*\",resource=\"cpu\",container=\"$CONTAINER_NAME\"})" \
  --data-urlencode "start=$SEVEN_DAYS_AGO" \
  --data-urlencode "end=$NOW" \
  --data-urlencode "step=$STEP_1H" \
  -o $METRICS_DIR/cpu-pct-of-limit-7d-1h.json

echo "Exporting replica count over time (7 days, 1h resolution)..."
curl -sG "$BASE/query_range" \
  --data-urlencode "query=kube_deployment_status_replicas_available{deployment=\"$APP_LABEL\"}" \
  --data-urlencode "start=$SEVEN_DAYS_AGO" \
  --data-urlencode "end=$NOW" \
  --data-urlencode "step=$STEP_1H" \
  -o $METRICS_DIR/replicas-7d-1h.json

echo "Exporting P99 latency (7 days, 1h resolution)..."
curl -sG "$BASE/query_range" \
  --data-urlencode "query=histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{job=\"$APP_LABEL\"}[5m])) by (le))" \
  --data-urlencode "start=$SEVEN_DAYS_AGO" \
  --data-urlencode "end=$NOW" \
  --data-urlencode "step=$STEP_1H" \
  -o $METRICS_DIR/p99-latency-7d-1h.json

echo "Exporting peak RPS (max over 7 days)..."
curl -sG "$BASE/query" \
  --data-urlencode "query=max_over_time(sum(rate(http_requests_total{job=\"$APP_LABEL\"}[5m]))[7d:5m])" \
  -o $METRICS_DIR/peak-rps-7d.json

echo "Exporting trough RPS (min non-zero over 7 days)..."
curl -sG "$BASE/query" \
  --data-urlencode "query=min_over_time(sum(rate(http_requests_total{job=\"$APP_LABEL\"}[5m]))[7d:5m] > 0.1)" \
  -o $METRICS_DIR/trough-rps-7d.json

echo "Exporting CPU limit per pod..."
curl -sG "$BASE/query" \
  --data-urlencode "query=kube_pod_container_resource_limits{pod=~\"$APP_LABEL.*\",resource=\"cpu\",container=\"$CONTAINER_NAME\"}" \
  -o $METRICS_DIR/cpu-limit-per-pod.json

echo "Exporting current HPA state..."
kubectl get hpa -n payment-api -o json > $METRICS_DIR/hpa-current.json 2>/dev/null \
  || echo '{"items":[]}' > $METRICS_DIR/hpa-current.json

echo "Exporting current deployment state..."
kubectl get deployment $APP_LABEL -n payment-api -o json \
  > $METRICS_DIR/deployment-current.json 2>/dev/null \
  || echo '{}' > $METRICS_DIR/deployment-current.json

echo "Writing manifest..."
cat > $METRICS_DIR/manifest.json <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prometheus_url": "$PROMETHEUS_URL",
  "app": "$APP_LABEL",
  "container": "$CONTAINER_NAME",
  "collection_ranges": {
    "short_range_days": 7,
    "long_range_days": 30,
    "step_resolution": "1h"
  },
  "files": [
    "rps-7d-1h.json",
    "rps-30d-1h.json",
    "cpu-cores-7d-1h.json",
    "cpu-pct-of-limit-7d-1h.json",
    "replicas-7d-1h.json",
    "p99-latency-7d-1h.json",
    "peak-rps-7d.json",
    "trough-rps-7d.json",
    "cpu-limit-per-pod.json",
    "hpa-current.json",
    "deployment-current.json"
  ]
}
EOF

echo ""
echo "Done. Metrics saved to $METRICS_DIR/"
ls -lh $METRICS_DIR/