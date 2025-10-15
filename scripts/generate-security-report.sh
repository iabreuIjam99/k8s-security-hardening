#!/bin/bash
# Generate comprehensive security report for the cluster

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPORT_DIR="security-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/security-report-$TIMESTAMP.md"

mkdir -p "$REPORT_DIR"

echo -e "${GREEN}Generating Security Report...${NC}"
echo ""

# Start report
cat > "$REPORT_FILE" << EOF
# Kubernetes Security Report
**Generated:** $(date)
**Cluster:** $(kubectl config current-context)

---

## Executive Summary

EOF

# Function to add section
add_section() {
    local title="$1"
    echo "" >> "$REPORT_FILE"
    echo "## $title" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Function to check status
check_component() {
    local component="$1"
    local namespace="$2"
    local selector="$3"
    
    if kubectl get pods -n "$namespace" -l "$selector" --no-headers 2>/dev/null | grep -q "Running"; then
        echo "✅ $component: Running" >> "$REPORT_FILE"
        return 0
    else
        echo "❌ $component: Not Running" >> "$REPORT_FILE"
        return 1
    fi
}

# Component Status
add_section "Component Status"
echo -e "${YELLOW}Checking component status...${NC}"

check_component "OPA Gatekeeper" "gatekeeper-system" "control-plane=controller-manager"
check_component "Falco" "falco" "app.kubernetes.io/name=falco"
check_component "Prometheus" "monitoring" "app.kubernetes.io/name=prometheus"
check_component "Grafana" "monitoring" "app.kubernetes.io/name=grafana"

# Cluster Info
add_section "Cluster Information"
echo -e "${YELLOW}Gathering cluster info...${NC}"

cat >> "$REPORT_FILE" << EOF
- **Kubernetes Version:** $(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}')
- **Node Count:** $(kubectl get nodes --no-headers | wc -l)
- **Namespace Count:** $(kubectl get namespaces --no-headers | wc -l)
- **Pod Count:** $(kubectl get pods --all-namespaces --no-headers | wc -l)
EOF

# Node Information
add_section "Node Status"
echo -e "${YELLOW}Checking nodes...${NC}"

echo '```' >> "$REPORT_FILE"
kubectl get nodes -o wide >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"

# Security Policies
add_section "Security Policies"
echo -e "${YELLOW}Checking OPA policies...${NC}"

CONSTRAINT_COUNT=$(kubectl get constraints --no-headers 2>/dev/null | wc -l)
echo "- **Active Constraints:** $CONSTRAINT_COUNT" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$CONSTRAINT_COUNT" -gt 0 ]; then
    echo "### Policy Status" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    kubectl get constraints --no-headers 2>/dev/null >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
fi

# Policy Violations
add_section "Policy Violations"
echo -e "${YELLOW}Checking for violations...${NC}"

VIOLATIONS=$(kubectl get constraints -o json 2>/dev/null | jq -r '.items[].status.violations[]? | "\(.kind)/\(.name) in \(.namespace // "cluster-wide")"' 2>/dev/null | wc -l)

if [ "$VIOLATIONS" -gt 0 ]; then
    echo "⚠️ **Found $VIOLATIONS policy violations**" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    kubectl get constraints -o json 2>/dev/null | jq -r '.items[] | select(.status.violations != null) | "Constraint: \(.metadata.name)\nViolations:\n\(.status.violations | map("  - \(.kind)/\(.name) in \(.namespace // "cluster")") | join("\n"))"' >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
else
    echo "✅ **No policy violations found**" >> "$REPORT_FILE"
fi

# Falco Alerts
add_section "Runtime Security (Falco)"
echo -e "${YELLOW}Checking Falco alerts...${NC}"

if kubectl get pods -n falco -l app.kubernetes.io/name=falco --no-headers 2>/dev/null | grep -q "Running"; then
    FALCO_ALERTS=$(kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=100 --since=24h 2>/dev/null | grep -i "priority" | wc -l)
    echo "- **Alerts in last 24h:** $FALCO_ALERTS" >> "$REPORT_FILE"
    
    if [ "$FALCO_ALERTS" -gt 0 ]; then
        echo "" >> "$REPORT_FILE"
        echo "### Recent Critical Alerts" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 --since=24h 2>/dev/null | grep -i "critical\|error" >> "$REPORT_FILE" || echo "No critical alerts" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
    fi
else
    echo "⚠️ Falco is not running" >> "$REPORT_FILE"
fi

# Network Policies
add_section "Network Security"
echo -e "${YELLOW}Checking network policies...${NC}"

NETPOL_COUNT=$(kubectl get networkpolicies --all-namespaces --no-headers 2>/dev/null | wc -l)
echo "- **Network Policies:** $NETPOL_COUNT" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$NETPOL_COUNT" -gt 0 ]; then
    echo "### Network Policies by Namespace" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    kubectl get networkpolicies --all-namespaces >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
fi

# Pod Security
add_section "Pod Security Assessment"
echo -e "${YELLOW}Analyzing pod security...${NC}"

echo "### Pods Running as Root" >> "$REPORT_FILE"
ROOT_PODS=$(kubectl get pods --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.spec.securityContext.runAsNonRoot != true) | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l)
echo "- **Count:** $ROOT_PODS" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "### Privileged Containers" >> "$REPORT_FILE"
PRIV_PODS=$(kubectl get pods --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[]?.securityContext.privileged == true) | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l)
echo "- **Count:** $PRIV_PODS" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "### Pods Without Resource Limits" >> "$REPORT_FILE"
NO_LIMITS=$(kubectl get pods --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[] | .resources.limits == null) | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l)
echo "- **Count:** $NO_LIMITS" >> "$REPORT_FILE"

