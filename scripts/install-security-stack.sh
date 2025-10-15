#!/bin/bash
# Script to install the complete security stack on Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}K8s Security Stack Installation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
    command -v helm >/dev/null 2>&1 || { echo -e "${RED}helm is required but not installed.${NC}" >&2; exit 1; }
    
    kubectl cluster-info >/dev/null 2>&1 || { echo -e "${RED}Cannot connect to cluster.${NC}" >&2; exit 1; }
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
}

# Install OPA Gatekeeper
install_gatekeeper() {
    echo -e "${YELLOW}Installing OPA Gatekeeper...${NC}"
    
    kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
    
    echo "Waiting for Gatekeeper to be ready..."
    kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=300s
    
    echo -e "${GREEN}✓ OPA Gatekeeper installed${NC}"
}

# Apply OPA policies
apply_policies() {
    echo -e "${YELLOW}Applying OPA policies...${NC}"
    
    # Wait a bit for Gatekeeper CRDs to be fully available
    sleep 10
    
    kubectl apply -f ../policies/constraints/
    
    echo -e "${GREEN}✓ OPA policies applied${NC}"
}

# Install Falco
install_falco() {
    echo -e "${YELLOW}Installing Falco...${NC}"
    
    # Add Falco Helm repository
    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm repo update
    
    # Create namespace
    kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Falco with custom rules
    helm upgrade --install falco falcosecurity/falco \
        --namespace falco \
        --set falco.rules_file[0]=/etc/falco/falco_rules.yaml \
        --set falco.rules_file[1]=/etc/falco/falco_rules.local.yaml \
        --set falco.rules_file[2]=/etc/falco/k8s_audit_rules.yaml \
        --set falco.json_output=true \
        --set falco.log_level=info \
        --set falco.priority=warning \
        --set ebpf.enabled=true \
        --set-file customRules.rules=../falco/rules/custom-rules.yaml
    
    echo -e "${GREEN}✓ Falco installed${NC}"
}

# Install Prometheus and Grafana
install_monitoring() {
    echo -e "${YELLOW}Installing Prometheus and Grafana...${NC}"
    
    # Add Prometheus Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Create namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install kube-prometheus-stack
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set grafana.adminPassword=admin \
        --wait
    
    echo -e "${GREEN}✓ Monitoring stack installed${NC}"
    echo -e "${YELLOW}Grafana credentials: admin/admin${NC}"
}

# Apply security policies
apply_security_policies() {
    echo -e "${YELLOW}Applying security policies...${NC}"
    
    kubectl apply -f ../manifests/security/
    
    echo -e "${GREEN}✓ Security policies applied${NC}"
}

# Install Falco Exporter for Prometheus
install_falco_exporter() {
    echo -e "${YELLOW}Installing Falco Exporter...${NC}"
    
    helm upgrade --install falco-exporter falcosecurity/falco-exporter \
        --namespace falco \
        --set serviceMonitor.enabled=true
    
    echo -e "${GREEN}✓ Falco Exporter installed${NC}"
}

# Main installation flow
main() {
    check_prerequisites
    echo ""
    
    install_gatekeeper
    echo ""
    
    apply_policies
    echo ""
    
    install_falco
    echo ""
    
    install_falco_exporter
    echo ""
    
    install_monitoring
    echo ""
    
    apply_security_policies
    echo ""
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Access Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "2. Access Prometheus: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    echo "3. Check Falco logs: kubectl logs -n falco -l app.kubernetes.io/name=falco -f"
    echo "4. View Gatekeeper constraints: kubectl get constraints"
    echo ""
}

main
