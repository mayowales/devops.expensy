# Deploying to AKS — Step-by-Step Guide

## Overview

The Expensy application is deployed to a shared Azure Kubernetes Service (AKS) cluster (`dv-ft-main-cluster`) using **Terraform** to manage all Kubernetes resources. Everything runs in an isolated namespace (`wale-expensy-ns`).

## Architecture

```
Internet
    │
    ▼
[ NGINX Ingress Controller ]
    │
    ├── wale-expensy-safe.duckdns.org (HTTPS)
    │   ├── /api/* ──► Backend Service ──► Backend Pods (x2)
    │   └── /*     ──► Frontend Service ──► Frontend Pods (x2)
    │
    └── wale-expensy-unsafe.duckdns.org (HTTP)
        ├── /api/* ──► Backend Service ──► Backend Pods (x2)
        └── /*     ──► Frontend Service ──► Frontend Pods (x2)
                            │
                            ├──► MongoDB StatefulSet (1 pod + 10Gi disk)
                            └──► Redis StatefulSet (1 pod + 2Gi disk)

Monitoring:
    Prometheus (scrapes backend /metrics every 15s)
        └──► Grafana (dashboard at http://<GRAFANA_IP>:3000)
```

## Prerequisites

### Tools Required

- **Azure CLI**: `az` — to authenticate and get cluster credentials
- **kubectl**: to interact with the Kubernetes cluster
- **Terraform**: to deploy infrastructure as code
- **Docker**: to build and push container images
- **Docker Hub account**: to store container images

### Connect to the Cluster

```bash
# 1. Login to Azure
az login

# 2. Get cluster credentials (this configures kubectl)
az aks get-credentials --resource-group <RESOURCE_GROUP> --name dv-ft-main-cluster

# 3. Verify connection
kubectl get nodes

# 4. Confirm the context
kubectl config get-contexts
# The * should be next to dv-ft-main-cluster
```

---

## Step 1: Push Docker Images to Docker Hub

The AKS cluster pulls container images from Docker Hub.

```bash
# Login to Docker Hub
docker login

# Build backend
cd expensy_backend
docker build -t mayowales/devopsexpensy-backend-1:v1 .

# Build frontend (NEXT_PUBLIC_API_URL is baked in at build time)
cd ../expensy_frontend
docker build --build-arg NEXT_PUBLIC_API_URL=https://wale-expensy-safe.duckdns.org \
  -t mayowales/devopsexpensy-frontend-1:v1 .

# Push both images
docker push mayowales/devopsexpensy-backend-1:v1
docker push mayowales/devopsexpensy-frontend-1:v1
```

**Why rebuild the frontend?** `NEXT_PUBLIC_API_URL` tells the frontend where the backend API lives. Next.js bakes this into the JavaScript at build time. For local development it was `http://localhost:8706`, for AKS it must be the actual domain.

---

## Step 2: Configure Terraform

### File Structure

```
terraform/
├── main.tf           # Connects to the cluster via kubeconfig
├── variables.tf      # All configurable inputs
├── terraform.tfvars  # Your actual values (DO NOT commit to Git)
├── namespace.tf      # Namespace + ConfigMap + Secrets
├── mongo.tf          # MongoDB StatefulSet + Service
├── redis.tf          # Redis StatefulSet + Service
├── backend.tf        # Backend Deployment + Service
├── frontend.tf       # Frontend Deployment + Service
├── ingress.tf        # Ingress rules (safe + unsafe domains)
├── nginx-demo.tf     # Nginx demo deployment
├── monitoring.tf     # Prometheus + Grafana
└── outputs.tf        # Info printed after deploy
```

### What Each File Does

| File | Creates | Purpose |
|---|---|---|
| `main.tf` | Nothing | Configures Kubernetes provider using `~/.kube/config` |
| `namespace.tf` | Namespace, ConfigMap, Secret | Isolated space + environment variables + credentials |
| `mongo.tf` | StatefulSet, Service | MongoDB with persistent 10Gi disk |
| `redis.tf` | StatefulSet, Service | Redis cache with persistent 2Gi disk |
| `backend.tf` | Deployment (2 replicas), Service | Express.js API pulling from Docker Hub |
| `frontend.tf` | Deployment (2 replicas), Service | Next.js app pulling from Docker Hub |
| `ingress.tf` | 2 Ingress resources | HTTPS (safe) and HTTP (unsafe) routing |
| `monitoring.tf` | Prometheus + Grafana deployments | Metrics scraping and visualization |

### Set Your Values