# RBAC Analysis
add_section "RBAC Configuration"
echo -e "${YELLOW}Analyzing RBAC...${NC}"

echo "- **ClusterRoles:** $(kubectl get clusterroles --no-headers | wc -l)" >> "$REPORT_FILE"
echo "- **ClusterRoleBindings:** $(kubectl get clusterrolebindings --no-headers | wc -l)" >> "$REPORT_FILE"
echo "- **Roles:** $(kubectl get roles --all-namespaces --no-headers | wc -l)" >> "$REPORT_FILE"
echo "- **RoleBindings:** $(kubectl get rolebindings --all-namespaces --no-headers | wc -l)" >> "$REPORT_FILE"

# Secrets
add_section "Secrets Management"
echo -e "${YELLOW}Checking secrets...${NC}"

SECRETS_COUNT=$(kubectl get secrets --all-namespaces --no-headers 2>/dev/null | wc -l)
echo "- **Total Secrets:** $SECRETS_COUNT" >> "$REPORT_FILE"

# Vulnerabilities Summary
add_section "Security Recommendations"
echo -e "${YELLOW}Generating recommendations...${NC}"

cat >> "$REPORT_FILE" << EOF
Based on the analysis:

EOF

if [ "$VIOLATIONS" -gt 0 ]; then
    echo "- ⚠️ **High Priority:** Fix $VIOLATIONS policy violations" >> "$REPORT_FILE"
fi

if [ "$ROOT_PODS" -gt 0 ]; then
    echo "- ⚠️ **Medium Priority:** $ROOT_PODS pods running as root - configure runAsNonRoot" >> "$REPORT_FILE"
fi

if [ "$PRIV_PODS" -gt 0 ]; then
    echo "- 🔴 **Critical:** $PRIV_PODS privileged containers detected - remove privileged flag" >> "$REPORT_FILE"
fi

if [ "$NO_LIMITS" -gt 0 ]; then
    echo "- ⚠️ **Medium Priority:** $NO_LIMITS pods without resource limits" >> "$REPORT_FILE"
fi

if [ "$NETPOL_COUNT" -eq 0 ]; then
    echo "- ⚠️ **High Priority:** No network policies found - implement network segmentation" >> "$REPORT_FILE"
fi

# Compliance Status
add_section "Compliance Status"

cat >> "$REPORT_FILE" << EOF
| Control | Status | Notes |
|---------|--------|-------|
| Admission Control | $([ "$CONSTRAINT_COUNT" -gt 0 ] && echo "✅ Pass" || echo "❌ Fail") | $CONSTRAINT_COUNT policies active |
| Runtime Security | $(kubectl get pods -n falco --no-headers 2>/dev/null | grep -q "Running" && echo "✅ Pass" || echo "❌ Fail") | Falco monitoring |
| Network Policies | $([ "$NETPOL_COUNT" -gt 0 ] && echo "✅ Pass" || echo "⚠️ Warn") | $NETPOL_COUNT policies |
| Non-root Containers | $([ "$ROOT_PODS" -eq 0 ] && echo "✅ Pass" || echo "⚠️ Warn") | $ROOT_PODS violations |
| Resource Limits | $([ "$NO_LIMITS" -eq 0 ] && echo "✅ Pass" || echo "⚠️ Warn") | $NO_LIMITS violations |
| Privileged Containers | $([ "$PRIV_PODS" -eq 0 ] && echo "✅ Pass" || echo "❌ Fail") | $PRIV_PODS detected |
EOF

# Footer
cat >> "$REPORT_FILE" << EOF

---

## Next Steps

1. Review and address high-priority recommendations
2. Investigate any policy violations
3. Review Falco alerts for suspicious activity
4. Update network policies as needed
5. Schedule next security audit

**Report Location:** \`$REPORT_FILE\`

EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Report Generated Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Report saved to: ${BLUE}$REPORT_FILE${NC}"
echo ""
echo -e "View report:"
echo -e "  cat $REPORT_FILE"
echo ""
echo -e "Or open in browser (if using VS Code):"
echo -e "  code $REPORT_FILE"
echo ""

# Generate summary
echo -e "${YELLOW}Summary:${NC}"
echo -e "  Constraints: $CONSTRAINT_COUNT"
echo -e "  Violations: $VIOLATIONS"
echo -e "  Root Pods: $ROOT_PODS"
echo -e "  Privileged Pods: $PRIV_PODS"
echo -e "  Network Policies: $NETPOL_COUNT"
echo ""

# Return exit code based on critical issues
if [ "$PRIV_PODS" -gt 0 ] || [ "$VIOLATIONS" -gt 5 ]; then
    echo -e "${RED}⚠️  Critical issues found! Please review the report.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ No critical issues found.${NC}"
    exit 0
fi
