# Module 1 — Demo 2: Build and validate EKS infrastructure (AI-generated Terraform)

Use the prompt below with your GenAI tool to produce a **complete, production-style Terraform** layout that provisions the AWS pieces for this course’s **demo environment**.

---

## AI prompt (copy into your assistant)

```text
You are an expert AWS and Terraform engineer. Generate a complete, production-ready
Terraform configuration to provision the following AWS infrastructure for a demo environment.
```

---

## Requirements

### 1. AWS EKS cluster

| Setting | Value |
|---------|--------|
| Cluster name | `demo-eks-cluster` |
| Kubernetes version | **1.35** (supported on Amazon EKS for this demo) |

**Version note:** Kubernetes **1.36** may be the latest upstream release as of April 2026, but if AWS has not yet published it for EKS, stay on **1.35** until support appears, then bump the Terraform default.

**Networking (dedicated VPC)**

| Component | Count / role |
|-----------|----------------|
| Public subnets | 2 |
| Private subnets | 2 |
| NAT Gateway | Yes — egress for private subnets |
| Internet Gateway | Yes — public subnet access |

**Managed node group**

| Setting | Value |
|---------|--------|
| Instance type | `t3.medium` |
| Scaling | Desired **2**, min **1**, max **3** |
| Node OS | **Amazon Linux 2023 (AL2023)** — required for EKS **1.33+** (AL2 AMIs are not released for these versions) |
| Subnet placement | **Private** subnets only |
| Public IPs on nodes | **No** |

**Cluster add-ons (managed)**

- `coredns`
- `kube-proxy`
- `vpc-cni`
- `aws-ebs-csi-driver`

#### EKS access entries (console / API access)

- Grant **cluster admin** to:
  - `data.aws_caller_identity.current.arn` (the principal running `terraform apply`), and
  - every ARN in `var.cluster_admin_principal_arns`
- Use `aws_eks_access_entry` (type `STANDARD`) and `aws_eks_access_policy_association` with:
  - Policy: `arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy`
  - `access_scope { type = "cluster" }`

Do **not** rely on `bootstrap_cluster_creator_admin_permissions` alone for portability (creation-time semantics vary). **Explicit access entries** are more reliable across destroy/recreate and shared labs.

#### Add-on ordering (avoid CoreDNS / CSI stuck states)

| Order | Add-on | Dependency |
|-------|--------|----------------|
| Before node group | **`vpc-cni`** | Node group `depends_on` this add-on |
| After node group | **`kube-proxy`**, **`coredns`**, **`aws-ebs-csi-driver`** | Each `depends_on` the node group |

#### EBS CSI driver IAM (not the app IRSA role)

- **`aws-ebs-csi-driver`** must use its **own** IRSA role trusted for  
  `system:serviceaccount:kube-system:ebs-csi-controller-sa`
- Attach **`arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy`**
- Set `service_account_role_arn` on the `aws_eks_addon` named `aws-ebs-csi-driver` to that role
- **Never** reuse the payment-api application IRSA role for the EBS CSI add-on (wrong trust and policies → add-on stuck in `CREATING` / timeout)

#### OIDC for IRSA (required pattern)

- EKS exposes an OIDC issuer URL; **IAM OIDC provider is not created automatically** for Terraform IRSA.
- Use `data "tls_certificate" "eks_oidc"` against the cluster issuer URL and `resource "aws_iam_openid_connect_provider" "eks"` with `client_id_list = ["sts.amazonaws.com"]` and a valid `thumbprint_list`.
- **Do not** use on

### 2. Amazon ECR

| Requirement | Detail |
|-------------|--------|
| Repository name | `payment-api` |
| Tag mutability | **IMMUTABLE** |
| Scanning | On push |
| Lifecycle policy | Keep only the **last 10** tagged images; expire **untagged** images after **7** days |

### 3. IAM (EKS node group → ECR)

- Create an IAM role for the EKS **node group**
- Attach these managed policies to the **node** IAM role:

  | Policy | Purpose |
  |--------|---------|
  | `AmazonEKSWorkerNodePolicy` | Node join and cluster communication |
  | `AmazonEKS_CNI_Policy` | VPC CNI networking |
  | `AmazonEC2ContainerRegistryReadOnly` | **ECR image pull** |

- Create an **IAM OIDC provider** for the cluster (IRSA — IAM Roles for Service Accounts)
- **Output** the ECR repository URI for CI/CD and image builds

---

## Terraform structure

Organize the code like this:

```text
terraform/
├── main.tf              # Root module — wires child modules
├── variables.tf         # Inputs and defaults
├── outputs.tf           # Cluster endpoint, ECR URI, kubeconfig helper, etc.
├── providers.tf         # AWS (+ Kubernetes provider if used)
├── versions.tf          # Required Terraform and provider versions
└── modules/
    ├── vpc/             # VPC, subnets, IGW, NAT
    ├── eks/             # EKS cluster, node group, add-ons, OIDC
    └── ecr/             # ECR repo, lifecycle policy
```

---

## Technical constraints

| Area | Requirement |
|------|-------------|
| Terraform | `>= 1.6` |
| AWS provider | `~> 5.0` |
| EKS module | Official **`terraform-aws-modules/eks/aws`** (**v20+**) |
| VPC module | Official **`terraform-aws-modules/vpc/aws`** (**v5+**) |
| Region | **`us-east-1`**, parameterized via variable |
| State | **Local** backend for the demo (no remote backend required) |
| Account / region | Use **`aws_caller_identity`** and **`aws_region`** data sources — **no hardcoded account IDs** |

**Mandatory tags (all resources)**

| Tag | Value |
|-----|--------|
| `Environment` | `demo` |
| `Project` | `payment-api` |
| `ManagedBy` | `terraform` |

---

## Outputs to include

| Output | Description |
|--------|-------------|
| EKS cluster name | For `kubectl` / `aws eks` commands |
| EKS cluster endpoint | API server URL |
| EKS cluster certificate authority data | CA for kubeconfig |
| `update-kubeconfig` helper | e.g. `aws eks update-kubeconfig --region <region> --name <cluster-name>` |
| ECR repository URL | For the `payment-api` image pipeline |

---

## Additional notes

- Add **comments** in Terraform explaining each major block
- Security groups should follow **least privilege**
- Nodes stay **without** public IPs; use **AL2023** AMI type (AL2 is deprecated for EKS **1.33+**)

### README for `terraform/`

Include a **`README.md`** with:

1. **Prerequisites** — AWS CLI, `kubectl`, Terraform (versions aligned with `versions.tf`)
2. **Deploy steps** — init, plan, apply, and any ordering notes
3. **Push an image** — how to build/tag and push to the `payment-api` ECR repository
4. **Connect `kubectl`** — use the cluster name, region, and `aws eks update-kubeconfig` output from Terraform
