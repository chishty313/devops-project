# Troubleshooting (Task 6)

Brief, practical answers. Several of these we hit for real during the build — see
[`troubleshooting-log.md`](./troubleshooting-log.md) for the lived versions.

### 1. Pod is in CrashLoopBackOff. What do you check?
The container starts, exits, and Kubernetes keeps restarting it. Check, in order:
`kubectl describe pod` (events, last state, exit code), `kubectl logs <pod> --previous`
(the crashed container's output), then the usual causes: a bad command/entrypoint, a
missing env var or Secret/ConfigMap, the app failing to bind its port, a failing
migration/init, or an OOMKill (exit 137 → raise the memory limit). Also verify the
image tag exists and the config the app needs is actually mounted.

### 2. Deployment is successful, but the app is not reachable. What do you check?
"Deployed" only means Pods are running. Walk the request path: does the **Service**
have endpoints (`kubectl get endpoints`)? Do the Service `selector` labels match the Pod
labels? Is the **targetPort** the port the container actually listens on? Are the Pods
**Ready** (readiness probe passing)? Then the ingress: is there an Ingress with the right
host/path and `ingressClassName`, is the ingress controller running, and does the DNS
name resolve to the load balancer IP? Test layer by layer: `port-forward` the Pod, then
the Service, then hit the ingress.

### 3. Difference between readiness and liveness probe?
**Readiness** decides whether a Pod should receive traffic — if it fails, the Pod is
removed from Service endpoints but **not** restarted (used for "warming up" or a
temporarily unhealthy dependency). **Liveness** decides whether the container is alive —
if it fails, the kubelet **restarts** the container (used to recover a hung process).
Rule of thumb: liveness = "is it deadlocked?", readiness = "can it serve right now?".
Keep liveness cheap and dependency-free so a slow downstream doesn't cause restart loops.

### 4. Docker build works locally but fails in the pipeline. Why?
Common causes: files present locally but not committed (so the CI checkout lacks them),
`.dockerignore` excluding something CI needs, a dependency cached in your local layers
but not pinned in the lockfile, a different base-image architecture (Apple Silicon
`arm64` vs CI `amd64`), missing build args/secrets/registry auth in CI, or reliance on
local network/credentials. Reproduce with a clean clone and `--no-cache`.

### 5. Pipeline fails during Docker build. What do you check?
Read the failing step's log first. Check: registry login/permissions, the Dockerfile
path and build context, base-image pull rate limits, the failing `RUN` command
(dependency install), build-arg/secret availability, disk space on the runner, and
whether `npm ci` matches the committed lockfile. Run the same build command locally with
the same context to reproduce.

### 6. Certificate renewal failed. What do you check?
For cert-manager + Let's Encrypt: `kubectl describe certificate/certificaterequest/order/
challenge` for the failure reason. Usual culprits: the HTTP-01 challenge path isn't
reachable from the internet (DNS wrong, LB/NSG/firewall blocking 80, or the app
redirecting the ACME path), DNS-01 credentials expired, the ACME account/rate limit,
clock skew, or the Ingress annotation/issuer misconfigured. Confirm
`http://<host>/.well-known/acme-challenge/...` is reachable. (We hit exactly this —
an LB health-probe issue blocked port 80.)

### 7. Ingress returns 502 or 504. What do you check?
**502 (bad gateway)** = the ingress reached an upstream but got an invalid/failed
response: the backend Pod crashed, isn't Ready, the Service has no endpoints, or a
port/protocol mismatch (e.g. ingress speaking HTTP to an HTTPS-only backend). **504
(gateway timeout)** = the upstream didn't respond in time: the backend is slow/hung, a
downstream (DB) is blocking, or timeouts are too low. Check backend Pod health/logs,
Service endpoints, the target port, and ingress timeout annotations.

