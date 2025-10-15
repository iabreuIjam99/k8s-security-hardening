# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                      │  │
│  │                                                            │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │ Public Subnet│  │ Public Subnet│  │ Public Subnet│   │  │
│  │  │   AZ-1       │  │   AZ-2       │  │   AZ-3       │   │  │
│  │  │              │  │              │  │              │   │  │
│  │  │  NAT Gateway │  │  NAT Gateway │  │  NAT Gateway │   │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │  │
│  │         │                  │                  │           │  │
│  │  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐   │  │
│  │  │Private Subnet│  │Private Subnet│  │Private Subnet│   │  │
│  │  │   AZ-1       │  │   AZ-2       │  │   AZ-3       │   │  │
│  │  │              │  │              │  │              │   │  │
│  │  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │   │  │
│  │  │ │EKS Nodes │ │  │ │EKS Nodes │ │  │ │EKS Nodes │ │   │  │
│  │  │ └──────────┘ │  │ └──────────┘ │  │ └──────────┘ │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │  │
│  │                                                            │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │            EKS Control Plane                        │  │  │
│  │  │  (Managed by AWS, encrypted with KMS)              │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Security & Monitoring Services                           │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐               │  │
│  │  │   KMS    │  │CloudWatch│  │   IAM    │               │  │
│  │  │Encryption│  │   Logs   │  │  Roles   │               │  │
│  │  └──────────┘  └──────────┘  └──────────┘               │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

## Kubernetes Cluster Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    EKS Cluster                                   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Admission Control Layer                   │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │           OPA Gatekeeper (Policy Enforcement)         │  │ │
│  │  │  • Resource limits required                           │  │ │
│  │  │  • Privileged containers blocked                      │  │ │
│  │  │  • Approved registries only                           │  │ │
│  │  │  • Security context validation                        │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Application Namespaces                   │ │
│  │                                                              │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │ │
│  │  │  default    │  │ production  │  │  staging    │        │ │
│  │  │             │  │             │  │             │        │ │
│  │  │  Network    │  │  Network    │  │  Network    │        │ │
│  │  │  Policies   │  │  Policies   │  │  Policies   │        │ │
│  │  │             │  │             │  │             │        │ │
│  │  │  Workloads  │  │  Workloads  │  │  Workloads  │        │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              ▲                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Security Monitoring Layer                 │ │
│  │                                                              │ │
│  │  ┌──────────────┐         ┌──────────────┐                │ │
│  │  │    Falco     │         │  Prometheus  │                │ │
│  │  │   (Runtime   │         │  (Metrics)   │                │ │
│  │  │   Security)  │◄────────┤              │                │ │
│  │  └──────────────┘         └──────┬───────┘                │ │
│  │         │                         │                         │ │
│  │         │                         ▼                         │ │
│  │         │                  ┌──────────────┐                │ │
│  │         └─────────────────►│   Grafana    │                │ │
│  │                             │ (Dashboards) │                │ │
│  │                             └──────────────┘                │ │
│  └────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

## Security Flow

```
┌─────────────┐
│  Developer  │
└──────┬──────┘
       │ 1. Push Code
       ▼
┌─────────────────────┐
│   GitHub Actions    │
│   CI/CD Pipeline    │
│                     │
│ 2. Security Scans:  │
│   • Terraform (TFSec)│
│   • Containers (Trivy)│
│   • YAML (kubeval)  │
│   • Policies (OPA)  │
└──────┬──────────────┘
       │ 3. Deploy (if passed)
       ▼
┌─────────────────────┐
│  Kubernetes API     │
└──────┬──────────────┘
       │ 4. Admission Request
       ▼
┌─────────────────────┐
│  OPA Gatekeeper     │
│  Policy Evaluation  │
│                     │
│ 5. Checks:          │
│   ✓ Resource limits?│
│   ✓ Security ctx?   │
│   ✓ Approved image? │
│   ✓ Non-root user?  │
└──────┬──────────────┘
       │
       ├─► DENIED ──► Reject & Log
       │
       └─► APPROVED
              │ 6. Deploy
              ▼
       ┌─────────────────┐
       │   Pod Running   │
       └─────┬───────────┘
             │
             │ 7. Runtime Monitoring
             ▼
       ┌─────────────────┐
       │     Falco       │
       │  Watches for:   │
       │  • Shell access │
       │  • Privilege esc│
       │  • File changes │
       │  • Suspicious   │
       │    activity     │
       └─────┬───────────┘
             │ 8. Alerts
             ▼
       ┌─────────────────┐
       │   Prometheus    │
       │   & Grafana     │
       │                 │
       │ 9. Visualize &  │
       │    Alert        │
       └─────────────────┘
```

## Component Interactions

