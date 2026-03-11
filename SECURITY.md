# Security & Compliance

## 1. IAM — Role-Based Access Control (RBAC)

The shared AKS cluster (dv-ft-main-cluster) uses Azure Active Directory integration for authentication. Access control is managed at two levels:

**Azure Level:**
- Users authenticate via Azure AD before accessing the cluster.
- Cluster access is granted through Azure role assignments (Azure Kubernetes Service Cluster User Role).
- No root or admin credentials are shared — each user authenticates with their own Azure AD identity.

**Kubernetes Level:**
- All Expensy resources are deployed in the wale-expensy-ns namespace, providing isolation from other users on the shared cluster.
- Kubernetes RBAC restricts what each user can do within their namespace.
- Service accounts are scoped to the namespace — pods cannot access resources in other namespaces.

**Best Practices Followed:**
- No cluster-admin credentials are used for application deployment.
- Each team member authenticates individually via Azure AD.
- Namespace isolation ensures resources are not visible to other users.

---

## 2. Network Security

**Namespace Isolation:**
All application components run within the wale-expensy-ns namespace. MongoDB and Redis use headless ClusterIP services — they are only accessible within the cluster and cannot be reached from the internet.

**Service Exposure:**

| Service | Type | Accessible From |
|---|---|---|
| Frontend | ClusterIP (via Ingress) | Internet (through NGINX Ingress) |
| Backend | ClusterIP (via Ingress) | Internet (through NGINX Ingress) |
| MongoDB | Headless ClusterIP | Within namespace only |
| Redis | Headless ClusterIP | Within namespace only |
| Prometheus | ClusterIP | Within namespace only |
| Grafana | LoadBalancer | Internet (for monitoring access) |

**Recommendations for Production:**
- Add Kubernetes NetworkPolicies to restrict pod-to-pod communication (e.g., only backend can reach MongoDB and Redis).
- Move Grafana behind the Ingress with authentication instead of a public LoadBalancer.
- Use Azure Network Security Groups (NSGs) to restrict inbound traffic to the Ingress controller IP only.

---

## 3. TLS/HTTPS

TLS is enabled on the Ingress using cert-manager with Let's Encrypt certificates.

**Setup:**
- cert-manager is installed on the cluster and manages certificate lifecycle automatically.
- A ClusterIssuer (letsencrypt-production) is configured to request certificates from Let's Encrypt using HTTP-01 challenges.
- The Ingress annotation cert-manager.io/cluster-issuer: letsencrypt-production triggers automatic certificate provisioning.

**Domains:**

| Domain | Protocol | TLS Certificate |
|---|---|---|
| wale-expensy-safe.duckdns.org | HTTPS | Let's Encrypt (auto-renewed) |
| wale-expensy-unsafe.duckdns.org | HTTP | None (intentionally insecure for comparison) |

**Certificate Details:**
- Certificate is stored in Kubernetes Secret wale-expensy-safe-tls.
- cert-manager automatically renews certificates before expiry (default: 30 days before).
- The NGINX Ingress controller terminates TLS and forwards decrypted traffic to backend services.

**Verification:**
```bash
kubectl get certificate -n wale-expensy-ns
kubectl describe certificate wale-expensy-safe-tls -n wale-expensy-ns
```

---

## 4. Secrets Management

**Current Implementation:**
- Sensitive credentials (MongoDB password, Redis password, database connection URI) are stored as Kubernetes Secrets.
- Secrets are managed via Terraform with sensitive = true, preventing values from appearing in plan output or logs.
- The terraform.tfvars file containing secret values is excluded from Git via .gitignore.
- Base64 encoding is handled automatically by Terraform.

**Secrets Inventory:**

| Secret Key | Purpose | Used By |
|---|---|---|
| MONGO_ROOT_USERNAME | MongoDB authentication | MongoDB StatefulSet |
| MONGO_ROOT_PASSWORD | MongoDB authentication | MongoDB StatefulSet |
| DATABASE_URI | MongoDB connection string | Backend Deployment |
| REDIS_PASSWORD | Redis authentication | Redis StatefulSet, Backend |

**What is NOT in Secrets (correctly):**
- Non-sensitive config (ports, hostnames) is in a ConfigMap, not a Secret.
- NEXT_PUBLIC_API_URL is baked into the frontend Docker image at build time — it is a public URL, not a secret.

**Best Practices Followed:**
- Secrets are never committed to Git.
- Environment variables reference Secrets via secretKeyRef — values are injected at runtime, not hardcoded.
- Docker images do not contain any secrets.

**Recommendations for Production:**
- Use Azure Key Vault with the CSI Secrets Store Driver to manage secrets externally.
- Enable encryption at rest for Kubernetes Secrets.
- Rotate credentials regularly and use short-lived tokens where possible.

---

## 5. Compliance

**Data Storage:**
- User data (expenses) is stored in MongoDB running within the AKS cluster in the wale-expensy-ns namespace.
- MongoDB data is persisted on Azure Managed Disks (10Gi) via PersistentVolumeClaims.
- Data resides in the Azure region where the AKS cluster is deployed.

**GDPR Considerations (EU Data):**
- The application stores financial expense data (name, amount, category) — no personally identifiable information (PII) like email addresses or national IDs is collected.
- Data is stored within Azure infrastructure. If the cluster is in an EU region, data residency requirements are met.
- For full GDPR compliance in production, implement data export (right to portability), data deletion (right to erasure), access logging, and a privacy policy.

**Security Audit Checklist:**
- [x] No secrets committed to Git
- [x] TLS enabled for production traffic
- [x] Database not exposed to the internet
- [x] Redis not exposed to the internet
- [x] Resource limits set on all pods
- [x] Namespace isolation from other cluster users
- [x] Monitoring and logging enabled
- [ ] NetworkPolicies (recommended for production)
- [ ] Azure Key Vault integration (recommended for production)
- [ ] Pod Security Standards enforcement (recommended for production)
SECEOF
