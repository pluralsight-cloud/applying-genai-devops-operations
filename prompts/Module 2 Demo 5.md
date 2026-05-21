# Module 2 — Demo 5: Build a Jenkins CI/CD pipeline for EKS (AI-assisted)

Use the prompt below with your GenAI tool to generate a **complete, production-ready Jenkins Pipeline** using **Job DSL** for the **payment-api**. The pipeline builds a **Node.js 24** TypeScript API, pushes the Docker image to **AWS ECR**, and deploys to **AWS EKS** using existing Kubernetes manifests in the repo.

This version incorporates fixes from real pipeline runs (Docker paths, kubeconfig handling, Declarative Pipeline Groovy rules, and Jenkins agent setup).

---

## AI prompt (copy into your assistant)

```text
You are an expert Jenkins and DevOps engineer. Generate a complete, production-ready
Jenkins Pipeline using Job DSL for the payment-api. The pipeline will build a
Node.js 24 TypeScript API, push the Docker image to AWS ECR, and deploy it to an
AWS EKS cluster using existing Kubernetes manifests.

Follow ALL implementation notes in the "Critical implementation notes" section
at the end of this prompt — they prevent common failures seen in production Jenkins runs.
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
| External access | **`LoadBalancer` Service** only — **no Ingress** (see Demo 4 manifests) |

### Repository layout (important)

| Path | Purpose |
|------|---------|
| `app/` | Node.js application (`package.json`, `src/`, tests) |
| `app/Dockerfile` | Multi-stage Docker build — **not** at repo root |
| `k8s/` | Kubernetes manifests (Kustomize) |
| `jenkins/` | Jenkinsfile, seed job, helper scripts |

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
    └── rollback.sh     ← Rollback to previous ReplicaSet on failure
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
| `ECR_REPOSITORY` | `payment-api` |
| `EKS_CLUSTER_NAME` | `demo-eks-cluster` |
| `K8S_NAMESPACE` | `payment-api` |
| `DEPLOYMENT_NAME` | `payment-api` |
| `SCRIPTS_DIR` | `jenkins/scripts` |
| `TRIVY_REPORT` | `trivy-report.json` |

**Do not hardcode `ECR_REGISTRY` or `IMAGE_NAME` in the top-level `environment {}` block.** Resolve them at runtime in the Checkout stage using the `ecr-account-id` credential:

```groovy
withCredentials([string(credentialsId: 'ecr-account-id', variable: 'ECR_ACCOUNT_ID')]) {
    env.ECR_REGISTRY = "${ECR_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
}
env.IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
```

Set `IMAGE_TAG` from the short Git SHA (`GIT_COMMIT.take(7)`), or from the `IMAGE_TAG` build parameter on manual builds.

**Options:**

```groovy
timeout(time: 30, unit: 'MINUTES')
buildDiscarder(logRotator(numToKeepStr: '10'))
disableConcurrentBuilds()
timestamps()
```

### Stage 1 — Checkout

- Check out source code from SCM
- In a `script {}` block: resolve branch name, commit SHA, `IMAGE_TAG`, `ECR_REGISTRY`, and `IMAGE_NAME`
- Print the branch name and short Git commit SHA being built
- Set build display name: `#${BUILD_NUMBER} - ${GIT_BRANCH_SHORT} - ${IMAGE_TAG}`

### Stage 2 — Lint and validate

- Run all commands from the **`app/`** directory (`cd app` or `dir('app')`), where `package.json` lives
- Install dependencies: `npm ci` (fall back to `npm install` if no lockfile)
- Run TypeScript type checking: `npx tsc --noEmit`
- Run linter: `npm run lint` (if the script exists, otherwise skip gracefully)
- Run unit tests: `npm test`
- Publish test results if a JUnit-compatible report is generated (`junit allowEmptyResults: true`)

### Stage 3 — Build Docker image

- Build using the Dockerfile in **`app/`**, not the repo root
- In `jenkins/scripts/build.sh`, use:

```bash
docker build \
  --build-arg BUILD_DATE="${BUILD_DATE}" \
  --build-arg GIT_COMMIT="${GIT_COMMIT}" \
  -t "${IMAGE_SHA}" \
  -f app/Dockerfile \
  app
```

- Tag the image with:
  1. Short Git SHA: `<ecr-registry>/payment-api:<git-sha>`
  2. Branch name (slashes replaced with `-`): `<ecr-registry>/payment-api:<branch-name>`
  3. **Latest** (only on `main`/`master`): `<ecr-registry>/payment-api:latest`
