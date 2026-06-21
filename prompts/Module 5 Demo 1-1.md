Run the following commands and save the output to a folder called cost-management:
# EKS cluster and node group details
aws eks describe-cluster --name [CLUSTER_NAME] --output json
aws eks list-nodegroups --cluster-name [CLUSTER_NAME] --output json
aws eks describe-nodegroup --cluster-name [CLUSTER_NAME] --nodegroup-name [NODEGROUP_NAME] --output json

# EC2 instances (EKS worker nodes)
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=[CLUSTER_NAME]" \
  --query "Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,LaunchTime:LaunchTime,AZ:Placement.AvailabilityZone}" \
  --output table

# CloudWatch CPU utilisation for EKS nodes (last 14 days)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=[ASG_NAME] \
  --start-time $(date -u -d '14 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 \
  --statistics Average Maximum \
  --output table

# EBS volumes — find unattached and gp2 volumes
aws ec2 describe-volumes \
  --query "Volumes[*].{ID:VolumeId,Size:Size,Type:VolumeType,State:State,IOPS:Iops,Attachments:Attachments[0].State}" \
  --output table

# EBS snapshots owned by this account
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[*].{ID:SnapshotId,Size:VolumeSize,StartTime:StartTime,Description:Description}" \
  --output table

# Load balancers
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[*].{Name:LoadBalancerName,Type:Type,State:State.Code,DNS:DNSName,Created:CreatedTime}" \
  --output table

# Load balancer target group health (identify idle load balancers)
aws elbv2 describe-target-groups --output json

# ECR repositories and image count
aws ecr describe-repositories \
  --query "repositories[*].{Name:repositoryName,URI:repositoryUri,Created:createdAt}" \
  --output table

# ECR images — find old and untagged images
aws ecr list-images \
  --repository-name [ECR_REPO_NAME] \
  --filter tagStatus=UNTAGGED \
  --query "imageIds[*].imageDigest" \
  --output table

# Data transfer — NAT Gateway usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/NatGateway \
  --metric-name BytesOutToDestination \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 2592000 \
  --statistics Sum \
  --output table

# Savings Plans and Reserved Instance coverage
aws ce get-savings-plans-coverage \
  --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --output json

# Current month cost breakdown by service
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json

# Right-sizing recommendations from AWS Compute Optimizer
aws compute-optimizer get-ec2-instance-recommendations \
  --output json

aws compute-optimizer get-auto-scaling-group-recommendations \
  --output json