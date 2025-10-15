# Kubernetes Security Best Practices

## Container Security

### 1. Use Minimal Base Images

❌ **Bad:**
```dockerfile
FROM ubuntu:latest
```

✅ **Good:**
```dockerfile
FROM alpine:3.18
# or
FROM gcr.io/distroless/static-debian11
```

**Why:**
- Smaller attack surface
- Fewer vulnerabilities
- Faster deployment

### 2. Don't Run as Root

❌ **Bad:**
```yaml
spec:
  containers:
  - name: app
    image: myapp
    # Runs as root by default
```

✅ **Good:**
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    image: myapp
    securityContext:
      allowPrivilegeEscalation: false
```

### 3. Use Read-Only Root Filesystem

✅ **Good:**
```yaml
securityContext:
  readOnlyRootFilesystem: true
volumeMounts:
- name: tmp
  mountPath: /tmp
- name: cache
  mountPath: /var/cache
```

### 4. Drop All Capabilities

✅ **Good:**
```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE  # Only if needed
```

## Network Security

### 1. Implement Network Policies

Default deny all:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

Then whitelist specific traffic:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

### 2. Use Service Mesh for mTLS

Consider implementing Istio or Linkerd for:
- Automatic mTLS
- Traffic encryption
- Zero-trust networking

## RBAC Best Practices

### 1. Principle of Least Privilege

❌ **Bad:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: bad-binding
subjects:
- kind: ServiceAccount
  name: my-app
  namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-admin  # Too permissive!
```

✅ **Good:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: ServiceAccount
  name: my-app
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
```

### 2. Don't Use Default Service Account

✅ **Good:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
automountServiceAccountToken: false
---
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      serviceAccountName: my-app-sa
      automountServiceAccountToken: false  # If not needed
```

## Secrets Management

### 1. Never Hardcode Secrets

❌ **Bad:**
```yaml
env:
- name: DB_PASSWORD
  value: "password123"  # Never do this!
```

✅ **Good:**
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```

### 2. Use External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aws-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: db-credentials
  data:
  - secretKey: password
    remoteRef:
      key: prod/db/password
```

### 3. Encrypt Secrets at Rest

Enable encryption in EKS:
```hcl
# In Terraform
encryption_config {
  provider {
    key_arn = aws_kms_key.eks.arn
  }
  resources = ["secrets"]
}
```

## Image Security

### 1. Scan Images for Vulnerabilities

```yaml
# In CI/CD pipeline
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:latest'
    severity: 'CRITICAL,HIGH'
```

### 2. Sign and Verify Images

Use Cosign:
```bash
# Sign
cosign sign myregistry.io/myapp:latest

# Verify in admission webhook
```

### 3. Use Image Pull Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: regcred
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-config>
---
spec:
  imagePullSecrets:
  - name: regcred
```

## Resource Management

### 1. Always Set Resource Limits

✅ **Required:**
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

### 2. Use Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

### 3. Configure Pod Priority

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "High priority class"
```

## Monitoring and Auditing

### 1. Enable Audit Logging

```yaml
# EKS control plane logging
cluster_enabled_log_types = [
  "api",
  "audit",
  "authenticator",
  "controllerManager",
  "scheduler"
]
```

### 2. Monitor Runtime Behavior with Falco

Install and configure Falco to detect:
- Shell access in containers
- Privilege escalation
- Unexpected process execution
- File system modifications

### 3. Set Up Alerts

```yaml
# Example Prometheus alert
- alert: PodCrashLooping
  expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Pod {{ $labels.pod }} is crash looping"
```

## Supply Chain Security

### 1. Use Software Bill of Materials (SBOM)

```bash
# Generate SBOM
syft myapp:latest -o spdx-json > sbom.json

# Scan SBOM
grype sbom:./sbom.json
```

### 2. Verify Dependencies

```dockerfile
# Use specific versions, not latest
FROM node:18.17.0-alpine

# Verify checksums
RUN wget https://example.com/app.tar.gz && \
    echo "expected_checksum app.tar.gz" | sha256sum -c
```

### 3. Minimize Attack Surface

```dockerfile
# Multi-stage build
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o myapp

FROM gcr.io/distroless/static-debian11
COPY --from=builder /app/myapp /
ENTRYPOINT ["/myapp"]
```

## Compliance

### 1. Run CIS Benchmark

```bash
# Using kube-bench
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# View results
kubectl logs job/kube-bench
```

### 2. Implement Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 3. Regular Security Assessments

Schedule regular:
- Vulnerability scans
- Penetration testing
- Policy audits
- Access reviews

## Disaster Recovery

### 1. Backup Etcd

```bash
# Automated backup
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### 2. Backup Persistent Volumes

Use Velero:
```bash
velero backup create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces production
```

### 3. Test Recovery Procedures

Regularly test:
- Cluster recovery
- Data restoration
- Failover procedures

## Security Checklist

- [ ] All containers run as non-root
- [ ] Read-only root filesystem enabled
- [ ] All capabilities dropped
- [ ] Resource limits defined
- [ ] Network policies implemented
- [ ] RBAC configured with least privilege
- [ ] Secrets stored externally
- [ ] Images scanned for vulnerabilities
- [ ] Audit logging enabled
- [ ] Runtime security monitoring (Falco)
- [ ] Regular backups configured
- [ ] Disaster recovery tested
- [ ] CIS benchmark passing
- [ ] Pod Security Standards enforced

## Resources

- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)
- [NSA Kubernetes Hardening Guide](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
