# Payment API Kubernetes Deployment

Production-ready Kubernetes manifests for deploying the Node.js payment API on AWS EKS (Kubernetes 1.35).

## Overview

This directory contains complete Kubernetes manifests using Kustomize for deploying:
- **Application**: Payment API (Node.js 24, TypeScript)
- **Namespace**: `payment-api`
- **Environment**: Production
- **External Access**: AWS LoadBalancer Service (no Ingress)

## Prerequisites

### 1. kubectl Configuration

Ensure `kubectl` is configured to connect to your EKS cluster:

```bash
# Update kubeconfig with EKS cluster credentials
aws eks update-kubeconfig --region <region> --name demo-eks-cluster

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### 2. EKS Load Balancer Support

EKS automatically provisions AWS Load Balancers for `Service` type `LoadBalancer` using the AWS Cloud Controller Manager. No additional configuration needed for basic setups.

### 3. Container Image in ECR

Ensure your container image is pushed to Amazon ECR:

```bash
# Build and tag image
docker build -t payment-api:latest .
docker tag <account-id>.dkr.ecr.<region>.amazonaws.com/payment-api:latest

# Push to ECR
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/payment-api:latest
```

### 4. Update Image Reference

Before deployment, update the container image in `deployment.yaml` with your actual ECR details:

```yaml
image: "<account-id>.dkr.ecr.<region>.amazonaws.com/payment-api:latest"
```

Replace:
- `<account-id>` with your AWS account ID
- `<region>` with your AWS region (e.g., `us-east-1`)

---

## Deployment

### Apply All Resources (Recommended)

Using Kustomize to apply all resources at once:

```bash
kubectl apply -k k8s/
```

This applies resources in the correct order:
1. Namespace
2. ConfigMap
3. Deployment
4. Service
5. HorizontalPodAutoscaler
6. PodDisruptionBudget

### Apply Individual Files

Apply resources manually in order:

```bash
# 1. Create namespace
kubectl apply -f k8s/namespace.yaml

# 2. Create ConfigMap
kubectl apply -f k8s/configmap.yaml

# 3. Create Deployment
kubectl apply -f k8s/deployment.yaml

# 4. Create Service
kubectl apply -f k8s/service.yaml

# 5. Create HPA
kubectl apply -f k8s/hpa.yaml

# 6. Create PDB
kubectl apply -f k8s/pdb.yaml
```

---

## Verification

### Check Deployment Status

Verify the deployment has completed successfully:

```bash
kubectl rollout status deployment/payment-api -n payment-api
```

### View Pods

Check that pods are running and ready:

```bash
kubectl get pods -n payment-api
```

Expected output:
```
NAME                          READY   STATUS    RESTARTS   AGE
payment-api-xxxxxxxxx-xxxxx   1/1     Running   0          2m
payment-api-xxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### View Services

Get the LoadBalancer hostname:

```bash
kubectl get svc payment-api -n payment-api
```

Expected output:
```
NAME          TYPE           CLUSTER-IP       EXTERNAL-IP                                           PORT(S)        AGE
payment-api   LoadBalancer   10.100.XX.XX     abc123xyz-123456789.us-east-1.elb.amazonaws.com   80:3000/TCP   3m
```

The `EXTERNAL-IP` column shows your AWS LoadBalancer DNS name. Wait a few minutes for it to be provisioned.

### Test Endpoint

Once the LoadBalancer is active, test the health endpoint:

```bash
# Get the LoadBalancer hostname
LB_HOST=$(kubectl get svc payment-api -n payment-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://${LB_HOST}/health
```

---

## Operations

### View Logs

Stream logs from all payment-api pods:

```bash
kubectl logs -l app=payment-api -n payment-api --follow
```

View logs from a specific pod:

```bash
kubectl logs -n payment-api <pod-name>
```

### Describe Resources

Get detailed information about resources:

```bash
# Deployment details
kubectl describe deployment payment-api -n payment-api

# Pod details
kubectl describe pod -l app=payment-api -n payment-api

# Service details
kubectl describe svc payment-api -n payment-api

# HPA details (shows current scaling metrics)
kubectl describe hpa payment-api -n payment-api
```

