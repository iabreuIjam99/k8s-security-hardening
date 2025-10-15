# Installation Guide

## Prerequisites

Before starting the installation, ensure you have the following tools installed:

### Required Tools

- **AWS CLI** (>= 2.0)
  ```bash
  aws --version
  ```

- **Terraform** (>= 1.0)
  ```bash
  terraform version
  ```

- **kubectl** (>= 1.24)
  ```bash
  kubectl version --client
  ```

- **Helm** (>= 3.0)
  ```bash
  helm version
  ```

- **Git**
  ```bash
  git --version
  ```

### AWS Account Requirements

- AWS account with appropriate permissions
- IAM user with programmatic access
- Sufficient service quotas for:
  - VPCs
  - EKS clusters
  - EC2 instances
  - Elastic IPs

## Step-by-Step Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd k8s-security-hardening
```

### 2. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter output format (json)
```

### 3. Customize Variables

Copy the example variables file and customize it:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region      = "us-east-1"
environment     = "dev"
cluster_name    = "my-security-cluster"
kubernetes_version = "1.28"

# Add your IP for kubectl access
allowed_cidr_blocks = ["YOUR_IP/32"]

# Customize node groups
node_groups = {
  general = {
    desired_size   = 2
    min_size       = 1
    max_size       = 4
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
    labels = {
      role = "general"
    }
    taints = []
  }
}
```

### 4. Initialize Terraform

```bash
cd terraform/environments/dev
terraform init
```

### 5. Review Infrastructure Plan

```bash
terraform plan
```

Review the output carefully. It will show:
- VPC and subnets to be created
- EKS cluster configuration
- Security groups
- IAM roles

### 6. Apply Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. This will take 15-20 minutes.

### 7. Configure kubectl

```bash
aws eks update-kubeconfig --name your-cluster-name --region us-east-1
```

Verify connection:

```bash
kubectl get nodes
```

### 8. Install Security Components

```bash
cd ../../../scripts
chmod +x install-security-stack.sh
./install-security-stack.sh
```

This script will install:
- OPA Gatekeeper
- Falco
- Prometheus
- Grafana
- Security policies

### 9. Verify Installation

```bash
chmod +x security-tests.sh
./security-tests.sh
```

### 10. Access Monitoring Tools

**Grafana:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
Open http://localhost:3000
- Username: admin
- Password: admin

**Prometheus:**
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```
Open http://localhost:9090

## Post-Installation

### Import Grafana Dashboards

1. Navigate to Grafana (http://localhost:3000)
2. Go to Dashboards → Import
3. Import the following dashboards from the `monitoring/grafana/` directory:
   - Security Overview
   - Falco Alerts
   - OPA Policy Violations

### Configure Falco Alerts

Edit Falco configuration to send alerts to your preferred channel:

```bash
kubectl edit configmap falco -n falco
```

Add Slack webhook or other notification methods.

### Set up Regular Backups

Configure automated backups for:
- Terraform state (use S3 backend)
- Cluster etcd snapshots
- Persistent volume data

### Enable Cluster Autoscaling

Install the Cluster Autoscaler:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

## Troubleshooting

### Common Issues

**Issue: Terraform apply fails with quota errors**
```
Solution: Request quota increases in AWS Console
```

**Issue: kubectl cannot connect to cluster**
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Update kubeconfig
aws eks update-kubeconfig --name your-cluster-name --region us-east-1
```

**Issue: Pods stuck in Pending state**
```bash
# Check node status
kubectl get nodes

# Describe pod to see events
kubectl describe pod <pod-name>
```

**Issue: Gatekeeper blocking legitimate pods**
```bash
# Check constraint violations
kubectl get constraints

# View specific constraint
kubectl describe constraint <constraint-name>
```

## Uninstallation

To destroy the infrastructure:

```bash
cd terraform/environments/dev
terraform destroy
```

**⚠️ Warning:** This will delete all resources. Ensure you have backups!

## Next Steps

- [Configure Policies](policies.md)
- [Set up Monitoring](monitoring.md)
- [Best Practices](best-practices.md)
- [Troubleshooting Guide](troubleshooting.md)
