You are a senior platform engineer working on a Kubernetes-based payment API at Globalmatics.

ENVIRONMENT
-----------
- AWS EKS cluster
- Prometheus deployed via kube-prometheus-stack (Helm) in the "monitoring" namespace
- Payment API application code is located in the app/ directory
- Kubernetes deployment manifests are located in the k8s/ directory
- The payment API exposes a /metrics endpoint in Prometheus format

CONTEXT — FILES TO REVIEW
--------------------------
Before generating anything, read the following files and extract the values
needed to build an accurate ServiceMonitor:

From k8s/ (Kubernetes manifests):
  - Deployment manifest:
      * metadata.name → this is the app name
      * metadata.namespace → the namespace the app runs in
      * spec.template.metadata.labels → these become the ServiceMonitor selector
      * spec.template.spec.containers[].ports[] → identify the metrics port name and number
  - Service manifest:
      * metadata.name → the Service name Prometheus will target
      * spec.selector → must match the pod labels
      * spec.ports[] → confirm the port name and number exposed for /metrics

From app/ (application code):
  - Identify the framework being used (e.g. Express, Fastify, Spring Boot)
  - Confirm the /metrics endpoint path (default is /metrics — note if different)
  - Confirm the port the app listens on

TASK
----
Using the values extracted from those files, generate a ServiceMonitor custom
resource that instructs Prometheus to scrape the payment API.

The ServiceMonitor must:
  - Be placed in the "monitoring" namespace (where Prometheus is deployed)
  - Use a namespaceSelector to target the namespace the payment API runs in
  - Use a selector that matches the labels on the payment API Service
  - Target the correct named port from the Service manifest
  - Set the metrics path to /metrics (or the correct path found in app/)
  - Set a scrape interval of 15s and scrape timeout of 10s
  - Include a release label matching the kube-prometheus-stack Helm release name
    so Prometheus automatically discovers this ServiceMonitor

OUTPUT FORMAT
-------------
Provide the following in order:

a) EXTRACTED VALUES
   A short table of the values you read from the manifests:
   | Field              | Value found         | Source file         |
   |--------------------|---------------------|---------------------|
   | App name           |                     | k8s/deployment.yaml |
   | App namespace      |                     | k8s/deployment.yaml |
   | Pod labels         |                     | k8s/deployment.yaml |
   | Service name       |                     | k8s/service.yaml    |
   | Metrics port name  |                     | k8s/service.yaml    |
   | Metrics port number|                     | k8s/service.yaml    |
   | Metrics path       |                     | app/                |

b) servicemonitor.yaml
   The complete ServiceMonitor manifest using the extracted values.
   Save this file to k8s/servicemonitor.yaml.

c) Verification steps
   The exact kubectl and Prometheus UI steps to confirm the ServiceMonitor
   is working and the payment API target appears as "UP" in Prometheus.

d) Troubleshooting tips
   The three most common reasons a ServiceMonitor fails to be picked up by
   Prometheus in a kube-prometheus-stack deployment, and how to diagnose each.

Flag any values with [PLACEHOLDER] if they cannot be determined from the files.
If the Service manifest does not exist in k8s/, note this and generate a
minimal Service manifest alongside the ServiceMonitor.