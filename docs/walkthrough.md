# Walkthrough — building the platform, step by step

> Storytelling build log. Each phase records *what I set out to do*, the key
> commands, and the **reason** behind them — written so my future self can relearn
> the whole platform from this one file.

---

## Phase 0 — Environment & repo (secret hygiene first)

**Goal:** working toolchain, Azure login, and a repo that is secret-safe from the
very first commit.

Verified `git`, `docker`, `node`, `az`, `terraform`, `kubectl`, `gh` are present.
Created the GitHub repo and, before writing any real file, added a `.gitignore`
that blocks `*.tfstate`, `*.tfvars` (keeping `*.example.tfvars`), `.env`, keys,
and `node_modules`. The rule I'm following the whole way: **git holds code and
templates; secrets and state live in Azure, GitHub Secrets, or Kubernetes — never
in the repo.** Putting the guardrail in commit #1 means there's never a window
where a secret could slip in.

**Azure access detour (real-world):** my first `az login` landed on a subscription
in another directory (`Default Directory`) where I'm only a *guest* — every
`az provider register` returned `AuthorizationFailed`. Root cause: the *active*
subscription was one I could see but had no role on. Fix: a senior granted me
**Owner** on subscription `1e87da18…`, after which provider registration and
resource creation worked. Lesson: being able to *see* a subscription ≠ having
rights in it; check the active subscription and your RBAC role first.

---

## Phase 1 — Frontend, backend, Docker, Compose (Task 1)

**Goal:** two separate apps that run locally with `docker compose up -d`.

- **Backend** — Express on port 8080. `/` returns `Application is running`,
  `/health` returns `{"status":"ok"}` (the exact contract the assessment
  specifies), plus `/api/status` and `/api/info` for the dashboard. I split the
  Express *app* (`app.js`) from the *server* (`server.js`) so tests exercise the
  routes without opening a port — the standard pattern that avoids flaky,
  port-conflict tests.
- **Frontend** — a React (Vite) dashboard served by nginx. It calls the backend
  through **relative `/api` paths**; nginx reverse-proxies those to `backend:8080`.
  This is the key portability decision: the same browser code works locally, in
  Compose, and behind the Kubernetes ingress, because *something* always proxies
  `/api`. No hardcoded backend URL anywhere.
- **Dockerfiles** — multi-stage. Backend installs prod-only deps (`npm ci
  --omit=dev`) and runs as a non-root user. Frontend builds with Node, then ships
  only the static files on nginx. Smaller images, smaller attack surface.
- **Compose** — backend published on `8080` (so `curl localhost:8080` works per
  spec), frontend on `8081`, joined on a private bridge network; frontend waits on
  the backend's healthcheck.

Verified: `docker compose up -d --build` → both containers healthy, the two curls
returned the exact required strings, dashboard live at `:8081`.

**Troubleshooting note:** first `docker compose up` failed with *"no configuration
file provided"* — I'd run it from the parent folder. Compose looks for
`docker-compose.yml` in the current directory; `cd` into the project fixed it.

---

## Phase 2 — CI/CD with GitHub Actions (Task 2)

**Goal:** one pipeline that tests, builds, tags, pushes, releases, and (eventually)
deploys.

Wrote `.github/workflows/deploy.yml` with four jobs: `test` (Jest + Vitest),
`build-and-push` (build both images, tag with the **git commit SHA**, push to
GitHub Container Registry), `release` (cut a GitHub Release on `v*` tags), and
`deploy` (an honest **mock** printing the exact `kubectl` commands until AKS
exists). Two deliberate choices: images are tagged by commit SHA, never `latest`
as the source of truth, so any running image traces to an exact commit; and the
build job is skipped on pull requests so PRs never publish. Result: all jobs green,
both images visible under the repo's Packages. Full detail in
[`ci-cd.md`](./ci-cd.md).

---

## Phase 3 — Terraform (in progress)

**Goal:** provision AKS + ACR + network + private PostgreSQL with custom modules
and a remote, locked state backend.

### Remote state bootstrap
Terraform records what it created in a **state file**, which can contain secrets
and must never be lost or committed. So before writing modules I created the
backend by hand with `az`: a resource group, a locked-down storage account
(`--allow-blob-public-access false`, TLS 1.2, blob versioning + 7-day soft delete),
and a `tfstate` container. State locking comes free via Azure blob **leases** — two
applies can't run at once.

### The constrained-Owner discovery (important)
My Owner role carries an **ABAC condition** limiting which roles I can assign. The
condition's allowlisted role ID (`8e3af657-a8ff-443c-a75c-2fe8c4bcb635`) is the
**Owner** role itself — meaning I can only assign *Owner*, nothing else. Two
consequences:
1. I couldn't self-assign `Storage Blob Data Contributor`, so **AAD data-plane auth
   to the state blob failed** (`terraform init` → 403 `AuthorizationPermissionMismatch`).
   **Fix:** authenticate the backend with the storage **account key**, supplied via
   the `ARM_ACCESS_KEY` environment variable — so the key stays out of every file
   and only lives in my shell session. This is the "secrets outside Terraform"
   principle applied literally.
2. The AKS→ACR `AcrPull` role assignment will hit the same wall — I'll need a
   fallback (image-pull secret, or a senior runs one `az role assignment create`).
   Flagged for the AKS module.