### 8. Vendor SFTP connection to port 22 times out. What do you check?
A timeout (vs "connection refused") points to a firewall/routing drop rather than the
service being down. Check: is the vendor's IP allowed outbound (egress firewall / NAT)
and are we allowed inbound on their side (they may require our egress IP allowlisted)?
NSG/security-group rules for port 22, correct host/port, DNS resolution, and whether the
route exists. Test with `nc -zv host 22` / `ssh -v`. "Timeout" almost always = firewall
or wrong address; "refused" = reachable host, nothing listening.

### 9. Terraform plan wants to recreate the cluster. What do you check?
Read the plan's `# forces replacement` markers to see which attribute triggers it.
Common causes: a changed immutable field (network plugin, node subnet, name, location,
some identity changes), provider upgrades changing defaults, or drift where someone
changed the resource in the portal. Before applying: check state drift, pin the provider
version, and if the change is safe/desired use `moved` blocks or `terraform state`
surgery, or `-target`/`lifecycle { ignore_changes }` to avoid an accidental rebuild.
Never apply a cluster-recreate without understanding why.

### 10. How would you upgrade AKS/EKS safely?
Upgrade the **control plane** first, then node pools, one minor version at a time. Check
the release notes and API deprecations. On AKS: `az aks get-upgrades`, upgrade the
control plane, then upgrade node pools with **surge** settings (`max_surge`) so new nodes
join before old ones drain — cordoned/drained gracefully, respecting PodDisruptionBudgets.
Test in dev/staging first, ensure workloads have ≥2 replicas and PDBs, have a rollback
plan, and do it during a maintenance window.

### 11. Frontend loads, but backend API calls fail. What do you check?
The static frontend is fine but its API calls break. Check the browser network tab for
the failing status/URL. Then: is the API path proxied correctly (our nginx/ingress
routes `/api` → backend)? Is the backend Service reachable and Ready? CORS if calling
cross-origin? Auth token/headers? A wrong base URL baked into the frontend build? Test
the backend directly (`curl` the Service via port-forward or the ingress `/api` path) to
isolate frontend vs backend.

### 12. Backend pod is running, but database connection times out. What do you check?
Timeout = network/firewall, not auth. Check: does the DB hostname resolve
(`nslookup`/`nc` from the Pod)? Is the DB port open from the Pod's subnet (NSG/security
group allowing the app subnet on 5432)? Is the DB actually up and listening on that
address (`listen_addresses`)? Correct host/port in config? We verify with
`kubectl run ... nc -zv postgres.devops.internal 5432`. If `nc` fails it's network; if
`nc` works but the app fails, it's credentials/pg_hba/SSL.

### 13. Private DNS is not resolving the database hostname. What do you check?
Check that the **private DNS zone exists** and has the A record, that it's **linked to
the VNet** the Pods run in (`azurerm_private_dns_zone_virtual_network_link`), and that the
Pod is using the VNet DNS (CoreDNS → Azure DNS `168.63.129.16`). Test from a Pod:
`nslookup postgres.devops.internal`. Common misses: zone not linked to the AKS VNet, wrong
record name, or the app using an external resolver. (On EKS: Route 53 private hosted zone
associated with the VPC.)

### 14. How would you rotate database credentials safely?
Zero-downtime rotation: (1) create a **new** DB user/password (or set a second password)
so both old and new work; (2) update the secret store (Key Vault / the Kubernetes Secret)
with the new value; (3) roll the backend Deployment so Pods pick up the new secret; (4)
verify connectivity; (5) revoke the old credential. Automate via Terraform + Key Vault
with versioning; never edit the password in place with a single credential (that causes
an outage window). Rotate on a schedule and after any suspected exposure.

### 15. Secrets were accidentally committed to GitHub. What do you do?
Treat the secret as **compromised immediately** — rotate/revoke it first (a key in git
history is exposed even after deletion). Then remove it from history (`git filter-repo`
or BFG), force-push, and invalidate any caches/forks. Add it to `.gitignore`, move the
value to a proper secret store (GitHub Secrets / Key Vault), and add a pre-commit secret
scanner (gitleaks/trufflehog) so it can't happen again. Order matters: **rotate before
cleanup** — scrubbing history without rotating leaves you exposed.
