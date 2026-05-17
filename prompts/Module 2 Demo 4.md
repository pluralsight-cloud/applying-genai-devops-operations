# Module 2 — Demo 4: Production-ready Kubernetes manifests (AI-assisted)

Use the prompt below with your GenAI tool to generate manifests for a **Node.js payment API** on **AWS EKS** (Kubernetes **1.35**). The demo has **no database**. The API is exposed **only** via a `Service` of type `LoadBalancer` — **no Ingress**.

---

## AI prompt (copy into your assistant)

```text
You are an expert Kubernetes engineer. Generate complete, production-ready Kubernetes
manifests for a Node.js payment API running on an AWS EKS cluster (Kubernetes 1.35).
This is a demo application with no database. The API must be publicly accessible
from the internet using a Kubernetes Service of type LoadBalancer only. Do not
use any Ingress resources for this demo.
```

---

## Application details

| Item | Value |
|------|--------|
| App name | `payment-api` |
| Container image | `<account-id>.dkr.ecr.<region>.amazonaws.com/payment-api:latest` |
| Container port | `3000` |
| Language | Node.js 24 (TypeScript, compiled) |
| Environment | `prod` |
| Storage | No database or persistent volumes |

---

## Manifest requirements

### 1. Namespace

- Create namespace: **`payment-api`**
- Labels:
  - `app.kubernetes.io/name: payment-api`
  - `environment: prod`

### 2. Deployment

| Field | Value |
|-------|--------|
| Name / namespace | `payment-api` / `payment-api` |
| Replicas | `2` |
| Image | `<account-id>.dkr.ecr.<region>.amazonaws.com/payment-api:latest` |
| `imagePullPolicy` | `Always` |
| Container port | `3000` |

**Labels and selectors (pods and template):**

- `app: payment-api`
- `app.kubernetes.io/name: payment-api`
- `app.kubernetes.io/version: "1.0.0"`
- `environment: prod`

**Environment**

- `NODE_ENV=production`, `PORT=3000` at runtime
- Add placeholders for extra config via **ConfigMap** references (`envFrom` or `valueFrom`)

**Resources**

```yaml
requests:
  cpu: "100m"
  memory: "128Mi"
limits:
  cpu: "500m"
  memory: "256Mi"
```

**Probes**

| Probe | Path | initialDelaySeconds | periodSeconds | timeoutSeconds | failureThreshold |
|-------|------|---------------------|----------------|----------------|------------------|
| Liveness | `/health` | 15 | 20 | 5 | 3 |
| Readiness | `/health` | 5 | 10 | 3 | 3 |

**Security — pod**

- `runAsNonRoot: true`
- `runAsUser: 1000`
- `fsGroup: 1000`

**Security — container**

- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true`
- `capabilities.drop: ["ALL"]`

**Other**

- `restartPolicy: Always`
- **Topology spread:** spread across zones — `topologyKey: topology.kubernetes.io/zone`, `maxSkew: 1`, `whenUnsatisfiable: ScheduleAnyway`

### 3. Service

- **No Ingress** — this is the only external entrypoint.
- Name: `payment-api`, namespace: `payment-api`
- Type: **`LoadBalancer`** (not ClusterIP or NodePort alone)
- Port **80** → `targetPort` **3000**, protocol **TCP**
- Selector: **`app: payment-api`**

### 4. ConfigMap

- Name: `payment-api-config`, namespace: `payment-api`
- Data (non-sensitive):

  | Key | Value |
  |-----|--------|
  | `NODE_ENV` | `"production"` |
  | `PORT` | `"3000"` |
  | `LOG_LEVEL` | `"info"` |

- Reference this ConfigMap in the Deployment **`envFrom`** block.

### 5. HorizontalPodAutoscaler (HPA)

- Name: `payment-api`, namespace: `payment-api`
- Target: `Deployment/payment-api`
- Min replicas: **2**, max replicas: **5**
- Scale when average **CPU** utilization **> 70%**
- Scale when average **memory** utilization **> 80%**
- API: **`autoscaling/v2`**

### 6. PodDisruptionBudget (PDB)

- Name: `payment-api`, namespace: `payment-api`
- `minAvailable: 1` (at least one pod during drains / voluntary disruption)

---

## File structure

```text
k8s/
├── namespace.yaml
├── configmap.yaml
├── deployment.yaml
├── service.yaml
├── hpa.yaml
├── pdb.yaml
└── kustomization.yaml   # references all of the above
```

---

## Kustomize requirements

Create **`kustomization.yaml`** that:

1. Lists every file above under **`resources`**
2. Sets **`namespace: payment-api`** globally (avoid repeating namespace in each file where appropriate)
3. Adds common labels on all resources:
   - `managed-by: kustomize`
   - `environment: prod`

---

## README for `k8s/`

Include **`k8s/README.md`** covering:

### 1. Prerequisites

- `kubectl` configured for **demo-eks-cluster** (or your target context)
- EKS can provision AWS load balancers for `Service` type `LoadBalancer` (default cloud controller)
- Image pushed to ECR

### 2. Apply everything

```bash
kubectl apply -k k8s/
```

### 3. Apply individual files

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/pdb.yaml
```

### 4. Deployment status

```bash
kubectl rollout status deployment/payment-api -n payment-api
```

### 5. LoadBalancer hostname (no Ingress)

```bash
kubectl get svc payment-api -n payment-api
```

### 6. Pods

```bash
kubectl get pods -n payment-api
```

### 7. Logs

```bash
kubectl logs -l app=payment-api -n payment-api --follow
```

### 8. Rolling image update

```bash
kubectl set image deployment/payment-api \
  payment-api=<account-id>.dkr.ecr.<region>.amazonaws.com/payment-api:<new-tag> \
  -n payment-api
```

---

## Technical constraints

- Target Kubernetes **1.35**
- Use **stable** API versions only (no alpha/beta unless unavoidable — document exceptions)
- Use **`app.kubernetes.io/*`** recommended labels on resources
- All namespaced resources in **`payment-api`**
- Do **not** use `hostNetwork`, `hostPID`, or privileged containers
- Do **not** use Ingress; external traffic only via **`LoadBalancer`** `Service`
- **Comment** each manifest section so learners know what it does
- Set **`imagePullPolicy: Always`** so ECR’s latest image is pulled on relevant restarts
