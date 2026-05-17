# Module 2 — Demo 4: Build a Jenkins CI/CD pipeline for EKS (AI-assisted)

Use the prompt below with your GenAI tool to generate a **complete, production-ready Jenkins Pipeline** using **Job DSL** for the **payment-api**. The pipeline builds a **Node.js 24** TypeScript API, pushes the Docker image to **AWS ECR**, and deploys to **AWS EKS** using existing Kubernetes manifests in the repo.

---

## AI prompt (copy into your assistant)

```text
You are an expert Jenkins and DevOps engineer. Generate a complete, production-ready
Jenkins Pipeline using Job DSL for the payment-api. The pipeline will build a
Node.js 24 TypeScript API, push the Docker image to AWS ECR, and deploy it to an
AWS EKS cluster using existing Kubernetes manifests.
```

---

## Context and existing infrastructure

The following infrastructure already exists and must be referenced exactly:

| Item | Value |
|------|--------|
| EKS cluster name | `demo-eks-cluster` |
| EKS region | `us-east-1` |
| ECR repository | `<account-id>.dkr.ecr.us-east-1.amazonaws.com/payment-api` |
| Kubernetes namespace | `payment-api` |
| Manifests location | `k8s/` (in the same repo) |
| Deployment name | `payment-api` |
| Container name | `payment-api` |
| Environment | `prod` |
| Node.js version | **24** (LTS) |
| Kustomize | Yes — `k8s/kustomization.yaml` exists |

---

## Job DSL requirements

### 1. Seed job

- Create a Job DSL seed job script (`seed.groovy`) that programmatically generates the pipeline job.
- The seed job must:
  - Be stored in the repo at `jenkins/seed.groovy`
  - Generate a pipeline job named **`payment-api-pipeline`**
  - Configure the pipeline to read its Jenkinsfile from SCM
  - Set the Jenkinsfile path to **`jenkins/Jenkinsfile`**
  - Configure the pipeline to poll SCM or use a webhook trigger

### 2. Folder structure

Organize all Jenkins files as follows:

```text
jenkins/
├── seed.groovy         ← Job DSL seed script (creates the pipeline job)
├── Jenkinsfile         ← Declarative pipeline definition
└── scripts/
    ├── build.sh        ← Docker build and ECR push logic
    ├── deploy.sh       ← kubectl/kustomize deploy logic
    └── rollback.sh     ← Rollback to previous image tag on failure
```

---

## Pipeline requirements (Jenkinsfile)

Use **Declarative Pipeline** syntax with the following stages.

### Pipeline-level configuration

| Setting | Value |
|---------|--------|
| Agent | `any` (or a labeled agent with Docker and `kubectl` installed) |

**Environment variables (top-level):**

| Variable | Value |
|----------|--------|
| `AWS_REGION` | `us-east-1` |
| `ECR_REGISTRY` | `<account-id>.dkr.ecr.us-east-1.amazonaws.com` |
| `ECR_REPOSITORY` | `payment-api` |
| `EKS_CLUSTER_NAME` | `demo-eks-cluster` |
| `K8S_NAMESPACE` | `payment-api` |
| `DEPLOYMENT_NAME` | `payment-api` |
| `IMAGE_TAG` | `${env.GIT_COMMIT.take(7)}` — short Git SHA as tag |
| `IMAGE_NAME` | `${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}` |

**Options:**

```groovy
timeout(time: 30, unit: 'MINUTES')
buildDiscarder(logRotator(numToKeepStr: '10'))
disableConcurrentBuilds()
timestamps()
```

### Stage 1 — Checkout

- Check out source code from SCM
- Print the branch name and short Git commit SHA being built
- Set build display name: `#${BUILD_NUMBER} - ${GIT_BRANCH} - ${IMAGE_TAG}`

### Stage 2 — Lint and validate

