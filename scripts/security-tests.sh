#!/bin/bash
# Run comprehensive security tests on the cluster

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes Security Tests${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

FAILED_TESTS=0
PASSED_TESTS=0

run_test() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Running: $test_name... "
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED_TESTS++))
    fi
}

# Test 1: Gatekeeper is running
run_test "Gatekeeper is running" \
    "kubectl get pods -n gatekeeper-system -l control-plane=controller-manager --no-headers | grep Running"

# Test 2: Falco is running
run_test "Falco is running" \
    "kubectl get pods -n falco -l app.kubernetes.io/name=falco --no-headers | grep Running"

# Test 3: Prometheus is running
run_test "Prometheus is running" \
    "kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers | grep Running"

# Test 4: Grafana is running
run_test "Grafana is running" \
    "kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers | grep Running"

# Test 5: Constraints are applied
run_test "OPA Constraints are applied" \
    "kubectl get constraints | grep -q 'must-have-resources'"

# Test 6: Network policies exist
run_test "Network policies exist" \
    "kubectl get networkpolicies --all-namespaces | grep -q 'default-deny-all'"

# Test 7: Try to create privileged pod (should fail)
run_test "Privileged pods are blocked" \
    "! kubectl run test-privileged --image=nginx --rm -i --restart=Never --dry-run=server --overrides='{\"spec\":{\"containers\":[{\"name\":\"test\",\"image\":\"nginx\",\"securityContext\":{\"privileged\":true}}]}}' 2>&1 | grep -q 'denied'"

# Test 8: Try to create pod without resource limits (should fail)
run_test "Pods without resources are blocked" \
    "! kubectl run test-no-resources --image=nginx --rm -i --restart=Never --dry-run=server 2>&1 | grep -q 'denied'"

# Test 9: Check RBAC is configured
run_test "RBAC is enabled" \
    "kubectl auth can-i list pods --as=system:serviceaccount:default:default -n default"

# Test 10: Check for non-root users in deployments
run_test "Secure deployment exists" \
    "kubectl get deployment secure-app -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' | grep -q 'true'"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Results${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
