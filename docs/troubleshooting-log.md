# Troubleshooting log (real issues hit during the build)

Running log of problems I actually hit: **symptom → what I checked → root cause →
fix → lesson.** (Task 6's `troubleshooting.md` answers the assessment's 15 questions;
this file is the lived record that feeds it.)

---

### 1. `az provider register` → `AuthorizationFailed` on every namespace
- **Symptom:** every `az provider register` failed with `AuthorizationFailed` for my
  account.
- **Checked:** `az account show` — the *active* subscription was "Azure subscription 1"
  in a directory (`Default Directory`) where I'm only a guest.
- **Root cause:** I had no RBAC role on that subscription; being able to see it ≠ having
  rights.
- **Fix:** switched intent to a subscription I own; a senior granted me **Owner** on
  `1e87da18…`. Registration then worked.
- **Lesson:** always confirm the active subscription *and* your role before creating.

---

### 2. `terraform init` → 403 `AuthorizationPermissionMismatch` on the state blob
- **Symptom:** backend init failed listing blobs with HTTP 403.
- **Checked:** my role assignment — an earlier attempt to grant myself
  `Storage Blob Data Contributor` had failed.
- **Root cause:** my Owner role has an **ABAC condition** that only lets me assign the
  *Owner* role, so I can't grant myself the Storage Blob **data-plane** role that AAD
  auth to blobs requires. (Container *creation* had worked because that's a
  management-plane action, which Owner allows.)
- **Fix:** switched the backend to storage **account-key** auth via the
  `ARM_ACCESS_KEY` env var (key never committed).
- **Lesson:** management-plane rights (Owner) don't imply data-plane blob rights; those
  are separate `Storage Blob Data *` roles.

---

### 3. `terraform plan` hung at "Acquiring state lock..."
- **Symptom:** plan stalled on acquiring the state lock.
- **Checked:** the state blob's lease status (`az storage blob show … properties.lease`)
  — it was `unlocked`.
- **Root cause:** a transient slow lease acquisition on the first attempt (no real stale
  lock).
- **Fix:** cancelled and re-ran; it acquired and released the lock normally. (If a lease
  is ever genuinely stuck: `az storage blob lease break …`; for a solo plan,
  `-lock=false` is a safe bypass.)
- **Lesson:** "Acquiring state lock" is a blob lease; check the actual lease state before
  assuming corruption.

---

### 4. `docker compose up` → "no configuration file provided: not found"
- **Symptom:** Compose couldn't find a config.
- **Root cause:** run from the parent directory, not the project root.
- **Fix:** `cd` into the project (where `docker-compose.yml` lives).
- **Lesson:** Compose resolves `docker-compose.yml` from the current directory.

---

### 6. AKS create failed: "The VM size of Standard_B2s is not allowed in your subscription"
- **Symptom:** cluster creation returned HTTP 400 — `Standard_B2s` not allowed in `eastus`.
- **Checked:** the error message itself listed every *allowed* VM size — all D/E/F/M
  v7 families, no B-series at all.
- **Root cause:** a subscription-level policy/offer restricts which VM SKUs can be
  used (not a quota issue — quota was 65 vCPUs). B-series is simply blocked here.
- **Fix:** switched `node_size` to `standard_d2as_v7` (smallest allowed general-purpose
  size) in `dev.tfvars` and re-applied. The apply is idempotent, so the already-created
  identity and role assignment were kept and only the cluster was created.
- **Lesson:** "not allowed" ≠ "out of quota". Read the error — Azure lists the exact
  allowed SKUs. Also: Terraform partial failures are safe to resume with re-apply.

### 7. PostgreSQL Flexible Server failed: "LocationIsOfferRestricted" in eastus
- **Symptom:** Flexible Server creation failed — the subscription is restricted from
  provisioning PostgreSQL in `eastus`.
- **Checked:** the error links to a quota-increase page; the restriction is by
  subscription offer + region, not general quota.
- **Root cause:** this subscription's offer can't create PostgreSQL Flexible Server in
  eastus, and VNet-integrated Flexible Server must be in the same region as the VNet —
  so moving just the DB wasn't an option without relocating the whole stack.
- **Fix:** pivoted to a **VM-based PostgreSQL** in the private DB subnet (no public IP,
  NSG allows 5432 only from AKS, private DNS A record). Kept all other infrastructure.
  Removed the subnet delegation (that's only for the managed service).
- **Lesson:** managed services carry region/offer restrictions independent of VM quota;
  a VM-based DB is a valid, fully-private fallback that satisfies the same requirements.

### 8. Ingress 80/443 timed out; Let's Encrypt HTTP-01 challenge failed
- **Symptom:** `curl -I http://app.chishty.me` timed out; cert-manager challenge went
  `invalid` with "Timeout during connect (likely firewall problem)".
- **Checked:** `kubectl -n app describe challenge` (self-check timeout), and that the LB
  had a public IP and DNS resolved to it — so DNS was fine but the packets never landed.
- **Root cause:** the AKS subnet uses a **bring-your-own NSG**. AKS's cloud controller
  only manages the NSG it creates, so it never added the inbound 80/443 allow rules for
  the LoadBalancer service. The empty NSG's default `DenyAllInbound` blocked web traffic.
- **Fix (part 1 — NSG):** added inbound Allow rules for TCP 80/443 (source `Internet`,
  destination `*`) to the AKS subnet NSG. Destination must be `*`/the LB IP, not the
  subnet CIDR — Azure evaluates the flow against the load balancer frontend.
- **Fix (part 2 — the real blocker: health probe):** even with NSGs open, the direct LB
  IP still timed out. The Azure LB health probe was **HTTP GET `/`** on the node ports,
  but ingress-nginx answers `/` with a **308 redirect**, and Azure's HTTP probe only
  treats **200** as healthy — so every backend was marked unhealthy and the LB
  black-holed all traffic. Fixed by pointing the probe at `/healthz` (which returns 200):
  `kubectl -n ingress-nginx annotate svc ingress-nginx-controller \
   service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path=/healthz --overwrite`
- **Lesson:** "allowed but still times out" on an Azure LB usually means **all backends
  fail the health probe**. Check the probe's protocol/port/path against what the app
  actually returns. For ingress-nginx on AKS, set the probe path to `/healthz`.

### 5. `terraform apply` cancelled unexpectedly
- **Symptom:** apply said "Apply cancelled" after I confirmed.
- **Root cause:** I typed `1` at the approval prompt; Terraform only accepts the literal
  word `yes`.
- **Lesson:** the exact-word confirmation is a deliberate guard against accidental applies.