- Run inside a **`node:24-alpine`** Docker container
- Install dependencies: `npm ci`
- Run TypeScript type checking: `npx tsc --noEmit`
- Run linter: `npm run lint` (if the script exists, otherwise skip gracefully)
- Run unit tests: `npm test`
- Publish test results if a JUnit-compatible report is generated

### Stage 3 — Build Docker image

- Build the Docker image using the Dockerfile in the repo root
- Tag the image with:
  1. Short Git SHA: `<ecr-registry>/payment-api:<git-sha>`
  2. Branch name: `<ecr-registry>/payment-api:<branch-name>`
  3. **Latest** (only on `main`/`master`): `<ecr-registry>/payment-api:latest`
- Use `--build-arg` to pass `BUILD_DATE` and `GIT_COMMIT` into the image
- Print the image size after build

### Stage 4 — Security scan

- Run a **Trivy** vulnerability scan on the built image
- Fail the build if any **CRITICAL** vulnerabilities are found
- Generate a scan report and archive it as a build artifact
- Use the **`aquasec/trivy`** Docker image (no local install needed)

### Stage 5 — Push to ECR

Authenticate and push:

```bash
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY
```

- Push all three image tags to ECR
- Push **`latest`** only when building from **`main`** or **`master`**
- Wrap in **try/catch** — if push fails, mark the stage failed but continue so rollback logic can run

### Stage 6 — Update kubeconfig

```bash
aws eks update-kubeconfig \
  --region $AWS_REGION \
  --name $EKS_CLUSTER_NAME
```

Verify cluster connectivity:

```bash
kubectl cluster-info
kubectl get nodes
```

### Stage 7 — Deploy to EKS

Update the image tag with Kustomize, then apply:

```bash
cd k8s && kustomize edit set image \
  payment-api=$IMAGE_NAME

kubectl apply -k k8s/
```

Wait for rollout:

```bash
kubectl rollout status deployment/$DEPLOYMENT_NAME \
  -n $K8S_NAMESPACE \
  --timeout=5m
```

After successful rollout, print the ALB URL:

```bash
kubectl get ingress payment-api \
  -n $K8S_NAMESPACE \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Stage 8 — Smoke test

- Wait **30 seconds** for the ALB to become available
- Retrieve the ALB hostname from the Ingress
- Hit `/health` and assert HTTP **200**:

```bash
curl -f http://<alb-hostname>/health
```

- If the smoke test fails, trigger the rollback stage automatically

### Stage 9 — Rollback (only on failure)

- Runs **only** if Stage 7 or Stage 8 fails

```bash
kubectl rollout undo deployment/$DEPLOYMENT_NAME \
  -n $K8S_NAMESPACE
```

- Wait for the rollback rollout to complete
- Print the image rolled back to:

```bash
kubectl get deployment $DEPLOYMENT_NAME \
  -n $K8S_NAMESPACE \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

- Send a failure notification (see Post section)

---

## Triggers

Configure the following triggers in the Job DSL seed script:

| Trigger | Detail |
|---------|--------|
| SCM webhook | GitHub/SCM webhook on push to **`main`** |
| Scheduled (optional) | Nightly build — cron: `H 2 * * *` (2:00 AM daily) |
| Manual / parameterized | Allow manual trigger with custom **`IMAGE_TAG`** to deploy a specific version |

---

## Post-build actions

In the Jenkinsfile `post {}` block:

| Condition | Actions |
|-----------|---------|
| **always** | Clean up local Docker images: `docker rmi $IMAGE_NAME \|\| true`; archive the Trivy scan report |
| **success** | Print: `✅ Deployment successful — payment-api:${IMAGE_TAG} is live`; print the ALB public URL |
| **failure** | Print failure summary with failed stage; trigger rollback if deploy or smoke test failed; send notification (placeholder): `❌ Pipeline FAILED — payment-api build #${BUILD_NUMBER} Branch: ${GIT_BRANCH} \| Commit: ${IMAGE_TAG}` |
| **unstable** | Notify that tests passed with warnings |