```
┌────────────────────────────────────────────────────────────┐
│                    Infrastructure Layer                     │
│                                                              │
│  Terraform ──► AWS API ──► EKS + VPC + IAM + KMS           │
└────────────────────────────────┬───────────────────────────┘
                                 │
                                 ▼
┌────────────────────────────────────────────────────────────┐
│                   Security Enforcement Layer                │
│                                                              │
│  OPA Gatekeeper ◄──► Kubernetes API ──► Audit Logs         │
│        │                                                     │
│        └──► Constraint Templates ──► Constraints            │
└────────────────────────────────┬───────────────────────────┘
                                 │
                                 ▼
┌────────────────────────────────────────────────────────────┐
│                   Runtime Security Layer                    │
│                                                              │
│  Falco ──► System Calls ──► Rules Engine ──► Alerts        │
│    │                              │                          │
│    └──► Kubernetes Events ────────┘                         │
└────────────────────────────────┬───────────────────────────┘
                                 │
                                 ▼
┌────────────────────────────────────────────────────────────┐
│                    Monitoring Layer                         │
│                                                              │
│  Prometheus ◄──┬──► Falco Exporter                         │
│       │        ├──► Gatekeeper Metrics                      │
│       │        └──► kube-state-metrics                      │
│       │                                                      │
│       └──► Grafana ──► Dashboards + Alerts                 │
└────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Pod Creation Flow
```
kubectl apply
    │
    ▼
API Server
    │
    ▼
Admission Webhooks
    ├─► OPA Gatekeeper (Policy Check)
    │       │
    │       ├─► PASS ──► Continue
    │       └─► FAIL ──► Reject
    │
    ▼
Scheduler
    │
    ▼
Kubelet (Node)
    │
    ▼
Container Runtime
    │
    ▼
Falco (Monitor)
```

### 2. Security Event Flow
```
Container Activity
    │
    ▼
System Call
    │
    ▼
Falco Rule Engine
    │
    ├─► Match Rule?
    │       │
    │       └─► YES ──► Generate Alert
    │                       │
    ▼                       ▼
No Action          Falco Exporter
                          │
                          ▼
                   Prometheus
                          │
                          ▼
                   Grafana Dashboard
                          │
                          ▼
                   Alert Manager
                          │
                          ▼
              Notification (Slack/Email)
```

## Network Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Internet                               │
└─────────────────────┬────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)              │
│                    (Public Subnet)                        │
└─────────────────────┬────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────┐
│               Ingress Controller                          │
│                 (Private Subnet)                          │
│                                                            │
│  ┌──────────────────────────────────────────────────┐   │
│  │         Network Policies                          │   │
│  │  • Default Deny All                               │   │
│  │  • Allow from Ingress                             │   │
│  │  • Allow to specific services                     │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────┬────────────────────────────────────┘
                      │
         ┌────────────┼────────────┐
         │            │            │
         ▼            ▼            ▼
    ┌────────┐  ┌────────┐  ┌────────┐
    │Service │  │Service │  │Service │
    │   A    │  │   B    │  │   C    │
    └────┬───┘  └────┬───┘  └────┬───┘
         │           │           │
         │  Network Policy Rules │
         │  Control Traffic Flow │
         └───────────────────────┘
```

## Deployment Pipeline

```
┌─────────────┐
│  Git Push   │
└──────┬──────┘
       │
       ▼
┌──────────────────────────┐
│  GitHub Actions Trigger  │
└──────┬───────────────────┘
       │
       ├─► Terraform Validate
       ├─► TFSec Scan
       ├─► Checkov Scan
       ├─► YAML Validation
       ├─► OPA Policy Test
       ├─► Trivy Image Scan
       └─► ShellCheck
              │
              ▼
         All Passed?
              │
              ├─► NO ──► Fail Build
              │
              └─► YES
                    │
                    ▼
            Terraform Apply
                    │
                    ▼
            Install Security Stack
                    │
                    ▼
            Run Security Tests
                    │
                    ▼
            Deploy Complete
                    │
                    ▼
            Monitor & Alert
```

## Key Security Boundaries

1. **Network Boundary**: VPC isolation, private subnets
2. **Admission Boundary**: OPA Gatekeeper policies
3. **Runtime Boundary**: Falco monitoring
4. **Access Boundary**: RBAC and IAM
5. **Data Boundary**: KMS encryption

## Scalability

- **Horizontal**: Add more nodes to EKS cluster
- **Vertical**: Resize node instance types
- **Multi-region**: Deploy in multiple AWS regions
- **Multi-cloud**: Extend to GCP/Azure

## High Availability

- Multi-AZ deployment
- Redundant NAT Gateways
- EKS control plane managed by AWS
- Auto-scaling node groups
- Pod disruption budgets

## Disaster Recovery

- Automated etcd backups
- Terraform state in S3
- Velero for backup/restore
- Multi-region capability
- Infrastructure as Code for quick rebuild
