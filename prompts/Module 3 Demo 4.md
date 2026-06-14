You are a senior SRE specializing in Prometheus alerting for Kubernetes-based
payment systems at Globalmatics.

ENVIRONMENT
-----------
- AWS EKS cluster
- Prometheus deployed via kube-prometheus-stack (Helm) in the "monitoring" namespace
- Alertmanager deployed as part of kube-prometheus-stack
- Payment API: Node.js application running in its own namespace
- Kubernetes deployment manifests are located in the k8s/ directory
- ServiceMonitor is already configured and the payment API is being scraped

SLACK CONFIGURATION
-------------------
- Slack workspace: [SLACK_WORKSPACE_NAME]
- Critical alerts channel: #payments-critical
- Warning alerts channel: #payments-warnings
- Info alerts channel: #payments-info
- Slack webhook URL: [SLACK_WEBHOOK_URL] (store as a Kubernetes Secret)
- Slack bot token: [SLACK_BOT_TOKEN] (store as a Kubernetes Secret)

CONTEXT — FILES TO REVIEW
--------------------------
Before generating anything, read the following files:

From k8s/ (Kubernetes manifests):
  - Deployment manifest:
      * metadata.namespace → the namespace alerts should target
      * spec.template.metadata.labels → used to scope PromQL expressions
      * spec.replicas → used to define minimum healthy replica thresholds
  - ServiceMonitor manifest:
      * spec.endpoints[].port → confirm the metrics port name
      * spec.endpoints[].path → confirm the metrics path

From Prometheus (confirm these metrics exist before writing expressions):
  Assume the payment API exposes standard Prometheus metrics including:
      * http_requests_total (labels: method, route, status_code)
      * http_request_duration_seconds (histogram)
      * db_connection_pool_active (gauge)
      * db_connection_pool_max (gauge)
      * payment_transactions_total (labels: status — "success" or "failure")
      * process_resident_memory_bytes
  If the metric names differ from the above, adjust all PromQL expressions
  accordingly and note every substitution made.

SLO TARGETS
-----------
- Availability: 99.9% (error budget: ~43 min/month)
- P99 latency: ≤ 500ms
- Error rate: ≤ 0.1%

TASK
----
Generate a Kubernetes PrometheusRule custom resource and a complete
Alertmanager configuration that routes alerts to the correct Slack channels
based on severity.

