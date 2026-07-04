# Terraform — AKS Platform (Task 5)

Module-based Terraform that provisions the whole platform: resource group, network,
ACR, Log Analytics, AKS, and a private PostgreSQL VM. **All modules are custom-written**
(no third-party modules), as the assessment requires.

## Layout

```
terraform/
├── provider.tf        # azurerm + random providers
├── versions.tf        # required_version + provider constraints
├── backend.tf         # remote state in Azure Storage (key via ARM_ACCESS_KEY)
├── main.tf            # wires the modules together
├── variables.tf       # env, region, cluster name inputs, node size/count, k8s version, roles
├── outputs.tf         # cluster name, endpoint, registry, network id, db info
├── environments/
│   ├── dev.tfvars           # real values (gitignored)
│   └── dev.example.tfvars   # committed template
└── modules/
    ├── network/       # VNet, subnets, NSGs
    ├── acr/           # container registry
    ├── monitoring/    # Log Analytics workspace
    ├── aks/           # cluster, node pool, identity, role assignments
    └── database/      # private PostgreSQL VM + private DNS
```

## How to run

```bash
# State backend key (never committed) — export once per shell
export ARM_ACCESS_KEY=$(az storage account keys list \
  -g rg-devops-tfstate -n <state-storage-account> --query "[0].value" -o tsv)

terraform init
terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

Variables cover: `environment`, `location`, `project`, `node_count`, `node_size`,
`kubernetes_version`, and the identity role names. Outputs expose the cluster name,
API endpoint, ACR login server/name, VNet ID, and DB host/name.

---

## Maintenance & operations

### How to safely upgrade AKS/EKS
Upgrade the **control plane first**, then node pools, one minor version at a time.
List options with `az aks get-upgrades`. Pin `kubernetes_version`, bump it in tfvars,
`plan` (confirm it's an in-place upgrade, not a replace), then `apply`. Node pools
upgrade with **surge** (`max_surge`) so new nodes join before old ones drain, respecting
PodDisruptionBudgets. Always rehearse in dev/staging first and check API deprecations.

### How to add or resize node pools
- **Resize (scale):** change `node_count` (or enable the cluster autoscaler with
  min/max). This is an in-place change.
- **Change VM size:** the `default_node_pool` `vm_size` is immutable — changing it forces
  a pool replacement. The safe pattern is to add a **new node pool** with the new size,
  cordon/drain the old one, migrate workloads, then remove the old pool — no downtime.
  Model additional pools as their own `azurerm_kubernetes_cluster_node_pool` resources.

### How to maintain Terraform state
State lives in Azure Storage (remote backend) with **blob-lease locking** so two applies
can't collide, plus **blob versioning + soft delete** for recovery. The access key is
supplied via `ARM_ACCESS_KEY` (never in a file). Keep separate state per environment
(separate `key`/container), never edit state by hand except with `terraform state`
commands, and back up before risky operations.

### How to avoid downtime during cluster changes
Run workloads with **≥2 replicas** and **PodDisruptionBudgets**; use node-pool **surge**
upgrades and cordon/drain for node changes; for immutable changes add-new-then-remove-old
(node pools, and blue/green for the cluster itself if ever recreating). Always `plan` and
read `# forces replacement` before `apply`. Keep the ingress/LB and DB stable while
rolling the app.

### How to separate dev, staging, and production
Per-environment **tfvars** (`dev.tfvars`, `staging.tfvars`, `prod.tfvars`) drive naming,
sizing, and region, with **separate state files** (distinct backend `key`/container) and
ideally **separate subscriptions or resource groups** so blast radius is contained. The
`environment` variable prefixes every resource name. Promote the same module code across
envs; only the values change. Add manual approval gates for prod.

### How to handle secrets outside Terraform code
No secret is hardcoded. The DB password is **generated** (`random_password`) and lives only
in the (locked-down, private) remote state; it's injected into Kubernetes as a Secret at
deploy time from `terraform output`. Pipeline credentials go in GitHub Secrets/OIDC. The
production-grade step is **Azure Key Vault** (referenced by Terraform via data sources and
mounted into pods with the Key Vault CSI driver), so secrets never sit in code, tfvars, or
plaintext state.

### What to check if Terraform wants to recreate the cluster
Read the plan's `# forces replacement` line to find the triggering attribute. Typical
causes: an **immutable field** changed (network plugin, node subnet, DNS prefix, location,
some identity settings), a **provider upgrade** changing a default, or **drift** from a
manual portal change. Do NOT apply blindly — reconcile drift (`terraform refresh`/import),
pin the provider version, and use `moved`/`ignore_changes`/`-target` or state surgery to
avoid an accidental rebuild. Recreating a cluster is a full outage.
