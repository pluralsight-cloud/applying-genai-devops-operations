# Terraform Demo Environment

This Terraform configuration provisions a complete AWS demo environment with:
- **EKS cluster** (Kubernetes 1.35) with managed node group
- **ECR repository** for the payment-api container images
- **VPC networking** with public/private subnets and NAT gateway

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Terraform | >= 1.6 | [Download](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | >= 2.0 | [Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| kubectl | Latest | [Install](https://kubernetes.io/docs/tasks/tools/) |

### AWS Configuration

1. **Configure AWS credentials**:
   ```bash
   aws configure
   ```

2. **Ensure you have permissions** to create:
   - EKS clusters
   - VPC resources
   - ECR repositories
   - IAM roles and policies

## Deploy Steps

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

This downloads the required providers:
- AWS provider (~> 5.0)
- Kubernetes provider (~> 2.0)
- terraform-aws-modules/vpc/aws (v5.0)
- terraform-aws-modules/eks/aws (v20.0)

### 2. Plan the deployment

```bash
terraform plan
```

Review the execution plan to ensure it matches your expectations.

### 3. Apply the configuration

```bash
terraform apply
```

**Note**: This will take approximately **15-20 minutes** to complete as EKS cluster creation is time-consuming.

### 4. Verify deployment

After `terraform apply` completes, verify the outputs:

```bash
terraform output
```

You should see:
- `cluster_name`
- `cluster_endpoint`
- `cluster_ca_data`
- `kubeconfig_helper`
- `ecr_repository_uri`

## Push an Image to ECR

### 1. Authenticate Docker to ECR

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

Replace `<account-id>` with your AWS account ID (from `terraform output`).

### 2. Build and tag your image

```bash
docker build -t payment-api .
docker tag payment-api:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/payment-api:latest
```

### 3. Push to ECR

```bash
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/payment-api:latest
```

## Connect kubectl to the Cluster

### 1. Update kubeconfig

Use the command from `terraform output kubeconfig_helper`:

```bash
aws eks update-kubeconfig --region us-east-1 --name demo-eks-cluster
```

### 2. Verify cluster access

```bash
kubectl get nodes
kubectl get pods -A
```

You should see the EKS managed node group nodes and system pods running.

## Architecture Overview

### VPC Configuration
- **VPC CIDR**: 10.0.0.0/16
- **Public subnets**: 2 (10.0.1.0/24, 10.0.2.0/24)
- **Private subnets**: 2 (10.0.10.0/24, 10.0.20.0/24)
- **NAT Gateway**: Single NAT for private subnet egress
- **Internet Gateway**: For public subnet access

### EKS Cluster
- **Kubernetes version**: 1.35
- **Managed node group**: 
  - Instance type: t3.medium
  - Scaling: 1-3 nodes (desired: 2)
  - OS: Amazon Linux 2023 (AL2023)
  - Placement: Private subnets only
  - Public IPs: Disabled

### EKS Add-ons (Managed)
1. **vpc-cni** (created before node group)
2. **kube-proxy** (created after node group)
3. **coredns** (created after node group)
4. **aws-ebs-csi-driver** (created after node group with dedicated IRSA role)

### ECR Repository
- **Name**: payment-api
- **Tag mutability**: IMMUTABLE
- **Scanning**: Enabled on push
- **Lifecycle policy**:
  - Keep last 10 tagged images
  - Expire untagged images after 7 days

## IAM Roles

### EKS Node IAM Role
Attached policies:
- `AmazonEKSWorkerNodePolicy` - Node join and cluster communication
- `AmazonEKS_CNI_Policy` - VPC CNI networking
- `AmazonEC2ContainerRegistryReadOnly` - ECR image pull

### EBS CSI Driver IAM Role
- **Trust**: `system:serviceaccount:kube-system:ebs-csi-controller-sa`
- **Policy**: `AmazonEBSCSIDriverPolicy`
- **Note**: Separate from application IRSA roles

## Access Control

### Cluster Admin Access
The following principals have `AmazonEKSClusterAdminPolicy`:
- The Terraform user running `terraform apply`
- Any ARNs specified in `var.cluster_admin_principal_arns`

Access is granted via explicit `aws_eks_access_entry` and `aws_eks_access_policy_association` resources.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete:
- EKS cluster and all workloads
- VPC and networking resources
- ECR repository and all images
- IAM roles and policies

## Variables

Customize the deployment by editing `variables.tf`:

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `cluster_name` | `demo-eks-cluster` | EKS cluster name |
| `eks_version` | `1.35` | Kubernetes version |
| `node_instance_type` | `t3.medium` | Node instance type |
| `node_desired_count` | `2` | Desired node count |
| `node_min_size` | `1` | Minimum node count |
| `node_max_size` | `3` | Maximum node count |
| `ecr_repository_name` | `payment-api` | ECR repository name |

## Troubleshooting

### EKS Add-on Stuck in CREATING

If `aws-ebs-csi-driver` add-on is stuck:
1. Check the EBS CSI driver IAM role exists
2. Verify the OIDC provider is created
3. Ensure the trust policy matches `system:serviceaccount:kube-system:ebs-csi-controller-sa`

### Node Group Issues

If nodes fail to launch:
1. Check VPC has sufficient IP addresses
2. Verify IAM role has correct policies
3. Check AWS service limits for EC2 instances

### kubectl Connection Issues

If you can't connect:
1. Ensure `aws eks update-kubeconfig` was run
2. Check your kubeconfig context: `kubectl config get-contexts`
3. Verify the cluster endpoint is publicly accessible

## Cost Estimation

Approximate monthly cost (us-east-1):
- EKS cluster: $70/month
- 2x t3.medium nodes: ~$60/month
- NAT Gateway: ~$30/month
- ECR storage: ~$1-5/month (depending on images)

**Total**: ~$160-165/month

## Tags

All resources are tagged with:
- `Environment`: `demo`
- `Project`: `payment-api`
- `ManagedBy`: `terraform`