For every alert include:
  - alert name (PascalCase, prefixed with PaymentAPI)
  - expr (valid PromQL — scope to the correct namespace and job labels)
  - for duration
  - severity label: critical, warning, or info
  - summary annotation (one line, human-readable)
  - description annotation (include the current metric value using {{ $value }})
  - runbook_url annotation (use https://wiki.globalmatics.internal/runbooks/[ALERT_NAME])

1. GROUP — Availability
   PaymentAPIDown
     - Condition: zero healthy payment API pods for > 1 min
     - Severity: critical → routes to #payments-critical
     - Hint: use kube_deployment_status_replicas_available

   PaymentAPIReplicasMismatch
     - Condition: available replicas < desired replicas for > 3 min
     - Severity: warning → routes to #payments-warnings
     - Hint: compare kube_deployment_spec_replicas vs kube_deployment_status_replicas_available

   PaymentAPICrashLooping
     - Condition: pod restart count increases by > 3 in a 15-min window
     - Severity: critical → routes to #payments-critical
     - Hint: use rate() over kube_pod_container_status_restarts_total

2. GROUP — Error rate (multi-severity)
   PaymentAPIHighErrorRate
     - Condition: HTTP 5xx rate > 1% of total requests over 5-min window
     - Severity: warning → routes to #payments-warnings
     - for: 5m

   PaymentAPICriticalErrorRate
     - Condition: HTTP 5xx rate > 5% of total requests over 2-min window
     - Severity: critical → routes to #payments-critical
     - for: 2m

   PaymentAPIHighClientErrorRate
     - Condition: HTTP 4xx rate > 10% of total requests over 10-min window
     - Severity: warning → routes to #payments-warnings
     - Hint: exclude 404s if they represent expected "not found" responses

3. GROUP — Latency (multi-severity)
   PaymentAPIHighLatency
     - Condition: P99 latency > 500ms sustained for 5 min
     - Severity: warning → routes to #payments-warnings
     - Hint: use histogram_quantile(0.99, ...) over http_request_duration_seconds

   PaymentAPICriticalLatency
     - Condition: P99 latency > 1,000ms sustained for 3 min
     - Severity: critical → routes to #payments-critical

   PaymentAPIElevatedP95Latency
     - Condition: P95 latency > 300ms sustained for 10 min
     - Severity: info → routes to #payments-info

4. GROUP — Payment business metrics
   PaymentAPIHighFailureRate
     - Condition: payment transaction failure rate > 2% over a 5-min window
     - Severity: critical → routes to #payments-critical
     - Hint: rate(payment_transactions_total{status="failure"}) /
             rate(payment_transactions_total)

   PaymentAPINoSuccessfulTransactions
     - Condition: zero successful payment transactions in any 10-min window
     - Severity: critical → routes to #payments-critical
     - Note: this is a dead man's switch — silence means something is wrong

   PaymentAPITransactionSpikeAnomaly
     - Condition: failure rate > 3× the 1-hour rolling average
     - Severity: warning → routes to #payments-warnings
     - Hint: compare a short rate() window against a longer rate() window

5. GROUP — SLO burn rate (multi-window)
   Generate a multi-window, multi-burn-rate SLO alert set for a 99.9%
   availability target using the error rate as the SLI.

   Fast burn (page immediately):
     - 14× burn rate over both 1h and 5m windows
     - Severity: critical → routes to #payments-critical
     - for: 2m

   Slow burn (create a ticket):
     - 3× burn rate over both 6h and 30m windows
     - Severity: warning → routes to #payments-warnings
     - for: 15m

   Include a comment in the YAML explaining how the burn rate multipliers
   relate to the monthly error budget.

ALERTMANAGER CONFIGURATION
--------------------------
Generate a complete Alertmanager configuration that:

1. ROUTING
   - Routes severity=critical alerts to #payments-critical
       * group_wait: 0s (page immediately)
       * group_interval: 5m
       * repeat_interval: 1h
   - Routes severity=warning alerts to #payments-warnings
       * group_wait: 5m
       * group_interval: 10m
       * repeat_interval: 4h
   - Routes severity=info alerts to #payments-info
       * group_wait: 10m
       * group_interval: 30m
       * repeat_interval: 12h
   - Group alerts by: alertname, namespace, severity

2. SLACK MESSAGE FORMAT
   For each severity, customise the Slack message template to include:
   - Alert name and severity as the message title
   - Emoji indicator: 🔴 critical | 🟡 warning | 🔵 info
   - Description annotation value
   - Current metric value ({{ $value }})
   - Runbook URL as a clickable link
   - Cluster name and namespace
   - A "View in Grafana" link (use [GRAFANA_URL] as placeholder)
   - Firing vs resolved state — show a distinct resolved message with ✅

3. INHIBITION RULES
   - Suppress warning alerts when a critical alert is firing for the same
     payment API pod
   - Suppress latency and error alerts when PaymentAPIDown is active
   - Suppress all alerts during a maintenance window label:
     alertname="MaintenanceWindow"

OUTPUT FORMAT
-------------
Provide the following in order:

a) prometheusrule.yaml
   A single PrometheusRule manifest containing all six alert groups.
   - namespace: monitoring
   - Include a release label matching the kube-prometheus-stack Helm release
   - Save to k8s/prometheusrule.yaml

b) alertmanager-secret.yaml
   A Kubernetes Secret manifest storing the Slack webhook URL and bot token.
   Use base64-encoded [PLACEHOLDER] values.
   - namespace: monitoring
   - Save to k8s/alertmanager-secret.yaml

c) alertmanager-config.yaml
   Complete Alertmanager configuration as a Kubernetes Secret or AlertmanagerConfig
   CRD (whichever is appropriate for kube-prometheus-stack), including:
   - Full routing tree (critical → warning → info)
   - Slack receiver definitions for all three channels with the message templates above
   - Inhibition rules
   - Save to k8s/alertmanager-config.yaml

d) PROMQL REFERENCE TABLE
   A markdown table listing every alert, its PromQL expression, severity,
   target Slack channel, and threshold rationale:
   | Alert | Severity | Channel | PromQL expression | Threshold rationale |

e) Verification steps
   - kubectl commands to confirm the PrometheusRule is loaded
   - How to confirm Alertmanager has picked up the new routing config
   - How to send a test alert to each Slack channel using the
     Alertmanager API (amtool or curl) without triggering a real incident

f) Testing guidance
   How to manually fire each severity level in a non-production environment
   and confirm the correct Slack channel receives the message with the
   correct format.

Flag all [PLACEHOLDER] values clearly. Note any metric names that could not
be confirmed from the files and list every assumption made.