- Print the image size after build
- Pass `ECR_REGISTRY`, `IMAGE_TAG`, `GIT_BRANCH`, `GIT_COMMIT`, and AWS credentials via `withCredentials`

### Stage 4 — Security scan

- Run a **Trivy** vulnerability scan on the built image (`${IMAGE_NAME}`)
- Fail the build if any **CRITICAL** vulnerabilities are found
- Generate a scan report and archive it as a build artifact
- Use the **`aquasec/trivy`** Docker image with the host Docker socket mounted:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)":/workspace \
  -w /workspace \
  aquasec/trivy:latest image \
  --severity CRITICAL \
  --exit-code 1 \
  --format json \
  --output trivy-report.json \
  "${IMAGE_NAME}"
```

### Stage 5 — Push to ECR

Authenticate and push (in `build.sh push`):

```bash
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY
```

- Push all applicable image tags to ECR
- Push **`latest`** only when building from **`main`** or **`master`**
- Use Declarative **`catchError`**` (not raw `try/catch` in `steps {}`) so a push failure is recorded without breaking Groovy parsing
- Set an env flag (e.g. `PUSH_FAILED=true`) when push fails; skip deploy stages when push failed

### Stage 6 — Configure kubeconfig

**Do not use `aws eks update-kubeconfig` in the pipeline** if you are storing a kubeconfig file in Jenkins credentials (`eks-kubeconfig`). The stored file typically uses EKS `exec` authentication and still requires AWS credentials at `kubectl` runtime.

Copy the kubeconfig **once** per build:

```bash
export AWS_DEFAULT_REGION="${AWS_REGION}"
rm -f "${WORKSPACE}/.kubeconfig"
cp "${KUBECONFIG_FILE}" "${WORKSPACE}/.kubeconfig"
chmod 600 "${WORKSPACE}/.kubeconfig"
export KUBECONFIG="${WORKSPACE}/.kubeconfig"
kubectl cluster-info
kubectl get nodes
```

Use `withCredentials` for **both**:
- `aws-credentials` (Username/Password → `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`)
- `eks-kubeconfig` (Secret file → `KUBECONFIG_FILE`)

**Later stages must not re-copy** the kubeconfig file. Only set:

```bash
export AWS_DEFAULT_REGION="${AWS_REGION}"
export KUBECONFIG="${WORKSPACE}/.kubeconfig"
```

Re-copying causes `cp: Permission denied` when the file becomes read-only after `kubectl` uses it.

Skip this stage (and deploy) when `PUSH_FAILED == 'true'`.

### Stage 7 — Deploy to EKS

- Reuse `${WORKSPACE}/.kubeconfig` from Stage 6 — do not copy again
- Provide `aws-credentials` and `export AWS_DEFAULT_REGION`
- Call `jenkins/scripts/deploy.sh`, which:
  - Verifies `KUBECONFIG` exists
  - Does **not** call `aws eks update-kubeconfig`
  - Patches the image with Kustomize and applies manifests

```bash
cd k8s && kustomize edit set image payment-api="${IMAGE_NAME}"
kubectl apply -k k8s/
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE} --timeout=5m
```

Print the LoadBalancer hostname or IP from the `payment-api` Service.

On stage failure, set `ROLLBACK_NEEDED=true` in a `post { failure { script { ... } } }` block.

### Stage 8 — Smoke test

- Reuse `${WORKSPACE}/.kubeconfig` with `aws-credentials` (no re-copy)
- Wait **30 seconds** for the LoadBalancer
- Retrieve hostname or IP from the `payment-api` Service (`jsonpath` for `.hostname`, fall back to `.ip`)
- Hit `/health` with retries:

```bash
curl -f --retry 5 --retry-delay 10 "http://${LB_HOST}/health"
```

- On failure, set `ROLLBACK_NEEDED=true`

### Stage 9 — Rollback (only on failure)

- Runs only when `ROLLBACK_NEEDED == 'true'`
- Reuse `${WORKSPACE}/.kubeconfig` with `aws-credentials`

