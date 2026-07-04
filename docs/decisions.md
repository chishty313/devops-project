# Decisions log

Why we chose what we chose. One entry per real decision, with the trade-off.

## Cloud & platform
- **Azure + AKS** over AWS/EKS — existing Azure familiarity; managed control plane
  lets us focus on automation/security rather than running the control plane by hand.
- **Managed PostgreSQL Flexible Server** (private access) over a self-managed DB VM —
  cheaper (~$15 vs ~$20/mo), nothing to patch, can be stopped between sessions, and
  still fully private via VNet integration. Trade-off: less low-level control than a VM.

## Apps
- **Node/Express backend + React (Vite) frontend** — industry-standard, minimal, easy
  to test; the React dashboard also *visualizes* the platform and lets us test
  endpoints from the browser.
- **Frontend calls relative `/api`** (proxied by nginx / ingress) instead of a
  hardcoded backend URL — same code runs locally, in Compose, and in Kubernetes.

## CI/CD
- **GitHub Actions** over Jenkins/Azure DevOps — native to the repo, free runners,
  first-class secrets and Releases.
- **Push to GHCR now, ACR later** — GHCR is a real registry needing no secret setup,
  so CI is genuinely publishing today; ACR gets wired in once it exists.
- **Tag images by commit SHA, not `latest`** — every running image traces to an exact
  commit; `latest` is a moving target that makes "what's running?" unanswerable.

## Terraform
- **Custom modules only** — required by the assessment; also forces real understanding
  of each resource.
- **Remote state in Azure Storage + blob-lease locking** — no state on laptops, safe
  concurrent use, recoverable via versioning + soft delete.
- **State auth via storage account key in `ARM_ACCESS_KEY`** (not AAD) — because our
  **constrained Owner role** (ABAC condition allows assigning only the Owner role)
  cannot grant us the `Storage Blob Data` role needed for AAD data-plane access. The
  key is never committed; it lives only in the shell env. Trade-off: a long-lived key
  exists, vs. AAD tokens — acceptable since it's never written to a file and the
  storage account is locked down.

## Known constraint to design around
- **Constrained Owner cannot assign non-Owner roles.** Impacts the AKS→ACR `AcrPull`
  assignment. Planned fallback: Kubernetes image-pull secret, or have a senior run the
  single `az role assignment create` for AcrPull. Decision to be finalized in the AKS
  module.

## Region & sizing
- **East US** — highest quota (65 vCPUs confirmed), lowest cost, all services available.
- **Standard_B2s × 2 nodes** — small and cheap (~4 vCPUs total) for a lab; easily
  resized later via a variable.
- **Destroy between sessions** — everything is Terraform, so `terraform destroy` keeps
  total cost to a few dollars across the whole assessment.