### Scaling

Manual scaling (overrides HPA temporarily):

```bash
# Scale to 3 replicas
kubectl scale deployment payment-api --replicas=3 -n payment-api

# Let HPA manage scaling again
kubectl scale deployment payment-api --replicas=2 -n payment-api
```

### Rolling Update

Update to a new image version:

```bash
kubectl set image deployment/payment-api \
  payment-api=<account-id>.dkr.ecr.<region>.amazonaws.com/payment-api:<new-tag> \
  -n payment-api
```

Monitor the rollout:

```bash
kubectl rollout status deployment/payment-api -n payment-api
```

### Rollback

Rollback to previous revision:

```bash
# Rollback to previous version
kubectl rollout undo deployment/payment-api -n payment-api

# Rollback to specific revision
kubectl rollout undo deployment/payment-api --to-revision=<revision> -n payment-api
```

View rollout history:

```bash
kubectl rollout history deployment/payment-api -n payment-api
```

---

## Monitoring

### HPA Metrics

View current HPA scaling metrics:

```bash
kubectl get hpa payment-api -n payment-api
```

Output shows current CPU/memory utilization and replica count.

### Resource Usage

Check resource consumption:

```bash
kubectl top pods -n payment-api
```

### Events

View namespace events for troubleshooting:

```bash
kubectl get events -n payment-api --sort-by='.lastTimestamp'
```

---

## Security Features

These manifests include production security best practices:

### Pod Security
- ✅ Runs as non-root user (UID 1000)
- ✅ Read-only root filesystem
- ✅ All Linux capabilities dropped
- ✅ Privilege escalation disabled

### Network Security
- ✅ No hostNetwork or hostPID
- ✅ No privileged containers
- ✅ Service exposes only port 80

### Availability
- ✅ Topology spread across availability zones
- ✅ PodDisruptionBudget ensures minimum availability
- ✅ Health checks (liveness/readiness probes)

---

## Cleanup

### Delete All Resources

Delete the entire namespace and all resources:

```bash
kubectl delete namespace payment-api
```

### Delete Individual Resources

```bash
kubectl delete -f k8s/pdb.yaml
kubectl delete -f k8s/hpa.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/configmap.yaml
kubectl delete -f k8s/namespace.yaml
```

### Using Kustomize

```bash
kubectl delete -k k8s/
```

---

## Troubleshooting

### Pods Not Starting

Check events and logs:

```bash
kubectl describe pod -l app=payment-api -n payment-api
kubectl logs -l app=payment-api -n payment-api
```

### LoadBalancer Not Provisioned

Check service status:

```bash
kubectl describe svc payment-api -n payment-api
```

Look for events indicating AWS LoadBalancer provisioning issues.

### HPA Not Scaling

Ensure metrics server is installed:

```bash
kubectl get pods -n kube-system | grep metrics-server
```

Check HPA events:

```bash
kubectl describe hpa payment-api -n payment-api
```

---

## Architecture

```
Internet
    ↓
AWS LoadBalancer (Service type: LoadBalancer)
    ↓
Payment API Pods (2-5 replicas, spread across zones)
    ↓
Health Endpoint: /health (port 3000)
```

### Components

| Resource | Purpose |
|----------|---------|
| Namespace | Isolation boundary for payment-api resources |
| ConfigMap | Non-sensitive configuration (NODE_ENV, PORT, LOG_LEVEL) |
| Deployment | Manages 2-5 replicas with rolling updates |
| Service | Exposes app via AWS LoadBalancer on port 80 |
| HPA | Auto-scales based on CPU (>70%) and memory (>80%) |
| PDB | Ensures 1 pod available during disruptions |

---

## Notes

- **No Database**: This demo application has no persistent storage
- **No Ingress**: External access is via LoadBalancer Service only
- **Image Pull**: Uses `imagePullPolicy: Always` to always fetch latest from ECR
- **ECR Authentication**: If needed, configure `imagePullSecrets` in deployment.yaml