Edit `terraform.tfvars`:

```hcl
kube_context   = "dv-ft-main-cluster"
namespace      = "wale-expensy-ns"
backend_image  = "mayowales/devopsexpensy-backend-1:v1"
frontend_image = "mayowales/devopsexpensy-frontend-1:v1"

mongo_root_username = "root"
mongo_root_password = "your-secure-password"
redis_password      = "your-secure-redis-password"
```

---

## Step 3: Deploy with Terraform

```bash
cd terraform/

# Initialize Terraform (downloads the Kubernetes provider)
terraform init

# Preview what will be created
terraform plan

# Deploy everything
terraform apply
```

Terraform creates resources in dependency order:
1. Namespace
2. ConfigMap + Secrets
3. MongoDB + Redis (data stores first)
4. Backend (depends on MongoDB + Redis)
5. Frontend
6. Ingress
7. Prometheus + Grafana

### First Deploy Troubleshooting

If the backend image is cached on nodes, force a fresh pull:

```bash
kubectl delete pods -l app=backend -n wale-expensy-ns
kubectl delete pods -l app=frontend -n wale-expensy-ns
```

---

## Step 4: Configure DNS

The Ingress controller has an external IP assigned by Azure. Point your DuckDNS domains to it:

```bash
# Find the Ingress controller IP
kubectl get svc -n ingress-nginx
```

Go to https://www.duckdns.org and update both domains to point to the external IP:
- `wale-expensy-safe` → `<INGRESS_IP>`
- `wale-expensy-unsafe` → `<INGRESS_IP>`

**Note:** If the Ingress controller is redeployed (shared cluster), the IP may change. Update DuckDNS accordingly.

---

## Step 5: Verify the Deployment

```bash
# All pods should be Running with 1/1 READY
kubectl get pods -n wale-expensy-ns

# Check services
kubectl get svc -n wale-expensy-ns

# Check ingress and certificate
kubectl get ingress -n wale-expensy-ns
kubectl get certificate -n wale-expensy-ns

# Test the backend API
kubectl exec -it deployment/backend -n wale-expensy-ns -- \
  sh -c "wget -qO- http://localhost:8706/api/expenses"

# Check backend logs
kubectl logs deployment/backend -n wale-expensy-ns

# Check frontend logs
kubectl logs deployment/frontend -n wale-expensy-ns
```

### Expected Results

- **https://wale-expensy-safe.duckdns.org** — App loads with HTTPS padlock
- **http://wale-expensy-unsafe.duckdns.org** — App loads without HTTPS
- **http://<GRAFANA_IP>:3000** — Grafana dashboard (admin / expensy123)

---

## Updating the Application

### Option 1: Via CI/CD Pipeline (recommended)

Push code to main → pipeline builds, tests, pushes images → approve deployment in GitHub Actions.

### Option 2: Manual Update

```bash
# Rebuild and push new image
docker build -t mayowales/devopsexpensy-backend-1:v2 ./expensy_backend
docker push mayowales/devopsexpensy-backend-1:v2

# Update the deployment
kubectl set image deployment/backend \
  backend=mayowales/devopsexpensy-backend-1:v2 \
  -n wale-expensy-ns

# Watch the rollout
kubectl rollout status deployment/backend -n wale-expensy-ns
```

### Rolling Back

```bash
# Undo the last deployment
kubectl rollout undo deployment/backend -n wale-expensy-ns
kubectl rollout undo deployment/frontend -n wale-expensy-ns
```

---

## Tearing Down

To remove everything you deployed without affecting other users on the cluster:

```bash
cd terraform/
terraform destroy
```

This deletes the namespace and all resources inside it. Other namespaces are untouched.

---

## Docker-Compose vs Kubernetes Mapping

| docker-compose | Kubernetes (Terraform) | File |
|---|---|---|
| `services.mongo` | StatefulSet + Service | `mongo.tf` |
| `services.redis` | StatefulSet + Service | `redis.tf` |
| `services.backend` | Deployment + Service | `backend.tf` |
| `services.frontend` | Deployment + Service | `frontend.tf` |
| `environment:` (non-secret) | ConfigMap | `namespace.tf` |
| `environment:` (secret) | Secret | `namespace.tf` |
| `ports: "3000:3000"` | Ingress | `ingress.tf` |
| `volumes: mongo_data` | PersistentVolumeClaim | `mongo.tf` |
| `depends_on:` | `depends_on` + probes | `backend.tf` |
| `restart: unless-stopped` | Built-in (K8s always restarts) | Default |