### First apply
`terraform apply` created `rg-devops-dev` and wrote `dev.terraform.tfstate` to the
container — confirming the full write path (lock → create → remote state). Safety
detail I hit: Terraform only accepts the literal word `yes`; typing `1` correctly
cancelled the apply.

**Every new terminal:** re-export the key before Terraform commands:
```bash
export ARM_ACCESS_KEY=$(az storage account keys list \
  -g rg-devops-tfstate -n tfstatedevops1783530332 --query "[0].value" -o tsv)
```

### Building the infrastructure, module by module
Each module was written, `plan`-reviewed, and `apply`-ed on its own so a failure had a
small blast radius:
- **network** — VNet `10.20.0.0/16`, `snet-aks` and `snet-db`, and the NSG that allows
  5432 *only* from the AKS subnet (the core of Task 4).
- **acr** + **monitoring** — a registry (admin disabled) and a Log Analytics workspace.
- **aks** — the cluster on the custom subnet, with a user-assigned identity. Here the
  **constrained Owner** bit us: a custom-subnet cluster needs a *Network Contributor*
  role assignment, and the kubelet needs *AcrPull* — neither of which my ABAC condition
  lets me assign. The workaround: assign **Owner** (the only role I'm allowed to grant),
  narrowly scoped to the VNet and the ACR. Over-privileged but scoped, self-service, and
  documented — the module code still defaults to the correct least-privilege roles.
- **database** — the managed PostgreSQL Flexible Server was **offer-restricted** in the
  region, so I pivoted to a **PostgreSQL VM** in `snet-db` (no public IP), configured by
  cloud-init, with a private DNS A record `postgres.devops.internal → 10.20.2.4`.

Two subscription restrictions shaped the build and are worth remembering: **B-series VMs
were blocked** (switched to `standard_d2as_v7`), and **managed PostgreSQL was region-
restricted** (switched to a VM). Both are documented in the troubleshooting log — the
lesson being that "not allowed" (offer/policy) is different from "out of quota".

---

## Phase 4 — Kubernetes manifests + deploy (Task 3)

**Goal:** the apps live on AKS, exposed on HTTPS, backend internal-only.

Built the images straight into ACR (`az acr build`, tagged `v1` — never `latest`), then
applied the manifests: 2 replicas each, readiness + liveness probes, resource
requests/limits, backend config from a **ConfigMap** and the DB password from a **Secret**
created at deploy time from `terraform output` (never in git). The backend Service is
**ClusterIP** (internal); the ingress exposes only the frontend, which proxies `/api` to
the backend — so the backend is never directly reachable from outside. Confirmed
load-balancing by calling `/api/info` twice and watching the pod hostname change.

### The five-layer ingress→TLS debugging saga (the interesting part)
Getting `https://app.chishty.me` live meant peeling back five layers, each masking the
next:
1. **NSG missing 80/443** — a bring-your-own NSG on the AKS subnet means AKS doesn't add
   the LoadBalancer rules; I added them.
2. **Wrong NSG destination** — the rule must target the LB frontend (`*`), not the subnet
   CIDR, because Azure evaluates the flow against the public IP.
3. **The real blocker — health probe** — even with NSGs open, the LB timed out. The
   Azure HTTP health probe hit `/` and got a **308** from ingress-nginx; Azure only treats
   **200** as healthy, so every backend was marked down and traffic was black-holed. Fixed
   by pointing the probe at `/healthz`.
4. **cert-manager backoff** — after the earlier failures the Certificate sat in a retry
   backoff; deleting it let ingress-shim recreate it fresh.
5. **Success** — with HTTP reachable, the Let's Encrypt HTTP-01 challenge passed and the
   cert issued in ~26 seconds. `curl -I https://app.chishty.me` → `HTTP/2 200` with HSTS.

This is fully written up in [`troubleshooting-log.md`](./troubleshooting-log.md) — the
"allowed but still times out → it's the health probe" lesson is the kind of layered
diagnosis the job is really about.

---

## Phase 5 — Private database connectivity (Task 4)

**Goal:** the backend actually talks to the private database, and prove it's not public.

Added a `/api/db` endpoint (node-postgres) that connects using the ConfigMap/Secret env
vars and runs a real query, plus a **Database (private)** card in the dashboard. Rebuilt
as `v2` and rolled it out (a real rolling update, no downtime). Verified the whole private
path:
- `nc postgres.devops.internal 5432` from a Pod → `10.20.2.4:5432 open` (private DNS +
  NSG + VM listening).
- `curl https://app.chishty.me/api/db` → `{"connected":true, ... "PostgreSQL 14.23"}`.
- `az vm show` → **no public IP**.

Design and verification are documented in [`private-database.md`](./private-database.md).

---

## What I'd change for production
Captured in [`future-improvements.md`](./future-improvements.md): Key Vault-backed
secrets, image scanning, Prometheus/Grafana alerting, HPA + cluster autoscaler, a private
API server, a WAF, GitOps with Argo CD, canary deploys, DB backup/DR, default-deny
NetworkPolicies, and using least-privilege roles (Network Contributor / AcrPull) once the
ABAC constraint is lifted.
