# OPA Gatekeeper Policies Guide

## Overview

This guide explains the OPA (Open Policy Agent) Gatekeeper policies implemented in this project and how to customize them.

## Architecture

```
Kubernetes API
      ↓
Admission Webhook
      ↓
OPA Gatekeeper
      ↓
ConstraintTemplates (Policy Logic)
      ↓
Constraints (Policy Enforcement)
```

## Implemented Policies

### 1. Required Resources Policy

**Purpose:** Ensures all containers have CPU and memory limits defined.

**Location:** `policies/constraints/required-resources.yaml`

**Why it matters:**
- Prevents resource exhaustion
- Enables proper scheduling
- Protects cluster stability

**Example violation:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
spec:
  containers:
  - name: app
    image: nginx
    # Missing resources! Will be rejected
```

**Correct usage:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: good-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
```

### 2. Block Privileged Containers

**Purpose:** Prevents containers from running in privileged mode.

**Location:** `policies/constraints/block-privileged.yaml`

**Why it matters:**
- Privileged containers have root access to the host
- Major security risk
- Violates least privilege principle

**Example violation:**
```yaml
securityContext:
  privileged: true  # Will be rejected!
```

### 3. Allowed Container Registries

**Purpose:** Only allows containers from approved registries.

**Location:** `policies/constraints/allowed-repos.yaml`

**Why it matters:**
- Prevents pulling images from untrusted sources
- Supply chain security
- Malware prevention

**Customize allowed registries:**
```yaml
parameters:
  repos:
    - "docker.io/"
    - "gcr.io/"
    - "your-company.azurecr.io/"  # Add your registry
```

### 4. Require Labels (Optional)

**Purpose:** Enforces required labels on resources.

**Create this policy:**
```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }
```

## Testing Policies

### Test a Policy Manually

```bash
# Try to create a pod that violates a policy
kubectl run test-pod --image=nginx --dry-run=server
```

### Audit Existing Resources

```bash
# Check which resources violate policies
kubectl get constraints

# View violations for a specific constraint
kubectl describe constraint must-have-resources
```

## Creating Custom Policies

### Step 1: Write the ConstraintTemplate

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8scustompolicy
spec:
  crd:
    spec:
      names:
        kind: K8sCustomPolicy
      validation:
        openAPIV3Schema:
          type: object
          properties:
            # Define parameters here
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8scustompolicy
        
        violation[{"msg": msg}] {
          # Your policy logic in Rego
        }
```

### Step 2: Create the Constraint

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sCustomPolicy
metadata:
  name: my-custom-policy
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
  parameters:
    # Your parameters
```

### Step 3: Test and Apply

```bash
# Validate syntax
kubectl apply --dry-run=client -f custom-policy.yaml

# Apply the policy
kubectl apply -f custom-policy.yaml

# Monitor for issues
kubectl get constraints
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

## Common Rego Patterns

### Check if field exists
```rego
violation[{"msg": msg}] {
  not input.review.object.spec.securityContext
  msg := "SecurityContext is required"
}
```

### Iterate over containers
```rego
violation[{"msg": msg}] {
  container := input.review.object.spec.containers[_]
  # Check something about container
}
```

### Use parameters
```rego
violation[{"msg": msg}] {
  allowed := input.parameters.allowedValues
  actual := input.review.object.spec.someField
  not actual in allowed
  msg := sprintf("Value %v not in allowed list", [actual])
}
```

## Excluding Namespaces

Exclude system namespaces from policies:

```yaml
spec:
  match:
    excludedNamespaces:
      - "kube-system"
      - "kube-public"
      - "kube-node-lease"
      - "gatekeeper-system"
```

## Enforcement vs Audit Mode

### Enforcement (Default)
- Blocks non-compliant resources
- Immediate security

```yaml
spec:
  enforcementAction: deny
```

### Audit Mode
- Logs violations but allows resources
- Good for testing new policies

```yaml
spec:
  enforcementAction: warn
```

## Monitoring Policy Violations

### View all constraints
```bash
kubectl get constraints --all-namespaces
```

### Check specific constraint
```bash
kubectl describe constraint must-have-resources
```

### Export violations for reporting
```bash
kubectl get constraints -o json | jq '.items[].status.violations'
```

## Best Practices

1. **Start with Audit Mode**
   - Test policies in warn mode first
   - Analyze impact
   - Then switch to deny mode

2. **Document Policies**
   - Add clear descriptions
   - Explain why policy exists
   - Provide examples

3. **Version Control**
   - Track policy changes in Git
   - Review policy updates
   - Test before deploying

4. **Monitor Impact**
   - Watch Gatekeeper logs
   - Track violation metrics
   - Adjust as needed

5. **Gradual Rollout**
   - Start with one namespace
   - Expand gradually
   - Get feedback from teams

## Troubleshooting

### Policy not enforcing
```bash
# Check Gatekeeper is running
kubectl get pods -n gatekeeper-system

# Check constraint status
kubectl describe constraint <name>

# View Gatekeeper logs
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

### Policy too strict
```bash
# Switch to warn mode temporarily
kubectl patch constraint <name> --type='json' -p='[{"op": "replace", "path": "/spec/enforcementAction", "value": "warn"}]'
```

## Resources

- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/)
- [Rego Playground](https://play.openpolicyagent.org/)
- [Policy Library](https://github.com/open-policy-agent/gatekeeper-library)
