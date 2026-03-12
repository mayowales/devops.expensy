# CI/CD Pipeline Documentation

## Overview

The Expensy project uses a **GitHub Actions** CI/CD pipeline that automates building, testing, containerizing, and deploying the application to Azure Kubernetes Service (AKS).

## Pipeline Stages

```
Push to any branch
    │
    ▼
[ 1. Build ] ── Compiles frontend and backend
    │
    ▼
[ 2. Test ] ── Runs tests (placeholder for now)
    │
    ▼                          ← Only on main branch ↓
[ 3. Docker Build & Push ] ── Builds images, pushes to Docker Hub
    │
    ▼
[ 4. Deploy ] ── Manual approval required, then deploys to AKS
```

**On feature branches:** Only stages 1 and 2 run (fast feedback).
**On main branch:** All 4 stages run (full pipeline with deployment).

## Pipeline File

Location: `.github/workflows/ci-cd.yaml`

### Stage 1: Build

Installs dependencies and compiles both services. This catches syntax errors, missing imports, and TypeScript compilation failures before building Docker images.

- **Backend**: Runs `npm ci` then `npm run build` in `./expensy_backend`
- **Frontend**: Runs `npm ci` then `npm run build` in `./expensy_frontend` with `NEXT_PUBLIC_API_URL` set

### Stage 2: Test

Runs after build succeeds. Currently a placeholder since no tests exist yet. Replace `echo` commands with `npm test` when tests are added.

### Stage 3: Docker Build & Push

Only runs on pushes to `main`. Builds Docker images for both services and pushes them to Docker Hub with two tags:
- **Git SHA tag** (e.g., `abc123f`): Every image is tied to an exact commit for traceability
- **`latest` tag**: Convenience tag for the most recent build

The frontend build passes `NEXT_PUBLIC_API_URL` as a build argument since Next.js bakes environment variables into the JavaScript at build time.

### Stage 4: Deploy to AKS

Uses the `production` GitHub Environment which **requires manual approval**. A reviewer must click "Approve" in GitHub Actions before deployment proceeds.

Deployment uses `kubectl set image` to update the running deployments to the new image tag (Git SHA), then `kubectl rollout status` waits until all pods are running the new version.

---

## Environment Variables

### Build-Time Variables

| Variable | Where Set | Purpose |
|---|---|---|
| `NEXT_PUBLIC_API_URL` | GitHub Actions workflow `env` block | Baked into frontend at build time. Points to `https://wale-expensy-safe.duckdns.org` |

### Runtime Variables (Kubernetes)

These are set via Terraform in `namespace.tf` and injected into pods at runtime.

**ConfigMap (non-sensitive):**

| Variable | Value | Used By |
|---|---|---|
| `PORT` | `8706` | Backend |
| `REDIS_HOST` | `redis` | Backend |
| `REDIS_PORT` | `6379` | Backend |

**Secrets (sensitive):**

| Variable | Purpose | Used By |
|---|---|---|
| `MONGO_ROOT_USERNAME` | MongoDB authentication | MongoDB |
| `MONGO_ROOT_PASSWORD` | MongoDB authentication | MongoDB |
| `DATABASE_URI` | Full MongoDB connection string | Backend |
| `REDIS_PASSWORD` | Redis authentication | Redis, Backend |

These are managed in `terraform.tfvars` (never committed to Git) and created as Kubernetes Secrets by Terraform.

---

## Required Secrets and Tokens

### GitHub Repository Secrets

Set these in: **GitHub Repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | How to Get It | Purpose |
|---|---|---|
| `DOCKERHUB_USERNAME` | Your Docker Hub username (e.g., `mayowales`) | Authenticates to Docker Hub for pushing images |
| `DOCKERHUB_TOKEN` | Docker Hub → Account Settings → Security → New Access Token | Password alternative for Docker Hub (more secure than using your actual password) |
| `KUBE_CONFIG` | Run: `kubectl config view --minify --flatten --context=dv-ft-main-cluster` and copy the output | Allows GitHub Actions to run kubectl commands against the AKS cluster |

### GitHub Environment

Set up in: **GitHub Repo → Settings → Environments → New environment**

| Environment Name | Protection Rule | Purpose |
|---|---|---|
| `production` | Required reviewers (add yourself) | Pauses the Deploy stage until someone manually approves |

### How to Generate Each Token

**Docker Hub Access Token:**
1. Go to https://hub.docker.com
2. Click your profile → Account Settings → Security
3. Click "New Access Token"
4. Name it "github-actions"
5. Copy the token and save it as `DOCKERHUB_TOKEN` in GitHub

**Kube Config:**
```bash
# This outputs a clean kubeconfig with only the AKS cluster context
kubectl config view --minify --flatten --context=dv-ft-main-cluster
```
Copy the entire output and save it as `KUBE_CONFIG` in GitHub.

---

## How to Trigger the Pipeline

**Automatic:** Push to any branch or merge a PR to main.

```bash
git add .
git commit -m "your changes"
git push origin your-branch
```

**Manual re-run:** Go to GitHub → Actions → click the workflow → Re-run all jobs.

## How to Approve a Deployment

1. Go to GitHub → Actions tab
2. Click the running workflow
3. The Deploy stage shows "Review deployments"
4. Click it → check "production" → click "Approve and deploy"

## How to Roll Back

If a deployment breaks something:

```bash
# Roll back backend to previous version
kubectl rollout undo deployment/backend -n wale-expensy-ns

# Roll back frontend to previous version
kubectl rollout undo deployment/frontend -n wale-expensy-ns
```