---

## Credentials and secrets

All secrets must be stored in the **Jenkins Credentials Store** — never hardcoded. Reference them with `credentials()` or `withCredentials()`.

| ID | Type | Used for |
|----|------|----------|
| `aws-credentials` | AWS Access Key | ECR auth, EKS |
| `eks-kubeconfig` | Secret file | `kubectl` access |
| `ecr-account-id` | Secret text | ECR registry URL |
| `github-token` | Username/Password | SCM checkout |
| `slack-webhook-url` | Secret text | Failure alerts (optional) |

In the Jenkinsfile:

```groovy
withCredentials([...])
// or
environment { AWS_CREDS = credentials('aws-credentials') }
```

---

## Seed job requirements (`seed.groovy`)

The `seed.groovy` file must:

- Create a **`pipelineJob`** named **`payment-api-pipeline`** inside folder **`payment-api`**
- Configure:
  - **Description:** `CI/CD pipeline for the payment-api — builds, scans, and deploys to EKS (prod)`
  - **SCM:** Git repo URL + credentials
  - **Branch to build:** `*/main`
  - **Jenkinsfile path:** `jenkins/Jenkinsfile`
  - **Build discarder:** keep last **10** builds
  - **Build parameters:**

    | Parameter | Type | Default | Notes |
    |-----------|------|---------|--------|
    | `DEPLOY_ENV` | choice | `prod` | Locked to prod for now |
    | `IMAGE_TAG` | string | `latest` | Override for manual deploys |
    | `SKIP_TESTS` | boolean | `false` | Escape hatch for hotfixes |

  - **Triggers:**
    - GitHub webhook (push to `main`)
    - Cron: `H 2 * * *` (nightly)

---

## Jenkins agent requirements

Document required tools on the Jenkins agent (or Docker-in-Docker setup):

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | latest | Build and push images |
| `kubectl` | 1.35 | Deploy to EKS |
| Kustomize | latest | Image tag patching |
| AWS CLI | v2 | ECR auth, EKS config |
| Node.js | 24 (LTS) | Lint and test stage |
| Trivy | latest | Security scanning |
| `curl` | any | Smoke test |

Provide a sample **`jenkins-agent/Dockerfile`** for a custom Jenkins agent image that pre-installs all of the above.

---

## File deliverables

| # | Path | Description |
|---|------|-------------|
| 1 | `jenkins/seed.groovy` | Job DSL seed script |
| 2 | `jenkins/Jenkinsfile` | Declarative pipeline |
| 3 | `jenkins/scripts/build.sh` | Docker build + ECR push |
| 4 | `jenkins/scripts/deploy.sh` | `kubectl`/Kustomize deploy |
| 5 | `jenkins/scripts/rollback.sh` | Rollback on failure |
| 6 | `jenkins-agent/Dockerfile` | Custom Jenkins agent image |
| 7 | `jenkins/README.md` | Setup and usage documentation |

---

## README requirements (`jenkins/README.md`)

Include the following sections:

### 1. Prerequisites

- Jenkins version **2.400+**
- Required Jenkins plugins:
  - Job DSL, Pipeline, Git, AWS Steps
  - Kubernetes CLI, Credentials Binding
  - Blue Ocean (optional), Timestamper
  - JUnit, HTML Publisher

### 2. First-time setup

- How to run the seed job to generate the pipeline
- How to configure credentials in Jenkins
- How to configure the GitHub webhook

### 3. Pipeline flow diagram

ASCII art showing all stages end to end.

### 4. Manual deployment

- How to trigger a manual build with a custom image tag

### 5. Rollback instructions

| Type | Steps |
|------|--------|
| **Automatic** | Pipeline handles rollback on deploy/smoke failure |
| **Manual** | `kubectl rollout undo deployment/payment-api -n payment-api` |
