# Quick Start Guide

Get your Kubernetes security hardening stack up and running in 15 minutes!

## Prerequisites Check

```bash
# Check all required tools
aws --version         # AWS CLI >= 2.0
terraform version     # Terraform >= 1.0
kubectl version       # kubectl >= 1.24
helm version          # Helm >= 3.0
```

## 5-Step Quick Start

### Step 1: Clone and Configure (2 min)

```bash
# Clone repository
git clone <your-repo-url>
cd k8s-security-hardening

# Configure AWS
aws configure
# Enter your credentials when prompted

# Set variables
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars and set:
# - allowed_cidr_blocks to your IP
# - cluster_name to your desired name
```

### Step 2: Deploy Infrastructure (10-15 min)

```bash
# Initialize and apply
terraform init
terraform plan
terraform apply  # Type 'yes' when prompted

# This creates:
# ✓ VPC with public/private subnets
# ✓ EKS cluster with security hardening
# ✓ IAM roles and policies
# ✓ KMS encryption keys
```

### Step 3: Configure kubectl (1 min)

```bash
# Update kubeconfig
aws eks update-kubeconfig --name your-cluster-name --region us-east-1

# Verify connection
kubectl get nodes
```

### Step 4: Install Security Stack (5-8 min)

```bash
cd ../../../scripts
chmod +x install-security-stack.sh
./install-security-stack.sh

# This installs:
# ✓ OPA Gatekeeper (policy enforcement)
# ✓ Falco (runtime security)
# ✓ Prometheus (monitoring)
# ✓ Grafana (dashboards)
# ✓ Security policies
```

### Step 5: Verify and Access (2 min)

```bash
# Run security tests
chmod +x security-tests.sh
./security-tests.sh

# Access Grafana (in new terminal)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000
# Login: admin/admin

# View Falco alerts (in new terminal)
kubectl logs -n falco -l app.kubernetes.io/name=falco -f
```

## What You Get

### 🛡️ Security Components

| Component | Purpose | Access |
|-----------|---------|--------|
| **OPA Gatekeeper** | Policy enforcement | `kubectl get constraints` |
| **Falco** | Runtime monitoring | `kubectl logs -n falco -l app.kubernetes.io/name=falco` |
| **Prometheus** | Metrics collection | `kubectl port-forward -n monitoring svc/prometheus 9090:9090` |
| **Grafana** | Security dashboards | `kubectl port-forward -n monitoring svc/grafana 3000:80` |

### 📋 Implemented Policies

- ✅ Container resource limits required
- ✅ Privileged containers blocked
- ✅ Approved container registries only
- ✅ Non-root users enforced
- ✅ Network policies (default deny)
- ✅ Pod Security Standards

### 📊 Dashboards Available

1. **Security Overview** - Overall security posture
2. **Falco Alerts** - Runtime security events
3. **Policy Violations** - OPA Gatekeeper violations
4. **Resource Usage** - Container resources

## Quick Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# View security policies
kubectl get constrainttemplates
kubectl get constraints

# Check Falco alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50

# View policy violations
kubectl get constraints -o json | jq '.items[].status.violations'

# Test security (try to create privileged pod - should fail)
kubectl run test --image=nginx --privileged=true

# Access monitoring
make grafana      # Port-forward Grafana
make prometheus   # Port-forward Prometheus
make falco-logs   # View Falco logs
```

## Testing the Security

Try these commands to see policies in action:

```bash
# 1. Try to create pod without resource limits (BLOCKED)
kubectl run test-no-limits --image=nginx
# Expected: Error from OPA Gatekeeper

# 2. Try to create privileged pod (BLOCKED)
kubectl run test-priv --image=nginx --privileged=true
# Expected: Error - privileged containers not allowed

# 3. Deploy secure workload (ALLOWED)
kubectl apply -f manifests/workloads/secure-deployment.yaml
# Expected: Deployment created successfully

# 4. Check Falco for any suspicious activity
kubectl logs -n falco -l app.kubernetes.io/name=falco -f
# Watch for real-time security events
```

## Common Use Cases

### Deploy a New Application Securely

```bash
# Use the secure deployment template
cp manifests/workloads/secure-deployment.yaml my-app-deployment.yaml

# Edit for your app
# Then apply
kubectl apply -f my-app-deployment.yaml
```

### Add Custom Security Policy

```bash
# 1. Create constraint template
vim policies/constraints/my-policy.yaml

# 2. Validate
kubectl apply --dry-run=client -f policies/constraints/my-policy.yaml

# 3. Apply
kubectl apply -f policies/constraints/my-policy.yaml

# 4. Test
kubectl get constraints
```

### Monitor Security Events

```bash
# Real-time Falco alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco -f

# View in Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000/dashboards

# Check policy violations
kubectl get constraints
```

## Troubleshooting

### Can't connect to cluster
```bash
aws eks update-kubeconfig --name your-cluster-name --region us-east-1
kubectl cluster-info
```

### Gatekeeper not enforcing policies
```bash
# Check Gatekeeper status
kubectl get pods -n gatekeeper-system
kubectl logs -n gatekeeper-system -l control-plane=controller-manager

# Re-apply constraints
kubectl apply -f policies/constraints/
```

### Falco not generating alerts
```bash
# Check Falco status
kubectl get pods -n falco
kubectl logs -n falco -l app.kubernetes.io/name=falco

# Trigger test alert
kubectl exec -it <any-pod> -- /bin/sh
# Should see Falco alert for shell access
```

## Next Steps

1. **Customize Policies**
   - Edit `policies/constraints/` for your needs
   - Add organization-specific rules
   - [Policy Documentation](docs/policies.md)

2. **Configure Monitoring**
   - Import custom Grafana dashboards
   - Set up alert notifications
   - Configure Slack/PagerDuty integration

3. **Deploy Applications**
   - Use secure deployment templates
   - Test against policies
   - Monitor runtime behavior

4. **Production Hardening**
   - Review [Best Practices](docs/best-practices.md)
   - Run CIS benchmark
   - Configure backup strategy

## Useful Make Commands

```bash
make help          # Show all available commands
make all           # Complete setup (init + apply + install)
make validate      # Validate policies
make test          # Run security tests
make grafana       # Access Grafana
make prometheus    # Access Prometheus
make falco-logs    # View Falco logs
make destroy       # Destroy infrastructure
```

## Resources

- 📖 [Full Installation Guide](docs/installation.md)
- 🔒 [Security Best Practices](docs/best-practices.md)
- 📋 [Policy Guide](docs/policies.md)
- 🐛 [Troubleshooting](docs/troubleshooting.md)

## Get Help

- Check the [docs/](docs/) directory
- View logs: `kubectl logs -n <namespace> <pod-name>`
- Describe resources: `kubectl describe <resource> <name>`

## Clean Up

When done testing:

```bash
# Destroy all infrastructure
cd terraform/environments/dev
terraform destroy  # Type 'yes' when prompted

# Or use make
make destroy
```

---

**⭐ Tip:** Use `make` commands for easier management!

```bash
make all        # Deploy everything
make test       # Test security
make destroy    # Clean up
```
