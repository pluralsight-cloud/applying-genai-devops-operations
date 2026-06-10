You are a senior platform engineer specializing in Kubernetes observability on AWS EKS.

ENVIRONMENT
-----------
- AWS EKS cluster (managed with Terraform)
- Namespace: "monitoring" for all observability components
- Both Prometheus and Grafana must be publicly accessible via AWS Classic or
  Network Load Balancers using Kubernetes Service type: LoadBalancer
- Persistent storage using the gp2 or gp3 EBS StorageClass

TASK
----
Generate production-ready Kubernetes manifests and Helm values to deploy
Prometheus and Grafana on EKS using the kube-prometheus-stack Helm chart.

1. PROMETHEUS
   - Deploy via kube-prometheus-stack (latest stable Helm chart)
   - Enable scraping of: Node Exporter, kube-state-metrics, cAdvisor, and CoreDNS
   - Configure pod annotation-based scrape discovery:
       prometheus.io/scrape: "true"
       prometheus.io/path: "/metrics"
       prometheus.io/port: "[PORT]"
   - Set 15-day retention with a 50Gi PersistentVolumeClaim (gp2 or gp3 StorageClass)
   - Expose the Prometheus UI publicly via a Kubernetes Service of type: LoadBalancer
   - Use a dedicated ServiceAccount with minimum required RBAC permissions

2. GRAFANA
   - Deploy as part of kube-prometheus-stack
   - Pre-configure Prometheus as the default datasource
   - Set admin credentials via a Kubernetes Secret (do not hardcode in values.yaml)
   - Pre-install the following dashboards by Grafana dashboard ID:
       * Kubernetes cluster overview: 315
       * Node Exporter full: 1860
   - Enable persistent storage: 10Gi PVC (gp2 or gp3 StorageClass)
   - Expose Grafana publicly via a Kubernetes Service of type: LoadBalancer

OUTPUT FORMAT
-------------
Provide the following in order:

a) values.yaml
   Complete Helm values file for kube-prometheus-stack configuring both
   Prometheus and Grafana as described above. Use [PLACEHOLDER] for any
   value that must be supplied at deploy time (passwords, cluster name, etc.)

b) grafana-secret.yaml
   Kubernetes Secret manifest for Grafana admin credentials.
   Use base64-encoded [PLACEHOLDER] values.

c) namespace.yaml
   Kubernetes Namespace manifest for the "monitoring" namespace.

d) Apply order
   The exact sequence of commands to deploy everything:
   kubectl apply, helm repo add, helm install — in the correct order.

e) Verification steps
   The kubectl commands to:
   - Confirm all pods are Running
   - Retrieve the external LoadBalancer URLs for both Prometheus and Grafana
   - Validate Prometheus is successfully scraping targets

Flag all [PLACEHOLDER] values clearly and explain what each one requires.
Note any AWS-specific prerequisites (IAM permissions, EBS CSI driver, etc.)
that must be in place before deployment.