```bash
kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE}
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE} --timeout=5m
kubectl get deployment ${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE} \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

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
| **always** | `docker rmi "${IMAGE_NAME}" \|\| true`; archive Trivy report |
| **success** | Print deployment success; print LoadBalancer URL (use `aws-credentials` + existing `KUBECONFIG`, no re-copy) |
| **failure** | Print failure summary; optional Slack webhook (wrap `try/catch` inside **`script {}`** — see below) |
| **unstable** | Notify that tests passed with warnings (`try/catch` inside **`script {}`**) |

---

## Credentials and secrets

All secrets must be stored in the **Jenkins Credentials Store** — never hardcoded.

| ID | Type | Used for |
|----|------|----------|
| `aws-credentials` | Username/Password (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) | ECR push, EKS token via kubeconfig `exec`, all `kubectl` stages |
| `eks-kubeconfig` | Secret file | Copied once to `${WORKSPACE}/.kubeconfig` in Configure kubeconfig stage |
| `ecr-account-id` | Secret text | Build `ECR_REGISTRY` URL at runtime |
| `github-token` | Username/Password | SCM checkout (if needed) |
| `slack-webhook-url` | Secret text | Failure alerts (optional) |

The Jenkins IAM user needs at minimum:
- ECR: push/pull to `payment-api` repository
- EKS: `eks:DescribeCluster` (if you ever use `aws eks update-kubeconfig`)
- Kubernetes API access via the cluster’s `aws-auth` / EKS access entries (for `kubectl`)

---

## Critical implementation notes (read before generating code)

### 1. Declarative Pipeline Groovy rules

- Raw `try/catch` is **not** allowed directly under `post { failure { } }` or `post { unstable { } }`. Wrap in `script { try { ... } catch { ... } }`.
- Raw `try/catch` is **not** allowed directly in `steps { }` for push failure handling — use `catchError` or a `script {}` block.

### 2. Docker on the Jenkins agent

- The agent user (usually `jenkins`) must access `/var/run/docker.sock` (add user to the `docker` group and restart Jenkins).
- Error if missing: `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`

### 3. Dockerfile location

- Dockerfile path: **`app/Dockerfile`**
- Build context: **`app`**
- Error if wrong: `failed to read dockerfile: open Dockerfile: no such file or directory`

### 4. Kubeconfig pattern (copy once, reuse everywhere)

| Stage | `eks-kubeconfig` copy | `aws-credentials` | `KUBECONFIG` export |
|-------|----------------------|-------------------|---------------------|
| Configure kubeconfig | Yes (`rm -f`, `cp`, `chmod 600`) | Yes | Yes |
| Deploy / Smoke / Rollback / post success | **No** | Yes | Yes |

- Error if AWS creds missing during `kubectl`: `Unable to locate credentials` / `exec: executable aws failed with exit code 253`
- Error if re-copying kubeconfig: `cp: cannot create regular file '.kubeconfig': Permission denied`

### 5. `deploy.sh` must not call `aws eks update-kubeconfig`

Assume `${WORKSPACE}/.kubeconfig` was created in the Configure kubeconfig stage. Fail fast if the file is missing.

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

Document required tools on the Jenkins agent:

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | latest | Build and push images; Trivy scan via socket |
| `kubectl` | 1.35+ | Deploy to EKS |
| Kustomize | latest | Image tag patching (`kustomize edit set image`) |
| AWS CLI | v2 | ECR login; EKS token via kubeconfig exec |
| Node.js | 24 (LTS) | Lint and test stage (in `app/`) |
| Trivy | via `aquasec/trivy` image | Security scanning |
| `curl` | any | Smoke test |

**Agent setup checklist:**

```bash
# Docker socket access for jenkins user
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Verify
sudo -u jenkins docker ps
sudo -u jenkins aws sts get-caller-identity   # with Jenkins AWS creds exported
```

---

## File deliverables

| # | Path | Description |
|---|------|-------------|
| 1 | `jenkins/seed.groovy` | Job DSL seed script |
| 2 | `jenkins/Jenkinsfile` | Declarative pipeline |
| 3 | `jenkins/scripts/build.sh` | Docker build + ECR push (`-f app/Dockerfile app`) |
| 4 | `jenkins/scripts/deploy.sh` | kubectl/Kustomize deploy (no `update-kubeconfig`) |
| 5 | `jenkins/scripts/rollback.sh` | Rollback on failure |
| 6 | `jenkins/README.md` | Setup and usage documentation |

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
- How to configure credentials in Jenkins (`aws-credentials`, `eks-kubeconfig`, `ecr-account-id`)
- Add `jenkins` user to the `docker` group on the agent
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

### 6. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `permission denied` on `docker.sock` | Jenkins user not in `docker` group | `usermod -aG docker jenkins`, restart Jenkins |
| `open Dockerfile: no such file` | Wrong build context | Use `-f app/Dockerfile` and context `app` |
| `Unable to locate credentials` on `kubectl` | Missing `aws-credentials` in stage | Add `withCredentials` + `AWS_DEFAULT_REGION` |
| `cp: Permission denied` on `.kubeconfig` | Re-copying kubeconfig after kubectl | Copy once in Configure kubeconfig only |
| `Expected a step` at `try {` | `try/catch` outside `script {}` in `post {}` | Wrap in `script { }` |
