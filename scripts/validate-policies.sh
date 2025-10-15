#!/bin/bash
# Script to validate OPA policies before applying them

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Validating OPA Policies${NC}"
echo ""

POLICY_DIR="../policies/constraints"
ERRORS=0

# Validate YAML syntax
echo -e "${YELLOW}Checking YAML syntax...${NC}"
for file in "$POLICY_DIR"/*.yaml; do
    if [ -f "$file" ]; then
        echo -n "Validating $(basename "$file")... "
        if kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            ((ERRORS++))
        fi
    fi
done

echo ""

# Check if Gatekeeper is installed
echo -e "${YELLOW}Checking Gatekeeper installation...${NC}"
if kubectl get namespace gatekeeper-system >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Gatekeeper is installed${NC}"
else
    echo -e "${RED}✗ Gatekeeper is not installed${NC}"
    ((ERRORS++))
fi

echo ""

# Test policies with example resources
echo -e "${YELLOW}Testing policies with example resources...${NC}"

# Test 1: Deployment without resource limits (should be rejected)
echo -n "Test 1: Deployment without resource limits... "
cat <<EOF | kubectl apply --dry-run=server -f - 2>&1 | grep -q "denied" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-no-resources
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: test
        image: nginx:latest
EOF

# Test 2: Privileged container (should be rejected)
echo -n "Test 2: Privileged container... "
cat <<EOF | kubectl apply --dry-run=server -f - 2>&1 | grep -q "denied" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
spec:
  containers:
  - name: test
    image: nginx:latest
    securityContext:
      privileged: true
EOF

echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All validations passed!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS validation(s) failed!${NC}"
    exit 1
fi
