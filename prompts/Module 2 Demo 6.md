# Module 2 — Demo 6: Auditing a GitHub Actions Pipeline (AI-assisted)

Use the prompt below with your GenAI tool to conduct a **formal security and configuration audit** of a GitHub Actions workflow. The sample workflow in this doc is intentionally flawed — your assistant should identify every issue across efficiency, misconfiguration, and security categories.

---

## AI prompt (copy into your assistant)

```text
You are a senior DevOps security engineer conducting a formal audit of a GitHub
Actions CI/CD pipeline. Your job is to find every problem — do not summarize what
is working correctly; focus entirely on what needs to be fixed.

Review the workflow YAML provided below and identify all issues across these
three categories:

EFFICIENCY ISSUES
Unnecessary or redundant steps, missing build caching, repeated authentication,
slow or wasteful patterns, and anything that increases pipeline runtime or cost
without adding value.

MISCONFIGURATION ISSUES
Incorrect triggers, wrong branch or environment targeting, unpinned or invalid
action references, missing error handling or rollout safeguards, and settings
that cause unreliable or unintended deployments.

SECURITY ISSUES
Overly broad permissions, secrets exposed in logs or environment variables,
long-lived credentials in the runner environment, unpinned third-party actions,
and any practice that increases credential leakage or supply-chain risk.

For each finding, provide:
- SEVERITY: Critical / High / Medium / Low
- CATEGORY: Efficiency / Misconfiguration / Security
- LOCATION: Exactly where in the file/config the issue exists
- FINDING: What the problem is
- RISK: What could go wrong as a result
- REMEDIATION: The corrected code or configuration
```

---

## Workflow under audit

Copy the YAML below along with the AI prompt above:

```yaml
name: Deploy Payment Service

on:
  push:
    branches: [main]

permissions: write-all

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@main

      - name: Configure AWS
        run: |
          echo "AWS_ACCESS_KEY_ID=${{ secrets.AWS_ACCESS_KEY }}" >> $GITHUB_ENV
          echo "AWS_SECRET_ACCESS_KEY=${{ secrets.AWS_SECRET }}" >> $GITHUB_ENV

      - name: Build Docker image
        run: |
          docker build -t payment-service:${{ github.sha }} .
          docker tag payment-service:${{ github.sha }} \
            ${{ secrets.ECR_REGISTRY }}/payment-service:latest

      - name: Push to ECR
        run: |
          aws ecr get-login-password | docker login \
            --username AWS \
            --password-stdin ${{ secrets.ECR_REGISTRY }}
          docker push ${{ secrets.ECR_REGISTRY }}/payment-service:latest

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name production-cluster
          kubectl set image deployment/payment-service \
            payment-service=${{ secrets.ECR_REGISTRY }}/payment-service:latest
          kubectl rollout status deployment/payment-service

      - name: Notify Slack
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -d '{"text": "Deployed ${{ github.actor }} to production"}'
```

---

## Audit categories

| Category | What to look for |
|----------|------------------|
| **Efficiency** | Redundant auth steps, missing layer caching, rebuilding unchanged artifacts, pushing duplicate tags, no concurrency controls |
| **Misconfiguration** | Deploy on every push with no gates, missing namespace/context, `:latest` tag in production, no rollback or smoke test, checkout pinned to a branch ref instead of a commit SHA |
| **Security** | `write-all` permissions, long-lived AWS keys written to `$GITHUB_ENV`, unpinned actions (`@main`), secrets interpolated into shell commands, production deploy without environment protection |

---

## Finding format

Each finding in the audit report should include all six fields:

| Field | Detail |
|-------|--------|
| **SEVERITY** | `Critical` / `High` / `Medium` / `Low` |
| **CATEGORY** | `Efficiency` / `Misconfiguration` / `Security` |
| **LOCATION** | File path and line or YAML key (e.g. `permissions:`, `steps[0].uses`) |
| **FINDING** | Clear description of the defect |
| **RISK** | Concrete impact if left unfixed |
| **REMEDIATION** | Corrected YAML, config snippet, or recommended practice |

---

## Quick checklist for reviewers

After running the audit, confirm the assistant addressed at least:

- [ ] **Permissions** — principle of least privilege (not `write-all`)
- [ ] **Action pinning** — commit SHA or version tag, not a floating branch ref
- [ ] **AWS authentication** — OIDC / IAM role, not static keys in `$GITHUB_ENV`
- [ ] **Secret handling** — no secrets echoed or passed unsafely in shell commands
- [ ] **Image tagging** — immutable SHA-based tags for deploys, not `:latest` alone
- [ ] **Deploy safety** — environment gates, namespace specified, smoke test or rollback path
- [ ] **Supply chain** — third-party actions pinned and from trusted sources

---

## Remediation patterns (reference)

When fixing findings, prefer these GitHub Actions best practices:

| Area | Recommended approach |
|------|---------------------|
| AWS auth | `aws-actions/configure-aws-credentials` with **OIDC** (`id-token: write`) and an IAM role — not access keys in env |
| Checkout | `actions/checkout@v4` pinned to a **full commit SHA** |
| Permissions | Explicit minimal scopes per job (e.g. `contents: read`, `id-token: write`) |
| ECR login | `aws ecr get-login-password --region <region>` with region set explicitly |
| Deploy | Use a GitHub **Environment** with required reviewers for production; deploy the **SHA tag**, not `latest` |
| Notifications | Use a dedicated action or mask webhook URLs; avoid building JSON with unescaped actor names in shell |
